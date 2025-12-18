// ignore_for_file: unused_field

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';

/// 🎤 FIXED Continuous Speech Manager
///
/// Key fixes:
/// - Proper TTS pause/resume handling
/// - Callbacks are always set correctly
/// - Single restart mechanism (no conflicts)
/// - Better state management
class ContinuousSpeechManager {
  final SpeechService _speechService;

  // State
  bool _shouldBeListening = false;
  bool _isPausedForTts = false;
  bool _isActive = false;
  Timer? _restartTimer;
  int _restartAttempts = 0;

  // Accumulated results
  final List<String> _allDetectedSpeech = [];
  String? _lastRecognizedValue;
  DateTime? _lastRecognitionTime;

  // Callbacks - ALWAYS set these properly
  Function(String)? onSpeechDetected;
  Function(String)? onFinalResult;
  Function(bool)? onListeningStateChanged;

  // Configuration
  static const int _maxRestartAttempts = 50;

  ContinuousSpeechManager(this._speechService) {
    _setupCallbacks();
    debugPrint('[ContinuousSpeech] 🎤 Manager created, callbacks set up');
  }

  void _setupCallbacks() {
    debugPrint('[ContinuousSpeech] 🔧 Setting up callbacks...');

    _speechService.onResult = (result) {
      debugPrint('[ContinuousSpeech] 📝 onResult called: "$result"');
      _handleResult(result);
    };

    _speechService.onSpeechDetected = (speech) {
      debugPrint('[ContinuousSpeech] 🎤 onSpeechDetected called: "$speech"');
      _handleSpeechDetected(speech);
    };

    _speechService.onListeningStarted = () {
      debugPrint('[ContinuousSpeech] ✅ onListeningStarted called');
      _handleListeningStarted();
    };

    _speechService.onListeningStopped = () {
      debugPrint('[ContinuousSpeech] ⏸️ onListeningStopped called');
      _handleListeningStopped();
    };

    _speechService.onError = (error) {
      debugPrint('[ContinuousSpeech] ⚠️ onError called: $error');
      _handleError(error);
    };

    debugPrint('[ContinuousSpeech] ✅ Callbacks configured');
  }

  /// Start continuous listening
  Future<void> start({
    Duration? listenDuration,
    int bufferMs = 1000,
    double minConfidence = 0.05,
  }) async {
    debugPrint(
      '[ContinuousSpeech] 🚀 Starting continuous speech (paused: $_isPausedForTts)',
    );

    _shouldBeListening = true;
    _restartAttempts = 0;
    _allDetectedSpeech.clear();
    _lastRecognizedValue = null; // ✅ Reset last recognized value on start

    // Don't start if paused for TTS
    if (_isPausedForTts) {
      debugPrint(
        '[ContinuousSpeech] ⏸️ Paused for TTS, will start when resumed',
      );
      return;
    }

    await _startListening(
      listenDuration: listenDuration,
      bufferMs: bufferMs,
      minConfidence: minConfidence,
    );
  }

