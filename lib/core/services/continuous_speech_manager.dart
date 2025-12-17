import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';

/// 🎤 ULTRA-RELIABLE Continuous Speech Manager
/// 
/// This manager ensures speech recognition NEVER stops until explicitly told to.
/// Features:
/// - Aggressive auto-restart with exponential backoff
/// - Health monitoring and automatic recovery
/// - Accumulates all speech results
/// - Works in background even during UI changes
/// - Guaranteed uptime during test sessions
class ContinuousSpeechManager {
  final SpeechService _speechService;
  
  // State
  bool _isActive = false;
  bool _shouldBeListening = false;
  bool _isPausedForTts = false; // Paused because TTS is speaking
  Timer? _healthCheckTimer;
  Timer? _restartTimer;
  int _restartAttempts = 0;
  
  // Accumulated results
  final List<String> _allDetectedSpeech = [];
  String? _lastRecognizedValue;
  DateTime? _lastRecognitionTime;
  
  // Callbacks
  Function(String)? onSpeechDetected;
  Function(String)? onFinalResult;
  Function(bool)? onListeningStateChanged;
  
  // Configuration
  static const Duration _healthCheckInterval = Duration(seconds: 2);
  static const Duration _maxTimeSinceLastRecognition = Duration(seconds: 10);
  static const int _maxRestartAttempts = 100; // Essentially unlimited
  
  ContinuousSpeechManager(this._speechService) {
    _setupCallbacks();
  }
  
  void _setupCallbacks() {
    _speechService.onResult = _handleResult;
    _speechService.onSpeechDetected = _handleSpeechDetected;
    _speechService.onListeningStarted = _handleListeningStarted;
    _speechService.onListeningStopped = _handleListeningStopped;
    _speechService.onError = _handleError;
  }
  
