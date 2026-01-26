// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/core/utils/navigation_utils.dart';
import '../../../core/widgets/distance_warning_overlay.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/continuous_speech_manager.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/models/visiual_acuity_result.dart';
import '../../../data/providers/test_session_provider.dart';
import 'distance_calibration_screen.dart';
import 'cover_right_eye_instruction_screen.dart';
import 'cover_left_eye_instruction_screen.dart';
import 'reading_test_instructions_screen.dart';
import '../../../core/services/distance_skip_manager.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/test_feedback_overlay.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

/// Visual Acuity Test using Tumbling E chart with distance monitoring
/// Implements Visiaxx specification for 1-meter testing
class VisualAcuityTestScreen extends StatefulWidget {
  const VisualAcuityTestScreen({super.key, this.startWithLeftEye = false});

  final bool startWithLeftEye;

  @override
  State<VisualAcuityTestScreen> createState() => _VisualAcuityTestScreenState();
}

class _VisualAcuityTestScreenState extends State<VisualAcuityTestScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final DistanceSkipManager _skipManager = DistanceSkipManager();
  late ContinuousSpeechManager _continuousSpeech;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Test state
  int _currentLevel = 0;
  int _correctAtLevel = 0;
  int _totalAtLevel = 0;
  int _totalCorrect = 0;
  int _totalResponses = 0;
  EDirection _currentDirection = EDirection.right;
  final List<EResponseRecord> _responses = [];

  // Eye being tested
  String _currentEye = 'right';
  bool _eyeSwitchPending = false;

  // Timing
  Timer? _eDisplayTimer;
  Timer? _relaxationTimer;
  int _relaxationCountdown = 10;
  late AnimationController
  _relaxationProgressController; // … NEW: Smooth animation
  DateTime? _eDisplayStartTime;
  int _eDisplayCountdown = TestConstants
      .eDisplayDurationSeconds; // 7 seconds per E as per user requirement
  Timer? _eCountdownTimer;

  // Display states
  bool _showDistanceCalibration = true; // Start with distance calibration
  bool _showRelaxation = false;
  bool _showE = false;
  bool _showResult = false;
  bool _testComplete = false;
  bool _waitingForResponse = false;

  // Voice recognition feedback
  bool _isListening = false;
  bool _isSpeechActive = false; // New: for waveform responsiveness
  Timer? _speechActiveTimer; // New: for debouncing responsiveness
  String? _lastDetectedSpeech;
  bool _isResettingSpeech = false;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  final bool _useDistanceMonitoring =
      true; // Enabled for real-time distance display
  bool _isTestPausedForDistance = false; // Test is paused due to wrong distance
  bool _isDistanceOk = true; // New: Tracks if distance is currently correct
  bool _isCalibrationActive = true; // New: Tracks if calibration is active

  final Random _random = Random();

  // Pixels per mm for this device (calculated based on screen metrics)
  double _pixelsPerMm = 6.0;

  Timer? _autoNavigationTimer;
  int _autoNavigationCountdown = 3;

  bool _isPausedForExit = false;
  bool _isNavigatingToNextTest = false;

  Timer? _speechEraserTimer; // … Timer to clear recognized text
  DateTime? _lastPlateStartTime; // ⏳ Warm-up grace period tracker

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // … FIX: Initialize synchronously to prevent LateInitializationError
    _continuousSpeech = ContinuousSpeechManager(_speechService);

    // 🚀 NUCLEAR SYNC: Connect hardware contention protection
    _continuousSpeech.onContentionStart = () {
      debugPrint(
        '🛡️ [VisualAcuity] HW CONTENTION START: Pausing Camera for Mic',
      );
      _distanceService.stopMonitoring();
    };

    _continuousSpeech.onContentionEnd = () {
      debugPrint('🛡️ [VisualAcuity] HW CONTENTION END: Resuming Camera');
      if (_useDistanceMonitoring && !_isTestPausedForDistance && !_showResult) {
        _distanceService.startMonitoring();
      }
    };
    _relaxationProgressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: TestConstants.relaxationDurationSeconds),
    );

    _relaxationProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _showRelaxation) {
        _showTumblingE();
      }
    });

    // Check if we are in practitioner mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<TestSessionProvider>();
        if (provider.profileType == 'patient') {
          debugPrint(
            '👨‍⚕️ [VisualAcuity] Practitioner mode detected: Silencing Speech globally',
          );
          context.read<SpeechService>().setGloballyDisabled(true);
        }
      }
    });

    _initServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App minimized or going to background
      _handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      // App resumed
      _handleAppResumed();
    }
  }

  void _handleAppPaused() {
    // Pause test timers
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();

    // Stop distance monitoring
    _distanceService.stopMonitoring();

    // Stop speech recognition
    _continuousSpeech.stop();

    // Pause relaxation animation if active
    if (_showRelaxation) {
      _relaxationProgressController.stop();
    }

    setState(() {
      _isTestPausedForDistance = true;
      _isDistanceOk = false; // Mark distance as not OK when paused
    });
  }

  void _handleAppResumed() {
    if (!mounted || _showDistanceCalibration) return;

    // Show unified pause dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_showDistanceCalibration) {
        // If test is complete, we still show the pause dialog to be safe
        // but maybe with a different reason or just standard minimized.
        _showPauseDialog(reason: 'minimized');
      }
    });
  }

  /// Unified pause dialog for both back button and app minimization
  void _showPauseDialog({String reason = 'back button'}) {
    // Pause timers and services while dialog is shown
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _relaxationProgressController.stop(); // … Stop smooth animation
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();
    _autoNavigationTimer?.cancel(); // … Added: Pause auto-navigation timer

    setState(() {
      _isPausedForExit = true;
      _isTestPausedForDistance = true;
      _isDistanceOk = false; // Mark distance as not OK when paused
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TestExitConfirmationDialog(
        onContinue: () {
          _resumeTestFromDialog();
        },
        onRestart: () {
          _restartCurrentTest();
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
      ),
    ).then((_) {
      if (mounted && _isPausedForExit) {
        _resumeTestFromDialog();
      }
    });
  }

  /// Resume the test from the pause dialog
  void _resumeTestFromDialog() {
    if (!mounted) return;

    if (_testComplete) {
      setState(() {
        _isPausedForExit = false;
        _isTestPausedForDistance = false;
        _isDistanceOk = true; // Reset distance status
        _lastShouldPauseTime = null;
      });
      _startAutoNavigationTimer(); // … Resume auto-navigation
      return;
    }

    debugPrint('[VisualAcuity] ”„ Resuming test from dialog');

    // Clear pause flags
    setState(() {
      _isPausedForExit = false;
      _isTestPausedForDistance = false;
      _isDistanceOk = true; // Reset distance status
      _lastShouldPauseTime = null;
    });

    // Restart distance monitoring
    _startContinuousDistanceMonitoring();

    // Resume based on current test phase
    if (_showE && _waitingForResponse) {
      debugPrint('[VisualAcuity] 🔄 Resuming E display phase');
      final provider = context.read<TestSessionProvider>();
      if (provider.profileType != 'patient') {
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
      _restartEDisplayTimer();
    } else if (_showRelaxation) {
      debugPrint('[VisualAcuity] ”„ Resuming relaxation phase');
      if (_relaxationCountdown <= 3) {
        final provider = context.read<TestSessionProvider>();
        if (provider.profileType != 'patient') {
          _continuousSpeech.start(
            listenDuration: const Duration(minutes: 10),
            minConfidence: 0.15,
            bufferMs: 1000,
          );
        }
      }
      _restartRelaxationTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculatePixelsPerMm();
  }

  void _calculatePixelsPerMm() {
    // Calculate pixels per mm based on device screen
    // Using a reasonable approximation for mobile devices
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final devicePixelRatio = mediaQuery.devicePixelRatio;

    // Average phone screen is approximately 65-75mm wide
    // Using 70mm as a reasonable estimate
    const estimatedScreenWidthMm = 70.0;
    _pixelsPerMm =
        (screenWidth * devicePixelRatio) /
        estimatedScreenWidthMm /
        devicePixelRatio;

    // Clamp to reasonable values (5-10 pixels per mm)
    _pixelsPerMm = _pixelsPerMm.clamp(5.0, 10.0);

    debugPrint(
      '✅ [VisualAcuity] “ PixelsPerMm calculated: $_pixelsPerMm '
      '(Screen Width: $screenWidth, DPR: $devicePixelRatio)',
    );
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    // Initialize continuous speech manager configuration
    _continuousSpeech.onFinalResult = _handleVoiceResponse;
    _continuousSpeech.onSpeechDetected = _handleSpeechDetected;
    _continuousSpeech.onListeningStateChanged = (isListening) {
      if (mounted) setState(() => _isListening = isListening);
    };
    // ✅ SAFE-SYNC: Pause speech when TTS is speaking to prevent focus collision
    _ttsService.onSpeakingStateChanged = (isSpeaking) {
      if (isSpeaking) {
        _continuousSpeech.pauseForTts();
      } else {
        _continuousSpeech.resumeAfterTts();
      }
    };

    // Mic start will be handled by relaxation timer (at 3 seconds remaining)
    // as per user requirement to avoid interference.

    // ✅ KEY FIX: Check if we should start with left eye
    if (!mounted) return;
    final provider = context.read<TestSessionProvider>();

    if (widget.startWithLeftEye ||
        (provider.currentEye == 'left' && provider.visualAcuityRight != null)) {
      // We're starting/resuming left eye - NO calibration needed
      debugPrint(
        '✅ [VisualAcuity] Starting LEFT EYE test - skipping calibration',
      );
      _showDistanceCalibration = false;
      _isCalibrationActive = false; // Mark calibration as not active
      _currentEye = 'left';
      provider.switchEye();

      // ✅ KEY: Resume continuous distance monitoring without recalibration
      await _startContinuousDistanceMonitoring();

      // Start test immediately
      _startEyeTest();
      return;
    }

    // First time (right eye) - show calibration
    debugPrint(
      '✅ [VisualAcuity] Starting RIGHT EYE test - showing calibration',
    );
    if (_useDistanceMonitoring && _showDistanceCalibration) {
      // Wait for build to complete, then show calibration screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCalibrationScreen();
      });
    } else {
      // Skip distance calibration and start directly
      _showDistanceCalibration = false;
      _isCalibrationActive = false; // Mark calibration as not active
      _startEyeTest();
    }
  }

  /// Shows the distance calibration screen as a full-screen overlay
  void _showCalibrationScreen() {
    setState(() {
      _isCalibrationActive = true;
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: 100.0,
          toleranceCm: 8.0,
          onCalibrationComplete: () {
            Navigator.of(context).pop();
            _onDistanceCalibrationComplete();
          },
          onSkip: () {
            Navigator.of(context).pop();
            _onDistanceCalibrationComplete();
          },
        ),
      ),
    );
  }

  void _handleSpeechDetected(String partialResult) {
    if (!mounted) return;

    // Disable speech detection logic for practitioners
    final provider = context.read<TestSessionProvider>();
    if (provider.profileType == 'patient') return;

    debugPrint('[VisualAcuity] 🗣️ Speech detected: "$partialResult"');
    if (mounted) {
      setState(() {
        _lastDetectedSpeech = partialResult;
        _isSpeechActive = true;
      });

      // … RAPID RESPONSE: If we match a direction even in partial speech, trigger now!
      if (_showE && _waitingForResponse) {
        final direction = SpeechService.parseDirection(partialResult);
        if (direction != null) {
          debugPrint(
            '[VisualAcuity] ¡ Rapid recognition from partial speech: $direction (Bypassing guard)',
          );
          _recordResponse(direction, source: 'partial_speech');
          return;
        }

        // … GUARD: Results arriving too quickly that AREN'T commands are ignored
        if (_eDisplayStartTime != null) {
          final sinceRotation = DateTime.now().difference(_eDisplayStartTime!);
          if (sinceRotation < const Duration(milliseconds: 500)) {
            debugPrint(
              '[VisualAcuity] ⏱️ Ignoring partial result: arrived too fast after rotation',
            );
            return;
          }
        }

        // Check for blurry
        final normalized = partialResult.toLowerCase().trim();
        final blurryKeywords = [
          'blurry',
          'blur',
          'cannot see',
          'can\'t see',
          'country',
        ];
        for (var keyword in blurryKeywords) {
          if (normalized.contains(keyword)) {
            debugPrint(
              '[VisualAcuity] ✅ Recognized "blurry" in partial (Bypassing guard)',
            );
            _recordResponse('blurry');
            return;
          }
        }
      }

      // … Make waveform responsive for 500ms
      _speechActiveTimer?.cancel();
      _speechActiveTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isSpeechActive = false);
      });

      // … Auto-erase recognized text after 2.5 seconds
      _speechEraserTimer?.cancel();
      _speechEraserTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _lastDetectedSpeech = null;
          });
        }
      });
    }
  }

  void _onDistanceCalibrationComplete() {
    setState(() {
      _showDistanceCalibration = false;
      _isCalibrationActive = false; // Mark calibration as not active
    });
    // Start continuous distance monitoring after calibration
    _startContinuousDistanceMonitoring();

    // … FIX: Show cover eye instruction AFTER calibration for right eye
    if (_currentEye == 'right') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CoverLeftEyeInstructionScreen(
            onContinue: () {
              Navigator.of(context).pop();
              _startEyeTest();
            },
          ),
        ),
      );
    } else {
      _startEyeTest();
    }
  }

  /// Start continuous distance monitoring during the test
  Future<void> _startContinuousDistanceMonitoring() async {
    if (!_useDistanceMonitoring) return;

    debugPrint('✅ [DistanceMonitor] Starting/Resuming distance monitoring');

    // Set up distance update callback
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    _distanceService.onError = (msg) => debugPrint('[DistanceMonitor] $msg');

    // … FIX: Always ensure camera is initialized/re-initialized
    // This prevents "stale" camera handles after returning from calibration screen or restarts
    debugPrint('✅ [DistanceMonitor] Initializing/Ensuring camera');
    await _distanceService.initializeCamera();

    if (!_distanceService.isMonitoring) {
      debugPrint('✅ [DistanceMonitor] Starting monitoring');
      await _distanceService.startMonitoring();
    } else {
      debugPrint('✅ [DistanceMonitor] Monitoring already active');
    }
  }

  /// Handle real-time distance updates
  /// Handle real-time distance updates with auto pause/resume
  DateTime? _lastShouldPauseTime;
  static const Duration _distancePauseDebounce = Duration(milliseconds: 1000);

  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    // … FIX: Don't process distance updates while pause dialog is showing
    if (_isPausedForExit) return;

    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      'visual_acuity',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
      // … FIX: Only set _isDistanceOk to true here.
      // It is set to false only in _pauseTestForDistance after cooldown check.
      if (!shouldPause) {
        _isDistanceOk = true;
      }
    });

    // … AUTO PAUSE/RESUME logic with DEBOUNCING
    // ALWAYS check if we should pause, regardless of _showE, but only apply pause if we are in a state where it matters
    if (shouldPause) {
      _lastShouldPauseTime ??= DateTime.now();
      final durationSinceFirstIssue = DateTime.now().difference(
        _lastShouldPauseTime!,
      );

      if (durationSinceFirstIssue >= _distancePauseDebounce &&
          !_isTestPausedForDistance) {
        // Only pause if actually in a test phase (E or Relaxation)
        if (_showE || _showRelaxation) {
          _skipManager
              .canShowDistanceWarning(DistanceTestType.visualAcuity)
              .then((canShow) {
                if (mounted && canShow && !_isPausedForExit) {
                  _pauseTestForDistance();
                }
              });
        }
      }
    } else {
      _lastShouldPauseTime = null;
      if (_isTestPausedForDistance && !_isPausedForExit) {
        _resumeTestAfterDistance();
      }
    }
  }

  /// Pause the test due to incorrect distance
  void _pauseTestForDistance() {
    setState(() {
      _isTestPausedForDistance = true;
      _isDistanceOk = false; // Mark distance as not OK when paused
    });

    // Cancel timers
    _eCountdownTimer?.cancel();
    _eDisplayTimer?.cancel();

    // ✅ NO verbal "Test Paused" here - visual overlay is sufficient
    // This allows the user's voice to be heard even if they are slightly too close
    HapticFeedback.mediumImpact();
  }

  /// Resume the test after distance is corrected or dialog is closed
  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;

    setState(() {
      _isTestPausedForDistance = false;
      _isDistanceOk = true; // Mark distance as OK when resumed
      _lastShouldPauseTime = null;
    });

    // Resume distance monitoring if needed
    if (!_showDistanceCalibration) {
      _startContinuousDistanceMonitoring();
    }

    // Restart the countdown timer with remaining time
    if (_showE && _waitingForResponse) {
      // Resume speech recognition if needed
      final provider = context.read<TestSessionProvider>();
      if (provider.profileType != 'patient' && !_continuousSpeech.isActive) {
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
      _restartEDisplayTimer();
    } else if (_showRelaxation) {
      // 🎤 RESUME MIC: If we were already below 3s when distance was corrected
      final provider = context.read<TestSessionProvider>();
      if (provider.profileType != 'patient' &&
          _relaxationCountdown <= 3 &&
          !_continuousSpeech.isActive) {
        debugPrint(
          '[VisualAcuity] 🗣️ Resuming mic (already below 3s in relaxation)',
        );
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
      _restartRelaxationTimer();
    }
    HapticFeedback.mediumImpact();
  }

  void _restartRelaxationTimer() {
    _relaxationTimer?.cancel();

    if (_isTestPausedForDistance) {
      _relaxationProgressController.stop();
      return;
    }

    // Start/Resume smooth animation
    _relaxationProgressController.forward();

    _relaxationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // … CRITICAL FIX: If paused for distance, do not decrement countdown
      if (_isTestPausedForDistance) {
        _relaxationProgressController.stop();
        return;
      }

      setState(() {
        _relaxationCountdown--;
      });

      final provider = context.read<TestSessionProvider>();
      if (provider.profileType != 'patient' &&
          _relaxationCountdown == 3 &&
          mounted) {
        debugPrint('[VisualAcuity] 🎤 3s remaining - Starting mic early');
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }

      if (_relaxationCountdown <= 0) {
        timer.cancel();
        // … FALLBACK: Transition phase if animation listener fails
        if (_showRelaxation) {
          _showTumblingE();
        }
      }
    });
  }

  /// Restart the E display timer with remaining time
  void _restartEDisplayTimer() {
    if (_eDisplayCountdown <= 0) {
      // If no time left, record no response
      _recordResponse(null);
      return;
    }

    // 🎤 Ensure mic is active when resuming E phase
    final provider = context.read<TestSessionProvider>();
    if (provider.profileType != 'patient' && !_continuousSpeech.isActive) {
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.15,
        bufferMs: 1000,
      );
    }

    // Restart countdown timer
    _eCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) {
        timer.cancel();
        return;
      }
      setState(() {
        _eDisplayCountdown--;
      });
      if (_eDisplayCountdown <= 0) {
        timer.cancel();
      }
    });

    // Auto-advance if no response within time limit
    _eDisplayTimer = Timer(
      Duration(seconds: _eDisplayCountdown), // Use remaining countdown
      () {
        if (_waitingForResponse && !_isTestPausedForDistance) {
          // Use last recognized value if available
          final lastValue = _continuousSpeech.getLastRecognized();
          if (lastValue != null) {
            final direction = SpeechService.parseDirection(lastValue);
            _recordResponse(direction, source: 'timer_timeout_last_value');
          } else {
            _recordResponse(
              null,
              source: 'timer_timeout_no_value',
            ); // No response
          }
        }
      },
    );
  }

  void _startEyeTest() {
    if (!mounted || _testComplete || _showE || _showRelaxation) {
      debugPrint(
        '[VisualAcuity] ⚠️ _startEyeTest IGNORED: Test already in progress',
      );
      return;
    }

    debugPrint('✅ [VisualAcuity] _startEyeTest called for eye: $_currentEye');
    setState(() {
      _isTestPausedForDistance = false;
      _isDistanceOk = true; // Reset distance status
    });
    _ttsService.speakEyeInstruction(_currentEye);

    // Wait 4 seconds for instructions to finish, then start relaxation
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        debugPrint('✅ [VisualAcuity] Delay finished, calling _startRelaxation');
        _startRelaxation();
      }
    });
  }

  void _startRelaxation() {
    debugPrint(
      '[VisualAcuity] _startRelaxation starting (Duration: ${TestConstants.relaxationDurationSeconds}s)',
    );
    // 💡 ALWAYS-LISTENING: We no longer stop the mic here.
    // The manager will keep listening in the background.

    setState(() {
      _showRelaxation = true;
      _showE = false;
      _showResult = false; // … Ensure result screen from prev trial is cleared
      _isTestPausedForDistance =
          false; // Reset to ensure no accidental carry-over
      _isDistanceOk = true; // Reset distance status
      _relaxationCountdown = TestConstants.relaxationDurationSeconds;
    });

    _eDisplayStartTime = null; // … Reset timing guard for next E
    _ttsService.speak(TtsService.relaxationInstruction);

    _relaxationProgressController.reset();
    _restartRelaxationTimer();
  }

  void _showTumblingE() {
    if (!mounted) return;

    debugPrint(
      '✅ [VisualAcuity] _showTumblingE called (Current Level: $_currentLevel)',
    );
    // … NEW: Clear ANY stale speech before rotation to prevent "leakage" from last E
    _continuousSpeech.clearAccumulated();

    // … Explicitly reset display state
    _eDisplayCountdown = TestConstants.eDisplayDurationSeconds;
    _eDisplayStartTime = DateTime.now();
    _lastPlateStartTime = DateTime.now(); // ⏳ Start grace period

    // ✅ CRITICAL: Flush ALL stale speech from previous plates
    // This fixes the bug where a silent timeout was recorded as an incorrect answer
    _continuousSpeech.clearAccumulated();

    // … Cancel ANY existing timers for this eye/trial
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();

    _currentLevel = _currentLevel.clamp(
      0,
      TestConstants.visualAcuityLevels.length - 1,
    );

    final directions = EDirection.values
        .where((d) => d != _currentDirection && d != EDirection.blurry)
        .toList();
    final newDirection = directions[_random.nextInt(directions.length)];

    debugPrint(
      '✅ [VisualAcuity] DIRECTION ROTATION: $_currentDirection -> $newDirection',
    );
    _currentDirection = newDirection;

    // … Reset preview when NEW E starts
    _lastDetectedSpeech = null;

    setState(() {
      _showRelaxation = false;
      _showE = true;
      _showResult = false;
      _waitingForResponse = true;
      _lastDetectedSpeech = null;
      _eDisplayStartTime = DateTime.now();

      debugPrint(
        '✅ [VisualAcuity] 👁️ Displaying E: Size=${TestConstants.visualAcuityLevels[_currentLevel].sizeMm}mm '
        '(Index: $_currentLevel)',
      );
    });

    // Start mic for new plate if not already active
    if (!_continuousSpeech.isActive) {
      debugPrint('[VisualAcuity] 🎤 Starting mic for new plate');
      _continuousSpeech.start(bufferMs: 800);
    }

    // … CRITICAL FIX: If already paused due to distance, do not start interaction timers yet
    if (_isTestPausedForDistance) {
      debugPrint(
        '[VisualAcuity] ⏸️ Postponing timers: test is currently paused for distance',
      );
      return;
    }

    // Start countdown timer for display
    _eCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) {
        // If paused or unmounted, we don't clear the timer here as we want it to survive for resume,
        // but we stop the countdown from progressing.
        if (!mounted) timer.cancel();
        return;
      }
      setState(() {
        _eDisplayCountdown--;
      });
      if (_eDisplayCountdown <= 0) {
        timer.cancel();
      }
    });

    // Auto-advance if no response within time limit
    _eDisplayTimer = Timer(
      Duration(seconds: _eDisplayCountdown), // Use remaining countdown
      () {
        if (_waitingForResponse && !_isTestPausedForDistance) {
          // Use last recognized value if available
          final lastValue = _continuousSpeech.getLastRecognized();
          if (lastValue != null) {
            final direction = SpeechService.parseDirection(lastValue);
            _recordResponse(direction, source: 'timer_timeout_last_value');
          } else {
            _recordResponse(
              null,
              source: 'timer_timeout_no_value',
            ); // No response
          }
        }
      },
    );
  }

  void _handleVoiceResponse(String recognized) {
    debugPrint(
      '[VisualAcuity] ✅✅✅ _handleVoiceResponse called with: "$recognized"',
    );

    // Only process if the E is currently displayed and we are waiting for a response
    if (!mounted || !_showE || !_waitingForResponse) {
      debugPrint(
        '[VisualAcuity] ⚠️ Not in E display phase or not waiting for response - ignoring voice input',
      );
      return;
    }

    final normalized = recognized.toLowerCase().trim();

    // 1. Try to match a direction FIRST (Bypass timing guard for clear commands)
    debugPrint('[VisualAcuity] 💬 Parsing direction from: "$recognized"');
    final direction = SpeechService.parseDirection(normalized);
    debugPrint('[VisualAcuity] ✅ Parsed direction: $direction');

    if (direction != null) {
      debugPrint(
        '[VisualAcuity] … Recording direction: $direction (Bypassing timing guard)',
      );
      if (mounted) setState(() => _lastDetectedSpeech = recognized);
      _recordResponse(direction, source: 'voice_final');
      return;
    }

    // 2. Check for blurry keywords (Also bypass guard for clear "blurry" intent)
    final blurryKeywords = [
      'blurry',
      'blur',
      'bloody',
      'body',
      'blush',
      'cannot see',
      'can\'t see',
      'kanchi',
      'cannot see clearly',
      'can\'t see clearly',
      'too blurry',
      'not clear',
      'nothing',
      'country',
    ];

    for (var keyword in blurryKeywords) {
      if (normalized.contains(keyword)) {
        debugPrint(
          '[VisualAcuity] ✅ Recognized "blurry" keyword (Bypassing timing guard)',
        );
        _recordResponse('blurry', source: 'voice_blurry_keyword');
        return;
      }
    }

    // 3. APPLY TIMING GUARD ONLY FOR UNRECOGNIZED SPEECH
    // This prevents accidental triggers from previous plates but allows immediate
    // correct commands to work (fixing the "Up" issue where it's too fast).
    if (_eDisplayStartTime != null) {
      final sinceRotation = DateTime.now().difference(_eDisplayStartTime!);
      if (sinceRotation < const Duration(milliseconds: 500)) {
        debugPrint(
          '[VisualAcuity] ⏱️ Ignoring unrecognized speech: arrived too fast after rotation (${sinceRotation.inMilliseconds}ms)',
        );
        return;
      }
    }

    debugPrint(
      '[VisualAcuity] ❌ Direction/Blurry not matched from: "$normalized"',
    );
  }

  void _handleButtonResponse(EDirection direction) {
    if (!_waitingForResponse) return;

    debugPrint('[VisualAcuity] 🖱️ BUTTON PRESSED: ${direction.label}');

    // Just flush the buffer to prevent clash, don't interfere with speech service
    _continuousSpeech.clearAccumulated();

    // Record response immediately
    _recordResponse(direction.label.toLowerCase(), source: 'manual_button');
  }

  void _recordResponse(String? userResponse, {String source = 'unknown'}) {
    debugPrint(
      '[VisualAcuity] 🎬 _recordResponse START (source: $source, value: $userResponse)',
    );
    if (!_waitingForResponse) {
      debugPrint(
        '[VisualAcuity] ⚠️ _recordResponse ABORT: Already recorded/waiting=false',
      );
      return;
    }
    debugPrint(
      '[VisualAcuity] ✅ _recordResponse called from $source with: $userResponse',
    );
    if (!_waitingForResponse) {
      debugPrint('[VisualAcuity] ⚠️ _recordResponse IGNORED: Already recorded');
      return;
    }

    // ✅ CLEAR: Just flush the buffer, keep hardware active as requested
    _continuousSpeech.clearAccumulated();

    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();

    // … HANDLE NO RESPONSE section continues here...
    _continuousSpeech.clearAccumulated();
    // 📌 DO NOT clear _lastDetectedSpeech here - let it persist for result screen

    // … HANDLE NO RESPONSE (Silence): Rotate E in SAME size and try again
    if (userResponse == null) {
      debugPrint(
        '[VisualAcuity] Timeout - Rotating E (staying at level $_currentLevel)',
      );
      // 🔥 CLEAR: Ensure no carry-over to the rotated plate
      _continuousSpeech.clearAccumulated();

      // Update UI state to show rotation is happening
      if (mounted) {
        setState(() {
          _waitingForResponse = false;
          _showE = false;
        });
      }

      // Short delay for rotation feel so the user sees a "new" attempt
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _showTumblingE();
      });
      return;
    }

    // ⚡️ PROACTIVE: If user used buttons, the mic might have captured noise.
    // Clean it up immediately and ensure state is fresh for next letter.
    _isTestPausedForDistance = false;
    _isDistanceOk = true;

    _continuousSpeech.clearAccumulated();

    final responseTime = _eDisplayStartTime != null
        ? DateTime.now().difference(_eDisplayStartTime!).inMilliseconds
        : 0;

    // Check if response was "blurry"
    final wasBlurry = userResponse.toLowerCase() == 'blurry';
    final isCorrect =
        !wasBlurry &&
        userResponse.toLowerCase() == _currentDirection.label.toLowerCase();

    // Create response record
    final record = EResponseRecord(
      level: _currentLevel,
      eSize: TestConstants.visualAcuityLevels[_currentLevel].flutterFontSize,
      expectedDirection: _currentDirection.label,
      userResponse: userResponse,
      isCorrect: isCorrect,
      responseTimeMs: responseTime,
      wasBlurry: wasBlurry,
    );

    _responses.add(record);
    _totalResponses++;

    // Voice confirmation feedback
    if (isCorrect) {
      _correctAtLevel++;
      _totalCorrect++;
      _ttsService.speakCorrect(userResponse);
    } else {
      _incorrectCounterAtLevel++; // NEW track incorrect specifically
      _ttsService.speakIncorrect(userResponse);
    }
    _totalAtLevel++;

    setState(() {
      _waitingForResponse = false;
      _showE = false;
      _showResult = true;
    });

    // Clear timing guard to prevent reuse
    _eDisplayStartTime = null;

    // Show result briefly - Increased for better visibility as a "screen"
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _evaluateAndContinue();
    });
  }

  // Helper counter for incorrect responses
  int _incorrectCounterAtLevel = 0;

  // … FIXED METHOD: Test exactly 7 plates (one per level)
  void _evaluateAndContinue() {
    debugPrint('[VisualAcuity] 🔄 _evaluateAndContinue START');
    setState(() => _showResult = false);

    // … ALWAYS move to next level after any response (correct or incorrect)
    // As per user requirement: "once i get one size once should n't ask again in the same size"
    _currentLevel++;
    _correctAtLevel = 0;
    _totalAtLevel = 0;
    _incorrectCounterAtLevel = 0;

    if (_currentLevel >= TestConstants.visualAcuityLevels.length) {
      debugPrint('… [VisualAcuity] Finished all levels');
      _completeEyeTest();
    } else {
      debugPrint('… [VisualAcuity] Moving to next level: $_currentLevel');
      _startRelaxation();
    }
  }

  void _completeEyeTest() {
    // … NEW SCORING LOGIC: Find the BEST (smallest) font size correctly identified
    int bestLevelIndex = -1;
    for (var response in _responses) {
      if (response.isCorrect) {
        // Higher level index means smaller size (6/6 is index 6)
        if (bestLevelIndex == -1 || response.level > bestLevelIndex) {
          bestLevelIndex = response.level;
        }
      }
    }

    // Default to level 0 (6/60) if none were correct
    final vaLevel = bestLevelIndex != -1
        ? TestConstants.visualAcuityLevels[bestLevelIndex]
        : TestConstants.visualAcuityLevels[0];

    String status;
    if (bestLevelIndex == -1) {
      status = 'Significant reduction (Below 6/60)';
    } else if (vaLevel.logMAR <= 0.0) {
      status = 'Normal Vision';
    } else if (vaLevel.logMAR <= 0.3) {
      status = 'Mild reduction';
    } else {
      status = 'Significant reduction';
    }

    final result = VisualAcuityResult(
      eye: _currentEye,
      snellenScore: bestLevelIndex == -1 ? 'Worse than 6/60' : vaLevel.snellen,
      logMAR: vaLevel.logMAR,
      correctResponses: _totalCorrect,
      totalResponses: _totalResponses,
      durationSeconds: _responses.isNotEmpty
          ? (_responses.map((r) => r.responseTimeMs).reduce((a, b) => a + b) /
                    1000)
                .round()
          : 0,
      responses: _responses.toList(),
      status: status,
    );

    // Save result
    final provider = context.read<TestSessionProvider>();
    provider.setVisualAcuityResult(result);

    if (_currentEye == 'right') {
      // Switch to left eye
      setState(() {
        _eyeSwitchPending = true;
      });
    } else {
      // Both eyes complete - START AUTO-NAVIGATION TIMER
      setState(() {
        _testComplete = true;
        _autoNavigationCountdown = 5; // Reset countdown
      });

      // Start the auto-navigation countdown
      _startAutoNavigationTimer();
    }
  }

  void _startAutoNavigationTimer() {
    _autoNavigationTimer?.cancel();

    _autoNavigationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _autoNavigationCountdown--;
      });

      if (_autoNavigationCountdown <= 0) {
        timer.cancel();
        _proceedToBothEyesTest();
      }
    });
  }

  void _proceedToBothEyesTest() {
    if (_isNavigatingToNextTest) return;
    _isNavigatingToNextTest = true;

    // Stop distance monitoring before navigating
    _distanceService.stopMonitoring();

    final provider = context.read<TestSessionProvider>();
    if (provider.isIndividualTest) {
      Navigator.pushReplacementNamed(context, '/quick-test-result');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ReadingTestInstructionsScreen(),
        ),
      );
    }
  }

  Future<void> _manualSpeechReset() async {
    if (_isResettingSpeech) return;

    debugPrint('[VisualAcuity] 🌪️ MANUALLY triggering verified speech reset');
    if (mounted) setState(() => _isResettingSpeech = true);

    try {
      // 🛡️ VERIFIED RETRY: Returns false if hardware failed
      final success = await _continuousSpeech.retryListening().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (mounted) {
        if (success) {
          _showResetSuccessSnackbar();
        } else {
          debugPrint('[VisualAcuity] 🛑 Reset failed at hardware level');
          _showResetErrorSnackbar();
        }
      }
    } catch (e) {
      debugPrint('[VisualAcuity] 🚨 Manual retry EXCEPTION: $e');
      if (mounted) _showResetErrorSnackbar();
    } finally {
      if (mounted) {
        setState(() => _isResettingSpeech = false);
      }
    }
  }

  void _showResetSuccessSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Voice system ready',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showResetErrorSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Reset failed - try again',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _relaxationProgressController.dispose();
    context.read<SpeechService>().setGloballyDisabled(
      false,
    ); // Reset for next session
    _speechEraserTimer?.cancel();
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _speechActiveTimer?.cancel();
    _isResettingSpeech = false;
    _continuousSpeech.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    _distanceService.stopMonitoring();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_testComplete) {
      return _buildTestCompleteView();
    }

    return PopScope(
      canPop: false, // Prevent accidental exit
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          title: Text(
            'Visual Acuity - ${_currentEye.toUpperCase()} Eye',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main test content
              LayoutBuilder(
                builder: (context, constraints) {
                  final isLandscape =
                      MediaQuery.of(context).orientation ==
                      Orientation.landscape;
                  final availableHeight = constraints.maxHeight;

                  if (isLandscape && _showE && _waitingForResponse) {
                    return Column(
                      children: [
                        _buildInfoBar(isLandscape: true),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildEView(
                                  isLandscape: true,
                                  isSideBySide: true,
                                ),
                              ),
                              Container(
                                width: 1,
                                color: AppColors.border.withValues(alpha: 0.2),
                              ),
                              SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  width: 280,
                                  child:
                                      _buildLandscapeDirectionButtonsSidePanel(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      // Progress and info bar (more compact in landscape)
                      _buildInfoBar(isLandscape: isLandscape),

                      // Main content
                      Expanded(
                        child: _buildMainContent(
                          isLandscape: isLandscape,
                          maxHeight: availableHeight,
                        ),
                      ),

                      // Direction buttons (when showing E) - Adaptive layout
                      if (_showE && _waitingForResponse)
                        _buildDirectionButtons(isLandscape: isLandscape),
                    ],
                  );
                },
              ),

              Positioned(
                bottom: _showE && _waitingForResponse ? 150 : 50,
                left: 0,
                right: 0,
                child: Center(child: _buildRecognizedTextIndicator()),
              ),
              // Distance warning overlay
              DistanceWarningOverlay(
                isVisible:
                    _isDistanceOk == false &&
                    (_waitingForResponse || _showRelaxation) &&
                    !_isCalibrationActive,
                status: _distanceStatus,
                currentDistance: _currentDistance,
                targetDistance: 100.0,
                onSkip: () {
                  _skipManager.recordSkip(DistanceTestType.visualAcuity);
                  _resumeTestAfterDistance();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceIndicator({bool compact = false}) {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      100.0,
      testType: 'visual_acuity',
    );
    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'Searching...';

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          color: indicatorColor.withValues(alpha: 0.08),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              distanceText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: indicatorColor,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0.15),
                AppColors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: indicatorColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: indicatorColor.withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulse-like status circle
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISTANCE',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: indicatorColor.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    distanceText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: indicatorColor,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    _showPauseDialog(reason: 'back button');
  }

  void _restartCurrentTest() {
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    // 💡 No stop here, resetTest will handle full cleanup if needed

    _distanceService.stopMonitoring();

    if (_currentEye == 'right') {
      _resetTest();
    } else {
      // Restarting left eye should take back to left eye instruction
      final provider = Provider.of<TestSessionProvider>(context, listen: false);
      provider.resetVisualAcuityLeft();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CoverRightEyeInstructionScreen(),
        ),
      );
    }
  }

  void _resetTest() {
    final provider = Provider.of<TestSessionProvider>(context, listen: false);
    provider.resetVisualAcuity();

    setState(() {
      _currentLevel = 0;
      _correctAtLevel = 0;
      _totalAtLevel = 0;
      _totalCorrect = 0;
      _totalResponses = 0;
      _responses.clear();
      _currentEye = widget.startWithLeftEye ? 'left' : 'right';
      _eyeSwitchPending = false;
      _showRelaxation = false;
      _showE = false;
      _showResult = false;
      _testComplete = false;
      _waitingForResponse = false;
      _isTestPausedForDistance = false;
      _isNavigatingToNextTest = false;
      _showDistanceCalibration = true;
    });

    // … FIX: Explicitly show calibration screen after state reset
    // Wait for setState to complete, then show calibration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showDistanceCalibration) {
        _showCalibrationScreen();
      }
    });
  }

  Widget _buildInfoBar({bool isLandscape = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 6 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Level indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: ShapeDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadows: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'LEVEL ${_currentLevel + 1}/${TestConstants.visualAcuityLevels.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Score indicator (Squircle)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: ShapeDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadows: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$_totalCorrect/$_totalResponses',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          if (isLandscape && _showE) ...[
            const SizedBox(width: 8),
            // Snellen Size in Bar (Landscape)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                TestConstants.visualAcuityLevels[_currentLevel].snellen,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Timer in Bar (Landscape)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color:
                    (_eDisplayCountdown <= 2
                            ? AppColors.error
                            : AppColors.primary)
                        .withValues(alpha: 0.08),
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: _eDisplayCountdown <= 2
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_eDisplayCountdown}s',
                    style: TextStyle(
                      color: _eDisplayCountdown <= 2
                          ? AppColors.error
                          : AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          // Distance Indicator (Compact)
          if (_useDistanceMonitoring && !_showDistanceCalibration) ...[
            _buildDistanceIndicator(compact: true),
            const SizedBox(width: 8),
          ],
          // Speech waveform with Retry Indicator
          // Speech waveform with Retry Indicator
          Builder(
            builder: (context) {
              final provider = context.watch<TestSessionProvider>();
              if (provider.profileType == 'patient') {
                return const SizedBox.shrink();
              }

              final bool shouldBeListening =
                  _continuousSpeech.shouldBeListening;
              final bool isActuallyListening = _isListening;
              final bool isPausedForTts = _continuousSpeech.isPausedForTts;
              final bool isRestarting = _continuousSpeech.isRestartPending;

              final bool isInListeningPhase =
                  _showE || (_showRelaxation && _relaxationCountdown <= 3);

              // ⏳ GRACE PERIOD: HW takes ~1-2s to warm up on some devices
              final bool isInGracePeriod =
                  _lastPlateStartTime != null &&
                  DateTime.now().difference(_lastPlateStartTime!).inSeconds < 4;

              // STALLED = Engine is OFF but should be ON, and isn't currently TRYING to fix itself
              final bool isStalled =
                  shouldBeListening &&
                  !isActuallyListening &&
                  !isPausedForTts &&
                  !isRestarting && // 🛡️ CRITICAL: Don't show stalled if we are in the middle of a restart
                  isInListeningPhase &&
                  !_isPausedForExit &&
                  !_isTestPausedForDistance &&
                  !_isResettingSpeech &&
                  !_eyeSwitchPending && // 🛡️ Hide during eye transition
                  !isInGracePeriod; // 🛡️ Give hardware time to wake up (now 4s)

              final bool isWorking = isActuallyListening && !isPausedForTts;

              return GestureDetector(
                onTap: isStalled ? _manualSpeechReset : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isStalled
                        ? Colors.red.withValues(alpha: 0.1)
                        : (isWorking
                              ? AppColors.success.withValues(alpha: 0.1)
                              : (isRestarting
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(
                                        alpha: 0.05,
                                      ))),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isStalled
                          ? Colors.red.withValues(alpha: 0.3)
                          : (isRestarting
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : Colors.transparent),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isStalled) ...[
                        _SpeechWaveform(
                          isListening: isWorking,
                          isTalking: _isSpeechActive,
                          color: isWorking
                              ? AppColors.success
                              : (isRestarting
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(width: 8),
                        if (isWorking)
                          Text(
                            'LISTENING',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.success,
                              letterSpacing: 0.5,
                            ),
                          )
                        else if (isRestarting)
                          Text(
                            'RECONNECTING...',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        if (isWorking || isRestarting) const SizedBox(width: 6),
                        Icon(
                          isPausedForTts
                              ? Icons.volume_up_rounded
                              : (isWorking
                                    ? Icons.mic
                                    : (isRestarting
                                          ? Icons.sync
                                          : Icons.mic_off)),
                          size: 16,
                          color: isWorking
                              ? AppColors.success
                              : (isRestarting
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.5)),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TAP TO RETRY',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizedTextIndicator() {
    final bool hasRecognized =
        _lastDetectedSpeech != null && _lastDetectedSpeech!.isNotEmpty;

    if (!hasRecognized) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _lastDetectedSpeech!,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMainContent({bool isLandscape = false, double maxHeight = 0}) {
    if (_eyeSwitchPending) {
      return _buildEyeSwitchView();
    }

    if (_showDistanceCalibration) {
      return _buildDistanceCalibrationView();
    }

    if (_showRelaxation) {
      return _buildRelaxationView(isLandscape: isLandscape);
    }

    if (_showE) {
      return _buildEView(isLandscape: isLandscape, isSideBySide: false);
    }

    if (_showResult) {
      return _buildResultFeedback();
    }

    return const Center(child: EyeLoader(size: 60));
  }

  Widget _buildDistanceCalibrationView() {
    // This view is shown briefly while navigating to the calibration screen
    // The actual calibration happens in DistanceCalibrationScreen
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EyeLoader(size: 80),
          const SizedBox(height: 24),
          Text(
            'Opening Distance Calibration...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationView({bool isLandscape = false}) {
    return Container(
      color: AppColors.testBackground,
      width: double.infinity,
      height: double.infinity,
      child: isLandscape
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Side: Image and Overlapping Timer (Left Aligned)
                  Expanded(
                    flex: 12, // Take more space
                    child: _buildRelaxationHero(isLandscape: true),
                  ),
                  const SizedBox(width: 32),
                  // Right Side: Instructions (Take remaining space)
                  Expanded(flex: 5, child: _buildRelaxationInstructions()),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildRelaxationHero(isLandscape: false),
                    const SizedBox(height: 60),
                    _buildRelaxationInstructions(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRelaxationImage({required bool isLandscape, double? height}) {
    return Builder(
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final finalHeight =
            height ?? (isLandscape ? screenHeight : screenHeight * 0.60);

        return Container(
          height: finalHeight,
          width: double.infinity,
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            shadows: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            AppAssets.relaxationImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.primary.withValues(alpha: 0.05),
              child: const Icon(
                Icons.landscape,
                size: 100,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRelaxationTimer() {
    return AnimatedBuilder(
      animation: _relaxationProgressController,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(
                alpha: 0.8,
              ), // More opaque since it's not over image
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: _relaxationProgressController.value,
                    strokeWidth: 5,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  '$_relaxationCountdown',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    fontFamily: 'Inter',
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRelaxationHero({required bool isLandscape}) {
    return Builder(
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;

        final imageHeight = isLandscape
            ? screenHeight * 0.8
            : screenHeight * 0.60;

        return Align(
          alignment: isLandscape ? Alignment.centerLeft : Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: isLandscape
                ? Alignment.centerRight
                : Alignment.bottomCenter,
            children: [
              // Image Card
              Container(
                margin: EdgeInsets.only(
                  right: isLandscape ? 50 : 0, // Room for timer overlap
                  bottom: isLandscape ? 0 : 45, // Room for timer overlap
                ),
                child: _buildRelaxationImage(
                  isLandscape: isLandscape,
                  height: imageHeight,
                ),
              ),

              // Glassmorphism Smooth Timer
              Positioned(
                right: isLandscape ? 0 : null,
                bottom: isLandscape ? null : -45,
                child: _buildRelaxationTimer(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRelaxationInstructions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Standardized Instruction Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Relax and focus on the distance',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEView({bool isLandscape = false, bool isSideBySide = false}) {
    final level = TestConstants.visualAcuityLevels[_currentLevel];

    final eSize = level.flutterFontSize;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Timer and Size indicator row
          if (!isSideBySide && !isLandscape)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isLandscape ? 6 : 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ✅ PROMINENT Size indicator on LEFT
                  Container(
                    width: 72,
                    height: 44,
                    decoration: ShapeDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      shadows: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        level.snellen,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  // Timer on RIGHT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TIME REMAINING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: _eDisplayCountdown <= 2
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isTestPausedForDistance
                                ? 'PAUSED'
                                : '${_eDisplayCountdown}s',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _eDisplayCountdown <= 2
                                  ? AppColors.error
                                  : AppColors.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Main E display area - Use a guaranteed height if expanded is too small
          Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              minHeight: isLandscape ? (isSideBySide ? 200 : 150) : 250,
            ),
            child: Center(
              child: Transform.rotate(
                angle: _currentDirection.rotationDegrees * pi / 180,
                // ✅ FIX: Force antialiasing and proper rendering
                filterQuality: FilterQuality.high,
                child: Text(
                  'E',
                  style: TextStyle(
                    fontSize: eSize,
                    fontWeight: FontWeight.bold, // Maximum boldness

                    color: AppColors.black,
                    letterSpacing: 0,
                    height: 1.0,
                  ),
                  // ✅ Add text scaling to ensure crisp rendering
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
          ),

          // Instruction text with voice status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Builder(
              builder: (context) {
                final provider = context.watch<TestSessionProvider>();
                final isPractitioner = provider.profileType == 'patient';

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isListening && !isPractitioner)
                          Icon(
                            Icons.mic,
                            size: 20,
                            color: _isTestPausedForDistance
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        if (_isListening && !isPractitioner)
                          const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isTestPausedForDistance
                                ? 'Test paused - Adjust distance'
                                : 'Which way is the E pointing?',
                            style: TextStyle(
                              color: _isTestPausedForDistance
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                              fontWeight: _isTestPausedForDistance
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    if (!isPractitioner && !isSideBySide) ...[
                      const SizedBox(height: 8),
                      Text(
                        _isTestPausedForDistance
                            ? 'Voice recognition active - waiting to resume'
                            : 'Use buttons or say: Upper or Upward, Down or Downward, Left, Right',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButtons({bool isLandscape = false}) {
    if (isLandscape) {
      return _buildLandscapeDirectionButtons();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up button
          _DirectionButton(
            direction: EDirection.up,
            onPressed: () => _handleButtonResponse(EDirection.up),
          ),
          const SizedBox(height: 12),
          // Left, Right buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DirectionButton(
                direction: EDirection.left,
                onPressed: () => _handleButtonResponse(EDirection.left),
              ),
              const SizedBox(width: 80),
              _DirectionButton(
                direction: EDirection.right,
                onPressed: () => _handleButtonResponse(EDirection.right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Down button
          _DirectionButton(
            direction: EDirection.down,
            onPressed: () => _handleButtonResponse(EDirection.down),
          ),
          const SizedBox(height: 20),
          // Blurry/Can't See Clearly button (Proper Button)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleButtonResponse(EDirection.blurry),
              icon: const Icon(
                Icons.visibility_off_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              label: const Text(
                "BLURRY / CAN'T SEE CLEARLY",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeDirectionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left button
          _DirectionButton(
            direction: EDirection.left,
            compact: true,
            onPressed: () => _handleButtonResponse(EDirection.left),
          ),
          const SizedBox(width: 20),
          // Column for Up/Down
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DirectionButton(
                direction: EDirection.up,
                compact: true,
                onPressed: () => _handleButtonResponse(EDirection.up),
              ),
              const SizedBox(height: 8),
              _DirectionButton(
                direction: EDirection.down,
                compact: true,
                onPressed: () => _handleButtonResponse(EDirection.down),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Right button
          _DirectionButton(
            direction: EDirection.right,
            compact: true,
            onPressed: () => _handleButtonResponse(EDirection.right),
          ),
          const SizedBox(width: 40),
          // Blurry button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _handleButtonResponse(EDirection.blurry),
              icon: const Icon(Icons.visibility_off_rounded, size: 16),
              label: const Text(
                "BLURRY",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeDirectionButtonsSidePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'CONTROLS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          _DirectionButton(
            direction: EDirection.up,
            compact: true,
            onPressed: () => _handleButtonResponse(EDirection.up),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DirectionButton(
                direction: EDirection.left,
                compact: true,
                onPressed: () => _handleButtonResponse(EDirection.left),
              ),
              const SizedBox(width: 80),
              _DirectionButton(
                direction: EDirection.right,
                compact: true,
                onPressed: () => _handleButtonResponse(EDirection.right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DirectionButton(
            direction: EDirection.down,
            compact: true,
            onPressed: () => _handleButtonResponse(EDirection.down),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _handleButtonResponse(EDirection.blurry),
                icon: const Icon(
                  Icons.visibility_off_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: const Text(
                  "BLURRY",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultFeedback() {
    final lastResponse = _responses.isNotEmpty ? _responses.last : null;
    return TestFeedbackOverlay(
      isCorrect: lastResponse?.isCorrect ?? false,
      isBlurry: lastResponse?.wasBlurry ?? false,
      label: lastResponse?.wasBlurry == true ? 'BLURRY' : null,
    );
  }

  Widget _buildEyeSwitchView() {
    // Navigate to instruction screen - only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_eyeSwitchPending && mounted) {
        // ✅ FIX: Stop monitoring before showing cover eye instruction
        _distanceService.stopMonitoring();

        // Mark as handled immediately
        setState(() {
          _eyeSwitchPending = false;
        });

        // Navigate to instruction screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CoverRightEyeInstructionScreen(),
          ),
        );
      }
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EyeLoader(size: 45),
          const SizedBox(height: 24),
          Text(
            'Preparing left eye test...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCompleteView() {
    final provider = context.read<TestSessionProvider>();
    final rightAcuity = provider.visualAcuityRight?.snellenScore ?? 'N/A';
    final leftAcuity = provider.visualAcuityLeft?.snellenScore ?? 'N/A';

    // Qualitative feedback logic has been integrated into individual cards.

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          title: const Text('Visual Acuity Result'),
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.testBackground,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                size: 40,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Visual Acuity Test Completed',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Separate Eye Result Cards with Details
                      _buildIndividualSummaryCard(
                        'Right Eye',
                        rightAcuity,
                        AppColors.rightEye,
                        correct:
                            provider.visualAcuityRight?.correctResponses ?? 0,
                        total: provider.visualAcuityRight?.totalResponses ?? 0,
                      ),
                      const SizedBox(height: 16),
                      _buildIndividualSummaryCard(
                        'Left Eye',
                        leftAcuity,
                        AppColors.leftEye,
                        correct:
                            provider.visualAcuityLeft?.correctResponses ?? 0,
                        total: provider.visualAcuityLeft?.totalResponses ?? 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky Bottom Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _autoNavigationTimer?.cancel();
                    _proceedToBothEyesTest();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Continue Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_autoNavigationCountdown}s',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualSummaryCard(
    String eye,
    String score,
    Color color, {
    required int correct,
    required int total,
  }) {
    final status = _getShortStatus(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.remove_red_eye_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eye,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status == 'Optimal'
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'SNELLEN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    score,
                    style: TextStyle(
                      fontSize: score.contains('Worse') ? 13 : 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatRow(
                'Correct',
                '$correct',
                Icons.check_circle_outline,
                AppColors.success,
              ),
              _buildStatRow(
                'Total',
                '$total',
                Icons.analytics_outlined,
                AppColors.primary,
              ),
              _buildStatRow(
                'Accuracy',
                '${total > 0 ? (correct / total * 100).toStringAsFixed(0) : 0}%',
                Icons.insights,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getShortStatus(String score) {
    if (score == 'N/A') return 'Pending';
    try {
      final denominator = int.parse(score.split('/').last);
      if (denominator <= 20) return 'Optimal';
      if (denominator <= 40) return 'Good';
      return 'Needs Review';
    } catch (_) {
      return 'Normal';
    }
  }
}

class _DirectionButton extends StatelessWidget {
  final EDirection direction;
  final VoidCallback onPressed;
  final bool compact;

  const _DirectionButton({
    required this.direction,
    required this.onPressed,
    this.compact = false,
  });

  IconData get _icon {
    switch (direction) {
      case EDirection.up:
        return Icons.arrow_upward;
      case EDirection.down:
        return Icons.arrow_downward;
      case EDirection.left:
        return Icons.arrow_back;
      case EDirection.right:
        return Icons.arrow_forward;
      case EDirection.blurry:
        return Icons.visibility_off; // Can't see clearly icon
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = compact ? 48.0 : 64.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: compact ? 6 : 10,
            offset: Offset(0, compact ? 2 : 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Center(child: Icon(_icon, color: AppColors.white, size: 28)),
        ),
      ),
    );
  }
}

// … NEW Waveform animation for microphone
class _SpeechWaveform extends StatefulWidget {
  final bool isListening;
  final bool isTalking;
  final Color color;

  const _SpeechWaveform({
    required this.isListening,
    required this.isTalking,
    required this.color,
  });

  @override
  State<_SpeechWaveform> createState() => _SpeechWaveformState();
}

class _SpeechWaveformState extends State<_SpeechWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // … Animate when either listening OR actively talking
    final shouldAnimate = widget.isListening || widget.isTalking;

    if (!shouldAnimate) {
      // Static bars when not active
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Container(
            width: 3,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Create wave effect with different phases
            final phase = (index * 0.3) + _controller.value;
            final height = 4.0 + (10.0 * (0.5 + 0.5 * sin(phase * 2 * pi)));

            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