  Future<void> _startListening({
    Duration? listenDuration,
    int bufferMs = 1000,
    double minConfidence = 0.05,
  }) async {
    // Don't start if we shouldn't be listening or paused for TTS
    if (!_shouldBeListening || _isPausedForTts) {
      debugPrint(
        '[ContinuousSpeech] ⏸️ Skipping start (shouldListen: $_shouldBeListening, pausedForTts: $_isPausedForTts)',
      );
      return;
    }

    try {
      debugPrint(
        '[ContinuousSpeech] 🎤 Starting speech service (attempt ${_restartAttempts + 1})',
      );

      await _speechService.startListening(
        listenFor: listenDuration ?? const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 10),
        bufferMs: bufferMs,
        minConfidence: minConfidence,
      );

      _isActive = true;
      _restartAttempts = 0;
      debugPrint('[ContinuousSpeech] ✅ Speech service started successfully');
    } catch (e) {
      debugPrint('[ContinuousSpeech] ❌ Error starting speech: $e');
      _scheduleRestart();
    }
  }

  void _handleResult(String result) {
    debugPrint('[ContinuousSpeech] 📝 Final result received: "$result"');

    _lastRecognizedValue = result;
    _lastRecognitionTime = DateTime.now();

    if (!_allDetectedSpeech.contains(result)) {
      _allDetectedSpeech.add(result);
    }

    // Call the callback
    if (onFinalResult != null) {
      debugPrint('[ContinuousSpeech] 🔥 Calling onFinalResult callback');
      onFinalResult!(result);
    } else {
      debugPrint('[ContinuousSpeech] ⚠️ WARNING: onFinalResult is NULL!');
    }
  }

  void _handleSpeechDetected(String speech) {
    debugPrint('[ContinuousSpeech] 🎤 Speech detected: "$speech"');

    _lastRecognitionTime = DateTime.now();

    if (!_allDetectedSpeech.contains(speech)) {
      _allDetectedSpeech.add(speech);
    }

    // Call the callback
    if (onSpeechDetected != null) {
      debugPrint('[ContinuousSpeech] 🔥 Calling onSpeechDetected callback');
      onSpeechDetected!(speech);
    } else {
      debugPrint('[ContinuousSpeech] ⚠️ WARNING: onSpeechDetected is NULL!');
    }
  }

  void _handleListeningStarted() {
    debugPrint('[ContinuousSpeech] ✅ Listening started');
    _isActive = true;
    onListeningStateChanged?.call(true);
  }

  void _handleListeningStopped() {
    debugPrint('[ContinuousSpeech] ⏸️ Listening stopped');
    _isActive = false;
    onListeningStateChanged?.call(false);

    // Auto-restart ONLY if:
    // 1. We should be listening
    // 2. NOT paused for TTS
    // 3. Haven't exceeded max attempts
    if (_shouldBeListening &&
        !_isPausedForTts &&
        _restartAttempts < _maxRestartAttempts) {
      debugPrint('[ContinuousSpeech] 🔄 Scheduling auto-restart...');
      _scheduleRestart();
    } else {
      debugPrint(
        '[ContinuousSpeech] ⏹️ Not restarting (should: $_shouldBeListening, tts: $_isPausedForTts, attempts: $_restartAttempts)',
      );
    }
  }

  void _handleError(String error) {
    debugPrint('[ContinuousSpeech] ⚠️ Error: $error');
    _isActive = false;

    // Try to restart on error (if not paused for TTS)
    if (_shouldBeListening && !_isPausedForTts) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_shouldBeListening || _isPausedForTts) {
      debugPrint(
        '[ContinuousSpeech] ⏹️ Not scheduling restart (should: $_shouldBeListening, tts: $_isPausedForTts)',
      );
      return;
    }

    if (_restartAttempts >= _maxRestartAttempts) {
      debugPrint(
        '[ContinuousSpeech] ❌ Max restart attempts reached ($_maxRestartAttempts)',
      );
      return;
    }

    _restartTimer?.cancel();

    // Exponential backoff: 200ms, 400ms, 800ms, max 2000ms
    final delayMs = (200 * (1 << _restartAttempts)).clamp(200, 2000);
    _restartAttempts++;

    debugPrint(
      '[ContinuousSpeech] ⏰ Scheduling restart in ${delayMs}ms (attempt $_restartAttempts)',
    );

    _restartTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_shouldBeListening && !_isPausedForTts) {
        debugPrint('[ContinuousSpeech] 🔄 Executing restart...');
        await _startListening();
      }
    });
  }

  /// ⭐ KEY FIX: Pause for TTS - stops mic from picking up TTS audio
  Future<void> pauseForTts() async {
    if (_isPausedForTts) {
      debugPrint('[ContinuousSpeech] ⚠️ Already paused for TTS');
      return;
    }

    debugPrint('[ContinuousSpeech] 🔇 PAUSING FOR TTS');
    _isPausedForTts = true;

    // Cancel any pending restarts
    _restartTimer?.cancel();

    // Stop the speech service immediately
    if (_isActive || _speechService.isListening) {
      await _speechService.stopListening();
      debugPrint('[ContinuousSpeech] 🛑 Speech service stopped for TTS');
    }
  }

  /// ⭐ KEY FIX: Resume after TTS - restarts listening
  Future<void> resumeAfterTts() async {
    if (!_isPausedForTts) {
      debugPrint('[ContinuousSpeech] ⚠️ Not paused for TTS');
      return;
    }

    debugPrint('[ContinuousSpeech] 🔊 RESUMING AFTER TTS');
    _isPausedForTts = false;
    _restartAttempts = 0; // Reset attempts

    // Restart if we should be listening
    if (_shouldBeListening) {
      // Small delay to ensure TTS is fully done
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('[ContinuousSpeech] 🔄 Restarting speech after TTS...');
      await _startListening();
    }
  }

  /// Stop continuous listening
  Future<void> stop() async {
    debugPrint('[ContinuousSpeech] 🛑 Stopping continuous speech recognition');

    _shouldBeListening = false;
    _isActive = false;
    _isPausedForTts = false;

    _restartTimer?.cancel();

    await _speechService.stopListening();

    onListeningStateChanged?.call(false);
  }

  /// Get all accumulated speech
  List<String> getAllDetectedSpeech() => List.from(_allDetectedSpeech);

  /// Get last recognized value
  String? getLastRecognized() => _lastRecognizedValue;

  /// Clear accumulated speech
  void clearAccumulated() {
    _allDetectedSpeech.clear();
    _lastRecognizedValue = null;
  }

  /// Check if currently active
  bool get isActive => _isActive && _speechService.isListening;

  /// Check if should be listening
  bool get shouldBeListening => _shouldBeListening;

  /// Check if paused for TTS
  bool get isPausedForTts => _isPausedForTts;

  /// Dispose resources
  void dispose() {
    debugPrint('[ContinuousSpeech] 🗑️ Disposing...');
    _restartTimer?.cancel();
    _shouldBeListening = false;
    _isPausedForTts = false;
  }
}