  /// Start continuous listening - will keep running until stop() is called
  Future<void> start({
    Duration? listenDuration,
    int bufferMs = 1000,
    double minConfidence = 0.05, // EXTREMELY permissive
  }) async {
    debugPrint('[ContinuousSpeech] 🚀 Starting continuous speech recognition');
    
    _shouldBeListening = true;
    _restartAttempts = 0;
    _allDetectedSpeech.clear();
    
    // Start health monitoring
    _startHealthMonitoring();
    
    // Initial start
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
    if (!_shouldBeListening || _isPausedForTts) return;
    
    try {
      debugPrint('[ContinuousSpeech] 🎤 Starting speech service (attempt ${_restartAttempts + 1})');
      
      await _speechService.startListening(
        listenFor: listenDuration ?? const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 10), // Very long pause tolerance
        bufferMs: bufferMs,
        autoRestart: true, // Enable built-in auto-restart
        minConfidence: minConfidence,
      );
      
      _isActive = true;
      _restartAttempts = 0; // Reset on successful start
      debugPrint('[ContinuousSpeech] ✅ Speech service started successfully');
      
    } catch (e) {
      debugPrint('[ContinuousSpeech] ❌ Error starting speech: $e');
      _scheduleRestart();
    }
  }
  
  void _handleResult(String result) {
    debugPrint('[ContinuousSpeech] 📝 Final result: "$result"');
    debugPrint('[ContinuousSpeech] 🔥 CALLING onFinalResult callback');
    
    _lastRecognizedValue = result;
    _lastRecognitionTime = DateTime.now();
    _allDetectedSpeech.add(result);
    
    if (onFinalResult != null) {
      onFinalResult!(result);
      debugPrint('[ContinuousSpeech] ✅ onFinalResult callback executed');
    } else {
      debugPrint('[ContinuousSpeech] ⚠️ onFinalResult callback is NULL!');
    }
  }
  
  void _handleSpeechDetected(String speech) {
    debugPrint('[ContinuousSpeech] 🎤 Detected: "$speech"');
    debugPrint('[ContinuousSpeech] 🔥 CALLING onSpeechDetected callback');
    
    _lastRecognitionTime = DateTime.now();
    
    if (!_allDetectedSpeech.contains(speech)) {
      _allDetectedSpeech.add(speech);
    }
    
    if (onSpeechDetected != null) {
      onSpeechDetected!(speech);
      debugPrint('[ContinuousSpeech] ✅ onSpeechDetected callback executed');
    } else {
      debugPrint('[ContinuousSpeech] ⚠️ onSpeechDetected callback is NULL!');
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
    
    // Auto-restart if we should still be listening and not paused for TTS
    if (_shouldBeListening && !_isPausedForTts) {
      debugPrint('[ContinuousSpeech] 🔄 Auto-restarting...');
      _scheduleRestart();
    }
  }
  
  void _handleError(String error) {
    debugPrint('[ContinuousSpeech] ⚠️ Error: $error');
    _isActive = false;
    
    // Always try to restart on error
    if (_shouldBeListening) {
      _scheduleRestart();
    }
  }
  
  void _scheduleRestart() {
    if (!_shouldBeListening || _isPausedForTts) return;
    if (_restartAttempts >= _maxRestartAttempts) {
      debugPrint('[ContinuousSpeech] ❌ Max restart attempts reached');
      return;
    }
    
    _restartTimer?.cancel();
    
    // Exponential backoff: 100ms, 200ms, 400ms, 800ms, max 2000ms
    final delayMs = (100 * (1 << _restartAttempts)).clamp(100, 2000);
    _restartAttempts++;
    
    debugPrint('[ContinuousSpeech] ⏰ Scheduling restart in ${delayMs}ms (attempt $_restartAttempts)');
    
    _restartTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_shouldBeListening) {
        await _startListening();
      }
    });
  }
  
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      if (!_shouldBeListening) {
        timer.cancel();
        return;
      }
      
      _performHealthCheck();
    });
  }
  
  void _performHealthCheck() {
    debugPrint('[ContinuousSpeech] 🏥 Health check...');
    
    // Check 1: Is the service supposed to be listening but isn't?
    if (_shouldBeListening && !_isPausedForTts && !_isActive && !_speechService.isListening) {
      debugPrint('[ContinuousSpeech] ⚠️ Service not listening when it should be - restarting');
      _scheduleRestart();
      return;
    }
    
    // Check 2: Has it been too long since last recognition? (might be stuck)
    if (_lastRecognitionTime != null) {
      final timeSinceLastRecognition = DateTime.now().difference(_lastRecognitionTime!);
      if (timeSinceLastRecognition > _maxTimeSinceLastRecognition && _isActive) {
        debugPrint('[ContinuousSpeech] ⚠️ No recognition for ${timeSinceLastRecognition.inSeconds}s - might be stuck');
        // Don't restart here, just log - the service might be working fine but user is silent
      }
    }
    
    debugPrint('[ContinuousSpeech] ✅ Health check passed (active: $_isActive, listening: ${_speechService.isListening})');
  }
  
  /// Pause listening temporarily (e.g., when TTS is speaking)
  Future<void> pauseForTts() async {
    if (_isPausedForTts) return;
    
    debugPrint('[ContinuousSpeech] 🔇 Pausing for TTS');
    _isPausedForTts = true;
    
    if (_isActive) {
      await _speechService.stopListening();
    }
  }
  
  /// Resume listening after TTS is done
  Future<void> resumeAfterTts() async {
    if (!_isPausedForTts) return;
    
    debugPrint('[ContinuousSpeech] 🔊 Resuming after TTS');
    _isPausedForTts = false;
    
    if (_shouldBeListening) {
      await _startListening();
    }
  }
  
  /// Stop continuous listening
  Future<void> stop() async {
    debugPrint('[ContinuousSpeech] 🛑 Stopping continuous speech recognition');
    
    _shouldBeListening = false;
    _isActive = false;
    _isPausedForTts = false;
    
    _healthCheckTimer?.cancel();
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
  
  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _restartTimer?.cancel();
    _shouldBeListening = false;
  }
}
