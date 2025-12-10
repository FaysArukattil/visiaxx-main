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

  /// Parse direction from speech - ULTIMATE EDITION with ALL possible slang and variations
  static String? parseDirection(String speech) {
    final normalized = speech.toLowerCase().trim();
    
    // Remove common filler words
    final cleaned = normalized
        .replaceAll(RegExp(r'\b(go|move|turn|direction|side|the|to|towards?)\b'), '')
        .trim();

    // ============= UP VARIATIONS =============
    // Direct matches (highest priority)
    if (normalized == 'up' || cleaned == 'up' ||
        normalized == 'u' || cleaned == 'u') return 'up';
    
    // Common mishearings
    if (normalized == 'app' || normalized == 'a' || 
        normalized == 'uh' || normalized == 'ah' ||
        normalized == 'op' || normalized == 'oop' ||
        normalized == 'ep' || normalized == 'eep') return 'up';
    
    // Contains checks for UP
    if (normalized.contains('up') || cleaned.contains('up') ||
        normalized.contains('upp') || normalized.contains('uhp') ||
        normalized.contains('uup') || normalized.contains('oop') ||
        normalized.contains('aap') || normalized.contains('aup') ||
        normalized.contains('ap ') || normalized.contains(' ap')) return 'up';
    
    // Hindi/Indian variations for UP
    if (normalized.contains('upar') || normalized.contains('uper') ||
        normalized.contains('uppar') || normalized.contains('oopar') ||
        normalized.contains('upr') || normalized.contains('upor') ||
        normalized.contains('upaar') || normalized.contains('upeer') ||
        normalized.contains('upur') || normalized.contains('upir')) return 'up';
    
    // English synonyms for UP
    if (normalized.contains('upper') || normalized.contains('upward') ||
        normalized.contains('upside') || normalized.contains('above') ||
        normalized.contains('top') || normalized.contains('ceiling') ||
        normalized.contains('sky') || normalized.contains('overhead') ||
        normalized.contains('high') || normalized.contains('higher') ||
        normalized.contains('ascend') || normalized.contains('rise') ||
        normalized.contains('elevat')) return 'up';
    
    // Phonetic variations
    if (normalized.contains('uhp') || normalized.contains('awp') ||
        normalized.contains('ope') || normalized.contains('upe')) return 'up';

    // ============= DOWN VARIATIONS =============
    // Direct matches
    if (normalized == 'down' || cleaned == 'down' ||
        normalized == 'd' || cleaned == 'd') return 'down';
    
    // Common mishearings
    if (normalized == 'dawn' || normalized == 'dun' ||
        normalized == 'don' || normalized == 'town' ||
        normalized == 'daun') return 'down';
    
    // Contains checks for DOWN
    if (normalized.contains('down') || cleaned.contains('down') ||
        normalized.contains('dwn') || normalized.contains('doun') ||
        normalized.contains('daun') || normalized.contains('dowm') ||
        normalized.contains('donw')) return 'down';
    
    // Hindi/Indian variations for DOWN
    if (normalized.contains('neeche') || normalized.contains('neche') ||
        normalized.contains('nichay') || normalized.contains('niche') ||
        normalized.contains('neechi') || normalized.contains('neecha') ||
        normalized.contains('neechey') || normalized.contains('nichey') ||
        normalized.contains('necha') || normalized.contains('nicha') ||
        normalized.contains('neech') || normalized.contains('nich')) return 'down';
    
    // English synonyms for DOWN
    if (normalized.contains('downward') || normalized.contains('below') ||
        normalized.contains('bottom') || normalized.contains('floor') ||
        normalized.contains('ground') || normalized.contains('under') ||
        normalized.contains('beneath') || normalized.contains('lower') ||
        normalized.contains('descend') || normalized.contains('drop') ||
        normalized.contains('fall')) return 'down';
    
    // Phonetic variations
    if (normalized.contains('dahn') || normalized.contains('doun')) return 'down';

    // ============= RIGHT VARIATIONS =============
    // Direct matches
    if (normalized == 'right' || cleaned == 'right' ||
        normalized == 'r' || cleaned == 'r') return 'right';
    
    // Common mishearings
    if (normalized == 'rite' || normalized == 'write' ||
        normalized == 'wright' || normalized == 'rit' ||
        normalized == 'ryt' || normalized == 'ryte') return 'right';
    
    // Contains checks for RIGHT
    if (normalized.contains('right') || cleaned.contains('right') ||
        normalized.contains('rite') || normalized.contains('wright') ||
        normalized.contains('write') || normalized.contains('ryt') ||
        normalized.contains('righte') || normalized.contains('righ') ||
        normalized.contains('riht') || normalized.contains('rigth')) return 'right';
    
    // Hindi/Indian variations for RIGHT
    if (normalized.contains('daya') || normalized.contains('dayan') ||
        normalized.contains('dayen') || normalized.contains('dayein') ||
        normalized.contains('daine') || normalized.contains('dahina') ||
        normalized.contains('dahine') || normalized.contains('dahin') ||
        normalized.contains('daya') || normalized.contains('daaya') ||
        normalized.contains('dayaa') || normalized.contains('dya') ||
        normalized.contains('dye') || normalized.contains('dai')) return 'right';
    
    // English synonyms for RIGHT
    if (normalized.contains('rightward') || normalized.contains('rightside') ||
        normalized.contains('starboard') || normalized.contains('dexter') ||
        normalized.contains('clockwise')) return 'right';
    
    // Phonetic variations
    if (normalized.contains('rayt') || normalized.contains('rait') ||
        normalized.contains('riet') || normalized.contains('reet')) return 'right';

    // ============= LEFT VARIATIONS =============
    // Direct matches
    if (normalized == 'left' || cleaned == 'left' ||
        normalized == 'l' || cleaned == 'l') return 'left';
    
    // Common mishearings
    if (normalized == 'lef' || normalized == 'lift' ||
        normalized == 'laft' || normalized == 'lef') return 'left';
    
    // Contains checks for LEFT
    if (normalized.contains('left') || cleaned.contains('left') ||
        normalized.contains('lef') || normalized.contains('laft') ||
        normalized.contains('lefte') || normalized.contains('lft') ||
        normalized.contains('lefft') || normalized.contains('leff')) return 'left';
    
    // Hindi/Indian variations for LEFT
    if (normalized.contains('baya') || normalized.contains('bayan') ||
        normalized.contains('bayen') || normalized.contains('bayein') ||
        normalized.contains('baine') || normalized.contains('baaya') ||
        normalized.contains('bayaa') || normalized.contains('bya') ||
        normalized.contains('bye') || normalized.contains('bai') ||
        normalized.contains('baye') || normalized.contains('baay')) return 'left';
    
    // English synonyms for LEFT
    if (normalized.contains('leftward') || normalized.contains('leftside') ||
        normalized.contains('port') || normalized.contains('sinister') ||
        normalized.contains('counter') && normalized.contains('clock')) return 'left';
    
    // Phonetic variations
    if (normalized.contains('laeft') || normalized.contains('lefft')) return 'left';

    // ============= COMPASS DIRECTIONS =============
    if (normalized.contains('north') || normalized.contains('uttar') ||
        normalized.contains('utter')) return 'up';
    
    if (normalized.contains('south') || normalized.contains('dakshin') ||
        normalized.contains('dakshan')) return 'down';
    
    if (normalized.contains('east') || normalized.contains('purva') ||
        normalized.contains('poorva') || normalized.contains('purv')) return 'right';
    
    if (normalized.contains('west') || normalized.contains('paschim') ||
        normalized.contains('pashchim') || normalized.contains('pascham')) return 'left';

    // ============= SLANG & COLLOQUIAL =============
    // Indian English slang
    if (normalized.contains('uppar') || normalized.contains('oppar') ||
        normalized.contains('oopar')) return 'up';
    
    if (normalized.contains('niche') || normalized.contains('nichey')) return 'down';
    
    if (normalized.contains('right side') || normalized.contains('right hand') ||
        normalized.contains('right waala')) return 'right';
    
    if (normalized.contains('left side') || normalized.contains('left hand') ||
        normalized.contains('left waala')) return 'left';

    // ============= NUMERIC/GAMING SLANG =============
    if (normalized.contains('8') && !normalized.contains('18')) return 'up'; // numpad 8
    if (normalized.contains('2') && !normalized.contains('12') && !normalized.contains('20')) return 'down'; // numpad 2
    if (normalized.contains('6') && !normalized.contains('16')) return 'right'; // numpad 6
    if (normalized.contains('4') && !normalized.contains('14') && !normalized.contains('40')) return 'left'; // numpad 4

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