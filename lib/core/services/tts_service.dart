import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech service for reading instructions aloud
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Initialize TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5); // Slower for clear instructions
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((message) {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    
    if (_isSpeaking) {
      await stop();
    }

    await _flutterTts.speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Pre-defined instruction texts
  static const String relaxationInstruction =
      'Relax your eyes and look at the distant image. Focus on the horizon.';

  static const String visualAcuityInstruction =
      'You will see the letter E pointing in different directions. '
      'Indicate which way the letter E is pointing using the arrow buttons or by saying up, down, left, or right.';

  static const String colorVisionInstruction =
      'You will see colored plates with numbers hidden inside. '
      'Enter the number you see, or say "I don\'t see a number" if you cannot identify it.';

  static const String amslerGridInstruction =
      'Look at the center dot of the grid with one eye covered. '
      'Notice if any lines appear wavy, distorted, or missing. '
      'Tap on any areas that appear abnormal.';

  static const String distanceWarning =
      'Please maintain the correct distance from your device. '
      'The test will pause until you are at the proper distance.';

  static const String testComplete =
      'Test complete. Your results are now ready to view.';

  /// Speak a countdown number
  Future<void> speakCountdown(int number) async {
    await speak(number.toString());
  }

  /// Speak direction prompt for visual acuity test
  Future<void> speakDirectionPrompt() async {
    await speak('Which way is the E pointing?');
  }

  /// Speak color vision prompt
  Future<void> speakColorVisionPrompt() async {
    await speak('What number do you see?');
  }

  /// Speak eye instruction
  Future<void> speakEyeInstruction(String eye) async {
    await speak('Now testing your $eye eye. Cover your other eye.');
  }

  /// Speak voice confirmation for correct answer
  Future<void> speakCorrect(String direction) async {
    if (!_isInitialized) await initialize();
    // Use faster speech rate for quick confirmation
    await _flutterTts.setSpeechRate(0.6);
    await _flutterTts.speak('$direction, correct');
    await _flutterTts.setSpeechRate(0.5); // Reset to normal
  }

  /// Speak voice confirmation for incorrect answer
  Future<void> speakIncorrect(String direction) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setSpeechRate(0.6);
    await _flutterTts.speak('$direction, incorrect');
    await _flutterTts.setSpeechRate(0.5);
  }

  /// Speak quick confirmation without result
  Future<void> speakQuickConfirmation(String direction) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setSpeechRate(0.8); // Very fast
    await _flutterTts.speak(direction);
    await _flutterTts.setSpeechRate(0.5);
  }

  /// Dispose TTS engine
  Future<void> dispose() async {
    await stop();
  }
}
