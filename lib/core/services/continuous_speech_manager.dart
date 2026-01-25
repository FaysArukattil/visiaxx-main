// File: lib/core/services/continuous_speech_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';

/// Coordinator for persistent speech with hardware contention management.
class ContinuousSpeechManager {
  final SpeechService _speechService;

  bool _shouldBeListening = false;
  bool _isPausedForTts = false;
  bool _isActive = false;
  bool _isRestartPending = false;

  Timer? _restartTimer;
  int _restartAttempts = 0;
  Timer? _stuckCheckTimer;
  String? _lastResult;

  // Callbacks
  Function(String)? onSpeechDetected;
  Function(String)? onFinalResult;
  Function(bool)? onListeningStateChanged;

  // ⚡️ HW CONTENTION CALLS
  Function()? onContentionStart;
  Function()? onContentionEnd;

  ContinuousSpeechManager(this._speechService) {
    _speechService.onResult = (res) {
      _lastResult = res;
      _isActive = true;
      onFinalResult?.call(res);
      onListeningStateChanged?.call(true);
    };
    _speechService.onSpeechDetected = (s) {
      _isActive = true;
      onSpeechDetected?.call(s);
    };
    _speechService.onListeningStarted = () {
      _isActive = true;
      onListeningStateChanged?.call(true);
      onContentionEnd?.call();
    };
    _speechService.onListeningStopped = () {
      _isActive = false;
      onListeningStateChanged?.call(false);
      if (_shouldBeListening && !_isRestartPending && !_isPausedForTts) {
        _scheduleRestart();
      }
    };
    _speechService.onError = (e) {
      _isActive = false;
      onListeningStateChanged?.call(false);
      onContentionEnd?.call();
      if (e.contains('11') || e.contains('busy')) {
        _scheduleRestart(immediate: true);
      } else {
        _scheduleRestart();
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
    _shouldBeListening = true;
    if (force) {
      _isPausedForTts = false;
      _restartTimer?.cancel();
      _isRestartPending = false;
      onContentionStart?.call();
    }

    await _speechService.startListening(bufferMs: bufferMs);
    _startStuckCheck();
    return true; // Simplified return
  }

  void _startStuckCheck() {
    _stuckCheckTimer?.cancel();
    _stuckCheckTimer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (!_shouldBeListening || _isPausedForTts || _isRestartPending) return;
      if (!_isActive) {
        debugPrint('[ContinuousSpeech] Auto-Recovery kicking in...');
        _scheduleRestart(immediate: true);
      }
    });
  }

  void _scheduleRestart({bool immediate = false}) {
    if (_isRestartPending) return;
    _isRestartPending = true;

    Timer(const Duration(seconds: 8), () => _isRestartPending = false);

    final delay = immediate
        ? 1500
        : (1000 * (_restartAttempts + 1)).clamp(1000, 6000);
    _restartAttempts++;

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delay), () async {
      if (!_shouldBeListening || _isPausedForTts) return;
      if (_restartAttempts > 3 && immediate) {
        onContentionStart?.call();
        await _speechService.forceReinitialize();
      }
      await _speechService.startListening();
      _isRestartPending = false;
    });
  }

  Future<bool> retryListening() async {
    debugPrint('[ContinuousSpeech] 🌪️ FORCING HW RESET');
    onContentionStart?.call();
    _shouldBeListening = true;
    _isRestartPending = false;
    _restartAttempts = 0;
    _restartTimer?.cancel();

    await _speechService.forceReinitialize();
    await _speechService.startListening();

    // Give hardware 1 second to settle before clearing contention
    Timer(const Duration(seconds: 1), () => onContentionEnd?.call());
    return true;
  }

  Future<void> pauseForTts() async {
    _isPausedForTts = true;
    _restartTimer?.cancel();
    await _speechService.cancel();
  }

  Future<void> resumeAfterTts() async {
    _isPausedForTts = false;
    if (_shouldBeListening) await start(force: true);
  }

  Future<void> stop() async {
    _shouldBeListening = false;
    _isActive = false;
    _stuckCheckTimer?.cancel();
    _restartTimer?.cancel();
    await _speechService.stopListening();
  }

  void clearAccumulated() => _speechService.clearBuffer();
  String? getLastRecognized() => _lastResult;
  bool get isActive => _isActive || _speechService.isListening;
  bool get isRestartPending => _isRestartPending;
  bool get isPausedForTts => _isPausedForTts;
  bool get shouldBeListening => _shouldBeListening;

  void dispose() {
    _stuckCheckTimer?.cancel();
    _restartTimer?.cancel();
  }
}
