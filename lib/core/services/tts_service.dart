import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Enhanced Text-to-Speech service for reading instructions aloud
/// Features: queue management, multi-language support, voice configuration
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isMuted = false;

  // Callback for when speaking state changes
  Function(bool)? onSpeakingStateChanged;

  // Queue for sequential speech
  final List<String> _speechQueue = [];
  bool _isProcessingQueue = false;

  // Current configuration
  String _currentLanguage = 'en-US';
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;

  /// Initialize TTS engine
  Future<void> initialize({
    String language = 'en-US',
    double speechRate = 0.5,
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    if (_isInitialized) return;

    try {
      _currentLanguage = language;
      _speechRate = speechRate;
      _volume = volume;
      _pitch = pitch;

      await _flutterTts.setLanguage(_currentLanguage);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);

      // Set up handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakingStateChanged?.call(true);
        debugPrint('[TTS] Speaking started');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        debugPrint('[TTS] Speaking completed');
        _processNextInQueue();
      });

      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        debugPrint('[TTS] Error: $message');
        _processNextInQueue();
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        debugPrint('[TTS] Speaking cancelled');
      });

      _isInitialized = true;
      debugPrint('[TTS] Initialized successfully');
    } catch (e) {
      debugPrint('[TTS] Initialization error: $e');
    }
  }

  /// Speak the given text immediately (interrupts current speech)
  Future<void> speak(
    String text, {
    double? speechRate,
    bool skipIfMuted = true,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isMuted && skipIfMuted) {
      debugPrint('[TTS] Skipped (muted): $text');
      return;
    }

    if (_isSpeaking) {
      await stop();
    }

    // Temporarily adjust speech rate if provided
    if (speechRate != null) {
      await _flutterTts.setSpeechRate(speechRate);
    }

    debugPrint('[TTS] Speaking: $text');
    await _flutterTts.speak(text);

    // Reset speech rate
    if (speechRate != null) {
      await _flutterTts.setSpeechRate(_speechRate);
    }
  }

  /// Add text to speech queue (speaks after current speech finishes)
  Future<void> speakQueued(String text, {bool skipIfMuted = true}) async {
    if (!_isInitialized) await initialize();
    if (_isMuted && skipIfMuted) {
      debugPrint('[TTS] Skipped queue (muted): $text');
      return;
    }

    _speechQueue.add(text);
    debugPrint(
      '[TTS] Added to queue: $text (Queue size: ${_speechQueue.length})',
    );

    if (!_isProcessingQueue && !_isSpeaking) {
      _processNextInQueue();
    }
  }

  /// Process next item in speech queue
  Future<void> _processNextInQueue() async {
    if (_speechQueue.isEmpty || _isProcessingQueue) return;

    _isProcessingQueue = true;

    while (_speechQueue.isNotEmpty && !_isSpeaking) {
      final text = _speechQueue.removeAt(0);
      debugPrint('[TTS] Processing queue: $text');
      await speak(
        text,
        skipIfMuted: false,
      ); // Don't check mute for queued items

      // Wait for speech to complete
      while (_isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isProcessingQueue = false;
  }

  /// Stop speaking and clear queue
  Future<void> stop() async {
    await _flutterTts.stop();
    _speechQueue.clear();
    _isSpeaking = false;
    _isProcessingQueue = false;
  }

  /// Pause speaking
  Future<void> pause() async {
    await _flutterTts.pause();
    _isSpeaking = false;
  }

  /// Set mute state
  void setMuted(bool muted) {
    _isMuted = muted;
    if (muted && _isSpeaking) {
      stop();
    }
    debugPrint('[TTS] Muted: $muted');
  }

  /// Toggle mute
  void toggleMute() {
    setMuted(!_isMuted);
  }

  /// Change language
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    await _flutterTts.setLanguage(language);
    debugPrint('[TTS] Language set to: $language');
  }

  /// Change speech rate
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  /// Change volume
  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _flutterTts.setVolume(volume);
  }

  /// Change pitch
  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await _flutterTts.setPitch(pitch);
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e) {
      debugPrint('[TTS] Error getting languages: $e');
      return [];
    }
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Check if muted
  bool get isMuted => _isMuted;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  // ==================== Pre-defined Instructions ====================

  /// Relaxation instruction
  static const String relaxationInstruction =
      'Relax your eyes and look at the distant image. Focus on the horizon.';

  /// Visual acuity instruction
  static const String visualAcuityInstruction =
      'You will see the letter E pointing in different directions. '
      'Say upward, down, left, or right to indicate which way the E is pointing.';

  /// Color vision instruction
  static const String colorVisionInstruction =
      'You will see colored plates with numbers. '
      'Say the number you see, or say I don\'t know if you cannot identify it.';

  /// Amsler grid instruction
  static const String amslerGridInstruction =
      'Look at the center dot with one eye covered. '
      'Notice if any lines appear wavy, distorted, or missing. '
      'Tap on any areas that appear abnormal.';

  /// Distance warning
  static const String distanceWarning =
      'Please maintain the correct distance from your device. '
      'The test will pause until you are at the proper distance.';

  /// Test complete
  static const String testComplete =
      'Test complete. Your results are now ready to view.';

  // ==================== Specific Instructions ====================

  /// Speak countdown
  Future<void> speakCountdown(int number) async {
    await speak(number.toString(), speechRate: 0.6);
  }

  /// Speak direction prompt
  Future<void> speakDirectionPrompt() async {
    await speak('Which way is the E pointing?', speechRate: 0.6);
  }

  /// Speak color vision prompt
  Future<void> speakColorVisionPrompt() async {
    await speak('What number do you see?', speechRate: 0.6);
  }

  /// Speak eye instruction
  Future<void> speakEyeInstruction(String eye) async {
    final otherEye = eye.toLowerCase() == 'right' ? 'left' : 'right';
    await speak('Now testing your $eye eye. Cover your $otherEye eye.');
  }

  /// Quick confirmation (just echo the direction)
  Future<void> speakQuickConfirmation(String direction) async {
    await speak(direction, speechRate: 0.8);
  }

  /// Speak correct answer feedback
  Future<void> speakCorrect(String direction) async {
    // Optional: Provide positive feedback
    // For tests, it's often better to be silent to not disrupt flow
    // Uncomment if feedback is desired:
    // await speak('Correct', speechRate: 0.7);
  }

  /// Speak incorrect answer feedback
  Future<void> speakIncorrect(String direction) async {
    // Optional: Provide feedback
    // For tests, silence is usually better
    // Uncomment if feedback is desired:
    // await speak('Incorrect', speechRate: 0.7);
  }

  /// Speak test phase (e.g., "Starting visual acuity test")
  Future<void> speakTestPhase(String phase) async {
    await speak(phase);
  }

  /// Speak encouragement
  Future<void> speakEncouragement() async {
    const encouragements = [
      'You\'re doing great',
      'Keep going',
      'Almost there',
      'Good job',
    ];
    final index = DateTime.now().millisecondsSinceEpoch % encouragements.length;
    await speak(encouragements[index], speechRate: 0.7);
  }

  /// Speak error message
  Future<void> speakError(String message) async {
    await speak('Error: $message', speechRate: 0.6);
  }

  /// Speak welcome message
  Future<void> speakWelcome(String userName) async {
    await speak('Hello $userName. Let\'s begin your vision test.');
  }

  /// Speak ready prompt
  Future<void> speakReady() async {
    await speak('When you\'re ready, say start or tap the button.');
  }

  /// Speak distance instruction
  Future<void> speakDistanceInstruction() async {
    await speak(
      'Position yourself at arm\'s length from the screen. '
      'About 40 centimeters or 16 inches.',
    );
  }

  /// Speak brightness reminder
  Future<void> speakBrightnessReminder() async {
    await speak(
      'Make sure your screen brightness is at maximum for best results.',
    );
  }

  /// Speak quiet environment reminder
  Future<void> speakQuietEnvironmentReminder() async {
    await speak('Find a quiet place for accurate voice recognition.');
  }

  // ==================== Multi-language Support ====================

  /// Speak in Hindi (example for multi-language)
  Future<void> speakInHindi(String text) async {
    await setLanguage('hi-IN');
    await speak(text);
    await setLanguage('en-US'); // Reset to English
  }

  // ==================== Utility Methods ====================

  /// Spell out a word letter by letter
  Future<void> spellOut(String word) async {
    for (int i = 0; i < word.length; i++) {
      await speak(word[i], speechRate: 0.6);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Clear speech queue
  void clearQueue() {
    _speechQueue.clear();
    debugPrint('[TTS] Queue cleared');
  }

  /// Get queue size
  int get queueSize => _speechQueue.length;

  /// Dispose resources
  void dispose() {
    _flutterTts.stop();
    clearQueue();
  }
}
