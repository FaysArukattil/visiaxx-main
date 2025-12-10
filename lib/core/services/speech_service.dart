import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';

/// Speech recognition service for voice input during tests
/// Enhanced to support continuous listening with last-value capture
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Store the last recognized value for buffer mechanism
  String? _lastRecognizedValue;
  Timer? _bufferTimer;
  
  // Callbacks
  Function(String recognized)? onResult;
  Function(String error)? onError;
  /// Called whenever speech is detected (for visual feedback)
  Function(String partialResult)? onSpeechDetected;
  /// Called when listening starts (for UI indicator)
  Function()? onListeningStarted;
  /// Called when listening stops
  Function()? onListeningStopped;

  /// Check and request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;
      print('[SpeechService] Microphone permission status: $status');
      
      if (status.isDenied) {
        status = await Permission.microphone.request();
        print('[SpeechService] Permission request result: $status');
      }
      
      if (status.isPermanentlyDenied) {
        print('[SpeechService] Microphone permission permanently denied');
        onError?.call('Microphone permission is permanently denied. Please enable it in Settings.');
        return false;
      }
      
      return status.isGranted;
    } catch (e) {
      print('[SpeechService] Permission check error: $e');
      // If permission_handler fails, try to continue anyway
      return true;
    }
  }

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('[SpeechService] Already initialized');
      return true;
    }

    try {
      // First check microphone permission
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        print('[SpeechService] No microphone permission');
        return false;
      }
      
      print('[SpeechService] Initializing speech recognition...');
      
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          print('[SpeechService] Speech error: ${error.errorMsg}');
          _isListening = false;
          onListeningStopped?.call();
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          print('[SpeechService] Status changed: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStopped?.call();
          } else if (status == 'listening') {
            onListeningStarted?.call();
          }
        },
        debugLogging: true,
      );
      
      print('[SpeechService] Initialization result: $_isInitialized');
      
      if (!_isInitialized) {
        onError?.call('Speech recognition not available on this device');
      }
      
      return _isInitialized;
    } catch (e) {
      print('[SpeechService] Initialization error: $e');
      onError?.call('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  /// Start listening for speech with continuous mode (captures last value)
  /// bufferMs: Wait this many milliseconds after last speech before finalizing
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
    int bufferMs = 500,
    bool autoRestart = false, // Auto-restart after stopping
  }) async {
    print('[SpeechService] startListening called');
    
    if (!_isInitialized) {
      print('[SpeechService] Not initialized, attempting to initialize...');
      final success = await initialize();
      if (!success) {
        print('[SpeechService] Initialization failed, cannot start listening');
        onError?.call('Speech recognition not available');
        return;
      }
    }

    // If already listening, stop and restart for fresh session
    if (_isListening) {
      print('[SpeechService] Already listening, stopping first...');
      await _speechToText.stop();
      _isListening = false;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isListening = true;
    _lastRecognizedValue = null;
    _bufferTimer?.cancel();
    
    print('[SpeechService] Starting to listen...');
    onListeningStarted?.call();
    
    try {
      // Get available locales and use English if available
      final locales = await _speechToText.locales();
      String? localeId;
      for (final locale in locales) {
        if (locale.localeId.startsWith('en')) {
          localeId = locale.localeId;
          break;
        }
      }
      print('[SpeechService] Using locale: ${localeId ?? "default"}');
      
      await _speechToText.listen(
        onResult: (result) => _onSpeechResultContinuous(result, bufferMs),
        listenFor: listenFor ?? const Duration(seconds: 10), // Longer listen time
        pauseFor: pauseFor ?? const Duration(seconds: 2), // Shorter pause for quicker whispers
        partialResults: true, // Enable continuous recognition
        cancelOnError: false, // Don't cancel on error
        listenMode: ListenMode.dictation, // Dictation mode for better sensitivity
        localeId: localeId,
        onSoundLevelChange: (level) {
          // Can be used to show audio level feedback
          print('[SpeechService] Sound level: $level');
        },
      );
      print('[SpeechService] Listen started successfully');
    } catch (e) {
      print('[SpeechService] Error starting listen: $e');
      _isListening = false;
      onListeningStopped?.call();
      onError?.call('Failed to start listening: $e');
    }
  }

  /// Handle continuous speech results - stores last value with buffer
  void _onSpeechResultContinuous(SpeechRecognitionResult result, int bufferMs) {
    final recognized = result.recognizedWords.toLowerCase().trim();
    
    if (recognized.isNotEmpty) {
      // Notify that speech was detected (for visual feedback)
      onSpeechDetected?.call(recognized);
      
      // Store as potential last value
      _lastRecognizedValue = recognized;
      
      // Reset buffer timer - wait for more input
      _bufferTimer?.cancel();
      
      if (result.finalResult) {
        // If this is the final result, call immediately
        onResult?.call(recognized);
      } else {
        // Otherwise, wait for buffer period before finalizing
        _bufferTimer = Timer(Duration(milliseconds: bufferMs), () {
          if (_lastRecognizedValue != null && _isListening) {
            onResult?.call(_lastRecognizedValue!);
          }
        });
      }
    }
  }

  /// Get the last recognized value (useful for manual submission)
  String? get lastRecognizedValue => _lastRecognizedValue;

  /// Stop listening
  Future<void> stopListening() async {
    _bufferTimer?.cancel();
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Cancel listening
  Future<void> cancel() async {
    _bufferTimer?.cancel();
    await _speechToText.cancel();
    _isListening = false;
    _lastRecognizedValue = null;
    onListeningStopped?.call();
  }

  /// Finalize with last recognized value (call when timeout occurs)
  String? finalizeWithLastValue() {
    _bufferTimer?.cancel();
    final value = _lastRecognizedValue;
    _lastRecognizedValue = null;
    return value;
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
  /// Supports: spoken numbers, digit-by-digit input, and numeric strings
  static String? parseNumber(String speech) {
    final normalized = speech.toLowerCase().trim();
    
    // Single digit words (for combining into multi-digit numbers)
    const singleDigits = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'to': '2', 'too': '2', 'for': '4', 'fore': '4', // Common homophones
    };
    
    // Full number word to digit mapping
    const numberWords = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
      'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17',
      'eighteen': '18', 'nineteen': '19', 'twenty': '20',
      'twenty one': '21', 'twenty two': '22', 'twenty three': '23',
      'twenty four': '24', 'twenty five': '25', 'twenty six': '26',
      'twenty seven': '27', 'twenty eight': '28', 'twenty nine': '29',
      'thirty': '30', 'forty': '40', 'forty two': '42', 'fifty': '50', 
      'sixty': '60', 'seventy': '70', 'seventy four': '74', 
      'eighty': '80', 'ninety': '90',
      // Hyphenated compound numbers
      'forty-two': '42',
      'seventy-four': '74',
      'twenty-nine': '29',
    };
    
    // Check for full number words first (longest match first)
    final sortedEntries = numberWords.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    
    for (final entry in sortedEntries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Try digit-by-digit parsing (e.g., "one two" → 12, "seven four" → 74)
    final words = normalized.split(RegExp(r'[\s,]+'));
    String digitResult = '';
    for (final word in words) {
      if (singleDigits.containsKey(word)) {
        digitResult += singleDigits[word]!;
      }
    }
    if (digitResult.isNotEmpty) {
      return digitResult;
    }
    
    // Check for digit string (e.g., "12", "74")
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
    _bufferTimer?.cancel();
    _speechToText.stop();
    _speechToText.cancel();
  }
}

