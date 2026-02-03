import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// - NATIVE Android Implementation (Max stability & accuracy)
/// - STRICT On-Device Recognition (No Cloud, high accuracy for short words)
/// - Advanced Fuzzy Matching (Handles misrecognitions in-app)
/// - Reliable Waveform & "Ting" sound support
class VoiceRecognitionService {
  static final VoiceRecognitionService _instance =
      VoiceRecognitionService._internal();
  factory VoiceRecognitionService() => _instance;
  VoiceRecognitionService._internal() {
    _setupMethodChannel();
  }

  static const _channel = MethodChannel('com.example.visiaxx/voice');

  // State management
  VoiceRecognitionState _state = VoiceRecognitionState.idle;
  bool _isInitialized = false;
  bool _isInitializing = false;
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
  bool get isListening => _state == VoiceRecognitionState.listening;
  bool get isAvailable =>
      _isInitialized && _state != VoiceRecognitionState.unavailable;
  String? get lastError => _lastError;
  double get audioLevel => _audioLevel;
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<VoiceRecognitionState> get stateStream => _stateController.stream;

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onResults':
          final map = Map<String, dynamic>.from(call.arguments);
          final text = map['text'] as String;
          final isFinal = map['isFinal'] as bool;
          _handleResult(text, isFinal);
          break;
        case 'onRmsChanged':
          final rmsdB = call.arguments as double;
          // Normalize RMS (usually -2 to 10+) to 0.0-1.0 range for wave
          _audioLevel = ((rmsdB + 2) / 12).clamp(0.0, 1.0);
          _audioLevelController.add(_audioLevel);
          break;
        case 'onError':
          final error = call.arguments as String;
          _onError(error);
          break;
        case 'onStatus':
          final status = call.arguments as String;
          _onStatus(status);
          break;
      }
    });
  }

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) return false;

    _isInitializing = true;
    try {
      debugPrint('[VoiceRecognition] Checking permissions...');
      final statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();

      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        debugPrint('[VoiceRecognition] Microphone permission denied');
        _updateState(VoiceRecognitionState.error);
        _lastError = 'Microphone permission required';
        return false;
      }

      _isInitialized = true;
      _updateState(VoiceRecognitionState.idle);
      debugPrint('[VoiceRecognition] Service ready (Native Mode)');
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
  Future<void> startListening({
    required Function(String recognizedText, bool isFinal) onResult,
    Duration? listenFor,
    Duration? pauseFor,
    List<String>? vocabularyHints,
    bool isRetry = false,
  }) async {
    // 1. Mandatory hardware "cooling" delay to prevent Error 11 (Not Connected)
    // Especially important when switching rapidly between 'E' stimulus items.
    if (!isRetry) {
      debugPrint('[VoiceRecognition] Hardware breathing room (100ms)...');
      // REMOVED redundant cancel() as it causes double-beeps.
      // Native side already handles cleanup efficiently.
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    _onResult = onResult;
    _audioLevel = 0.0;
    _audioLevelController.add(0.0);

    try {
      debugPrint(
        '[VoiceRecognition] Requesting Native Start (Total Fresh Start)...',
      );
      final success = await _channel.invokeMethod<bool>('startListening');
      if (success == true) {
        _updateState(VoiceRecognitionState.listening);
        debugPrint('[VoiceRecognition] ✅ Native started!');
      } else {
        _updateState(VoiceRecognitionState.error);
        _lastError = 'Native engine failed to start';
      }
    } catch (e) {
      debugPrint('[VoiceRecognition] Native Start EXCEPTION: $e');
      _lastError = e.toString();
      _updateState(VoiceRecognitionState.error);
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
      _updateState(VoiceRecognitionState.idle);
      _audioLevel = 0.0;
      _audioLevelController.add(0.0);
    } catch (e) {
      debugPrint('[VoiceRecognition] Error stopping: $e');
    }
  }

  /// Cancel any ongoing recognition
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancelListening');
      _updateState(VoiceRecognitionState.idle);
      _audioLevel = 0.0;
      _audioLevelController.add(0.0);
    } catch (e) {
      debugPrint('[VoiceRecognition] Error canceling: $e');
    }
  }

  /// Restart listening
  Future<void> restart({
    required Function(String recognizedText, bool isFinal) onResult,
  }) async {
    await startListening(onResult: onResult);
  }

  void _handleResult(String text, bool isFinal) {
    if (_state == VoiceRecognitionState.listening) {
      _updateState(VoiceRecognitionState.processing);
    }

    debugPrint('[VoiceRecognition] Result: "$text" (final: $isFinal)');
    _onResult?.call(text, isFinal);

    if (!isFinal && _state == VoiceRecognitionState.processing) {
      _updateState(VoiceRecognitionState.listening);
    }
  }

  void _onStatus(String status) {
    debugPrint('[VoiceRecognition] Status: $status');
    switch (status) {
      case 'listening':
        _updateState(VoiceRecognitionState.listening);
        break;
      case 'processing':
        _updateState(VoiceRecognitionState.processing);
        break;
      case 'idle':
        _updateState(VoiceRecognitionState.idle);
        break;
      case 'failed':
        _updateState(VoiceRecognitionState.error);
        break;
    }
  }

  void _onError(String error) {
    debugPrint('[VoiceRecognition] Native Error: $error');
    _lastError = error;
    _updateState(VoiceRecognitionState.error);
  }

  /// Update state and notify listeners
  void _updateState(VoiceRecognitionState newState) {
    if (_state != newState) {
      _state = newState;
      Future.microtask(() {
        if (!_stateController.isClosed) {
          _stateController.add(newState);
        }
      });
    }
  }

  /// Match recognized text against a vocabulary list
  String? matchVocabulary(String input, List<String> vocabulary) {
    if (input.isEmpty) return null;
    final normalizedInput = input.toLowerCase().trim();

    // First, try exact match
    for (final word in vocabulary) {
      if (normalizedInput == word.toLowerCase()) return word;
    }

    // Try word boundaries
    final words = normalizedInput.split(RegExp(r'\s+'));
    for (final word in vocabulary) {
      if (words.contains(word.toLowerCase())) return word;
    }

    // Fuzzy matching for directional words
    final fuzzyMatches = <String, List<String>>{
      'left': [
        'left',
        'lift',
        'lest',
        'let',
        'laughed',
        'cleft',
        'leaft',
        'lef',
      ],
      'right': [
        'right',
        'write',
        'rite',
        'wright',
        'white',
        'ride',
        'ripe',
        'rait',
      ],
      'up': ['up', 'app', 'hub', 'uhp', 'uh', 'upper', 'a', 'yup', 'uup'],
      'down': [
        'down',
        'town',
        'dawn',
        'done',
        'drown',
        'don',
        'dow',
        'downward',
        'download',
      ],
    };

    for (final entry in fuzzyMatches.entries) {
      if (vocabulary.contains(entry.key)) {
        for (final variant in entry.value) {
          if (normalizedInput.contains(variant)) return entry.key;
        }
      }
    }

    return null;
  }

  String? matchDirection(String input) =>
      matchVocabulary(input, ['left', 'right', 'up', 'down', 'blurry']);

  // ... rest of the matching methods remain the same but cleaner ...
  String? matchNumber(String input) {
    final digitMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(input);
    if (digitMatch != null) {
      return digitMatch.group(1);
    }
    if (input.toLowerCase().contains('nothing') ||
        input.toLowerCase().contains("can't see")) {
      return 'nothing';
    }
    return null;
  }

  String? matchLetter(String input) {
    final clean = input.trim().toUpperCase();
    if (clean.length == 1 && RegExp(r'[A-Z]').hasMatch(clean)) {
      return clean;
    }
    return null;
  }

  String? matchVisibility(String input) {
    final low = input.toLowerCase();
    if (low.contains('not') || low.contains('no') || low.contains("can't")) {
      return 'not visible';
    }
    if (low.contains('yes') || low.contains('visible') || low.contains('see')) {
      return 'visible';
    }
    return null;
  }

  String? matchReadingCapability(String input) {
    final low = input.toLowerCase();
    if (low.contains('not') || low.contains('no') || low.contains("can't")) {
      return 'cannot read';
    }
    if (low.contains('yes') || low.contains('read') || low.contains('can')) {
      return 'can read';
    }
    return null;
  }

  void dispose() {
    _audioLevelController.close();
    _stateController.close();
    _isInitialized = false;
  }
}
