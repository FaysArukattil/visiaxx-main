// File: lib/core/services/continuous_speech_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';

/// Coordinator for persistent speech with hardware contention management.
/// SIMPLIFIED: Clean restart logic with proper guards.
class ContinuousSpeechManager {
  final SpeechService _speechService;

  bool _shouldBeListening = false;
  bool _isPausedForTts = false;
  bool _isActive = false;
  bool _isRestartScheduled = false;

  Timer? _restartTimer;
  int _restartAttempts = 0;
  Timer? _stuckCheckTimer;
  String? _lastResult;

  // Callbacks
  Function(String)? onSpeechDetected;
  Function(String)? onFinalResult;
  Function(bool)? onListeningStateChanged;

  // HW CONTENTION CALLS
  Function()? onContentionStart;
  Function()? onContentionEnd;

  ContinuousSpeechManager(this._speechService) {
    _speechService.onResult = (res) {
      _lastResult = res;
      _isActive = true;
      _restartAttempts = 0;
      onFinalResult?.call(res);
      onListeningStateChanged?.call(true);
    };

    _speechService.onSpeechDetected = (s) {
      _isActive = true;
      onSpeechDetected?.call(s);
    };

    _speechService.onListeningStarted = () {
      debugPrint('[ContinuousSpeech] ✅ Listening STARTED');
      _isActive = true;
      _isRestartScheduled = false;
      _restartTimer?.cancel();
      onListeningStateChanged?.call(true);
      onContentionEnd?.call();
    };

    _speechService.onListeningStopped = () {
      debugPrint(
        '[ContinuousSpeech] 🔴 Listening STOPPED (shouldBe: $_shouldBeListening, paused: $_isPausedForTts)',
      );
      _isActive = false;
      onListeningStateChanged?.call(false);

      // Only restart if we should be listening and not paused
      if (_shouldBeListening && !_isPausedForTts && !_isRestartScheduled) {
        _scheduleRestart();
      }
    };

    _speechService.onError = (e) {
      debugPrint('[ContinuousSpeech] ❌ Error: $e');
      _isActive = false;
      onListeningStateChanged?.call(false);
      onContentionEnd?.call();

      if (_shouldBeListening && !_isPausedForTts && !_isRestartScheduled) {
        _scheduleRestart(isError: true);
      }
    };

    _speechService.onSoundLevelChange = (l) {};
  }

  Future<bool> start({
    Duration? listenDuration,
    int bufferMs = 1000,
    double minConfidence = 0.05,
    bool force = false,
  }) async {
    debugPrint(
      '[ContinuousSpeech] 🎤 START (force: $force, active: $_isActive)',
    );

    // If already active and not forcing, skip
    if (_isActive && !force) {
      debugPrint('[ContinuousSpeech] Already active, skipping start');
      return true;
    }

    _shouldBeListening = true;
    _restartTimer?.cancel();
    _isRestartScheduled = false;

    if (force) {
      _isPausedForTts = false;
      _restartAttempts = 0;
      onContentionStart?.call();
    }

    await _speechService.startListening(bufferMs: bufferMs);
    _startStuckCheck();
    return true;
  }

  void _startStuckCheck() {
    _stuckCheckTimer?.cancel();
    // Check every 15 seconds for stuck state
    _stuckCheckTimer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (!_shouldBeListening || _isPausedForTts || _isRestartScheduled) return;

      if (!_speechService.isListening && !_isActive) {
        debugPrint('[ContinuousSpeech] ⚠️ Stuck detected, restarting');
        _scheduleRestart();
      }
    });
  }

  void _scheduleRestart({bool isError = false}) {
    if (_isRestartScheduled) {
      debugPrint('[ContinuousSpeech] Restart already scheduled, skipping');
      return;
    }

    _isRestartScheduled = true;
    _restartAttempts++;

    // Use longer delays: 1.5s for errors, 1s base with backoff up to 5s
    final delay = isError ? 1500 : (1000 * _restartAttempts).clamp(1000, 5000);

    debugPrint(
      '[ContinuousSpeech] 🔄 Restart in ${delay}ms (attempt $_restartAttempts)',
    );

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delay), () async {
      _isRestartScheduled = false;

      if (!_shouldBeListening || _isPausedForTts) {
        debugPrint('[ContinuousSpeech] 🚫 Restart cancelled');
        return;
      }

      // Force reinitialize after 5 failed attempts
      if (_restartAttempts >= 5) {
        debugPrint(
          '[ContinuousSpeech] 🔧 Force reinit after $_restartAttempts attempts',
        );
        onContentionStart?.call();
        await _speechService.forceReinitialize();
        _restartAttempts = 0;
      }

      await _speechService.startListening();
    });
  }

  Future<bool> retryListening() async {
    debugPrint('[ContinuousSpeech] 🌪️ MANUAL RETRY');
    onContentionStart?.call();
    _shouldBeListening = true;
    _isRestartScheduled = false;
    _restartAttempts = 0;
    _restartTimer?.cancel();

    await _speechService.forceReinitialize();
    await _speechService.startListening();

    Timer(const Duration(milliseconds: 500), () => onContentionEnd?.call());
    return true;
  }

  Future<void> pauseForTts() async {
    debugPrint('[ContinuousSpeech] ⏸️ Pause for TTS');
    _isPausedForTts = true;
    _restartTimer?.cancel();
    _isRestartScheduled = false;
    await _speechService.cancel();
  }

  Future<void> resumeAfterTts() async {
    debugPrint('[ContinuousSpeech] ▶️ Resume after TTS');
    _isPausedForTts = false;
    if (_shouldBeListening) {
      await start(force: true);
    }
  }

  Future<void> stop() async {
    debugPrint('[ContinuousSpeech] ⏹️ STOP');
    _shouldBeListening = false;
    _isActive = false;
    _isRestartScheduled = false;
    _stuckCheckTimer?.cancel();
    _restartTimer?.cancel();
    await _speechService.stopListening();
  }

  void clearAccumulated() {
    _lastResult = null;
    _speechService.clearBuffer();
  }

  String? getLastRecognized() => _lastResult;
  bool get isActive => _isActive || _speechService.isListening;
  bool get isRestartPending => _isRestartScheduled;
  bool get isPausedForTts => _isPausedForTts;
  bool get shouldBeListening => _shouldBeListening;

  void dispose() {
    _stuckCheckTimer?.cancel();
    _restartTimer?.cancel();
  }
}
