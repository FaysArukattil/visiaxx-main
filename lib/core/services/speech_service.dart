import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Speech recognition service for voice input during tests
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  
  Function(String recognized)? onResult;
  Function(String error)? onError;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _isListening = false;
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      onError?.call('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    if (_isListening) return;

    _isListening = true;
    
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: listenFor ?? const Duration(seconds: 5),
      pauseFor: pauseFor ?? const Duration(seconds: 2),
      partialResults: false,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }

  /// Cancel listening
  Future<void> cancel() async {
    await _speechToText.cancel();
    _isListening = false;
  }

  /// Handle speech result
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      final recognized = result.recognizedWords.toLowerCase().trim();
      onResult?.call(recognized);
    }
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if speech recognition is available
  bool get isAvailable => _isInitialized;

  /// Parse direction from speech for visual acuity test
  static String? parseDirection(String speech) {
    final normalized = speech.toLowerCase().trim();
    
    // Direct matches
    if (normalized.contains('right')) return 'right';
    if (normalized.contains('left')) return 'left';
    if (normalized.contains('up')) return 'up';
    if (normalized.contains('down')) return 'down';
    
    // Phonetic variations
    if (normalized.contains('write') || normalized.contains('wright')) return 'right';
    if (normalized.contains('lift') || normalized.contains('lef')) return 'left';
    if (normalized.contains('app') || normalized.contains('uhp')) return 'up';
    if (normalized.contains('dawn') || normalized.contains('dun')) return 'down';
    
    return null;
  }

  /// Parse number from speech for color vision test
  static String? parseNumber(String speech) {
    final normalized = speech.toLowerCase().trim();
    
    // Number word to digit mapping
    const numberWords = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
      'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17',
      'eighteen': '18', 'nineteen': '19', 'twenty': '20',
      'twenty one': '21', 'twenty two': '22', 'twenty three': '23',
      'twenty four': '24', 'twenty five': '25', 'twenty six': '26',
      'twenty seven': '27', 'twenty eight': '28', 'twenty nine': '29',
      'thirty': '30', 'forty': '40', 'fifty': '50', 'sixty': '60',
      'seventy': '70', 'seventy four': '74', 'eighty': '80', 'ninety': '90',
    };
    
    // Check for number words
    for (final entry in numberWords.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Check for digit string
    final digitMatch = RegExp(r'\d+').firstMatch(normalized);
    if (digitMatch != null) {
      return digitMatch.group(0);
    }
    
    return null;
  }

  /// Parse yes/no from speech for Amsler grid test
  static bool? parseYesNo(String speech) {
    final normalized = speech.toLowerCase().trim();
    
    if (normalized.contains('yes') || 
        normalized.contains('yeah') || 
        normalized.contains('yep') ||
        normalized.contains('correct') ||
        normalized.contains('affirmative')) {
      return true;
    }
    
    if (normalized.contains('no') || 
        normalized.contains('nope') || 
        normalized.contains('negative')) {
      return false;
    }
    
    return null;
  }

  /// Dispose resources
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
  }
}
