// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visiaxx/core/utils/app_logger.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/features/quick_vision_test/screens/both_eyes_open_instruction_screen.dart';
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
import '../../../core/services/distance_skip_manager.dart';

/// Visual Acuity Test using Tumbling E chart with distance monitoring
/// Implements Visiaxx specification for 1-meter testing
class VisualAcuityTestScreen extends StatefulWidget {
  const VisualAcuityTestScreen({super.key, this.startWithLeftEye = false});

  final bool startWithLeftEye;

  @override
  State<VisualAcuityTestScreen> createState() => _VisualAcuityTestScreenState();
}

class _VisualAcuityTestScreenState extends State<VisualAcuityTestScreen>
    with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  late final ContinuousSpeechManager _continuousSpeech;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Distance monitoring service
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final DistanceSkipManager _skipManager = DistanceSkipManager();

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
  DateTime? _eDisplayStartTime;
  int _eDisplayCountdown = 5; // 5 seconds per E as per user requirement
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

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  final bool _useDistanceMonitoring =
      true; // Enabled for real-time distance display
  bool _isTestPausedForDistance = false; // Test is paused due to wrong distance

  final Random _random = Random();

  // Pixels per mm for this device (calculated based on screen metrics)
  double _pixelsPerMm = 6.0;

  Timer? _autoNavigationTimer;
  int _autoNavigationCountdown = 3;

  Timer? _speechEraserTimer; // ✅ Timer to clear recognized text

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    setState(() {
      _isTestPausedForDistance = true;
    });
  }

  void _handleAppResumed() {
    if (!mounted || _testComplete || _showDistanceCalibration) return;

    // Show resume dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_testComplete && !_showDistanceCalibration) {
        _showResumeDialog();
      }
    });
  }

  void _showResumeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.pause_circle_outline,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Test Paused',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The test was paused because the app was minimized.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'Would you like to continue?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Exit Test'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeAfterPause();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue Test'),
          ),
        ],
      ),
    );
  }

  void _resumeAfterPause() {
    setState(() {
      _isTestPausedForDistance = false;
    });

    // Resume distance monitoring if needed
    if (!_showDistanceCalibration) {
      _startContinuousDistanceMonitoring();
    }

    // Resume speech recognition
    if (_showE && _waitingForResponse) {
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.05,
        bufferMs: 300,
      );

      // Restart the display timer with remaining time
      _restartEDisplayTimer();
    } else if (_showRelaxation) {
      // Resume relaxation timer
      _startRelaxation();
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
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    // Initialize continuous speech manager
    _continuousSpeech = ContinuousSpeechManager(_speechService);
    _continuousSpeech.onFinalResult = _handleVoiceResponse;
    _continuousSpeech.onSpeechDetected = _handleSpeechDetected;
    _continuousSpeech.onListeningStateChanged = (isListening) {
      if (mounted) setState(() => _isListening = isListening);
    };

    // DON'T pause speech for TTS - let it run continuously

    // 🔥 KEY FIX: Check if we should start with left eye
    if (!mounted) return;
    final provider = context.read<TestSessionProvider>();

    if (widget.startWithLeftEye ||
        (provider.currentEye == 'left' && provider.visualAcuityRight != null)) {
      // We're starting/resuming left eye - NO calibration needed
      debugPrint(
        '🔥 [VisualAcuity] Starting LEFT EYE test - skipping calibration',
      );
      _showDistanceCalibration = false;
      _currentEye = 'left';
      provider.switchEye();

      // 🔥 KEY: Resume continuous distance monitoring without recalibration
      await _startContinuousDistanceMonitoring();

      // Start test immediately
      _startEyeTest();
      return;
    }

    // First time (right eye) - show calibration
    debugPrint(
      '🔥 [VisualAcuity] Starting RIGHT EYE test - showing calibration',
    );
    if (_useDistanceMonitoring && _showDistanceCalibration) {
      // Wait for build to complete, then show calibration screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCalibrationScreen();
      });
    } else {
      // Skip distance calibration and start directly
      _showDistanceCalibration = false;
      _startEyeTest();
    }
  }

  /// Shows the distance calibration screen as a full-screen overlay
  void _showCalibrationScreen() {
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
    debugPrint('[VisualAcuity] 🎤 Speech detected: "$partialResult"');
    if (mounted) {
      setState(() {
        _lastDetectedSpeech = partialResult;
        _isSpeechActive = true;
      });

      // ✅ Make waveform responsive for 500ms
      _speechActiveTimer?.cancel();
      _speechActiveTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isSpeechActive = false);
      });

      // ✅ Auto-erase recognized text after 2.5 seconds
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
    });
    // Start continuous distance monitoring after calibration
    _startContinuousDistanceMonitoring();
    _startEyeTest();
  }

  /// Start continuous distance monitoring during the test
  Future<void> _startContinuousDistanceMonitoring() async {
    if (!_useDistanceMonitoring) return;

    debugPrint('🔥 [DistanceMonitor] Starting/Resuming distance monitoring');

    // Set up distance update callback
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    _distanceService.onError = (msg) => debugPrint('[DistanceMonitor] $msg');

    // Initialize and start camera if not already running
    if (!_distanceService.isReady) {
      debugPrint('🔥 [DistanceMonitor] Initializing camera');
      await _distanceService.initializeCamera();
    } else {
      debugPrint('🔥 [DistanceMonitor] Camera already initialized, reusing');
    }

    if (!_distanceService.isMonitoring) {
      debugPrint('🔥 [DistanceMonitor] Starting monitoring');
      await _distanceService.startMonitoring();
    } else {
      debugPrint('🔥 [DistanceMonitor] Monitoring already active');
    }
  }

  /// Handle real-time distance updates
  /// Handle real-time distance updates with auto pause/resume
  DateTime? _lastShouldPauseTime;
  static const Duration _distancePauseDebounce = Duration(milliseconds: 1000);

  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      'visual_acuity',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
    });

    // ✅ AUTO PAUSE/RESUME logic with DEBOUNCING
    if (_showE && _waitingForResponse) {
      if (shouldPause) {
        _lastShouldPauseTime ??= DateTime.now();
        final durationSinceFirstIssue = DateTime.now().difference(
          _lastShouldPauseTime!,
        );

        if (durationSinceFirstIssue >= _distancePauseDebounce &&
            !_isTestPausedForDistance) {
          _skipManager
              .canShowDistanceWarning(DistanceTestType.visualAcuity)
              .then((canShow) {
                if (mounted && canShow) {
                  _pauseTestForDistance();
                }
              });
        }
      } else {
        _lastShouldPauseTime = null;
        if (_isTestPausedForDistance) {
          _resumeTestAfterDistance();
        }
      }
    }
  }

  /// Pause the test due to incorrect distance
  void _pauseTestForDistance() {
    setState(() {
      _isTestPausedForDistance = true;
    });

    // Cancel timers
    _eCountdownTimer?.cancel();
    _eDisplayTimer?.cancel();

    // 🔥 NO verbal "Test Paused" here - visual overlay is sufficient
    // This allows the user's voice to be heard even if they are slightly too close
    HapticFeedback.mediumImpact();
  }

  /// Resume the test after distance is corrected
  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;

    setState(() {
      _isTestPausedForDistance = false;
      _lastShouldPauseTime = null;
    });

    // 🔥 No verbal "Resuming" here either

    // Restart the countdown timer with remaining time
    if (_showE && _waitingForResponse) {
      _restartEDisplayTimer();
    }
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

    // Restart main display timer
    _eDisplayTimer = Timer(Duration(seconds: _eDisplayCountdown), () {
      if (_waitingForResponse && !_isTestPausedForDistance) {
        final lastValue = _continuousSpeech.getLastRecognized();
        if (lastValue != null) {
          final direction = SpeechService.parseDirection(lastValue);
          _recordResponse(direction);
        } else {
          _recordResponse(null);
        }
      }
    });
  }

  void _startEyeTest() {
    _ttsService.speakEyeInstruction(_currentEye);

    // Wait a moment then start
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _startRelaxation();
      }
    });
  }

  void _startRelaxation() {
    setState(() {
      _showRelaxation = true;
      _showE = false;
      _relaxationCountdown = TestConstants.relaxationDurationSeconds;
    });

    _ttsService.speak(TtsService.relaxationInstruction);

    _relaxationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _relaxationCountdown--;
      });

      if (_relaxationCountdown <= 3 && _relaxationCountdown > 0) {
        _ttsService.speakCountdown(_relaxationCountdown);
      }

      if (_relaxationCountdown <= 0) {
        timer.cancel();
        _showTumblingE();
      }
    });
  }

  void _showTumblingE() {
    final directions = EDirection.values
        .where((d) => d != _currentDirection)
        .toList();
    _currentDirection = directions[_random.nextInt(directions.length)];

    setState(() {
      _showRelaxation = false;
      _showE = true;
      _waitingForResponse = true;
      _lastDetectedSpeech = null; // ✅ Reset recognized text for new level
      _eDisplayCountdown = TestConstants.eDisplayDurationSeconds;
    });

    _eDisplayStartTime = DateTime.now();

    // Start continuous speech recognition if not already running
    if (!_continuousSpeech.isActive) {
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.05,
        bufferMs: 300,
      );
    }

    // Start countdown timer for display
    _eCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
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
      Duration(seconds: TestConstants.eDisplayDurationSeconds),
      () {
        if (_waitingForResponse) {
          // Use last recognized value if available
          final lastValue = _continuousSpeech.getLastRecognized();
          if (lastValue != null) {
            final direction = SpeechService.parseDirection(lastValue);
            _recordResponse(direction);
          } else {
            _recordResponse(null); // No response
          }
        }
      },
    );
  }

  void _handleVoiceResponse(String recognized) {
    debugPrint(
      '[VisualAcuity] 🔥🔥🔥 _handleVoiceResponse called with: "$recognized"',
    );
    debugPrint('[VisualAcuity] Waiting for response: $_waitingForResponse');

    if (!_waitingForResponse) {
      debugPrint('[VisualAcuity] ⚠️ NOT waiting for response - ignoring');
      return;
    }

    debugPrint('[VisualAcuity] 🔍 Parsing direction from: "$recognized"');
    final direction = SpeechService.parseDirection(recognized);
    debugPrint('[VisualAcuity] 📝 Parsed direction: $direction');

    if (direction != null) {
      debugPrint('[VisualAcuity] ✅ Recording direction: $direction');
      _recordResponse(direction);
    } else {
      debugPrint('[VisualAcuity] ❌ Direction is NULL - not recording');
    }
  }

  void _handleButtonResponse(EDirection direction) {
    if (!_waitingForResponse) return;
    _recordResponse(direction.label.toLowerCase());
  }

  void _recordResponse(String? userResponse) {
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _continuousSpeech.stop(); // ✅ Stop listening immediately after response

    // ✅ HANDLE NO RESPONSE: Rotate E in SAME size and try again
    if (userResponse == null) {
      debugPrint(
        '[VisualAcuity] Timeout - Rotating E (staying at level $_currentLevel)',
      );
      // Give a tiny delay for the user to see the "I didn't hear you" state if we had one
      // But user wants it integrated, so we just rotate.
      _showTumblingE(); // Direct rotation without changing size
      return;
    }

    // Reset distance pause if we were paused but got a response
    _isTestPausedForDistance = false;

    final responseTime = _eDisplayStartTime != null
        ? DateTime.now().difference(_eDisplayStartTime!).inMilliseconds
        : 0;

    final isCorrect =
        userResponse.toLowerCase() == _currentDirection.label.toLowerCase();

    final record = EResponseRecord(
      level: _currentLevel,
      eSize: TestConstants.visualAcuityLevels[_currentLevel].sizeMm,
      expectedDirection: _currentDirection.label,
      userResponse: userResponse,
      isCorrect: isCorrect,
      responseTimeMs: responseTime,
    );

    _responses.add(record);
    AppLogger.logLongDistance(
      eye: _currentEye.toUpperCase(),
      plateNumber: _responses.length,
      snellen: TestConstants.visualAcuityLevels[_currentLevel].snellen,
      fontSize: TestConstants.visualAcuityLevels[_currentLevel].flutterFontSize,
      expected: _currentDirection.label.toLowerCase(),
      userSaid: userResponse,
      correct: isCorrect,
    );
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

    // Show result briefly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _evaluateAndContinue();
    });
  }

  // Helper counter for incorrect responses
  int _incorrectCounterAtLevel = 0;

  // ✅ FIXED METHOD: Test exactly 7 plates (one per level)
  void _evaluateAndContinue() {
    setState(() => _showResult = false);

    // ✅ ALWAYS move to next level after any response (correct or incorrect)
    // As per user requirement: "once i get one size once should n't ask again in the same size"
    _currentLevel++;
    _correctAtLevel = 0;
    _totalAtLevel = 0;
    _incorrectCounterAtLevel = 0;

    if (_currentLevel >= TestConstants.visualAcuityLevels.length) {
      debugPrint('✅ [VisualAcuity] Finished all levels');
      _completeEyeTest();
    } else {
      debugPrint('✅ [VisualAcuity] Moving to next level: $_currentLevel');
      _startRelaxation();
    }
  }

  void _completeEyeTest() {
    // Calculate final score
    final level = _currentLevel > 0 ? _currentLevel - 1 : 0;
    final vaLevel = TestConstants.visualAcuityLevels[level];

    String status;
    if (vaLevel.logMAR <= 0.0) {
      status = 'Normal';
    } else if (vaLevel.logMAR <= 0.3) {
      status = 'Mild reduction';
    } else {
      status = 'Significant reduction';
    }

    final result = VisualAcuityResult(
      eye: _currentEye,
      snellenScore: vaLevel.snellen,
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
        _autoNavigationCountdown = 3; // Reset countdown
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
    // Stop distance monitoring before navigating
    _distanceService.stopMonitoring();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const BothEyesOpenInstructionScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _speechEraserTimer?.cancel();
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _autoNavigationTimer?.cancel();
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
    return PopScope(
      canPop: true, // Allow back navigation
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Clean up when going back
          _continuousSpeech.stop();
          _distanceService.stopMonitoring();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          title: Text('Visual Acuity - ${_currentEye.toUpperCase()} Eye'),
          backgroundColor: _currentEye == 'right'
              ? AppColors.rightEye.withValues(alpha: 0.1)
              : AppColors.leftEye.withValues(alpha: 0.1),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main test content
              Column(
                children: [
                  // Progress and info bar
                  _buildInfoBar(),

                  // Main content
                  Expanded(child: _buildMainContent()),

                  // Direction buttons (when showing E)
                  if (_showE && _waitingForResponse) _buildDirectionButtons(),
                ],
              ),

              // Distance indicator (bottom right corner)
              if (_useDistanceMonitoring && !_showDistanceCalibration)
                Positioned(
                  right: 12,
                  bottom: _showE && _waitingForResponse ? 120 : 12,
                  child: _buildDistanceIndicator(),
                ),

              // Recognized text (bottom center)
              if (_showE || _showRelaxation)
                Positioned(
                  bottom: _showE && _waitingForResponse ? 150 : 50,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildRecognizedTextIndicator()),
                ),
              // Distance warning overlay when explicitly paused
              if (_useDistanceMonitoring && _isTestPausedForDistance && _showE)
                _buildDistanceWarningOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      100.0,
    );
    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'No face';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: indicatorColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.straighten, size: 14, color: indicatorColor),
          const SizedBox(width: 4),
          Text(
            distanceText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: indicatorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceWarningOverlay() {
    // ✅ Dynamic messages based on status
    final pauseReason = DistanceHelper.getPauseReason(_distanceStatus, 100.0);
    final instruction = DistanceHelper.getDetailedInstruction(100.0);
    final rangeText = DistanceHelper.getAcceptableRangeText(100.0);

    // ✅ Icon changes based on issue
    final icon = _distanceStatus == DistanceStatus.noFaceDetected
        ? Icons.face_retouching_off
        : Icons.warning_rounded;

    final iconColor = _distanceStatus == DistanceStatus.noFaceDetected
        ? AppColors.error
        : AppColors.warning;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 60, color: iconColor),
              const SizedBox(height: 16),
              Text(
                pauseReason, // ✅ Dynamic title
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                instruction, // ✅ Dynamic instruction
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // ✅ Only show distance if face is detected
              if (_distanceStatus != DistanceStatus.noFaceDetected) ...[
                Text(
                  _currentDistance > 0
                      ? 'Current: ${_currentDistance.toStringAsFixed(0)}cm'
                      : 'Measuring...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  rangeText, // ✅ Dynamic range text
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                // ✅ Special message when no face
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Position your face in the camera',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ✅ Voice indicator (always show it's listening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Voice recognition active',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Skip button
              TextButton(
                onPressed: () {
                  _skipManager.recordSkip(DistanceTestType.visualAcuity);
                  setState(() {
                    _isTestPausedForDistance = false;
                  });

                  _restartEDisplayTimer();
                },
                child: Text(
                  'Continue Anyway',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          // Eye indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _currentEye == 'right'
                  ? AppColors.rightEye.withValues(alpha: 0.1)
                  : AppColors.leftEye.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility,
                  size: 14,
                  color: _currentEye == 'right'
                      ? AppColors.rightEye
                      : AppColors.leftEye,
                ),
                const SizedBox(width: 4),
                Text(
                  _currentEye.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _currentEye == 'right'
                        ? AppColors.rightEye
                        : AppColors.leftEye,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Level indicator (repositioned to left)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_currentEye[0].toUpperCase()}${_currentLevel + 1}/${TestConstants.visualAcuityLevels.length}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Score indicator (pill style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '$_totalCorrect/$_totalResponses',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          // Speech waveform (always visible, animates when listening)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SpeechWaveform(
                  isListening: _isListening,
                  isTalking: _isSpeechActive,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Icon(Icons.mic, size: 14, color: AppColors.success),
              ],
            ),
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
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _lastDetectedSpeech!,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMainContent() {
    if (_testComplete) {
      return _buildTestCompleteView();
    }

    if (_eyeSwitchPending) {
      return _buildEyeSwitchView();
    }

    if (_showDistanceCalibration) {
      return _buildDistanceCalibrationView();
    }

    if (_showRelaxation) {
      return _buildRelaxationView();
    }

    if (_showE) {
      return _buildEView();
    }

    if (_showResult) {
      return _buildResultFeedback();
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildDistanceCalibrationView() {
    // This view is shown briefly while navigating to the calibration screen
    // The actual calibration happens in DistanceCalibrationScreen
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Opening Distance Calibration...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Relaxation image
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              AppAssets.relaxationImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primary.withValues(alpha: 0.1),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.landscape, size: 80, color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Focus on the distance...',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Countdown
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Relax and focus on the distance',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: Center(
                  child: Text(
                    '$_relaxationCountdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ FIX #1: In visual_acuity_test_screen.dart
  // FIND the _buildEView() method and REPLACE with this:

  Widget _buildEView() {
    final level = TestConstants.visualAcuityLevels[_currentLevel];
    final eSize = level.flutterFontSize;

    return Column(
      children: [
        // Timer and Size indicator row - ALWAYS VISIBLE
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.surface.withValues(alpha: 0.9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ PROMINENT Size indicator on LEFT
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      level.snellen,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Timer on RIGHT
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 20,
                    color: _eDisplayCountdown <= 1
                        ? AppColors.error
                        : _isTestPausedForDistance
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTestPausedForDistance
                        ? 'PAUSED'
                        : '${_eDisplayCountdown}s',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _eDisplayCountdown <= 1
                          ? AppColors.error
                          : _isTestPausedForDistance
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Main E display area
        Expanded(
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

                  color: Colors.black,
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isListening)
                    Icon(
                      Icons.mic,
                      size: 20,
                      color: _isTestPausedForDistance
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  if (_isListening) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _isTestPausedForDistance
                          ? 'Test paused - Adjust distance'
                          : 'Which way is the E pointing?',
                      style: TextStyle(
                        color: _isTestPausedForDistance
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: _isTestPausedForDistance
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isTestPausedForDistance
                    ? 'Voice recognition active - waiting to resume'
                    : 'Use buttons or say: Upper or Upward, Down or Downward, Left, Right',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
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
              const SizedBox(width: 60),
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
        ],
      ),
    );
  }

  Widget _buildResultFeedback() {
    final lastResponse = _responses.isNotEmpty ? _responses.last : null;
    final isCorrect = lastResponse?.isCorrect ?? false;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 100,
            color: isCorrect ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? 'Correct!' : 'Incorrect',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isCorrect ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeSwitchView() {
    // Navigate to instruction screen - only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_eyeSwitchPending && mounted) {
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
          const CircularProgressIndicator(),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          Text(
            'Visual Acuity Test Complete!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Summary cards
          _buildSummaryCard(
            'Right Eye',
            context
                    .read<TestSessionProvider>()
                    .visualAcuityRight
                    ?.snellenScore ??
                'N/A',
            AppColors.rightEye,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Left Eye',
            context
                    .read<TestSessionProvider>()
                    .visualAcuityLeft
                    ?.snellenScore ??
                'N/A',
            AppColors.leftEye,
          ),
          const SizedBox(height: 32),

          // Auto-continue countdown indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: Center(
                    child: Text(
                      '$_autoNavigationCountdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Continuing in $_autoNavigationCountdown...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Continue button (now can be clicked immediately or wait for auto)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _autoNavigationTimer?.cancel();
                _proceedToBothEyesTest();
              },
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Continue Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String eye, String score, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.visibility, color: color),
              const SizedBox(width: 12),
              Text(
                eye,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          Text(
            score,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final EDirection direction;
  final VoidCallback onPressed;

  const _DirectionButton({required this.direction, required this.onPressed});

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 70,
          height: 70,
          child: Icon(_icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

// ✅ NEW Waveform animation for microphone
class _SpeechWaveform extends StatefulWidget {
  final bool isListening;
  final bool isTalking; // NEW
  final Color color;

  const _SpeechWaveform({
    required this.isListening,
    this.isTalking = false, // NEW
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
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final double baseHeight = 5.0;
            final double activeHeight = widget.isTalking ? 18.0 : 12.0;

            final double height = widget.isListening
                ? baseHeight +
                      activeHeight *
                          sin(
                            (_controller.value * 2 * pi) + (index * 0.8),
                          ).abs()
                : baseHeight;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 2.5,
              height: height,
              decoration: BoxDecoration(
                color: widget.color.withValues(
                  alpha: widget.isListening ? 0.8 : 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
