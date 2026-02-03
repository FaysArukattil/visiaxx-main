import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:permission_handler/permission_handler.dart';

/// Represents the current state of voice recognition
enum VoiceRecognitionState {
  /// Not yet initialized or stopped
  idle,

  /// Actively listening for speech
  listening,

  /// Processing recognized speech
  processing,

  /// An error occurred
  error,

  /// Speech recognition is not available on this device
  unavailable,
}

/// Voice Recognition Service for VisiAxx Eye Testing App
///
/// Features:
/// - Balance between Offline and Cloud recognition using device defaults
/// - Works across all Android variants (MIUI, OneUI, ColorOS, etc.)
/// - Uses device's default locale (no forced language)
/// - Vocabulary matching for test-specific words
/// - Error recovery with automatic restart capabilities
class VoiceRecognitionService {
  static final VoiceRecognitionService _instance =
      VoiceRecognitionService._internal();
  factory VoiceRecognitionService() => _instance;
  VoiceRecognitionService._internal();

  final SpeechToText _speech = SpeechToText();

  // State management
  VoiceRecognitionState _state = VoiceRecognitionState.idle;
  bool _isInitialized = false;
  bool _isInitializing = false;
  LocaleName? _systemLocale; // Store the system locale for offline recognition
  String? _lastError;

  // Audio level for waveform visualization
  double _audioLevel = 0.0;
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();

  // State stream
  final StreamController<VoiceRecognitionState> _stateController =
      StreamController<VoiceRecognitionState>.broadcast();

  // Result callback
  Function(String recognizedText, bool isFinal)? _onResult;

  // Getters
  VoiceRecognitionState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isListening => _speech.isListening;
  bool get isAvailable =>
      _isInitialized && _state != VoiceRecognitionState.unavailable;
  String? get lastError => _lastError;
  double get audioLevel => _audioLevel;
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<VoiceRecognitionState> get stateStream => _stateController.stream;

