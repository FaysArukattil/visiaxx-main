// ignore_for_file: unused_field

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';

/// FIXED Continuous Speech Manager
class ContinuousSpeechManager {
  final SpeechService _speechService;

  // State
  bool _shouldBeListening = false;
  bool _isPausedForTts = false;
  bool _isActive = false;
  Timer? _restartTimer;
  int _restartAttempts = 0;
  DateTime? _lastFailureTime;
  int _rapidFailureCount = 0;
  Timer? _stuckStateCheckTimer;
  DateTime? _lastSoundLevelTime;
  bool _isRestartPending = false; // Guard for concurrent restarts

  // Accumulated results
  final List<String> _allDetectedSpeech = [];
  String? _lastRecognizedValue;
  DateTime? _lastRecognitionTime;

  // Callbacks
  Function(String)? onSpeechDetected;
  Function(String)? onFinalResult;
  Function(bool)? onListeningStateChanged;

  // Configuration
  static const int _maxRestartAttempts = 50;

  ContinuousSpeechManager(this._speechService) {
    _setupCallbacks();
    debugPrint('[ContinuousSpeech] Manager created');
  }

  void _setupCallbacks() {
    _speechService.onResult = (result) {
      debugPrint('[ContinuousSpeech] onResult: "$result"');
      _handleResult(result);
    };

    _speechService.onSpeechDetected = (speech) {
      debugPrint('[ContinuousSpeech] onSpeechDetected: "$speech"');
      _handleSpeechDetected(speech);
    };

    _speechService.onListeningStarted = () {
      debugPrint('[ContinuousSpeech] Listening started');
      _handleListeningStarted();
    };

    _speechService.onListeningStopped = () {
      _handleListeningStopped();
    };

    _speechService.onError = (error) {
      _handleError(error);
    };

    _speechService.onSoundLevelChange = (level) {
      if (level > 0) {
        _lastSoundLevelTime = DateTime.now();
      }
    };
  }

  /// Start continuous listening
  /// Start continuous listening
  Future<void> start({
    Duration? listenDuration,
    int bufferMs = 1000,
    double minConfidence = 0.05,
    bool force = false,
  }) async {
    debugPrint(
      '[ContinuousSpeech] Starting continuous listener (force: $force)',
    );

    // ✅ CRITICAL: If already active and not forcing, don't start again
    if (!force && _isActive && _speechService.isListening) {
      debugPrint(
        '[ContinuousSpeech] Already active and listening, skipping start',
      );
      return;
    }

    _shouldBeListening = true;
    _restartAttempts = 0;

    if (force) {
      _isPausedForTts = false;
      _isRestartPending = false;
      _isActive = false;
      _restartTimer?.cancel();
    }

    _allDetectedSpeech.clear();
    _lastRecognizedValue = null;
    _speechService.clearBuffer();

    if (_isPausedForTts && !force) return;

    await _startListening(
      listenDuration: listenDuration,
      bufferMs: bufferMs,
      minConfidence: minConfidence,
      force: force,
    );

    _startStuckStateCheck();
  }

