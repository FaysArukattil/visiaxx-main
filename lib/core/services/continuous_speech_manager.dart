// File: lib/core/services/continuous_speech_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';

/// High-level coordinator for persistent speech recognition.
class ContinuousSpeechManager {
  final SpeechService _speechService;

  bool _shouldBeListening = false;
  bool _isPausedForTts = false;
  bool _isActive = false;
  bool _isRestartPending = false;

  Timer? _restartTimer;
  int _restartAttempts = 0;
  Timer? _stuckCheckTimer;
  DateTime? _lastSoundTime;
  String? _lastResult;

  Function(String)? onSpeechDetected;
  Function(String)? onFinalResult;
  Function(bool)? onListeningStateChanged;

  ContinuousSpeechManager(this._speechService) {
    _speechService.onResult = (res) {
      _lastResult = res;
      _isActive = true;
      onFinalResult?.call(res);
      onListeningStateChanged?.call(true);
    };
    _speechService.onSpeechDetected = (s) {
      _isActive = true;
      _lastSoundTime = DateTime.now();
      onSpeechDetected?.call(s);
    };
    _speechService.onListeningStarted = () {
      _isActive = true;
      onListeningStateChanged?.call(true);
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
      if (e.contains('11') || e.contains('busy')) {
        _scheduleRestart(immediate: true);
      } else {
        _scheduleRestart();
      }
    };
    _speechService.onSoundLevelChange = (l) {
      if (l > 0.1) _lastSoundTime = DateTime.now();
    };
  }

  Future<void> start({
    Duration? listenDuration,
    int bufferMs = 1000,
    double minConfidence = 0.05,
    bool force = false,
  }) async {
    _shouldBeListening = true;
    if (force) {
      _isPausedForTts = false;
      _isRestartPending = false;
      _restartTimer?.cancel();
    }
    await _speechService.startListening(bufferMs: bufferMs);
    _startStuckCheck();
  }

  void _startStuckCheck() {
    _stuckCheckTimer?.cancel();
    _stuckCheckTimer = Timer.periodic(const Duration(seconds: 12), (t) {
      if (!_shouldBeListening || _isPausedForTts || _isRestartPending) return;
      if (!_isActive ||
          (_lastSoundTime != null &&
              DateTime.now().difference(_lastSoundTime!).inSeconds > 20)) {
        debugPrint('[ContinuousSpeech] Stuck detected, restarting...');
        _scheduleRestart(immediate: true);
      }
    });
  }

  void _scheduleRestart({bool immediate = false}) {
    if (_isRestartPending) return;
    _isRestartPending = true;

    // Auto-clear lock
    Timer(const Duration(seconds: 6), () => _isRestartPending = false);

    final delay = immediate
        ? 1500
        : (1000 * (_restartAttempts + 1)).clamp(1000, 6000);
    _restartAttempts++;

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delay), () async {
      if (!_shouldBeListening || _isPausedForTts) return;
      if (_restartAttempts > 3 && immediate)
        await _speechService.forceReinitialize();
      await _speechService.startListening();
      _isRestartPending = false;
    });
  }

  Future<void> retryListening() async {
    _shouldBeListening = true;
    _isRestartPending = false;
    _restartAttempts = 0;
    await _speechService.forceReinitialize();
    await start(force: true);
  }

  Future<void> pauseForTts() async {
    _isPausedForTts = true;
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

  void clearAccumulated() {
    _lastResult = null;
    _speechService.clearBuffer();
  }

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