  /// Initialize the speech recognition service
  /// Returns true if initialization was successful
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) return false;

    _isInitializing = true;
    try {
      debugPrint('[VoiceRecognition] Checking microphone permission...');
      final status = await Permission.microphone.status;

      if (!status.isGranted) {
        debugPrint('[VoiceRecognition] Requesting microphone permission...');
        final result = await Permission.microphone.request().timeout(
          const Duration(seconds: 5),
          onTimeout: () => PermissionStatus.denied,
        );
        if (!result.isGranted) {
          debugPrint('[VoiceRecognition] Permission denied or timed out');
          _updateState(VoiceRecognitionState.error);
          _lastError = 'Microphone permission required';
          return false;
        }
      }

      debugPrint('[VoiceRecognition] Initializing system speech engine...');
      // Initialize with a timeout because it can hang if Play Services is buggy
      final bool available = await _speech
          .initialize(
            onStatus: _onStatus,
            onError: _onError,
            debugLogging: false, // Reduced log noise as requested
          )
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (!available) {
        debugPrint('[VoiceRecognition] Speech engine NOT AVAILABLE');
        _updateState(VoiceRecognitionState.unavailable);
        _lastError = 'Speech engine not available';
        return false;
      }

      _isInitialized = true;
      _updateState(VoiceRecognitionState.idle);

      _systemLocale = await _speech.systemLocale().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      debugPrint(
        '[VoiceRecognition] Ready! Locale: ${_systemLocale?.localeId ?? 'default'} (System Defaults)',
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceRecognition] Initialization EXCEPTION: $e');
      _lastError = e.toString();
      _updateState(VoiceRecognitionState.error);
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Start listening for speech
  /// [onResult] is called with recognized text (isFinal indicates if recognition is complete)
  /// [vocabularyHints] optional list of expected words to improve recognition accuracy
  Future<void> startListening({
    required Function(String recognizedText, bool isFinal) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    List<String>? vocabularyHints,
  }) async {
    if (!_isInitialized) {
      debugPrint('[VoiceRecognition] Cannot start: not initialized');
      final success = await initialize();
      if (!success) return;
    }

    // Aggressive cleanup before starting
    try {
      if (_speech.isListening || _speech.isAvailable) {
        await _speech.cancel();
        // Give the OS a moment to truly release the hardware
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {}

    _onResult = onResult;

    try {
      debugPrint(
        '[VoiceRecognition] Starting listen session (System Defaults)...',
      );

      // Use system defaults as requested.
      // This allows the OS to decide between offline and cloud automatically.
      bool started =
          await _speech.listen(
            onResult: _handleResult,
            listenFor: listenFor ?? const Duration(seconds: 45),
            pauseFor: pauseFor ?? const Duration(seconds: 5),
            listenOptions: SpeechListenOptions(
              onDevice: false, // Default behavior (Cloud/Online allowed)
              cancelOnError: false,
              partialResults: true,
            ),
            onSoundLevelChange: (level) {
              _audioLevel = ((level + 2) / 12).clamp(0.0, 1.0);
              _audioLevelController.add(_audioLevel);
            },
          ) ??
          false;

      // SAFETY: If it returns false but is actually listening (common bug), count as success
      if (!started && _speech.isListening) {
        debugPrint('[VoiceRecognition] ✅ Engine reported listening via status');
        started = true;
      }

      if (started || _speech.isListening) {
        _updateState(VoiceRecognitionState.listening);
        debugPrint('[VoiceRecognition] ✅ Started listening!');
      } else {
        debugPrint('[VoiceRecognition] ❌ Engine refused session.');
        _updateState(VoiceRecognitionState.error);
        _lastError = 'Could not start microphone';
      }
    } catch (e) {
      debugPrint('[VoiceRecognition] ❌ EXCEPTION: $e');
      _lastError = e.toString();
      _updateState(VoiceRecognitionState.error);
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    if (!_speech.isListening) return;

    try {
      await _speech.stop();
      _updateState(VoiceRecognitionState.idle);
      _audioLevel = 0.0;
      _audioLevelController.add(0.0);
      debugPrint('[VoiceRecognition] Stopped listening');
    } catch (e) {
      debugPrint('[VoiceRecognition] Error stopping: $e');
    }
  }

  /// Cancel any ongoing recognition
  Future<void> cancel() async {
    try {
      await _speech.cancel();
      _updateState(VoiceRecognitionState.idle);
      _audioLevel = 0.0;
      _audioLevelController.add(0.0);
    } catch (e) {
      debugPrint('[VoiceRecognition] Error canceling: $e');
    }
  }

  /// Restart listening (useful for error recovery)
  Future<void> restart({
    required Function(String recognizedText, bool isFinal) onResult,
  }) async {
    debugPrint('[VoiceRecognition] Restarting...');
    await cancel();

    // Small delay to ensure clean restart
    await Future.delayed(const Duration(milliseconds: 300));

    if (!_isInitialized) {
      await initialize();
    }

    if (_isInitialized && _state != VoiceRecognitionState.unavailable) {
      await startListening(onResult: onResult);
    }
  }

  /// Match recognized text against a vocabulary list
  /// Returns the matched word or null if no match found
  String? matchVocabulary(String input, List<String> vocabulary) {
    if (input.isEmpty) return null;

    final normalizedInput = input.toLowerCase().trim();

    // First, try exact match
    for (final word in vocabulary) {
      if (normalizedInput == word.toLowerCase()) {
        return word;
      }
    }

    // Try contains match (for when user says more than just the word)
    for (final word in vocabulary) {
      final normalizedWord = word.toLowerCase();
      // Check if the word is present as a separate word (not substring)
      final words = normalizedInput.split(RegExp(r'\s+'));
      if (words.contains(normalizedWord)) {
        return word;
      }
    }

    // Pre-process input to fix common misrecognitions
    String preprocessedInput = normalizedInput;

    // Fix common misrecognitions for directional words
    if (preprocessedInput.contains('download')) {
      preprocessedInput = preprocessedInput.replaceAll('download', 'down');
    }
    if (preprocessedInput.contains('upward')) {
      preprocessedInput = preprocessedInput.replaceAll('upward', 'up');
    }
    if (preprocessedInput.contains('downward')) {
      preprocessedInput = preprocessedInput.replaceAll('downward', 'down');
    }
    if (preprocessedInput.contains('leftward')) {
      preprocessedInput = preprocessedInput.replaceAll('leftward', 'left');
    }
    if (preprocessedInput.contains('rightward')) {
      preprocessedInput = preprocessedInput.replaceAll('rightward', 'right');
    }

    // Try fuzzy match for common mishearings with expanded variants
    final fuzzyMatches = <String, List<String>>{
      'left': ['left', 'lift', 'lest', 'let', 'laughed', 'cleft', 'leaft'],
      'right': ['right', 'write', 'rite', 'wright', 'white', 'ride', 'ripe'],
      'up': ['up', 'app', 'hub', 'uhp', 'uh', 'upper', 'a', 'yup'],
      'down': ['down', 'town', 'dawn', 'done', 'drown', 'don'],
      'blurry': ['blurry', 'blurred', 'blur', 'blury', 'blaring', 'bleary'],
      'visible': ['visible', 'I can see', 'visible', 'i see it', 'visual'],
      'not visible': [
        'not visible',
        'cannot see',
        "can't see",
        'invisible',
        'no',
      ],
    };

    // First check preprocessed input for exact matches
    for (final word in vocabulary) {
      if (preprocessedInput == word.toLowerCase()) {
        return word;
      }
    }

    // Then check for word boundaries in preprocessed input
    final preprocessedWords = preprocessedInput.split(RegExp(r'\s+'));
    for (final word in vocabulary) {
      final normalizedWord = word.toLowerCase();
      if (preprocessedWords.contains(normalizedWord)) {
        return word;
      }
    }

    // Finally apply fuzzy matching
    for (final entry in fuzzyMatches.entries) {
      if (vocabulary.contains(entry.key)) {
        for (final variant in entry.value) {
          if (preprocessedInput.contains(variant.toLowerCase())) {
            return entry.key;
          }
        }
      }
    }

    return null;
  }

  /// Match recognized text for direction commands
  /// Returns: 'left', 'right', 'up', 'down', 'blurry', or null
  String? matchDirection(String input) {
    return matchVocabulary(input, ['left', 'right', 'up', 'down', 'blurry']);
  }

  /// Match recognized text for numbers (1-99)
  /// Returns the number as string or null
  String? matchNumber(String input) {
    if (input.isEmpty) return null;

    final normalizedInput = input.toLowerCase().trim();

    // Number word to digit mapping
    final numberWords = <String, String>{
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
      'ten': '10',
      'eleven': '11',
      'twelve': '12',
      'thirteen': '13',
      'fourteen': '14',
      'fifteen': '15',
      'sixteen': '16',
      'seventeen': '17',
      'eighteen': '18',
      'nineteen': '19',
      'twenty': '20',
      'twenty one': '21',
      'twenty two': '22',
      'twenty three': '23',
      'twenty four': '24',
      'twenty five': '25',
      'twenty six': '26',
      'twenty seven': '27',
      'twenty eight': '28',
      'twenty nine': '29',
      'thirty': '30',
      'thirty one': '31',
      'thirty two': '32',
      'thirty three': '33',
      'thirty four': '34',
      'thirty five': '35',
      'thirty six': '36',
      'thirty seven': '37',
      'thirty eight': '38',
      'thirty nine': '39',
      'forty': '40',
      'forty one': '41',
      'forty two': '42',
      'forty three': '43',
      'forty four': '44',
      'forty five': '45',
      'forty six': '46',
      'forty seven': '47',
      'forty eight': '48',
      'forty nine': '49',
      'fifty': '50',
      'fifty one': '51',
      'fifty two': '52',
      'fifty three': '53',
      'fifty four': '54',
      'fifty five': '55',
      'fifty six': '56',
      'fifty seven': '57',
      'fifty eight': '58',
      'fifty nine': '59',
      'sixty': '60',
      'sixty one': '61',
      'sixty two': '62',
      'sixty three': '63',
      'sixty four': '64',
      'sixty five': '65',
      'sixty six': '66',
      'sixty seven': '67',
      'sixty eight': '68',
      'sixty nine': '69',
      'seventy': '70',
      'seventy one': '71',
      'seventy two': '72',
      'seventy three': '73',
      'seventy four': '74',
      'seventy five': '75',
      'seventy six': '76',
      'seventy seven': '77',
      'seventy eight': '78',
      'seventy nine': '79',
      'eighty': '80',
      'eighty one': '81',
      'eighty two': '82',
      'eighty three': '83',
      'eighty four': '84',
      'eighty five': '85',
      'eighty six': '86',
      'eighty seven': '87',
      'eighty eight': '88',
      'eighty nine': '89',
      'ninety': '90',
      'ninety one': '91',
      'ninety two': '92',
      'ninety three': '93',
      'ninety four': '94',
      'ninety five': '95',
      'ninety six': '96',
      'ninety seven': '97',
      'ninety eight': '98',
      'ninety nine': '99',
    };

    // Check word-based numbers first (longer matches first)
    final sortedKeys = numberWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in sortedKeys) {
      if (normalizedInput.contains(word)) {
        return numberWords[word];
      }
    }

    // Check for digit patterns
    final digitMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(normalizedInput);
    if (digitMatch != null) {
      final number = int.tryParse(digitMatch.group(1)!);
      if (number != null && number >= 0 && number <= 99) {
        return number.toString();
      }
    }

    // Check for "nothing" or "cannot see"
    if (normalizedInput.contains('nothing') ||
        normalizedInput.contains("can't see") ||
        normalizedInput.contains('cannot see')) {
      return 'nothing';
    }

    return null;
  }

  /// Match recognized text for letters (A-Z)
  /// Returns the letter as uppercase string or null
  String? matchLetter(String input) {
    if (input.isEmpty) return null;

    final normalizedInput = input.toLowerCase().trim();

    // Common letter pronunciations/mishearings
    final letterMappings = <String, String>{
      // Standard letters
      'a': 'A', 'ay': 'A', 'eh': 'A',
      'b': 'B', 'be': 'B', 'bee': 'B',
      'c': 'C', 'see': 'C', 'sea': 'C',
      'd': 'D', 'dee': 'D',
      'e': 'E', 'ee': 'E',
      'f': 'F', 'ef': 'F', 'eff': 'F',
      'g': 'G', 'gee': 'G', 'jee': 'G',
      'h': 'H', 'aitch': 'H',
      'i': 'I', 'eye': 'I',
      'j': 'J', 'jay': 'J',
      'k': 'K', 'kay': 'K',
      'l': 'L', 'el': 'L', 'ell': 'L',
      'm': 'M', 'em': 'M',
      'n': 'N', 'en': 'N',
      'o': 'O', 'oh': 'O',
      'p': 'P', 'pee': 'P',
      'q': 'Q', 'cue': 'Q', 'queue': 'Q',
      'r': 'R', 'are': 'R', 'ar': 'R',
      's': 'S', 'es': 'S', 'ess': 'S',
      't': 'T', 'tee': 'T', 'tea': 'T',
      'u': 'U', 'you': 'U',
      'v': 'V', 'vee': 'V',
      'w': 'W', 'double u': 'W', 'double you': 'W',
      'x': 'X', 'ex': 'X', 'ecks': 'X',
      'y': 'Y', 'why': 'Y', 'wye': 'Y',
      'z': 'Z', 'zee': 'Z', 'zed': 'Z',
    };

    // Split into words and check each
    final words = normalizedInput.split(RegExp(r'\s+'));
    for (final word in words) {
      if (letterMappings.containsKey(word)) {
        return letterMappings[word];
      }
    }

    // Check single character if input is just one letter
    if (normalizedInput.length == 1 &&
        RegExp(r'[a-z]').hasMatch(normalizedInput)) {
      return normalizedInput.toUpperCase();
    }

    return null;
  }

  /// Match recognized text for visibility responses (Pelli-Robson)
  /// Returns 'visible' or 'not visible' or null
  String? matchVisibility(String input) {
    if (input.isEmpty) return null;

    final normalizedInput = input.toLowerCase().trim();

    // Check for negative responses first (more specific)
    final notVisiblePatterns = [
      'not visible',
      'cannot see',
      "can't see",
      'invisible',
      'no',
      'not clear',
      'cannot read',
      "can't read",
      'blurry',
      'not visible',
      'i cannot',
      "i can't",
    ];

    for (final pattern in notVisiblePatterns) {
      if (normalizedInput.contains(pattern)) {
        return 'not visible';
      }
    }

    // Check for positive responses
    final visiblePatterns = [
      'visible',
      'yes',
      'i can see',
      'i see',
      'clear',
      'can see',
      'can read',
      'i can read',
    ];

    for (final pattern in visiblePatterns) {
      if (normalizedInput.contains(pattern)) {
        return 'visible';
      }
    }

    return null;
  }

  /// Match recognized text for reading capability (Short Distance Test)
  /// Returns 'can read' or 'cannot read' or null
  String? matchReadingCapability(String input) {
    if (input.isEmpty) return null;

    final normalizedInput = input.toLowerCase().trim();

    // Check for negative responses first
    final cannotReadPatterns = [
      'cannot read',
      "can't read",
      'unable to read',
      'blurry',
      'blur',
      'cannot see',
      "can't see",
      'no',
      'not clear',
      'too small',
      'hard to read',
    ];

    for (final pattern in cannotReadPatterns) {
      if (normalizedInput.contains(pattern)) {
        return 'cannot read';
      }
    }

    // Check for positive responses
    final canReadPatterns = [
      'can read',
      'i can read',
      'yes',
      'readable',
      'clear',
      'i can see',
      'visible',
    ];

    for (final pattern in canReadPatterns) {
      if (normalizedInput.contains(pattern)) {
        return 'can read';
      }
    }

    return null;
  }

  /// Handle speech recognition result
  void _handleResult(SpeechRecognitionResult result) {
    if (_state == VoiceRecognitionState.listening) {
      _updateState(VoiceRecognitionState.processing);
    }

    final recognizedText = result.recognizedWords;
    final isFinalResult = result.finalResult; // Null safety fix

    debugPrint(
      '[VoiceRecognition] Result: "$recognizedText" (final: $isFinalResult)',
    );

    _onResult?.call(recognizedText, isFinalResult);

    // Return to listening state if not final
    if (!isFinalResult && _state == VoiceRecognitionState.processing) {
      _updateState(VoiceRecognitionState.listening);
    }
  }

  /// Handle status changes from speech recognition
  void _onStatus(String status) {
    debugPrint('[VoiceRecognition] Status: $status');

    switch (status) {
      case 'listening':
        _updateState(VoiceRecognitionState.listening);
        break;
      case 'notListening':
        if (_state == VoiceRecognitionState.listening) {
          _updateState(VoiceRecognitionState.idle);
        }
        break;
      case 'done':
        _updateState(VoiceRecognitionState.idle);
        break;
    }
  }

  /// Handle errors from speech recognition
  void _onError(SpeechRecognitionError error) {
    debugPrint(
      '[VoiceRecognition] Error: ${error.errorMsg} (permanent: ${error.permanent})',
    );

    _lastError = error.errorMsg;

    if (error.permanent) {
      // Permanent error - might need reinitialization
      _updateState(VoiceRecognitionState.error);
    } else {
      // Temporary error - try to recover
      _updateState(VoiceRecognitionState.idle);
    }
  }

  /// Update state and notify listeners
  void _updateState(VoiceRecognitionState newState) {
    if (_state != newState) {
      _state = newState;
      // Use microtask to ensure we don't trigger builds during builds
      Future.microtask(() {
        if (!_stateController.isClosed) {
          _stateController.add(newState);
        }
      });
    }
  }

  /// Dispose resources
  void dispose() {
    _speech.stop();
    _audioLevelController.close();
    _stateController.close();
    _isInitialized = false;
  }
}
