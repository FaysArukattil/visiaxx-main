import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visiaxx/core/utils/app_logger.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/features/quick_vision_test/screens/both_eyes_open_instruction_screen.dart';
import 'package:visiaxx/widgets/common/snellen_size_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/models/visiual_acuity_result.dart';
import '../../../data/providers/test_session_provider.dart';
import 'distance_calibration_screen.dart';
import 'cover_right_eye_instruction_screen.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Distance monitoring service
  final DistanceDetectionService _distanceService = DistanceDetectionService();

  // Test state
  int _currentLevel = 0;
  int _correctAtLevel = 0;
  int _incorrectAtLevel = 0;
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
  String? _lastDetectedSpeech;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = true; // Start as true to avoid blocking on init
  bool _useDistanceMonitoring = true; // Enabled for real-time distance display
  bool _isTestPausedForDistance = false; // Test is paused due to wrong distance
  DistanceStatus? _lastSpokenDistanceStatus; // Track last spoken guidance

  final Random _random = Random();

  // Pixels per mm for this device (calculated based on screen metrics)
  double _pixelsPerMm = 6.0;

  Timer? _autoNavigationTimer;
  int _autoNavigationCountdown = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle for camera
    if (state == AppLifecycleState.inactive) {
      _distanceService.stopMonitoring();
    } else if (state == AppLifecycleState.resumed &&
        !_showDistanceCalibration) {
      _startContinuousDistanceMonitoring();
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

    // Set up speech service callbacks
    _speechService.onResult = _handleVoiceResponse;
    _speechService.onSpeechDetected = _handleSpeechDetected;
    _speechService.onListeningStarted = () {
      if (mounted) setState(() => _isListening = true);
    };
    _speechService.onListeningStopped = () {
      if (mounted) setState(() => _isListening = false);
    };

    // 🔥 KEY FIX: Check if we should start with left eye
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
    if (mounted) {
      setState(() {
        _lastDetectedSpeech = partialResult;
      });
      // Show visual feedback that speech was detected
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
  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    final wasOk = _isDistanceOk;
    final wasPaused = _isTestPausedForDistance;

    // ✅ NEW: Check using centralized helper
    final newIsOk = DistanceHelper.isDistanceAcceptable(distance, 100.0);
    final shouldPause = DistanceHelper.shouldPauseTest(status);

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
      _isDistanceOk = newIsOk;
    });

    // ✅ AUTO PAUSE/RESUME logic for active test
    if (_showE && _waitingForResponse) {
      if (shouldPause && !_isTestPausedForDistance) {
        // Need to pause - distance wrong or no face
        _pauseTestForDistance();
      } else if (!shouldPause && _isTestPausedForDistance) {
        // Can resume - distance is now correct AND face detected
        _resumeTestAfterDistance();
      }
    }

    // Speak guidance only when paused and status changes
    if (_isTestPausedForDistance && status != _lastSpokenDistanceStatus) {
      _lastSpokenDistanceStatus = status;
      _speakDistanceGuidance(status);
    }
  }

  /// Speak distance guidance
  void _speakDistanceGuidance(DistanceStatus status) {
    switch (status) {
      case DistanceStatus.tooClose:
        _ttsService.speak('Move back, you are too close');
        break;
      case DistanceStatus.tooFar:
        _ttsService.speak('Move closer, you are too far');
        break;
      case DistanceStatus.optimal:
        _ttsService.speak('Good, distance is correct');
        break;
      case DistanceStatus.noFaceDetected:
        _ttsService.speak('Position your face in view');
        break;
    }
  }

  /// Pause the test due to incorrect distance
  void _pauseTestForDistance() {
    setState(() {
      _isTestPausedForDistance = true;
    });

    // Cancel the countdown timer (pause it)
    _eCountdownTimer?.cancel();
    _eDisplayTimer?.cancel();

    // Stop speech recognition temporarily
    _speechService.stopListening();

    // Announce the pause
    _ttsService.speak('Test paused. Please adjust your distance.');

    // Haptic feedback
    HapticFeedback.heavyImpact();
  }

  /// Resume the test after distance is corrected
  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;

    setState(() {
      _isTestPausedForDistance = false;
    });

    // Announce resume
    _ttsService.speak('Resuming test');

    // Restart the countdown timer with remaining time
    _restartEDisplayTimer();

    // Restart speech recognition with continuous retry
    _speechService.startListening(
      listenFor: Duration(seconds: _eDisplayCountdown + 1),
      bufferMs: 300,
      autoRestart: true, // CRITICAL: Keep listening and auto-retry
      minConfidence: 0.2, // LOWERED: Accept more results for reliability
    );

    // Haptic feedback
    HapticFeedback.mediumImpact();
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
        final lastValue = _speechService.finalizeWithLastValue();
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
    // Generate random direction
    final directions = EDirection.values;
    _currentDirection = directions[_random.nextInt(directions.length)];

    setState(() {
      _showRelaxation = false;
      _showE = true;
      _waitingForResponse = true;
      _lastDetectedSpeech = null;
      _eDisplayCountdown = TestConstants.eDisplayDurationSeconds;
    });

    _eDisplayStartTime = DateTime.now();

    // Start listening for voice input with continuous retry
    _speechService.startListening(
      listenFor: Duration(seconds: TestConstants.eDisplayDurationSeconds + 1),
      bufferMs: 300, // Short buffer for quick response
      autoRestart: true, // CRITICAL: Keep listening and auto-retry
      minConfidence: 0.2, // LOWERED: Accept more results for reliability
    );

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
          final lastValue = _speechService.finalizeWithLastValue();
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
    if (!_waitingForResponse) return;

    final direction = SpeechService.parseDirection(recognized);
    if (direction != null) {
      _recordResponse(direction);
    }
  }

  void _handleButtonResponse(EDirection direction) {
    if (!_waitingForResponse) return;
    _recordResponse(direction.label.toLowerCase());
  }

  void _recordResponse(String? userResponse) {
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _speechService.cancel(); // Use cancel() to fully stop auto-restart

    final responseTime = _eDisplayStartTime != null
        ? DateTime.now().difference(_eDisplayStartTime!).inMilliseconds
        : 0;

    final isCorrect =
        userResponse?.toLowerCase() == _currentDirection.label.toLowerCase();

    final record = EResponseRecord(
      level: _currentLevel,
      eSize: TestConstants.visualAcuityLevels[_currentLevel].sizeMm,
      expectedDirection: _currentDirection.label,
      userResponse: userResponse ?? 'No response',
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
      userSaid: userResponse ?? 'no response',
      correct: isCorrect,
    );
    _totalResponses++;

    // Voice confirmation feedback
    if (userResponse != null) {
      if (isCorrect) {
        _correctAtLevel++;
        _totalCorrect++;
        _ttsService.speakCorrect(userResponse);
      } else {
        _incorrectAtLevel++;
        _ttsService.speakIncorrect(userResponse);
      }
    } else {
      _incorrectAtLevel++;
    }

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

  void _playFeedbackSound(bool correct) async {
    // Simple beep feedback
    try {
      // Using system sounds would be ideal, but for now we'll rely on TTS
      if (correct) {
        _ttsService.speak('Correct');
      }
    } catch (_) {}
  }

  // ✅ FIXED METHOD: Test exactly 7 plates (one per level)
  void _evaluateAndContinue() {
    setState(() => _showResult = false);

    // ✅ CRITICAL FIX: Always test all 7 plates (one per level)
    // Stop ONLY after 7 total responses (one per Snellen level)
    if (_responses.length >= 7) {
      debugPrint('✅ [VisualAcuity] Completed 7 plates - finishing test');
      _completeEyeTest();
      return;
    }

    // After each response, move to NEXT level automatically
    _currentLevel++;
    _correctAtLevel = 0;
    _incorrectAtLevel = 0;

    if (_currentLevel >= TestConstants.visualAcuityLevels.length) {
      // Reached end of levels
      debugPrint('✅ [VisualAcuity] Reached last level - finishing');
      _completeEyeTest();
    } else {
      // Continue to next level
      debugPrint(
        '✅ [VisualAcuity] Moving to level ${_currentLevel + 1} (plate ${_responses.length + 1}/7)',
      );
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

  void _switchToLeftEye() {
    setState(() {
      _currentEye = 'left';
      _eyeSwitchPending = false;
      _currentLevel = 0;
      _correctAtLevel = 0;
      _incorrectAtLevel = 0;
      _totalCorrect = 0;
      _totalResponses = 0;
      _responses.clear();
    });

    final provider = context.read<TestSessionProvider>();
    provider.switchEye();

    _startEyeTest();
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
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _ttsService.dispose();
    _speechService.dispose();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable back navigation during test
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_testComplete) {
          // Show confirmation dialog
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          title: Text('Visual Acuity - ${_currentEye.toUpperCase()} Eye'),
          backgroundColor: _currentEye == 'right'
              ? AppColors.rightEye.withOpacity(0.1)
              : AppColors.leftEye.withOpacity(0.1),
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
        color: indicatorColor.withOpacity(0.15),
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
      color: Colors.black.withOpacity(0.85),
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
                    color: AppColors.error.withOpacity(0.1),
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
                  color: AppColors.success.withOpacity(0.1),
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
                  setState(() {
                    _isDistanceOk = true;
                    _isTestPausedForDistance = false;
                  });
                  _restartEDisplayTimer();
                  _speechService.startListening(
                    listenFor: Duration(seconds: _eDisplayCountdown + 1),
                    bufferMs: 300,
                    autoRestart: true,
                    minConfidence: 0.2,
                  );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main info row
          Row(
            children: [
              // Eye indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _currentEye == 'right'
                      ? AppColors.rightEye.withOpacity(0.1)
                      : AppColors.leftEye.withOpacity(0.1),
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
              const Spacer(),
              // Level indicator
              Text(
                'L${_currentLevel + 1}/${TestConstants.visualAcuityLevels.length}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 12),
              // Score
              Text(
                '$_totalCorrect/$_totalResponses',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          // Voice indicator - separate row to avoid overflow
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _lastDetectedSpeech ?? 'Listening...',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary.withOpacity(0.1),
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
          color: AppColors.surface.withOpacity(0.9),
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
                  color: AppColors.primary.withOpacity(0.15),
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
                textScaleFactor: 1.0,
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
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
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
                Text(
                  'Auto-continuing in $_autoNavigationCountdown second${_autoNavigationCountdown != 1 ? 's' : ''}...',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
        child: Container(
          width: 70,
          height: 70,
          child: Icon(_icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