  void _startStuckStateCheck() {
    _stuckStateCheckTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) {
      if (!_shouldBeListening || _isRestartPending) return;
      // 💡 Heartbeat ignore _isPausedForTts because we want to detect stalls
      // even if something accidentally kept the pause flag on.

      final now = DateTime.now();

      // 1. HARD STUCK: Logically not active
      if (!_isActive) {
        debugPrint(
          '[ContinuousSpeech] STUCK: Engine not active. Restarting...',
        );
        _scheduleRestart();
        return;
      }

      // 2. SILENT STALL: Logically active but no audio data (Heartbeat)
      if (_lastSoundLevelTime != null &&
          now.difference(_lastSoundLevelTime!) > const Duration(seconds: 12)) {
        debugPrint(
          '[ContinuousSpeech] HEARTBEAT FAILURE: Microphone is silent. Kicking engine...',
        );
        _lastSoundLevelTime = null; // Reset
        _scheduleRestart(immediate: true);
      }
    });
  }

  Future<void> _startListening({
    Duration? listenDuration,
    int bufferMs = 1000,
    double minConfidence = 0.05,
    bool force = false,
  }) async {
    if (!_shouldBeListening) return;
    if (_isPausedForTts && !force) return;

    // Guard against concurrency (unless forced)
    if (!force && (_isActive || _speechService.isListening)) {
      debugPrint('[ContinuousSpeech] Already listening, skipping');
      return;
    }

    try {
      debugPrint('[ContinuousSpeech] Start attempt ${_restartAttempts + 1}');

      // Early re-init for persistent issues
      if (_restartAttempts > 3 && _restartAttempts % 3 == 0) {
        await _speechService.forceReinitialize();
      }

      await _speechService.startListening(
        listenFor: listenDuration ?? const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 10),
        bufferMs: bufferMs,
        minConfidence: minConfidence,
      );

      _isActive = true;
      _restartAttempts = 0;
      _isRestartPending = false;
    } catch (e) {
      debugPrint('[ContinuousSpeech] Start error: $e');
      _isActive = false;
      _isRestartPending = false;
      _scheduleRestart();
    }
  }

  void _handleResult(String result) {
    // 💡 LOGICAL SUPPRESSION: Ignore results while TTS is speaking
    // to prevent echo detection, without stopping hardware.
    if (_isPausedForTts) {
      debugPrint(
        '[ContinuousSpeech] Ignoring result (Logical TTS Pause): $result',
      );
      return;
    }
    _lastRecognizedValue = result;

    _lastRecognitionTime = DateTime.now();
    if (!_allDetectedSpeech.contains(result)) _allDetectedSpeech.add(result);
    if (onFinalResult != null) onFinalResult!(result);
  }

  void _handleSpeechDetected(String speech) {
    if (_isPausedForTts) return;
    _lastRecognitionTime = DateTime.now();

    if (!_allDetectedSpeech.contains(speech)) _allDetectedSpeech.add(speech);
    if (onSpeechDetected != null) onSpeechDetected!(speech);
  }

  void _handleListeningStarted() {
    _isActive = true;
    onListeningStateChanged?.call(true);
  }

  void _handleListeningStopped() {
    debugPrint('[ContinuousSpeech] Stop event');
    _isActive = false;
    onListeningStateChanged?.call(false);

    if (_shouldBeListening && !_isPausedForTts) {
      // Don't overwrite error-triggered restart
      if (!_isRestartPending) {
        _scheduleRestart();
      }
    }
  }

  void _handleError(String error) {
    debugPrint('[ContinuousSpeech] onError: $error');
    _isActive = false;

    if (!_shouldBeListening || _isPausedForTts) return;

    // ✅ CRITICAL: Handle server disconnect with longer delay
    if (error.contains('error_server_disconnected') ||
        error.contains('error_busy')) {
      debugPrint(
        '[ContinuousSpeech] ⚡️ Audio system disconnected - extended retry',
      );
      _scheduleRestart(immediate: true); // This now uses 5s delay
    } else if (error.contains('error_no_match')) {
      // No match is not a critical error - just restart normally
      _scheduleRestart();
    } else {
      _scheduleRestart();
    }
  }

  void _scheduleRestart({bool immediate = false}) {
    if (!_shouldBeListening ||
        _isPausedForTts ||
        _restartAttempts >= _maxRestartAttempts) {
      _isRestartPending = false;
      return;
    }

    if (!immediate && _isRestartPending) return;

    _restartTimer?.cancel();
    _isRestartPending = true;

    int delayMs;
    _restartAttempts++;

    if (immediate) {
      // ✅ CRITICAL FIX: Reduced from 5s to 2s for button interactions
      // This allows voice to resume quickly after button press
      delayMs = 2000;
    } else {
      final now = DateTime.now();
      if (_lastFailureTime != null &&
          now.difference(_lastFailureTime!) < const Duration(seconds: 2)) {
        _rapidFailureCount++;
      } else {
        _rapidFailureCount = 0;
      }
      _lastFailureTime = now;

      if (_rapidFailureCount > 3) {
        delayMs = 8000;
        _rapidFailureCount = 0;
      } else {
        delayMs = (1500 * (1 << (_restartAttempts - 1))).clamp(1500, 6000);
      }
    }

    debugPrint(
      '[ContinuousSpeech] Restarting in ${delayMs}ms (immediate: $immediate, attempt: $_restartAttempts)',
    );

    _restartTimer = Timer(Duration(milliseconds: delayMs), () async {
      await _startListening();
    });
  }

  Future<void> pauseForTts() async {
    if (_isPausedForTts) return;
    debugPrint('[ContinuousSpeech] 🔇 Pausing for TTS');
    _isPausedForTts = true;
    _restartTimer?.cancel();

    // ✅ FIX: Use stopListening instead of cancel to preserve initialized state
    if (_isActive || _speechService.isListening) {
      await _speechService.stopListening();
    }
  }

  Future<void> resumeAfterTts() async {
    if (!_isPausedForTts) return;
    debugPrint('[ContinuousSpeech] 🔊 Resuming after TTS');
    _isPausedForTts = false;
    _restartAttempts = 0;

    if (_shouldBeListening) {
      // ✅ FIX: Shorter delay (800ms instead of 1500ms) for faster response
      await Future.delayed(const Duration(milliseconds: 800));
      await _startListening(force: true);
    }
  }

  Future<void> stop() async {
    _shouldBeListening = false;
    _isActive = false;
    _isPausedForTts = false;
    _restartTimer?.cancel();
    _stuckStateCheckTimer?.cancel();
    await _speechService.stopListening();
    onListeningStateChanged?.call(false);
  }

  List<String> getAllDetectedSpeech() => List.from(_allDetectedSpeech);
  String? getLastRecognized() => _lastRecognizedValue;
  void clearAccumulated() {
    _allDetectedSpeech.clear();
    _lastRecognizedValue = null;
    _speechService.clearBuffer();
  }

  bool get isActive => _isActive && _speechService.isListening;
  bool get shouldBeListening => _shouldBeListening;
  bool get isPausedForTts => _isPausedForTts;

  void dispose() {
    _restartTimer?.cancel();
    _stuckStateCheckTimer?.cancel();
    _shouldBeListening = false;
  }
}
