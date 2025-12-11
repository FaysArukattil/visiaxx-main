import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// Enhanced speech recognition service for voice input during tests
/// Features: continuous listening, last-value buffer, auto-retry, confidence scoring
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // Store the last recognized value for buffer mechanism
  String? _lastRecognizedValue;
  double _lastConfidence = 0.0;
  Timer? _bufferTimer;
  Timer? _autoRestartTimer;

  // Auto-retry configuration
  int _consecutiveErrors = 0;
  static const int _maxRetries = 3;
  bool _autoRetryEnabled = false;

  // Callbacks
  Function(String recognized)? onResult;
  Function(String error)? onError;
  Function(String partialResult)? onSpeechDetected;
  Function()? onListeningStarted;
  Function()? onListeningStopped;
  Function(double level)? onSoundLevelChange;

  /// Check and request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;
      debugPrint('[SpeechService] Microphone permission status: $status');

      if (status.isDenied) {
        status = await Permission.microphone.request();
        debugPrint('[SpeechService] Permission request result: $status');
      }

      if (status.isPermanentlyDenied) {
        debugPrint('[SpeechService] Microphone permission permanently denied');
        onError?.call(
          'Microphone permission is permanently denied. Please enable it in Settings.',
        );
        return false;
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('[SpeechService] Permission check error: $e');
      // Try to continue anyway - some devices don't need explicit permission
      return true;
    }
  }

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('[SpeechService] Already initialized');
      return true;
    }

    try {
      // Check microphone permission first
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('[SpeechService] No microphone permission');
        return false;
      }

      debugPrint('[SpeechService] Initializing speech recognition...');

      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[SpeechService] Speech error: ${error.errorMsg}');
          _consecutiveErrors++;
          _isListening = false;
          onListeningStopped?.call();

          // Auto-retry on transient errors
          if (_autoRetryEnabled &&
              _consecutiveErrors < _maxRetries &&
              (error.errorMsg.contains('network') ||
                  error.errorMsg.contains('timeout') ||
                  error.errorMsg.contains('no speech'))) {
            debugPrint('[SpeechService] Auto-retrying after error...');
            _scheduleAutoRestart();
          } else {
            onError?.call(error.errorMsg);
          }
        },
        onStatus: (status) {
          debugPrint('[SpeechService] Status changed: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStopped?.call();

            // Auto-restart if enabled
            if (_autoRetryEnabled && _consecutiveErrors < _maxRetries) {
              _scheduleAutoRestart();
            }
          } else if (status == 'listening') {
            _isListening = true;
            _consecutiveErrors = 0; // Reset on successful start
            onListeningStarted?.call();
          }
        },
        debugLogging: kDebugMode,
      );

      debugPrint('[SpeechService] Initialization result: $_isInitialized');

      if (!_isInitialized) {
        onError?.call('Speech recognition not available on this device');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('[SpeechService] Initialization error: $e');
      onError?.call('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  /// Schedule auto-restart after a brief delay
  void _scheduleAutoRestart() {
    _autoRestartTimer?.cancel();
    _autoRestartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_autoRetryEnabled && !_isListening) {
        debugPrint('[SpeechService] Auto-restarting...');
        startListening(autoRestart: true);
      }
    });
  }

  /// Start listening for speech with continuous mode
  /// bufferMs: Wait this many milliseconds after last speech before finalizing
  /// autoRestart: Automatically restart listening after it stops
  /// minConfidence: Minimum confidence threshold (0.0 to 1.0)
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
    int bufferMs = 500,
    bool autoRestart = false,
    double minConfidence = 0.5,
  }) async {
    debugPrint('[SpeechService] startListening called');

    if (!_isInitialized) {
      debugPrint(
        '[SpeechService] Not initialized, attempting to initialize...',
      );
      final success = await initialize();
      if (!success) {
        debugPrint(
          '[SpeechService] Initialization failed, cannot start listening',
        );
        onError?.call('Speech recognition not available');
        return;
      }
    }

    // Stop if already listening
    if (_isListening) {
      debugPrint('[SpeechService] Already listening, stopping first...');
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _autoRetryEnabled = autoRestart;
    _lastRecognizedValue = null;
    _lastConfidence = 0.0;
    _bufferTimer?.cancel();

    debugPrint('[SpeechService] Starting to listen...');

    try {
      // Get available locales and prefer English
      final locales = await _speechToText.locales();
      String? localeId;
      for (final locale in locales) {
        if (locale.localeId.startsWith('en_')) {
          localeId = locale.localeId;
          break;
        }
      }
      debugPrint('[SpeechService] Using locale: ${localeId ?? "default"}');

      await _speechToText.listen(
        onResult: (result) =>
            _onSpeechResultContinuous(result, bufferMs, minConfidence),
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: localeId,
        onSoundLevelChange: (level) {
          onSoundLevelChange?.call(level);
        },
      );

      debugPrint('[SpeechService] Listen started successfully');
    } catch (e) {
      debugPrint('[SpeechService] Error starting listen: $e');
      _isListening = false;
      onListeningStopped?.call();
      onError?.call('Failed to start listening: $e');
    }
  }

  /// Handle continuous speech results with confidence filtering
  void _onSpeechResultContinuous(
    SpeechRecognitionResult result,
    int bufferMs,
    double minConfidence,
  ) {
    final recognized = result.recognizedWords.toLowerCase().trim();
    final confidence = result.confidence;

    debugPrint(
      '[SpeechService] Recognized: "$recognized" (confidence: ${(confidence * 100).toStringAsFixed(0)}%)',
    );

    if (recognized.isNotEmpty) {
      // Always notify for visual feedback
      onSpeechDetected?.call(recognized);

      // Only store if confidence meets threshold
      if (confidence >= minConfidence) {
        _lastRecognizedValue = recognized;
        _lastConfidence = confidence;

        debugPrint(
          '[SpeechService] Accepted with confidence ${(confidence * 100).toStringAsFixed(0)}%',
        );
      } else {
        debugPrint(
          '[SpeechService] Rejected - low confidence ${(confidence * 100).toStringAsFixed(0)}%',
        );
      }

      // Reset buffer timer
      _bufferTimer?.cancel();

      if (result.finalResult && _lastRecognizedValue != null) {
        // Final result - call immediately
        debugPrint('[SpeechService] Final result: $_lastRecognizedValue');
        onResult?.call(_lastRecognizedValue!);
      } else if (_lastRecognizedValue != null) {
        // Partial result - wait for buffer period
        _bufferTimer = Timer(Duration(milliseconds: bufferMs), () {
          if (_lastRecognizedValue != null && _isListening) {
            debugPrint(
              '[SpeechService] Buffer timeout - using last value: $_lastRecognizedValue',
            );
            onResult?.call(_lastRecognizedValue!);
          }
        });
      }
    }
  }

  /// Get the last recognized value with confidence
  Map<String, dynamic> getLastRecognized() {
    return {'value': _lastRecognizedValue, 'confidence': _lastConfidence};
  }

  /// Get the last recognized value (simplified)
  String? get lastRecognizedValue => _lastRecognizedValue;

  /// Stop listening
  Future<void> stopListening() async {
    _bufferTimer?.cancel();
    _autoRestartTimer?.cancel();
    _autoRetryEnabled = false;

    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Cancel listening completely
  Future<void> cancel() async {
    _bufferTimer?.cancel();
    _autoRestartTimer?.cancel();
    _autoRetryEnabled = false;

    await _speechToText.cancel();
    _isListening = false;
    _lastRecognizedValue = null;
    _lastConfidence = 0.0;
    onListeningStopped?.call();
  }

  /// Finalize with last recognized value
  String? finalizeWithLastValue() {
    _bufferTimer?.cancel();
    final value = _lastRecognizedValue;
    _lastRecognizedValue = null;
    _lastConfidence = 0.0;
    return value;
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if speech recognition is available
  bool get isAvailable => _isInitialized;

  /// Parse direction from speech (enhanced with extensive mishearing variations)
  static String? parseDirection(String speech) {
    final normalized = speech.toLowerCase().trim();

    // Remove common filler words to isolate the direction
    final cleaned = normalized
        .replaceAll(RegExp(r'\b(the|a|an|to|go|move|swipe|point)\b'), '')
        .trim();

    // UP variations - extensive matching (including Indian accents)
    final upPatterns = [
      // Direct matches
      'up', 'upward', 'upwards', 'upper', 'top', 'above',
      // Common mishearings
      'uup', 'uhp', 'app', 'ap', 'upp', 'yup',
      // Phonetic variations
      'op', 'oop', 'uh', 'ub', 'ep', 'eph',
      // Similar sounds
      'cap', // when isolated as a single word, might be "up"
      // Indian accent variations (South & North)
      'aap', 'aapu', 'appa', 'appu', 'upe', 'uppe',
      'ape', 'eep', 'eup', 'ab', 'abb',
      // Vowel substitutions common in Indian English
      'aep', 'aip', 'ayp', 'epp', 'ip', 'ipp',
      // Additional phonetic for Indian accents
      'hup', 'hap', 'kap', 'aps', 'aab',
      // NEW: Requested variations
      'apward', 'apwards', 'appward', 'aapward', 'apwerd',
      // Double consonants
      'uup', 'upp', 'uupp',
    ];

    // DOWN variations - extensive matching (including Indian accents)
    final downPatterns = [
      // Direct matches
      'down', 'downward', 'downwards', 'lower', 'bottom', 'below',
      // Common mishearings
      'dawn', 'donee', 'dahne', 'daawn', 'doun', 'doon', 'dun',
      // Phonetic variations
      'ton', 'town', 'dan', 'dane', 'dahn', 'doan',
      // Similar sounds
      'done', 'don', 'donne', 'downe', 'downn',
      // Indian accent variations (South & North)
      'daun', 'daan', 'davn', 'thon', 'thaun', 'thaan',
      'dhun', 'dhaan', 'dhown', 'dhaun', 'taun', 'taan',
      // Retroflex variations
      'ddon', 'ddawn', 'ddoun', 'dhawn', 'dhaawn',
      // T/D confusion and vowel substitutions
      'doen', 'toun', 'thown', 'thaown', 'dund', 'downd',
      // Additional for Indian accents
      'niche', 'neech', 'bottom', 'tala',
      // NEW: Requested variations
      'bbottom', 'bbotom', 'botom', 'bottam', 'bottem',
      // Double consonants
      'ddown', 'dowwn', 'botttom',
    ];

    // RIGHT variations - extensive matching (including Indian accents)
    final rightPatterns = [
      // Direct matches
      'right', 'rightward', 'rightwards',
      // Common homophones
      'write', 'wright', 'rite', 'ryte',
      // Phonetic variations
      'righ', 'rait', 'riht', 'righte', 'ryght',
      // Similar sounds
      'riet', 'wight', 'rated', 'righted',
      // Indian accent variations (South & North)
      'rightu', 'raitu', 'raight', 'raightu', 'writu',
      'righta', 'raita', 'rytu', 'rythu', 'righd',
      // V/W confusion common in South Indian
      'vrite', 'vright', 'wite', 'vait',
      // Retroflex variations
      'rright', 'rryte', 'rraight', 'rrite',
      // Vowel substitutions
      'rayt', 'raet', 'raete', 'raittu',
      // Compass (with Indian variations)
      'east', 'eastward', 'eest', 'estu', 'esta', 'purva',
      // NEW: Requested variations
      'wright', 'wryt', 'wrigh', 'wwright', 'rrite',
      // Double consonants
      'rright', 'rightt', 'riight',
    ];

    // LEFT variations - extensive matching (including Indian accents)
    final leftPatterns = [
      // Direct matches
      'left', 'leftward', 'leftwards',
      // Common mishearings
      'lef', 'laft', 'lehft', 'lafft', 'leaft', 'lefht',
      // Phonetic variations
      'leff', 'lefft', 'lift', 'leaft', 'laeft', 'lepht',
      // Similar sounds
      'laughed', 'lek', 'lept', 'let', 'leh',
      // Indian accent variations (South & North)
      'lephtu', 'laeftu', 'leftu', 'laftu',
      'lephta', 'laefta', 'lapht', 'leptu', 'leftd',
      // T/D confusion
      'lefd', 'lephd', 'lafd', 'leftd', 'lefhd',
      // Retroflex variations
      'lleft', 'llef', 'llepht', 'lleaft', 'llaft',
      // Vowel substitutions
      'laift', 'lipt', 'lept', 'laeft',
      // F/PH/FT confusion
      'lep', 'laph', 'lefh', 'laff', 'leff', 'laft',
      // Additional variations for better recognition
      'lef', 'laft', 'lehf', 'laft', 'leaft', 'laef',
      'laft', 'lif', 'lyft', 'lephd', 'lefhd',
      // Short forms
      'lft', 'lf', 'lph',
      // Compass (with Indian variations)
      'west', 'westward', 'westu', 'vesta', 'vwest', 'paschim',
      // NEW: Requested variations
      'lehft', 'lehf', 'lleft', 'llef', 'leftt',
      // Double consonants
      'lefft', 'lleeft',
    ];

    // Helper function to check if any pattern matches
    bool containsPattern(List<String> patterns) {
      for (final pattern in patterns) {
        // Check for exact word match first (most reliable)
        if (RegExp(r'\b' + pattern + r'\b').hasMatch(cleaned) ||
            RegExp(r'\b' + pattern + r'\b').hasMatch(normalized)) {
          return true;
        }
        // Fallback to contains check
        if (cleaned.contains(pattern) || normalized.contains(pattern)) {
          return true;
        }
      }
      return false;
    }

    // Check patterns in priority order
    // Check UP first as 'app' might be common
    if (containsPattern(upPatterns)) return 'up';

    // Check DOWN
    if (containsPattern(downPatterns)) return 'down';

    // Check RIGHT
    if (containsPattern(rightPatterns)) return 'right';

    // Check LEFT
    if (containsPattern(leftPatterns)) return 'left';

    // Additional fuzzy matching for very short inputs
    // If input is very short (1-3 chars), use phonetic matching
    if (cleaned.length <= 3) {
      // Single letter or very short
      if (cleaned.startsWith('u') || cleaned.startsWith('a')) return 'up';
      if (cleaned.startsWith('d')) return 'down';
      if (cleaned.startsWith('r') || cleaned.startsWith('w')) return 'right';
      if (cleaned.startsWith('l')) return 'left';
    }

    return null;
  }

  /// Parse number from speech (enhanced with better recognition)
  static String? parseNumber(String speech) {
    final normalized = speech.toLowerCase().trim();

    // Single digit words
    const singleDigits = {
      'zero': '0',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'to': '2',
      'too': '2',
      'for': '4',
      'fore': '4',
      'oh': '0',
      'o': '0',
    };

    // Full number words (sorted by length for longest match first)
    const numberWords = {
      'twenty nine': '29',
      'twenty-nine': '29',
      'twenty eight': '28',
      'twenty-eight': '28',
      'twenty seven': '27',
      'twenty-seven': '27',
      'twenty six': '26',
      'twenty-six': '26',
      'twenty five': '25',
      'twenty-five': '25',
      'twenty four': '24',
      'twenty-four': '24',
      'twenty three': '23',
      'twenty-three': '23',
      'twenty two': '22',
      'twenty-two': '22',
      'twenty one': '21',
      'twenty-one': '21',
      'seventy four': '74',
      'seventy-four': '74',
      'forty two': '42',
      'forty-two': '42',
      'nineteen': '19',
      'eighteen': '18',
      'seventeen': '17',
      'sixteen': '16',
      'fifteen': '15',
      'fourteen': '14',
      'thirteen': '13',
      'twelve': '12',
      'eleven': '11',
      'ninety': '90',
      'eighty': '80',
      'seventy': '70',
      'sixty': '60',
      'fifty': '50',
      'forty': '40',
      'thirty': '30',
      'twenty': '20',
      'ten': '10',
      'nine': '9',
      'eight': '8',
      'seven': '7',
      'six': '6',
      'five': '5',
      'four': '4',
      'three': '3',
      'two': '2',
      'one': '1',
      'zero': '0',
    };

    // Check full number words (longest first)
    final sortedEntries = numberWords.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedEntries) {
      if (normalized == entry.key ||
          normalized.contains(' ${entry.key} ') ||
          normalized.startsWith('${entry.key} ') ||
          normalized.endsWith(' ${entry.key}')) {
        return entry.value;
      }
    }

    // Try digit-by-digit parsing (e.g., "seven four" → "74")
    final words = normalized.split(RegExp(r'[\s,]+'));
    String digitResult = '';
    for (final word in words) {
      if (singleDigits.containsKey(word)) {
        digitResult += singleDigits[word]!;
      }
    }
    if (digitResult.isNotEmpty && digitResult.length <= 2) {
      return digitResult;
    }

    // Check for digit string
    final digitMatch = RegExp(r'\b\d{1,2}\b').firstMatch(normalized);
    if (digitMatch != null) {
      return digitMatch.group(0);
    }

    return null;
  }

  /// Parse yes/no from speech
  static bool? parseYesNo(String speech) {
    final normalized = speech.toLowerCase().trim();

    // Positive
    if (normalized.contains('yes') ||
        normalized.contains('yeah') ||
        normalized.contains('yep') ||
        normalized.contains('yup') ||
        normalized.contains('correct') ||
        normalized.contains('right') ||
        normalized.contains('affirmative') ||
        normalized.contains('true') ||
        normalized.contains('sure')) {
      return true;
    }

    // Negative
    if (normalized.contains('no') ||
        normalized.contains('nope') ||
        normalized.contains('nah') ||
        normalized.contains('negative') ||
        normalized.contains('false') ||
        normalized.contains('wrong')) {
      return false;
    }

    return null;
  }

  /// Get confidence of last recognition (0.0 to 1.0)
  double get lastConfidence => _lastConfidence;

  /// Get confidence percentage string
  String get lastConfidencePercent =>
      '${(_lastConfidence * 100).toStringAsFixed(0)}%';

  /// Dispose resources
  void dispose() {
    _bufferTimer?.cancel();
    _autoRestartTimer?.cancel();
    _speechToText.stop();
    _speechToText.cancel();
  }
}
