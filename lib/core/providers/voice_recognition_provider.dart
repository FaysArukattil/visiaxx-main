import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_recognition_service.dart';
import '../../data/models/user_model.dart';

/// Provider for managing voice recognition state app-wide
///
/// Features:
/// - Enabled/disabled toggle persisted with SharedPreferences
/// - Default ON for normal users, OFF for practitioners
/// - Current recognized text with automatic clearing
/// - Listening state synchronized with service
class VoiceRecognitionProvider extends ChangeNotifier {
  static const String _enabledPrefKey = 'voice_recognition_enabled';

  final VoiceRecognitionService _service = VoiceRecognitionService();
  SharedPreferences? _prefs;

  // State
  bool _isEnabled = true;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String _recognizedText = '';
  VoiceRecognitionState _state = VoiceRecognitionState.idle;
  Offset _overlayPosition = const Offset(0, 0);
  bool _hasSetInitialPosition = false;
  bool _prefsLoaded = false;

  // Subscriptions
  StreamSubscription<VoiceRecognitionState>? _stateSubscription;
  StreamSubscription<double>? _audioLevelSubscription;

  // Audio level for waveform
  double _audioLevel = 0.0;

  // Current result callback (set by test screens)
  Function(String recognizedText, bool isFinal)? _currentResultCallback;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  bool get isListening => _service.isListening;
  bool get isAvailable => _service.isAvailable;
  String get recognizedText => _recognizedText;
  VoiceRecognitionState get state => _state;
  String? get lastError => _service.lastError;
  double get audioLevel => _audioLevel;
  Offset get overlayPosition => _overlayPosition;
  VoiceRecognitionService get service => _service;

  VoiceRecognitionProvider() {
    _subscribeToState();
    // Start loading preferences immediately but don't block
    _loadPreferences();
  }

  /// Initialize the provider with user role
  /// Simply loads preferences to ensure the toggle state is correct
  void initializeWithUserRole(UserRole role) {
    if (_isInitializing) return;

    // Just load preferences. Hardware initialization will happen on-demand
    // when startListening is called for the first time during a test.
    _loadPreferences().catchError((e) {
      debugPrint('[VoiceRecognitionProvider] Prefs loading error: $e');
    });
  }

  /// Initialize voice recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) return false;

    _isInitializing = true;
    debugPrint('[VoiceRecognitionProvider] Initializing service...');

    try {
      final success = await _service.initialize();
      if (success) {
        _isInitialized = true;
        debugPrint(
          '[VoiceRecognitionProvider] Service initialized successfully',
        );
      } else {
        debugPrint('[VoiceRecognitionProvider] Service initialization failed');
      }
      return success;
    } catch (e) {
      debugPrint('[VoiceRecognitionProvider] Service initialization error: $e');
      return false;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    if (_prefsLoaded) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _isEnabled = _prefs!.getBool(_enabledPrefKey) ?? true;
      _prefsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[VoiceRecognitionProvider] Error loading prefs: $e');
    }
  }

  /// Subscribe to service state changes
  void _subscribeToState() {
    _stateSubscription = _service.stateStream.listen((state) {
      _state = state;
      notifyListeners();
    });

    _audioLevelSubscription = _service.audioLevelStream.listen((level) {
      _audioLevel = level;
      notifyListeners();
    });
  }

  /// Enable or disable voice recognition
  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) return;

    _isEnabled = enabled;
    notifyListeners();

    // Persist preference
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_enabledPrefKey, enabled);

    // Stop listening if disabled
    if (!enabled && _service.isListening) {
      await stopListening();
    }

    debugPrint(
      '[VoiceRecognitionProvider] Voice recognition ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Toggle voice recognition on/off
  Future<void> toggle() async {
    await setEnabled(!_isEnabled);
  }

  /// Start listening for speech with a result callback
  /// [vocabularyHints] optional list of expected words to improve recognition
  Future<void> startListening({
    required Function(String recognizedText, bool isFinal) onResult,
    List<String>? vocabularyHints,
  }) async {
    if (!_isEnabled) {
      debugPrint('[VoiceRecognitionProvider] Cannot start: disabled');
      return;
    }

    if (!_isInitialized) {
      debugPrint(
        '[VoiceRecognitionProvider] Not initialized, initializing first...',
      );
      await initialize();
    }

    _currentResultCallback = onResult;
    _recognizedText = '';
    notifyListeners();

    await _service.startListening(
      onResult: (text, isFinal) {
        _recognizedText = text;
        notifyListeners();
        _currentResultCallback?.call(text, isFinal);
      },
      vocabularyHints: vocabularyHints,
    );
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    await _service.stopListening();
    _currentResultCallback = null;
    notifyListeners();
  }

  /// Cancel ongoing recognition
  Future<void> cancel() async {
    await _service.cancel();
    _recognizedText = '';
    _currentResultCallback = null;
    notifyListeners();
  }

  /// Clear the recognized text (called when moving to next test item)
  void clearRecognizedText() {
    _recognizedText = '';
    notifyListeners();
  }

  /// Restart voice recognition (for error recovery)
  Future<void> restart() async {
    if (!_isEnabled) return;

    if (_currentResultCallback != null) {
      await _service.restart(
        onResult: (text, isFinal) {
          _recognizedText = text;
          notifyListeners();
          _currentResultCallback?.call(text, isFinal);
        },
      );
    }
  }

  /// Update overlay position (for draggable overlay)
  void setOverlayPosition(Offset position) {
    _overlayPosition = position;
    _hasSetInitialPosition = true;
    notifyListeners();
  }

  /// Set initial position if not already set
  void setInitialPositionIfNeeded(Size screenSize) {
    if (!_hasSetInitialPosition) {
      // Default position: bottom center with some padding
      _overlayPosition = Offset(
        (screenSize.width - 200) / 2, // Assuming overlay width ~200
        screenSize.height - 150, // 150px from bottom
      );
      _hasSetInitialPosition = true;
      notifyListeners();
    }
  }

  /// Match direction from current recognized text
  String? matchDirection() {
    return _service.matchDirection(_recognizedText);
  }

  /// Match number from current recognized text
  String? matchNumber() {
    return _service.matchNumber(_recognizedText);
  }

  /// Match letter from current recognized text
  String? matchLetter() {
    return _service.matchLetter(_recognizedText);
  }

  /// Match visibility from current recognized text
  String? matchVisibility() {
    return _service.matchVisibility(_recognizedText);
  }

  /// Match reading capability from current recognized text
  String? matchReadingCapability() {
    return _service.matchReadingCapability(_recognizedText);
  }

  /// Match against custom vocabulary
  String? matchVocabulary(List<String> vocabulary) {
    return _service.matchVocabulary(_recognizedText, vocabulary);
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
