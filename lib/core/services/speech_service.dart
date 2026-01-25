// File: lib/core/services/speech_service.dart

import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// ✅ STABLE Low-Level Offline Speech Recognition Wrapper
/// Provides synchronized native access to prevent hardware deadlocks.
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isListening = false;
  String? _lastReactiveMatch;

  // 🔒 NATIVE SYNC LOCK
  Future<void>? _nativeOperation;

  // Callbacks
  Function(String recognized)? onResult;
  Function(String error)? onError;
  Function(String partialResult)? onSpeechDetected;
  Function()? onListeningStarted;
  Function()? onListeningStopped;
  Function(double level)? onSoundLevelChange;

  Future<void> _safeNativeCall(Future<void> Function() call) async {
    final lockTimeout = DateTime.now().add(const Duration(seconds: 4));
    while (_nativeOperation != null) {
      if (DateTime.now().isAfter(lockTimeout)) {
        _nativeOperation = null;
        break;
      }
      await Future.any([
        _nativeOperation!,
        Future.delayed(const Duration(seconds: 2)),
      ]);
    }
    final completer = Completer<void>();
    _nativeOperation = completer.future;
    try {
      await call().timeout(const Duration(seconds: 6));
    } catch (_) {
      // Logic handled in callbacks
    } finally {
      if (!completer.isCompleted) completer.complete();
      _nativeOperation = null;
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) return false;
    _isInitializing = true;
    try {
      if (!await Permission.microphone.request().isGranted) {
        _isInitializing = false;
        return false;
      }
      await _safeNativeCall(() async {
        _isInitialized = await _speechToText.initialize(
          onError: (error) {
            _isListening = false;
            onListeningStopped?.call();
            onError?.call(error.errorMsg);
          },
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              onListeningStopped?.call();
            } else if (status == 'listening') {
              _isListening = true;
              onListeningStarted?.call();
            }
          },
          debugLogging: kDebugMode,
        );
      });
      _isInitializing = false;
      return _isInitialized;
    } catch (e) {
      _isInitializing = false;
      return false;
    }
  }

  Future<void> startListening({
    Duration? listenFor,
    Duration? pauseFor,
    int bufferMs = 800,
    double minConfidence = 0.0,
  }) async {
    if (!_isInitialized && !await initialize()) return;
    await _safeNativeCall(() async {
      final locale = await _speechToText.systemLocale();
      await _speechToText.listen(
        onResult: (result) => _handleResult(result, bufferMs),
        listenFor: listenFor ?? const Duration(seconds: 60),
        pauseFor: pauseFor ?? const Duration(seconds: 15),
        onSoundLevelChange: (level) => onSoundLevelChange?.call(level),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          onDevice: true,
        ),
        localeId: locale?.localeId,
      );
    });
  }

  void _handleResult(SpeechRecognitionResult result, int bufferMs) {
    final recognized = result.recognizedWords.toLowerCase().trim();
    if (recognized.isEmpty) return;

    final direction = parseDirection(recognized);
    if (direction != null) {
      if (_lastReactiveMatch == recognized) return;
      _lastReactiveMatch = recognized;
      onResult?.call(recognized);
    }

    if (result.finalResult) {
      _lastReactiveMatch = null;
      onResult?.call(recognized);
    }

    onSpeechDetected?.call(recognized);
  }

  Future<void> stopListening() async {
    await _safeNativeCall(() async {
      await _speechToText.stop();
      _isListening = false;
    });
  }

  Future<void> cancel() async {
    await _safeNativeCall(() async {
      await _speechToText.cancel();
      _isListening = false;
    });
  }

  Future<bool> forceReinitialize() async {
    _nativeOperation = null;
    await _speechToText.cancel().catchError((_) => {});
    _isInitialized = false;
    return await initialize();
  }

  void clearBuffer() {
    _lastReactiveMatch = null;
  }

  static String? parseDirection(String s) {
    if (s.contains('up') || s.contains('top')) return 'up';
    if (s.contains('down') || s.contains('bottom')) return 'down';
    if (s.contains('left')) return 'left';
    if (s.contains('right')) return 'right';
    if (s.contains('blur')) return 'blurry';
    return null;
  }

  bool get isListening => _isListening || _speechToText.isListening;
  bool get isReady => _isInitialized;

  Future<void> dispose() async {
    await _speechToText.cancel();
  }
}
