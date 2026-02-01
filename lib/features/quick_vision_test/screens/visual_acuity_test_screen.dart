// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/core/utils/navigation_utils.dart';
import '../../../core/widgets/distance_warning_overlay.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';

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
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final DistanceSkipManager _skipManager = DistanceSkipManager();
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

  DateTime? _lastPlateStartTime; // ⏳ Warm-up grace period tracker

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _relaxationProgressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: TestConstants.relaxationDurationSeconds),
    );

    _relaxationProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _showRelaxation) {
        _showTumblingE();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initTestFlow();
    });
  }

  /// Decides whether to show calibration or skip straight to the test
  Future<void> _initTestFlow() async {
    await _ttsService.initialize();

    if (!mounted) return;
    final provider = context.read<TestSessionProvider>();

    // Resume left eye if already done right eye
    if (widget.startWithLeftEye ||
        (provider.currentEye == 'left' && provider.visualAcuityRight != null)) {
      debugPrint(
        '✅ [VisualAcuity] Starting LEFT EYE test - skipping calibration',
      );
      _showDistanceCalibration = false;
      _isCalibrationActive = false;
      _currentEye = 'left';
      provider.switchEye();

      await _startContinuousDistanceMonitoring();
      _startEyeTest();
      return;
    }

    // First time (right eye) — show calibration
    debugPrint(
      '✅ [VisualAcuity] Starting RIGHT EYE test - showing calibration',
    );
    if (_useDistanceMonitoring && _showDistanceCalibration) {
      _showCalibrationScreen();
    } else {
      _showDistanceCalibration = false;
      _isCalibrationActive = false;
      _startEyeTest();
    }
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

      _restartEDisplayTimer();
    } else if (_showRelaxation) {
      debugPrint('[VisualAcuity] ”„ Resuming relaxation phase');

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
      _restartEDisplayTimer();
    } else if (_showRelaxation) {
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
          _recordResponse(null, source: 'timer_timeout_no_value');
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

    // … Explicitly reset display state
    _eDisplayCountdown = TestConstants.eDisplayDurationSeconds;
    _eDisplayStartTime = DateTime.now();
    _lastPlateStartTime = DateTime.now(); // ⏳ Start grace period

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

    setState(() {
      _showRelaxation = false;
      _showE = true;
      _showResult = false;
      _waitingForResponse = true;
      _eDisplayStartTime = DateTime.now();

      debugPrint(
        '✅ [VisualAcuity] 👁️ Displaying E: Size=${TestConstants.visualAcuityLevels[_currentLevel].sizeMm}mm '
        '(Index: $_currentLevel)',
      );
    });

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
    _eDisplayTimer = Timer(Duration(seconds: _eDisplayCountdown), () {
      if (_waitingForResponse && !_isTestPausedForDistance) {
        _recordResponse(null, source: 'timer_timeout_no_value');
      }
    });
  }

  void _handleButtonResponse(EDirection direction) {
    if (!_waitingForResponse) return;

    debugPrint('[VisualAcuity] 🖱️ BUTTON PRESSED: ${direction.label}');

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

    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();

    // … HANDLE NO RESPONSE (Silence): Rotate E in SAME size and try again
    if (userResponse == null) {
      debugPrint(
        '[VisualAcuity] Timeout - Rotating E (staying at level $_currentLevel)',
      );

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

    _isTestPausedForDistance = false;
    _isDistanceOk = true;

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

  @override
  void dispose() {
    _relaxationProgressController.dispose();

    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _ttsService.dispose();
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
        backgroundColor: context.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            'Visual Acuity - ${_currentEye.toUpperCase()} Eye',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          backgroundColor: context.surface,
          elevation: 0,
          iconTheme: IconThemeData(color: context.textPrimary),
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
                        // Single Unified Header
                        if (_showE) _buildAcuityFixedHeader(isLandscape: true),
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
                                color: context.border.withValues(alpha: 0.2),
                              ),
                              SizedBox(
                                width: 280,
                                child:
                                    _buildLandscapeDirectionButtonsSidePanel(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      // Single Unified Header
                      if (_showE) _buildAcuityFixedHeader(isLandscape: false),

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

              // Floating Distance Indicator (Pill Design)
              if (_useDistanceMonitoring &&
                  !_showDistanceCalibration &&
                  !_testComplete &&
                  _isDistanceOk &&
                  (_showE || _showRelaxation))
                Positioned(
                  top:
                      (MediaQuery.of(context).orientation ==
                          Orientation.landscape)
                      ? 60
                      : 100,
                  right:
                      (MediaQuery.of(context).orientation ==
                          Orientation.landscape)
                      ? null
                      : 16,
                  left:
                      (MediaQuery.of(context).orientation ==
                          Orientation.landscape)
                      ? 16
                      : null,
                  child: _buildDistanceIndicator(compact: false),
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
                context.surface.withValues(alpha: 0.15),
                context.surface.withValues(alpha: 0.05),
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

  Widget _buildAcuityFixedHeader({bool isLandscape = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(
          bottom: BorderSide(
            color: context.border.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Snellen Size (No label)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: ShapeDecoration(
              color: context.primary.withValues(alpha: 0.08),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              TestConstants.visualAcuityLevels[_currentLevel].snellen,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: context.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Level & Score Chip: LEVEL 2/7 ✅ 2/2
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: ShapeDecoration(
              color: context.primary.withValues(alpha: 0.05),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LEVEL ${_currentLevel + 1}/${TestConstants.visualAcuityLevels.length}',
                  style: TextStyle(
                    color: context.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 10,
                  color: context.primary.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle_outline,
                  size: 10,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_totalCorrect/$_totalResponses',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          const SizedBox(width: 12),
          // Timer
          _buildinfoBarTimer(compact: true),
        ],
      ),
    );
  }

  Widget _buildinfoBarTimer({bool compact = false}) {
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          Text(
            'TIME REMAINING',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: context.textSecondary.withValues(alpha: 0.5),
              letterSpacing: 0.8,
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 16,
              color: _eDisplayCountdown <= 2 ? context.error : context.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '${_eDisplayCountdown}s',
              style: TextStyle(
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w900,
                color: _eDisplayCountdown <= 2
                    ? context.error
                    : context.primary,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
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
      color: context.scaffoldBackground,
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
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, // Pin to top
                children: [
                  _buildRelaxationHero(isLandscape: false),
                  const SizedBox(height: 70), // Space for text below timer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildRelaxationInstructions(),
                  ),
                ],
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
            color: context.surface,
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
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: context.surface.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
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
                        backgroundColor: context.primary.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.primary,
                        ),
                      ),
                    ),
                    Text(
                      '$_relaxationCountdown',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: context.primary,
                        fontFamily: 'Inter',
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
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
            : screenHeight * 0.68; // Adjusted for text and padding

        return Align(
          alignment: isLandscape ? Alignment.centerLeft : Alignment.topCenter,
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
                  bottom: 0,
                  left: isLandscape ? 0 : 24, // Added left padding for portrait
                ),
                padding: EdgeInsets.only(
                  right: isLandscape
                      ? 0
                      : 24, // Added right padding for portrait
                ),
                child: _buildRelaxationImage(
                  isLandscape: isLandscape,
                  height: imageHeight,
                ),
              ),

              // Glassmorphism Smooth Timer
              Positioned(
                right: isLandscape ? 0 : null,
                bottom: isLandscape ? null : -50, // Half of 100px timer height
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
              color: context.textPrimary,
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
          // Main E display area - Use a guaranteed height if expanded is too small
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, // Always white background for E visibility
              borderRadius: BorderRadius.circular(24),
            ),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Builder(
              builder: (context) {
                // final provider = context.watch<TestSessionProvider>();
                // final isPractitioner = provider.profileType == 'patient';

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _isTestPausedForDistance
                                ? 'Test paused - Adjust distance'
                                : 'Which way is the E pointing?',
                            style: TextStyle(
                              color: _isTestPausedForDistance
                                  ? context.error
                                  : context.textSecondary,
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
                    const SizedBox(height: 8),
                    Text(
                      _isTestPausedForDistance
                          ? 'Test paused - Adjust distance'
                          : 'Use buttons to indicate direction',
                      style: TextStyle(
                        color: context.textPrimary.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
        color: context.surface,
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
              icon: Icon(
                Icons.visibility_off_rounded,
                size: 18,
                color: context.primary,
              ),
              label: Text(
                "BLURRY / CAN'T SEE CLEARLY",
                style: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: context.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: context.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeDirectionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final buttonSize = (availableHeight < 150) ? 44.0 : 56.0;
        final iconSize = buttonSize * 0.55;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(
              top: BorderSide(
                color: context.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left button
                _DirectionButton(
                  direction: EDirection.left,
                  size: buttonSize,
                  iconSize: iconSize,
                  onPressed: () => _handleButtonResponse(EDirection.left),
                ),
                const SizedBox(width: 24),
                // Column for Up/Down
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DirectionButton(
                      direction: EDirection.up,
                      size: buttonSize,
                      iconSize: iconSize,
                      onPressed: () => _handleButtonResponse(EDirection.up),
                    ),
                    const SizedBox(height: 12),
                    _DirectionButton(
                      direction: EDirection.down,
                      size: buttonSize,
                      iconSize: iconSize,
                      onPressed: () => _handleButtonResponse(EDirection.down),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Right button
                _DirectionButton(
                  direction: EDirection.right,
                  size: buttonSize,
                  iconSize: iconSize,
                  onPressed: () => _handleButtonResponse(EDirection.right),
                ),
                const SizedBox(width: 48),
                // Blurry button
                SizedBox(
                  width: 100,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleButtonResponse(EDirection.blurry),
                    icon: Icon(
                      Icons.visibility_off_rounded,
                      size: iconSize * 0.5,
                    ),
                    label: Text(
                      "BLURRY",
                      style: TextStyle(
                        color: context.primary,
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
          ),
        );
      },
    );
  }

  Widget _buildLandscapeDirectionButtonsSidePanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        // Calculate dynamic button size based on available height
        // Base ratio: height / 4.8 (allows for 3 buttons vertically + spacing + blurry)
        double calcButtonSize = availableHeight / 4.8;
        final buttonSize = calcButtonSize.clamp(40.0, 72.0);

        final iconSize = buttonSize * 0.55;
        final verticalGap = (buttonSize / 6).clamp(4.0, 16.0);
        final horizontalGap = (buttonSize * 1.1).clamp(30.0, 80.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: context.surface,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DirectionButton(
                  direction: EDirection.up,
                  size: buttonSize,
                  iconSize: iconSize,
                  onPressed: () => _handleButtonResponse(EDirection.up),
                ),
                SizedBox(height: verticalGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DirectionButton(
                      direction: EDirection.left,
                      size: buttonSize,
                      iconSize: iconSize,
                      onPressed: () => _handleButtonResponse(EDirection.left),
                    ),
                    SizedBox(width: horizontalGap),
                    _DirectionButton(
                      direction: EDirection.right,
                      size: buttonSize,
                      iconSize: iconSize,
                      onPressed: () => _handleButtonResponse(EDirection.right),
                    ),
                  ],
                ),
                SizedBox(height: verticalGap),
                _DirectionButton(
                  direction: EDirection.down,
                  size: buttonSize,
                  iconSize: iconSize,
                  onPressed: () => _handleButtonResponse(EDirection.down),
                ),
                SizedBox(height: verticalGap * 1.5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: buttonSize * 2.5, // Proportional width
                    child: OutlinedButton.icon(
                      onPressed: () => _handleButtonResponse(EDirection.blurry),
                      icon: Icon(
                        Icons.visibility_off_rounded,
                        size: iconSize * 0.6,
                        color: context.primary,
                      ),
                      label: Text(
                        "BLURRY",
                        style: TextStyle(
                          color: context.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: (buttonSize < 45) ? 9 : 11,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: (buttonSize < 45) ? 6 : 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        backgroundColor: context.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            'Visual Acuity Result',
            style: TextStyle(color: context.textPrimary),
          ),
          automaticallyImplyLeading: false,
          backgroundColor: context.scaffoldBackground,
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
                          color: context.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.success.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 40,
                                color: context.success,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Visual Acuity Test Completed',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
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
                    backgroundColor: context.primary,
                    foregroundColor: Colors.white,
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
                          color: Colors.white.withValues(alpha: 0.2),
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
        color: context.surface,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: context.textPrimary,
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
                  Text(
                    'SNELLEN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    score,
                    style: TextStyle(
                      fontSize: score.contains('Worse') ? 13 : 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: context.textSecondary.withValues(alpha: 0.7),
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
  final double size;
  final double iconSize;

  const _DirectionButton({
    required this.direction,
    required this.onPressed,
    this.size = 64.0,
    this.iconSize = 28.0,
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.3),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size * 0.3),
          child: Center(
            child: Icon(_icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
