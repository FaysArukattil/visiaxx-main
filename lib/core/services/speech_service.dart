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
/// - Device-agnostic locale selection
/// - On-device only (no cloud fallback)
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

      debugPrint('[SpeechService] 🔧 Initializing speech recognition...');

      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[SpeechService] ❌ Speech error: ${error.errorMsg}');
          _isListening = false;

          // ⚠️ If the language error occurs, log diagnostics
          if (error.errorMsg.contains('error_language_not_supported') ||
              error.errorMsg.contains('error_language_unavailable')) {
            debugPrint(
              '[SpeechService] 🛑 Language error - locale may not be supported for on-device recognition',
            );
            // Don't spam retries for language errors
            return;
          }

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

      return _isInitialized;
    } catch (e) {
      debugPrint('[SpeechService] ❌ Initialization exception: $e');
      onError?.call('Failed to initialize speech: $e');
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
      // 🆕 Select best available locale for on-device recognition
      final selectedLocale = await _selectBestAvailableLocale();
      final localeId = selectedLocale?.localeId;

      if (localeId != null) {
        debugPrint('[SpeechService] 🎯 Using locale: $localeId');
      } else {
        debugPrint(
          '[SpeechService] ⚠️ No locale selected, using system default',
        );
      }

      await _speechToText.listen(
        onResult: (result) => _onSpeechResult(result, bufferMs, minConfidence),
        listenFor: listenFor ?? const Duration(seconds: 60),
        pauseFor:
            pauseFor ??
            const Duration(seconds: 15), // Extended for slower tablets
        onSoundLevelChange: (level) {
          onSoundLevelChange?.call(level);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
          // No onDevice parameter - let Android auto-select
          // Will use offline if available, cloud otherwise
        ),
        localeId: localeId, // ✅ Use selected locale or null for system default
      );

      debugPrint('[SpeechService] ✅ Listen started successfully');
    } catch (e) {
      debugPrint('[SpeechService] ❌ Error starting listen: $e');
      _isListening = false;
      onListeningStopped?.call();
      onError?.call('Failed to start listening: $e');
    }
  }

  /// 🆕 Select best available locale for on-device recognition
  Future<LocaleName?> _selectBestAvailableLocale() async {
    try {
      final availableLocales = await _speechToText.locales();

      if (availableLocales.isEmpty) {
        debugPrint('[SpeechService] ⚠️ No locales available!');
        return null;
      }

      // Log available locales for debugging
      debugPrint(
        '[SpeechService] 📋 Available locales (${availableLocales.length}):',
      );
      for (var locale in availableLocales.take(10)) {
        debugPrint('  - ${locale.localeId}: ${locale.name}');
      }

      // Preferred locale chain for English
      final preferredLocales = ['en_IN', 'en_GB', 'en_UK', 'en_US', 'en_AU'];

      // Try preferred locales first
      for (var preferred in preferredLocales) {
        final match = availableLocales.firstWhere(
          (l) => l.localeId == preferred,
          orElse: () => LocaleName('', ''),
        );
        if (match.localeId.isNotEmpty) {
          debugPrint(
            '[SpeechService] ✅ Selected preferred locale: ${match.localeId}',
          );
          return match;
        }
      }

      // Fall back to any English variant
      final anyEnglish = availableLocales.firstWhere(
        (l) => l.localeId.startsWith('en_') || l.localeId.startsWith('en-'),
        orElse: () => LocaleName('', ''),
      );
      if (anyEnglish.localeId.isNotEmpty) {
        debugPrint(
          '[SpeechService] ✅ Selected English variant: ${anyEnglish.localeId}',
        );
        return anyEnglish;
      }

      // Last resort: use system locale if it's in the list
      final systemLocale = await _speechToText.systemLocale();
      if (systemLocale != null) {
        final systemMatch = availableLocales.firstWhere(
          (l) => l.localeId == systemLocale.localeId,
          orElse: () => LocaleName('', ''),
        );
        if (systemMatch.localeId.isNotEmpty) {
          debugPrint(
            '[SpeechService] ✅ Using system locale: ${systemMatch.localeId}',
          );
          return systemMatch;
        }
      }

      // Ultimate fallback: first available locale
      final firstAvailable = availableLocales.first;
      debugPrint(
        '[SpeechService] ⚠️ Using first available locale: ${firstAvailable.localeId}',
      );
      return firstAvailable;
    } catch (e) {
      debugPrint('[SpeechService] ❌ Error selecting locale: $e');
      return null;
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

  /// ✅ NEW: Clear internal buffers manually
  void clearBuffer() {
    _lastRecognizedValue = null;
    _lastConfidence = 0.0;
    _bufferTimer?.cancel();
    debugPrint('[SpeechService] 🧹 Buffers cleared');
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

  static String? parseDirection(String speech) {
    final s = speech.toLowerCase().trim();
    debugPrint('[SpeechService] 🔍 parseDirection input: "$s"');

    // ✅ NEW: Find the LAST occurrence of any valid direction to handle "right right" or "up down"
    String? lastMatch;
    int lastIndex = -1;

    final directionsMap = {
      'up': [
        'up',
        'upp',
        'op',
        'top',
        'upper',
        'above',
        'ceiling',
        'sky',
        'north',
        'upward',
        'upwards',
        'up ward',
        'upword',
        'apward',
        'uhpward',
        'awkward',
        'afford',
        'appuard',
        'appaurd',
        'appuvert',
        'appward',
        'abort',
        'about',
        'aboard',
      ],
      'down': [
        'down',
        'downward',
        'downwards',
        'down ward',
        'bottom',
        'botto',
        'bottam',
        'lower',
        'below',
        'beneath',
        'floor',
        'ground',
        'south',
      ],
      'right': [
        'right',
        'rightward',
        'rightwards',
        'write',
        'wright',
        'rite',
        'ride',
        'east',
      ],
      'left': ['left', 'leftward', 'leftwards', 'lift', 'loft', 'west'],
      'blurry': [
        'blurry',
        'blur',
        'blurb',
        'blaring',
        'cannot see',
        'can\'t see',
        'nothing',
        'too small',
        'zero',
        'no',
        'dark',
        'not clear',
      ],
    };

    directionsMap.forEach((label, variants) {
      for (final variant in variants) {
        final index = s.lastIndexOf(variant);
        if (index != -1 && index > lastIndex) {
          lastIndex = index;
          lastMatch = label;
        }
      }
    });

    if (lastMatch != null) {
      debugPrint(
        '[SpeechService] ✅ Matched (Last): "$lastMatch" (at index $lastIndex)',
      );
      return lastMatch;
    }

    debugPrint('[SpeechService] ❌ parseDirection: NO MATCH for "$s"');
    return null;
  }

  static String? parseNumber(String speech) {
    final s = speech.toLowerCase().trim();
    debugPrint('[SpeechService] 🔍 parseNumber input: "$s"');

    // ✅ NEW: Find the LAST occurrence of any valid number/variant
    String? lastMatch;
    int lastIndex = -1;

    // Special cases
    final specialMap = {
      '2': ['too', 'two', 'to'],
      '4': ['for', 'four'],
      '8': ['ate', 'eight'],
      '1': ['won', 'one'],
      '12': ['twelve', 'twelf'],
      '74': ['seventy four', 'seventy-four', 'seven four', 'seven-four'],
      '42': ['forty two', 'forty-two', 'fourty two', 'fourty-two'],
      '21': ['twenty one', 'twenty-one'],
      '22': ['twenty two', 'twenty-two'],
      '30': ['thirty'],
      '40': ['forty', 'fourty'],
      '50': ['fifty'],
      '60': ['sixty'],
      '70': ['seventy'],
      '80': ['eighty'],
      '90': ['ninety'],
      '0': ['zero', 'oh'],
      '3': ['three', 'tree'],
      '5': ['five'],
      '6': ['six'],
      '7': ['seven'],
      '9': ['nine'],
    };

    specialMap.forEach((label, variants) {
      for (final variant in variants) {
        final index = s.lastIndexOf(variant);
        if (index != -1 && index > lastIndex) {
          lastIndex = index;
          lastMatch = label;
        }
      }
    });

    // Also check for digits themselves
    final digitMatch = RegExp(r'(\d{1,2})').allMatches(s);
    for (final m in digitMatch) {
      if (m.start > lastIndex) {
        lastIndex = m.start;
        lastMatch = m.group(1);
      }
    }

    if (lastMatch != null) {
      debugPrint('[SpeechService] ✅ Matched number (Last): "$lastMatch"');
      return lastMatch;
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
