// File: lib/core/services/speech_service.dart

import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// ✅ FINAL STAND Offline Speech Recognition Service
/// Simple, rock-solid serialized native bridge.
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
      await call().timeout(const Duration(seconds: 8));
    } catch (_) {
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

  Future<void> startListening({int bufferMs = 800}) async {
    if (!_isInitialized && !await initialize()) return;

    await _safeNativeCall(() async {
      await _speechToText
          .cancel()
          .timeout(const Duration(seconds: 1))
          .catchError((_) => {});
      await Future.delayed(const Duration(milliseconds: 200));

      final system = await _speechToText.systemLocale();
      debugPrint(
        '[SpeechService] 🎤 Starting listening with locale: ${system?.localeId}',
      );

      await _speechToText.listen(
        onResult: (result) => _handleResult(result, bufferMs),
        listenFor: const Duration(
          seconds: 100,
        ), // Increased for much longer uninterrupted sessions
        pauseFor: const Duration(seconds: 10), // Standard stability
        onSoundLevelChange: (level) => onSoundLevelChange?.call(level),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          // onDevice removed as it causes immediate crashes/stops on many devices
        ),
        localeId: system?.localeId,
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
    _isListening = false;
    return await initialize();
  }

  void clearBuffer() {
    _lastReactiveMatch = null;
  }

  static String? parseDirection(String s) {
    s = s.toLowerCase();
    if (s.contains('up') ||
        s.contains('top') ||
        s.contains('app') ||
        s.contains('ab'))
      return 'up';
    if (s.contains('down') || s.contains('bottom') || s.contains('done'))
      return 'down';
    if (s.contains('left') ||
        s.contains('lift') ||
        s.contains('life') ||
        s.contains('leaf'))
      return 'left';
    if (s.contains('right') ||
        s.contains('write') ||
        s.contains('light') ||
        s.contains('ride'))
      return 'right';
    if (s.contains('blur') ||
        s.contains('see') ||
        s.contains('nothing') ||
        s.contains('clear'))
      return 'blurry';
    return null;
  }

  bool get isListening => _isListening || _speechToText.isListening;
  bool get isReady => _isInitialized && _isListening;

  Future<void> dispose() async {
    await _speechToText.cancel();
  }
}
