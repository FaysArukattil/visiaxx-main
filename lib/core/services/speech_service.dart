import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// ✅ ULTRA-RELIABLE Speech Recognition Service
/// Features: continuous listening, aggressive retry, dual-buffer system, comprehensive parsing
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // ✅ DUAL-BUFFER SYSTEM: Store both last and best results
  String? _lastRecognizedValue;
  String? _bestRecognizedValue;
  double _lastConfidence = 0.0;
  double _bestConfidence = 0.0;
  Timer? _bufferTimer;
  Timer? _autoRestartTimer;

  // ✅ AGGRESSIVE auto-retry configuration
  int _consecutiveErrors = 0;
  static const int _maxRetries = 10; // Increased from 3
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
      debugPrint('[SpeechService] 🎤 Microphone permission status: $status');

      if (status.isDenied) {
        status = await Permission.microphone.request();
        debugPrint('[SpeechService] 🎤 Permission request result: $status');
      }

      if (status.isPermanentlyDenied) {
        debugPrint(
          '[SpeechService] ❌ Microphone permission permanently denied',
        );
        onError?.call(
          'Microphone permission is permanently denied. Please enable it in Settings.',
        );
        return false;
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('[SpeechService] ⚠️ Permission check error: $e');
      return true; // Try anyway on some devices
    }
  }

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('[SpeechService] ✅ Already initialized');
      return true;
    }

    try {
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('[SpeechService] ❌ No microphone permission');
        return false;
      }

      debugPrint('[SpeechService] 🔄 Initializing speech recognition...');

      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[SpeechService] ❌ Speech error: ${error.errorMsg}');
          _consecutiveErrors++;
          _isListening = false;
          onListeningStopped?.call();

          // ✅ AGGRESSIVE auto-retry on ANY error
          if (_autoRetryEnabled && _consecutiveErrors < _maxRetries) {
            debugPrint(
              '[SpeechService] 🔄 Auto-retrying (${_consecutiveErrors}/$_maxRetries)...',
            );
            _scheduleAutoRestart();
          } else {
            onError?.call(error.errorMsg);
          }
        },
        onStatus: (status) {
          debugPrint('[SpeechService] 📊 Status changed: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStopped?.call();

            // ✅ Auto-restart immediately
            if (_autoRetryEnabled && _consecutiveErrors < _maxRetries) {
              _scheduleAutoRestart();
            }
          } else if (status == 'listening') {
            _isListening = true;
            _consecutiveErrors = 0; // Reset on successful start
            onListeningStarted?.call();
            debugPrint('[SpeechService] ✅ Listening started successfully');
          }
        },
        debugLogging: kDebugMode,
      );

      debugPrint(
        '[SpeechService] ${_isInitialized ? "✅" : "❌"} Initialization result: $_isInitialized',
      );

      if (!_isInitialized) {
        onError?.call('Speech recognition not available on this device');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('[SpeechService] ❌ Initialization error: $e');
      onError?.call('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  /// ✅ FAST auto-restart with aggressive retry
  void _scheduleAutoRestart() {
    _autoRestartTimer?.cancel();
    _autoRestartTimer = Timer(const Duration(milliseconds: 200), () {
      if (_autoRetryEnabled && !_isListening) {
        debugPrint(
          '[SpeechService] 🔄 Auto-restarting... (attempt ${_consecutiveErrors + 1})',
        );
        startListening(autoRestart: true);
      }
    });
  }

  /// ✅ ULTRA-RELIABLE START LISTENING
  ///
  /// Parameters:
  /// - [listenFor]: Maximum listening duration (default: 60 seconds)
  /// - [pauseFor]: How long to wait during silence (default: 5 seconds)
  /// - [bufferMs]: Wait time after last speech before finalizing (default: 1500ms)
  /// - [autoRestart]: Automatically restart listening after it stops (default: false)
  /// - [minConfidence]: Minimum confidence threshold 0.0-1.0 (default: 0.1 - very permissive)
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
    int bufferMs = 1500,
    bool autoRestart = false,
    double minConfidence = 0.1,
  }) async {
    debugPrint(
      '[SpeechService] 🎤 startListening called (autoRestart: $autoRestart)',
    );

    if (!_isInitialized) {
      debugPrint(
        '[SpeechService] ⚠️ Not initialized, attempting to initialize...',
      );
      final success = await initialize();
      if (!success) {
        debugPrint(
          '[SpeechService] ❌ Initialization failed, cannot start listening',
        );
        onError?.call('Speech recognition not available');
        return;
      }
    }

    // Stop if already listening
    if (_isListening) {
      debugPrint('[SpeechService] ⚠️ Already listening, stopping first...');
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _autoRetryEnabled = autoRestart;
    _lastRecognizedValue = null;
    _bestRecognizedValue = null;
    _lastConfidence = 0.0;
    _bestConfidence = 0.0;
    _bufferTimer?.cancel();

    debugPrint(
      '[SpeechService] 🎤 Starting to listen with ULTRA-RELIABLE settings...',
    );

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
      debugPrint('[SpeechService] 🌍 Using locale: ${localeId ?? "default"}');

      await _speechToText.listen(
        onResult: (result) =>
            _onSpeechResultUltraReliable(result, bufferMs, minConfidence),
        listenFor: listenFor ?? const Duration(seconds: 60),
        pauseFor: pauseFor ?? const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: localeId,
        onSoundLevelChange: (level) {
          onSoundLevelChange?.call(level);
        },
      );

      debugPrint(
        '[SpeechService] ✅ Listen started successfully with extended duration',
      );
    } catch (e) {
      debugPrint('[SpeechService] ❌ Error starting listen: $e');
      _isListening = false;
      onListeningStopped?.call();
      onError?.call('Failed to start listening: $e');

      // ✅ Retry even on start error
      if (_autoRetryEnabled && _consecutiveErrors < _maxRetries) {
        _consecutiveErrors++;
        _scheduleAutoRestart();
      }
    }
  }

  /// ✅ ULTRA-RELIABLE speech result handler with dual-buffer system
  void _onSpeechResultUltraReliable(
    SpeechRecognitionResult result,
    int bufferMs,
    double minConfidence,
  ) {
    final recognized = result.recognizedWords.toLowerCase().trim();
    final confidence = result.confidence;

    debugPrint(
      '[SpeechService] 🎤 Recognized: "$recognized" (confidence: ${(confidence * 100).toStringAsFixed(0)}%, final: ${result.finalResult})',
    );

    if (recognized.isNotEmpty) {
      // Always notify for visual feedback
      onSpeechDetected?.call(recognized);

      // ✅ Store BOTH last result AND best result
      _lastRecognizedValue = recognized;
      _lastConfidence = confidence;

      // Keep the BEST quality result (highest confidence)
      if (confidence >= _bestConfidence || _bestRecognizedValue == null) {
        _bestRecognizedValue = recognized;
        _bestConfidence = confidence;
        debugPrint(
          '[SpeechService] ⭐ NEW BEST: "$_bestRecognizedValue" (confidence: ${(_bestConfidence * 100).toStringAsFixed(0)}%)',
        );
      }

      // Accept even LOW confidence results (very permissive threshold)
      if (confidence >= minConfidence) {
        debugPrint('[SpeechService] ✅ Accepted (confidence OK)');
      } else {
        debugPrint('[SpeechService] ⚠️ Low confidence but stored anyway');
      }

      // Reset buffer timer
      _bufferTimer?.cancel();

      if (result.finalResult) {
        // ✅ Final result - use BEST recognized value
        final finalValue = _bestRecognizedValue ?? _lastRecognizedValue;
        if (finalValue != null) {
          debugPrint(
            '[SpeechService] ✅ FINAL result: "$finalValue" (best confidence: ${(_bestConfidence * 100).toStringAsFixed(0)}%)',
          );
          onResult?.call(finalValue);
        }
      } else {
        // ✅ Partial result - wait for buffer period but use BEST value
        _bufferTimer = Timer(Duration(milliseconds: bufferMs), () {
          final valueToUse = _bestRecognizedValue ?? _lastRecognizedValue;
          if (valueToUse != null && _isListening) {
            debugPrint(
              '[SpeechService] ⏱️ Buffer timeout - using BEST value: "$valueToUse"',
            );
            onResult?.call(valueToUse);
          }
        });
      }
    }
  }

  /// Get the BEST recognized value with confidence
  Map<String, dynamic> getLastRecognized() {
    return {
      'value': _bestRecognizedValue ?? _lastRecognizedValue,
      'confidence': _bestConfidence > 0 ? _bestConfidence : _lastConfidence,
    };
  }

  /// Get the best recognized value (simplified)
  String? get lastRecognizedValue =>
      _bestRecognizedValue ?? _lastRecognizedValue;

  /// Stop listening
  Future<void> stopListening() async {
    _bufferTimer?.cancel();
    _autoRestartTimer?.cancel();
    _autoRetryEnabled = false;

    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      onListeningStopped?.call();
      debugPrint('[SpeechService] 🛑 Stopped listening');
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
    _bestRecognizedValue = null;
    _lastConfidence = 0.0;
    _bestConfidence = 0.0;
    onListeningStopped?.call();
    debugPrint('[SpeechService] ❌ Cancelled listening');
  }

  /// ✅ Finalize with BEST recognized value
  String? finalizeWithLastValue() {
    _bufferTimer?.cancel();
    final value = _bestRecognizedValue ?? _lastRecognizedValue;
    _lastRecognizedValue = null;
    _bestRecognizedValue = null;
    _lastConfidence = 0.0;
    _bestConfidence = 0.0;
    debugPrint('[SpeechService] 📊 Finalized with value: "$value"');
    return value;
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if speech recognition is available
  bool get isAvailable => _isInitialized;

  /// Parse direction from speech - PRODUCTION READY
  /// Handles: upward/downward, positional words, homophones, mishears
  static String? parseDirection(String speech) {
    final s = speech.toLowerCase().trim();
    debugPrint('[SpeechService] 🔍 parseDirection input: "$s"');

    // ============ UP Detection ============
    // Direct variations: upward, upwards, up ward (space), upword (mishear)
    if (s.contains('upward') ||
        s.contains('upwards') ||
        s.contains('up ward') ||
        s.contains('upword') ||
        s.contains('apward') ||
        s.contains('uhpward')) {
      debugPrint('[SpeechService] ✅ Matched: upward variants → UP');
      return 'up';
    }
    // Direct: up (check after upward to avoid partial matches)
    if (s.contains('up') ||
        s == 'up' ||
        s.startsWith('up ') ||
        s.endsWith(' up')) {
      debugPrint('[SpeechService] ✅ Matched: up → UP');
      return 'up';
    }
    // Positional: top, upper, above, ceiling, sky
    if (s.contains('top') ||
        s.contains('upper') ||
        s.contains('above') ||
        s.contains('ceiling') ||
        s.contains('sky')) {
      debugPrint('[SpeechService] ✅ Matched: positional → UP');
      return 'up';
    }
    // Mishears for "up" and "upward": app, op, uhp, aap, oop, award, aboard
    if (s.contains('app') ||
        s == 'op' ||
        s.contains(' op ') ||
        s.contains('uhp') ||
        s.contains('aap') ||
        s.contains('oop') ||
        s.contains('aboard') ||
        (s.contains('award') && !s.contains('down'))) {
      debugPrint('[SpeechService] ✅ Matched: mishear → UP');
      return 'up';
    }

    // ============ DOWN Detection ============
    // Direct: downward, downwards, down ward (space)
    if (s.contains('downward') ||
        s.contains('downwards') ||
        s.contains('down ward')) {
      debugPrint('[SpeechService] ✅ Matched: downward/downwards → DOWN');
      return 'down';
    }
    // Direct: down
    if (s.contains('down')) {
      debugPrint('[SpeechService] ✅ Matched: down → DOWN');
      return 'down';
    }
    // Direct: bottom (very important!)
    if (s.contains('bottom') || s.contains('botto') || s.contains('bottam')) {
      debugPrint('[SpeechService] ✅ Matched: bottom → DOWN');
      return 'down';
    }
    // Positional: lower, below, beneath, floor, ground
    if (s.contains('lower') ||
        s.contains('below') ||
        s.contains('beneath') ||
        s.contains('floor') ||
        s.contains('ground')) {
      debugPrint('[SpeechService] ✅ Matched: positional → DOWN');
      return 'down';
    }
    // Mishears: dawn, bott, dun, done
    if (s.contains('dawn') ||
        s.contains('bott') ||
        s.contains('dun') ||
        s == 'done') {
      debugPrint('[SpeechService] ✅ Matched: mishear → DOWN');
      return 'down';
    }

    // ============ RIGHT Detection ============
    // Direct: right, rightward, rightwards
    if (s.contains('rightward') || s.contains('rightwards')) {
      debugPrint('[SpeechService] ✅ Matched: rightward/rightwards → RIGHT');
      return 'right';
    }
    if (s.contains('right')) {
      debugPrint('[SpeechService] ✅ Matched: right → RIGHT');
      return 'right';
    }
    // Homophones: write, wright, rite
    if (s.contains('write') || s.contains('wright') || s.contains('rite')) {
      debugPrint(
        '[SpeechService] ✅ Matched: homophone (write/wright/rite) → RIGHT',
      );
      return 'right';
    }
    // Mishears: righ, rait, rice
    if (s.contains('righ') || s.contains('rait') || s == 'rice') {
      debugPrint('[SpeechService] ✅ Matched: mishear → RIGHT');
      return 'right';
    }

    // ============ LEFT Detection ============
    // Direct: left, leftward, leftwards
    if (s.contains('leftward') || s.contains('leftwards')) {
      debugPrint('[SpeechService] ✅ Matched: leftward/leftwards → LEFT');
      return 'left';
    }
    if (s.contains('left')) {
      debugPrint('[SpeechService] ✅ Matched: left → LEFT');
      return 'left';
    }
    // Homophones: lift, loft
    if (s.contains('lift') || s.contains('loft')) {
      debugPrint('[SpeechService] ✅ Matched: homophone → LEFT');
      return 'left';
    }
    // Mishears: lef, laughed, laf, less
    if (s.contains('lef') ||
        s.contains('laughed') ||
        s.contains('laf') ||
        s == 'less') {
      debugPrint('[SpeechService] ✅ Matched: mishear → LEFT');
      return 'left';
    }

    // ============ Compass Directions (fallback) ============
    if (s.contains('east')) {
      debugPrint('[SpeechService] ✅ Matched: east → RIGHT');
      return 'right';
    }
    if (s.contains('west')) {
      debugPrint('[SpeechService] ✅ Matched: west → LEFT');
      return 'left';
    }
    if (s.contains('north')) {
      debugPrint('[SpeechService] ✅ Matched: north → UP');
      return 'up';
    }
    if (s.contains('south')) {
      debugPrint('[SpeechService] ✅ Matched: south → DOWN');
      return 'down';
    }

    debugPrint('[SpeechService] ❌ parseDirection: NO MATCH for "$s"');
    return null;
  }

  /// Parse number from speech - PRODUCTION READY
  /// Handles: 0-99, teens, tens, compounds, typos, mishears
  static String? parseNumber(String speech) {
    final s = speech.toLowerCase().trim();
    debugPrint('[SpeechService] 🔍 parseNumber input: "$s"');

    // ============ Check for digit first (most reliable) ============
    final digitMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(s);
    if (digitMatch != null) {
      debugPrint('[SpeechService] ✅ Matched digit: ${digitMatch.group(1)}');
      return digitMatch.group(1);
    }

    // ============ Priority: Twelve (commonly needed) ============
    if (s.contains('twelve') ||
        s.contains('twelf') ||
        s.contains('twell') ||
        s.contains('twelv')) {
      debugPrint('[SpeechService] ✅ Matched: twelve → 12');
      return '12';
    }

    // ============ Priority: Seventy-four (Ishihara) ============
    if ((s.contains('seventy') && s.contains('four')) ||
        (s.contains('seven') && s.contains('four'))) {
      debugPrint('[SpeechService] ✅ Matched: seventy four → 74');
      return '74';
    }

    // ============ Priority: Forty-two (Ishihara) ============
    if ((s.contains('forty') || s.contains('fourty')) && s.contains('two')) {
      debugPrint('[SpeechService] ✅ Matched: forty two → 42');
      return '42';
    }

    // ============ All compound numbers 21-99 ============
    final compounds = <String, String>{
      // Twenties
      'twenty one': '21', 'twenty-one': '21', 'twentyone': '21',
      'twenty two': '22', 'twenty-two': '22', 'twentytwo': '22',
      'twenty three': '23', 'twenty-three': '23', 'twentythree': '23',
      'twenty four': '24', 'twenty-four': '24', 'twentyfour': '24',
      'twenty five': '25', 'twenty-five': '25', 'twentyfive': '25',
      'twenty six': '26', 'twenty-six': '26', 'twentysix': '26',
      'twenty seven': '27', 'twenty-seven': '27', 'twentyseven': '27',
      'twenty eight': '28', 'twenty-eight': '28', 'twentyeight': '28',
      'twenty nine': '29', 'twenty-nine': '29', 'twentynine': '29',
      // Thirties
      'thirty one': '31', 'thirty-one': '31',
      'thirty two': '32', 'thirty-two': '32',
      'thirty three': '33', 'thirty-three': '33',
      'thirty four': '34', 'thirty-four': '34',
      'thirty five': '35', 'thirty-five': '35',
      'thirty six': '36', 'thirty-six': '36',
      'thirty seven': '37', 'thirty-seven': '37',
      'thirty eight': '38', 'thirty-eight': '38',
      'thirty nine': '39', 'thirty-nine': '39',
      // Forties (including typo "fourty")
      'forty one': '41', 'forty-one': '41', 'fourty one': '41',
      'forty two': '42', 'forty-two': '42', 'fourty two': '42',
      'forty three': '43', 'forty-three': '43', 'fourty three': '43',
      'forty four': '44', 'forty-four': '44', 'fourty four': '44',
      'forty five': '45', 'forty-five': '45', 'fourty five': '45',
      'forty six': '46', 'forty-six': '46', 'fourty six': '46',
      'forty seven': '47', 'forty-seven': '47', 'fourty seven': '47',
      'forty eight': '48', 'forty-eight': '48', 'fourty eight': '48',
      'forty nine': '49', 'forty-nine': '49', 'fourty nine': '49',
      // Fifties
      'fifty one': '51', 'fifty-one': '51',
      'fifty two': '52', 'fifty-two': '52',
      'fifty three': '53', 'fifty-three': '53',
      'fifty four': '54', 'fifty-four': '54',
      'fifty five': '55', 'fifty-five': '55',
      'fifty six': '56', 'fifty-six': '56',
      'fifty seven': '57', 'fifty-seven': '57',
      'fifty eight': '58', 'fifty-eight': '58',
      'fifty nine': '59', 'fifty-nine': '59',
      // Sixties
      'sixty one': '61', 'sixty-one': '61',
      'sixty two': '62', 'sixty-two': '62',
      'sixty three': '63', 'sixty-three': '63',
      'sixty four': '64', 'sixty-four': '64',
      'sixty five': '65', 'sixty-five': '65',
      'sixty six': '66', 'sixty-six': '66',
      'sixty seven': '67', 'sixty-seven': '67',
      'sixty eight': '68', 'sixty-eight': '68',
      'sixty nine': '69', 'sixty-nine': '69',
      // Seventies
      'seventy one': '71', 'seventy-one': '71',
      'seventy two': '72', 'seventy-two': '72',
      'seventy three': '73', 'seventy-three': '73',
      'seventy four': '74', 'seventy-four': '74',
      'seventy five': '75', 'seventy-five': '75',
      'seventy six': '76', 'seventy-six': '76',
      'seventy seven': '77', 'seventy-seven': '77',
      'seventy eight': '78', 'seventy-eight': '78',
      'seventy nine': '79', 'seventy-nine': '79',
      // Eighties
      'eighty one': '81', 'eighty-one': '81',
      'eighty two': '82', 'eighty-two': '82',
      'eighty three': '83', 'eighty-three': '83',
      'eighty four': '84', 'eighty-four': '84',
      'eighty five': '85', 'eighty-five': '85',
      'eighty six': '86', 'eighty-six': '86',
      'eighty seven': '87', 'eighty-seven': '87',
      'eighty eight': '88', 'eighty-eight': '88',
      'eighty nine': '89', 'eighty-nine': '89',
      // Nineties
      'ninety one': '91', 'ninety-one': '91',
      'ninety two': '92', 'ninety-two': '92',
      'ninety three': '93', 'ninety-three': '93',
      'ninety four': '94', 'ninety-four': '94',
      'ninety five': '95', 'ninety-five': '95',
      'ninety six': '96', 'ninety-six': '96',
      'ninety seven': '97', 'ninety-seven': '97',
      'ninety eight': '98', 'ninety-eight': '98',
      'ninety nine': '99', 'ninety-nine': '99',
    };

    // Check compounds (longest first)
    final sortedCompounds = compounds.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in sortedCompounds) {
      if (s.contains(entry.key)) {
        debugPrint(
          '[SpeechService] ✅ Matched compound: ${entry.key} → ${entry.value}',
        );
        return entry.value;
      }
    }

    // ============ Teens ============
    final teens = <String, String>{
      'nineteen': '19',
      'ninteen': '19',
      'eighteen': '18',
      'eigtheen': '18',
      'seventeen': '17',
      'sevnteen': '17',
      'sixteen': '16',
      'sixten': '16',
      'fifteen': '15',
      'fiften': '15',
      'fourteen': '14',
      'fourten': '14',
      'thirteen': '13',
      'thirten': '13',
      'eleven': '11',
      'elven': '11',
      'ten': '10',
    };

    for (final entry in teens.entries) {
      if (s.contains(entry.key)) {
        debugPrint(
          '[SpeechService] ✅ Matched teen: ${entry.key} → ${entry.value}',
        );
        return entry.value;
      }
    }

    // ============ Round tens ============
    final tens = <String, String>{
      'ninety': '90', 'eighty': '80', 'seventy': '70',
      'sixty': '60', 'fifty': '50',
      'forty': '40', 'fourty': '40', // typo
      'thirty': '30', 'twenty': '20',
    };

    for (final entry in tens.entries) {
      if (s.contains(entry.key)) {
        debugPrint(
          '[SpeechService] ✅ Matched tens: ${entry.key} → ${entry.value}',
        );
        return entry.value;
      }
    }

    // ============ Single digits ============
    final singles = <String, String>{
      'zero': '0',
      'oh': '0',
      'o': '0',
      'one': '1',
      'won': '1',
      'two': '2',
      'to': '2',
      'too': '2',
      'three': '3',
      'tree': '3',
      'four': '4',
      'for': '4',
      'fore': '4',
      'five': '5',
      'fiv': '5',
      'six': '6',
      'siks': '6',
      'seven': '7',
      'sevn': '7',
      'eight': '8',
      'ate': '8',
      'ait': '8',
      'nine': '9',
      'nein': '9',
    };

    // Check for single digit (must be exact match or word boundary)
    final words = s.split(RegExp(r'\s+'));
    for (final word in words) {
      if (singles.containsKey(word)) {
        debugPrint(
          '[SpeechService] ✅ Matched single: $word → ${singles[word]}',
        );
        return singles[word];
      }
    }

    // ============ Digit-by-digit parsing (e.g., "seven four" → 74) ============
    String digitResult = '';
    for (final word in words) {
      if (singles.containsKey(word)) {
        digitResult += singles[word]!;
      }
    }
    if (digitResult.isNotEmpty && digitResult.length <= 2) {
      debugPrint('[SpeechService] ✅ Matched digit-by-digit: $digitResult');
      return digitResult;
    }

    debugPrint('[SpeechService] ❌ parseNumber: NO MATCH for "$s"');
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
  double get lastConfidence =>
      _bestConfidence > 0 ? _bestConfidence : _lastConfidence;

  /// Get confidence percentage string
  String get lastConfidencePercent =>
      '${(lastConfidence * 100).toStringAsFixed(0)}%';

  /// Dispose resources
  void dispose() {
    _bufferTimer?.cancel();
    _autoRestartTimer?.cancel();
    _speechToText.stop();
    _speechToText.cancel();
  }
}
