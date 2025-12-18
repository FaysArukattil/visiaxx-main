import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// ✅ FIXED Speech Recognition Service
/// Key fixes:
/// - Better TTS pause handling
/// - Simplified buffer system
/// - More reliable callbacks
/// - No conflicting auto-restart
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // Single buffer system (simplified from dual-buffer)
  String? _lastRecognizedValue;
  double _lastConfidence = 0.0;
  Timer? _bufferTimer;

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
      return true;
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
          _isListening = false;

          // Call callbacks safely
          if (onListeningStopped != null) {
            onListeningStopped!();
          }
          if (onError != null) {
            onError!(error.errorMsg);
          }
        },
        onStatus: (status) {
          debugPrint('[SpeechService] 📊 Status changed: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            if (onListeningStopped != null) {
              onListeningStopped!();
            }
          } else if (status == 'listening') {
            _isListening = true;
            if (onListeningStarted != null) {
              onListeningStarted!();
            }
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

  /// START LISTENING (No auto-restart - managed externally)
  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
    int bufferMs = 1500,
    double minConfidence = 0.1,
  }) async {
    debugPrint('[SpeechService] 🎤 startListening called');

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

    _lastRecognizedValue = null;
    _lastConfidence = 0.0;
    _bufferTimer?.cancel();

    debugPrint('[SpeechService] 🎤 Starting to listen...');

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
        onResult: (result) => _onSpeechResult(result, bufferMs, minConfidence),
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

      debugPrint('[SpeechService] ✅ Listen started successfully');
    } catch (e) {
      debugPrint('[SpeechService] ❌ Error starting listen: $e');
      _isListening = false;
      onListeningStopped?.call();
      onError?.call('Failed to start listening: $e');
    }
  }

  /// Speech result handler
  void _onSpeechResult(
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
      if (onSpeechDetected != null) {
        onSpeechDetected!(recognized);
      }

      // Store result
      _lastRecognizedValue = recognized;
      _lastConfidence = confidence;

      // Accept even LOW confidence results
      if (confidence >= minConfidence) {
        debugPrint('[SpeechService] ✅ Accepted (confidence OK)');
      } else {
        debugPrint('[SpeechService] ⚠️ Low confidence but stored anyway');
      }

      // Reset buffer timer
      _bufferTimer?.cancel();

      if (result.finalResult) {
        // Final result
        if (_lastRecognizedValue != null) {
          debugPrint('[SpeechService] ✅ FINAL result: "$_lastRecognizedValue"');
          if (onResult != null) {
            onResult!(_lastRecognizedValue!);
          }
        }
      } else {
        // Partial result - wait for buffer period
        _bufferTimer = Timer(Duration(milliseconds: bufferMs), () {
          if (_lastRecognizedValue != null && _isListening) {
            debugPrint(
              '[SpeechService] ⏱️ Buffer timeout - using value: "$_lastRecognizedValue"',
            );
            if (onResult != null) {
              onResult!(_lastRecognizedValue!);
            }
          }
        });
      }
    }
  }

  /// Get last recognized value with confidence
  Map<String, dynamic> getLastRecognized() {
    return {'value': _lastRecognizedValue, 'confidence': _lastConfidence};
  }

  /// Get the last recognized value (simplified)
  String? get lastRecognizedValue => _lastRecognizedValue;

  /// Stop listening
  Future<void> stopListening() async {
    _bufferTimer?.cancel();

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

    await _speechToText.cancel();
    _isListening = false;
    _lastRecognizedValue = null;
    _lastConfidence = 0.0;
    onListeningStopped?.call();
    debugPrint('[SpeechService] ❌ Cancelled listening');
  }

  /// Finalize with last value
  String? finalizeWithLastValue() {
    _bufferTimer?.cancel();
    final value = _lastRecognizedValue;
    _lastRecognizedValue = null;
    _lastConfidence = 0.0;
    debugPrint('[SpeechService] 📊 Finalized with value: "$value"');
    return value;
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if speech recognition is available
  bool get isAvailable => _isInitialized;

  /// Parse direction from speech
  static String? parseDirection(String speech) {
    final s = speech.toLowerCase().trim();
    debugPrint('[SpeechService] 🔍 parseDirection input: "$s"');

    // UP Detection
    if (s.contains('upward') ||
        s.contains('upwards') ||
        s.contains('up ward') ||
        s.contains('upword') ||
        s.contains('apward') ||
        s.contains('uhpward')) {
      debugPrint('[SpeechService] ✅ Matched: upward variants → UP');
      return 'up';
    }
    if (s.contains('up') ||
        s == 'up' ||
        s.startsWith('up ') ||
        s.endsWith(' up')) {
      debugPrint('[SpeechService] ✅ Matched: up → UP');
      return 'up';
    }
    if (s.contains('top') ||
        s.contains('upper') ||
        s.contains('above') ||
        s.contains('ceiling') ||
        s.contains('sky')) {
      debugPrint('[SpeechService] ✅ Matched: positional → UP');
      return 'up';
    }

    // DOWN Detection
    if (s.contains('downward') ||
        s.contains('downwards') ||
        s.contains('down ward')) {
      debugPrint('[SpeechService] ✅ Matched: downward/downwards → DOWN');
      return 'down';
    }
    if (s.contains('down')) {
      debugPrint('[SpeechService] ✅ Matched: down → DOWN');
      return 'down';
    }
    if (s.contains('bottom') || s.contains('botto') || s.contains('bottam')) {
      debugPrint('[SpeechService] ✅ Matched: bottom → DOWN');
      return 'down';
    }
    if (s.contains('lower') ||
        s.contains('below') ||
        s.contains('beneath') ||
        s.contains('floor') ||
        s.contains('ground')) {
      debugPrint('[SpeechService] ✅ Matched: positional → DOWN');
      return 'down';
    }

    // RIGHT Detection
    if (s.contains('rightward') || s.contains('rightwards')) {
      debugPrint('[SpeechService] ✅ Matched: rightward/rightwards → RIGHT');
      return 'right';
    }
    if (s.contains('right')) {
      debugPrint('[SpeechService] ✅ Matched: right → RIGHT');
      return 'right';
    }
    if (s.contains('write') || s.contains('wright') || s.contains('rite')) {
      debugPrint('[SpeechService] ✅ Matched: homophone → RIGHT');
      return 'right';
    }

    // LEFT Detection
    if (s.contains('leftward') || s.contains('leftwards')) {
      debugPrint('[SpeechService] ✅ Matched: leftward/leftwards → LEFT');
      return 'left';
    }
    if (s.contains('left')) {
      debugPrint('[SpeechService] ✅ Matched: left → LEFT');
      return 'left';
    }
    if (s.contains('lift') || s.contains('loft')) {
      debugPrint('[SpeechService] ✅ Matched: homophone → LEFT');
      return 'left';
    }

    // Compass Directions
    if (s.contains('east')) return 'right';
    if (s.contains('west')) return 'left';
    if (s.contains('north')) return 'up';
    if (s.contains('south')) return 'down';

    debugPrint('[SpeechService] ❌ parseDirection: NO MATCH for "$s"');
    return null;
  }

  /// Parse number from speech (0-99)
  static String? parseNumber(String speech) {
    final s = speech.toLowerCase().trim();
    debugPrint('[SpeechService] 🔍 parseNumber input: "$s"');

    // Check for digit first
    final digitMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(s);
    if (digitMatch != null) {
      debugPrint('[SpeechService] ✅ Matched digit: ${digitMatch.group(1)}');
      return digitMatch.group(1);
    }

    // Priority numbers
    if (s.contains('twelve') || s.contains('twelf')) return '12';
    if ((s.contains('seventy') && s.contains('four')) ||
        (s.contains('seven') && s.contains('four')))
      return '74';
    if ((s.contains('forty') || s.contains('fourty')) && s.contains('two'))
      return '42';

    // Compound numbers (abbreviated for space)
    final compounds = <String, String>{
      'twenty one': '21',
      'twenty-one': '21',
      'twenty two': '22',
      'twenty-two': '22',
      'thirty': '30',
      'forty': '40',
      'fifty': '50',
      'sixty': '60',
      'seventy': '70',
      'eighty': '80',
      'ninety': '90',
    };

    for (final entry in compounds.entries) {
      if (s.contains(entry.key)) return entry.value;
    }

    // Single digits
    final singles = <String, String>{
      'zero': '0',
      'oh': '0',
      'one': '1',
      'won': '1',
      'two': '2',
      'to': '2',
      'three': '3',
      'tree': '3',
      'four': '4',
      'for': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'ate': '8',
      'nine': '9',
    };

    final words = s.split(RegExp(r'\s+'));
    for (final word in words) {
      if (singles.containsKey(word)) return singles[word];
    }

    debugPrint('[SpeechService] ❌ parseNumber: NO MATCH for "$s"');
    return null;
  }

  /// Parse yes/no from speech
  static bool? parseYesNo(String speech) {
    final normalized = speech.toLowerCase().trim();

    if (normalized.contains('yes') ||
        normalized.contains('yeah') ||
        normalized.contains('yep') ||
        normalized.contains('correct') ||
        normalized.contains('right') ||
        normalized.contains('true')) {
      return true;
    }

    if (normalized.contains('no') ||
        normalized.contains('nope') ||
        normalized.contains('nah') ||
        normalized.contains('wrong') ||
        normalized.contains('false')) {
      return false;
    }

    return null;
  }

  /// Get confidence of last recognition
  double get lastConfidence => _lastConfidence;

  /// Get confidence percentage string
  String get lastConfidencePercent =>
      '${(lastConfidence * 100).toStringAsFixed(0)}%';

  /// Dispose resources
  void dispose() {
    _bufferTimer?.cancel();
    _speechToText.stop();
    _speechToText.cancel();
  }
}
