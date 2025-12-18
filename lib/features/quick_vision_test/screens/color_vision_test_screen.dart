import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/constants/ishihara_plate_data.dart';
import 'package:visiaxx/features/quick_vision_test/screens/color_vision_cover_eye_screen';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/continuous_speech_manager.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../core/utils/distance_helper.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../widgets/ishihara_plate_viewer.dart';
import 'distance_calibration_screen.dart';
import 'color_vision_instructions_screen.dart';

/// Clinical-grade Color Vision Test
/// Tests BOTH eyes separately with 14 Ishihara plates each
class ColorVisionTestScreen extends StatefulWidget {
  const ColorVisionTestScreen({super.key});

  @override
  State<ColorVisionTestScreen> createState() => _ColorVisionTestScreenState();
}

class _ColorVisionTestScreenState extends State<ColorVisionTestScreen>
    with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  late final ContinuousSpeechManager _continuousSpeech;
  final DistanceDetectionService _distanceService = DistanceDetectionService(
    targetDistanceCm: 40.0,
    toleranceCm: 5.0,
  );
  final TextEditingController _answerController = TextEditingController();

  // Test configuration from IshiharaPlateData
  late List<IshiharaPlateConfig> _testPlates;

  // Test state
  TestPhase _phase = TestPhase.initialInstructions;
  String _currentEye = 'right'; // 'right' or 'left'
  int _currentPlateIndex = 0;
  final List<PlateResponse> _rightEyeResponses = [];
  final List<PlateResponse> _leftEyeResponses = [];

  bool _showingPlate = false;
  bool _isListening = false;
  String? _lastDetectedSpeech;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = true;
  bool _isTestPausedForDistance = false;
  bool _userDismissedDistanceWarning = false;
  Timer? _distanceAutoSkipTimer;
  Timer? _distanceWarningReenableTimer;

  // Timer
  Timer? _plateTimer;
  int _timeRemaining = TestConstants.colorVisionTimePerPlateSeconds;
  DateTime? _plateStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _testPlates = IshiharaPlateData.getTestPlates();
    _initServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  void _handleAppPaused() {
    // Pause test timer
    _plateTimer?.cancel();

    // Stop distance monitoring
    _distanceService.stopMonitoring();

    // Stop speech recognition
    _continuousSpeech.stop();

    setState(() {
      _isTestPausedForDistance = true;
    });
  }

  void _handleAppResumed() {
    if (!mounted || _phase == TestPhase.complete) return;

    // Show resume dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _phase != TestPhase.complete) {
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

    // Resume distance monitoring
    _startContinuousDistanceMonitoring();

    // Resume speech recognition
    if (_showingPlate) {
      _startContinuousSpeechRecognition();

      // Restart the plate timer with remaining time
      _restartPlateTimer();
    }
  }

  void _restartPlateTimer() {
    if (_timeRemaining <= 0) {
      _submitAnswer('');
      return;
    }

    _plateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) {
        timer.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        timer.cancel();
        _submitAnswer('');
      }
    });
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    // Initialize continuous speech manager
    _continuousSpeech = ContinuousSpeechManager(_speechService);
    _continuousSpeech.onFinalResult = _handleVoiceResponse;
    _continuousSpeech.onSpeechDetected = (text) {
      if (mounted) setState(() => _lastDetectedSpeech = text);
    };
    _continuousSpeech.onListeningStateChanged = (isListening) {
      if (mounted) setState(() => _isListening = isListening);
    };

    // DON'T pause speech for TTS - let it run continuously

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialInstructions();
    });
  }

  void _showInitialInstructions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ColorVisionInstructionsScreen(
          onContinue: () {
            Navigator.of(context).pop();
            _showCalibrationScreen();
          },
        ),
      ),
    );
  }

  void _showCalibrationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: 40.0,
          toleranceCm: 5.0,
          onCalibrationComplete: () {
            Navigator.of(context).pop();
            _onCalibrationComplete();
          },
          onSkip: () {
            Navigator.of(context).pop();
            _onCalibrationComplete();
          },
        ),
      ),
    );
  }

  void _onCalibrationComplete() {
    setState(() => _phase = TestPhase.rightEyeInstruction);
    _startContinuousDistanceMonitoring();
    _showRightEyeInstruction();
  }

  void _showRightEyeInstruction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ColorVisionCoverEyeScreen(
          eyeToCover: 'left',
          onContinue: () {
            Navigator.of(context).pop();
            setState(() {
              _phase = TestPhase.rightEyeTest;
              _currentEye = 'right';
              _currentPlateIndex = 0;
            });
            _startEyeTest();
          },
        ),
      ),
    );
  }

  void _showLeftEyeInstruction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ColorVisionCoverEyeScreen(
          eyeToCover: 'right',

          onContinue: () {
            Navigator.of(context).pop();
            setState(() {
              _phase = TestPhase.leftEyeTest;
              _currentEye = 'left';
              _currentPlateIndex = 0;
            });
            _startEyeTest();
          },
        ),
      ),
    );
  }

  Future<void> _startContinuousDistanceMonitoring() async {
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    if (!_distanceService.isReady) {
      await _distanceService.initializeCamera();
    }
    if (!_distanceService.isMonitoring) {
      await _distanceService.startMonitoring();
    }
  }

  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    final newIsOk = DistanceHelper.isDistanceAcceptable(distance, 40.0);

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
      _isDistanceOk = newIsOk;
    });

    // Auto-pause if distance is wrong (only if user hasn't dismissed)
    if (!_isDistanceOk &&
        !_isTestPausedForDistance &&
        !_userDismissedDistanceWarning) {
      _pauseTestForDistance();
    } else if (_isDistanceOk && _isTestPausedForDistance) {
      _resumeTestAfterDistance();
    }
  }

  void _pauseTestForDistance() {
    setState(() => _isTestPausedForDistance = true);
    _plateTimer?.cancel();
    // Keep speech recognition running even when paused
    _ttsService.speak(
      'Test paused. Please adjust your distance to 40 centimeters.',
    );
    HapticFeedback.heavyImpact();

    _distanceAutoSkipTimer?.cancel();
    _distanceAutoSkipTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isTestPausedForDistance) {
        _forceSkipDistanceCheck();
      }
    });
  }

  void _forceSkipDistanceCheck() {
    _distanceAutoSkipTimer?.cancel();
    setState(() => _isTestPausedForDistance = false);
    _ttsService.speak('Resuming test');
    _restartPlateTimer();
    // Speech recognition is already running continuously
  }

  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;
    _distanceAutoSkipTimer?.cancel();
    setState(() => _isTestPausedForDistance = false);
    _ttsService.speak('Resuming test');
    _restartPlateTimer();
    // Speech recognition is already running continuously
    HapticFeedback.mediumImpact();
  }

  // Navigation through test phases
  // void _showRightEyeInstruction() {
  //   Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (context) => CoverLeftEyeInstructionScreen(
  //         onContinue: () {
  //           Navigator.of(context).pop();
  //           setState(() {
  //             _phase = TestPhase.rightEyeTest;
  //             _currentEye = 'right';
  //             _currentPlateIndex = 0;
  //           });
  //           _startEyeTest();
  //         },
  //       ),
  //     ),
  //   );
  // }

  // void _showLeftEyeInstruction() {
  //   Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (context) => CoverRightEyeInstructionScreen(
  //         onContinue: () {
  //           Navigator.of(context).pop();
  //           setState(() {
  //             _phase = TestPhase.leftEyeTest;
  //             _currentEye = 'left';
  //             _currentPlateIndex = 0;
  //           });
  //           _startEyeTest();
  //         },
  //       ),
  //     ),
  //   );
  // }

  void _startEyeTest() {
    // Start continuous speech recognition for the entire eye test
    _startContinuousSpeechRecognition();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showNextPlate();
    });
  }

  void _startContinuousSpeechRecognition() {
    debugPrint(
      '[ColorVision] Starting ULTRA-RELIABLE continuous speech recognition',
    );
    _continuousSpeech.start(
      listenDuration: const Duration(minutes: 10), // Long duration
      minConfidence: 0.05, // EXTREMELY permissive
      bufferMs: 800, // Fast response
    );
  }

  void _showNextPlate() {
    if (_currentPlateIndex >= _testPlates.length) {
      _onEyeTestComplete();
      return;
    }

    _lastDetectedSpeech = null;
    _answerController.clear();
    _plateStartTime = DateTime.now();

    setState(() {
      _showingPlate = true;
      _timeRemaining = TestConstants.colorVisionTimePerPlateSeconds;
    });

    final plate = _testPlates[_currentPlateIndex];
    if (plate.isDemo) {
      _ttsService.speak(
        'Demo plate. This is plate ${plate.plateNumber}. What number do you see?',
      );
    } else {
      _ttsService.speak('What number do you see?');
    }

    // Speech recognition is already running continuously, no need to restart

    _plateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) {
        timer.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        timer.cancel();
        _submitAnswer('');
      }
    });
  }

  void _handleVoiceResponse(String recognized) {
    debugPrint(
      '[ColorVision] 🔥🔥🔥 _handleVoiceResponse called with: "$recognized"',
    );
    debugPrint('[ColorVision] Current plate index: $_currentPlateIndex');
    debugPrint('[ColorVision] Showing plate: $_showingPlate');

    debugPrint('[ColorVision] 🔍 Parsing number from: "$recognized"');
    final number = SpeechService.parseNumber(recognized);
    debugPrint('[ColorVision] 📝 Parsed number: $number');

    if (number != null) {
      debugPrint('[ColorVision] ✅ Setting answer to: $number');
      _answerController.text = number;
      _submitAnswer(number);
    } else {
      debugPrint('[ColorVision] ❌ Number is NULL - not submitting');
    }
  }

  void _submitAnswer(String answer) {
    _plateTimer?.cancel();
    // Don't stop speech recognition - it continues throughout the test

    final plate = _testPlates[_currentPlateIndex];
    final responseTime = _plateStartTime != null
        ? DateTime.now().difference(_plateStartTime!).inMilliseconds
        : 0;

    // Check if answer is correct
    final isCorrect = _checkAnswer(answer.trim(), plate);

    final response = PlateResponse(
      plateNumber: plate.plateNumber,
      category: plate.category.name,
      normalExpectedAnswer: plate.normalAnswer,
      userAnswer: answer.isEmpty ? 'No response' : answer,
      isCorrect: isCorrect,
      responseTimeMs: responseTime,
      wasDemo: plate.isDemo,
    );

    // Store in appropriate eye's responses
    if (_currentEye == 'right') {
      _rightEyeResponses.add(response);
    } else {
      _leftEyeResponses.add(response);
    }

    // Show brief feedback
    setState(() => _showingPlate = false);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _currentPlateIndex++);

      if (_currentPlateIndex < _testPlates.length) {
        _showNextPlate();
      } else {
        _onEyeTestComplete();
      }
    });
  }

  bool _checkAnswer(String answer, IshiharaPlateConfig plate) {
    if (answer.isEmpty) return false;

    // Normalize answers
    final normalized = answer.replaceAll(' ', '').toLowerCase();
    final expected = plate.normalAnswer.replaceAll(' ', '').toLowerCase();

    // Check for 'x' or 'nothing' for hidden plates
    if (normalized == 'x' || normalized == 'nothing' || normalized == 'none') {
      return expected == 'x';
    }

    return normalized == expected;
  }

  void _onEyeTestComplete() {
    // Stop continuous speech recognition when eye test is complete
    _continuousSpeech.stop();

    if (_currentEye == 'right') {
      // Right eye done, move to left eye
      _ttsService.speak(
        'Right eye test complete. Now we will test your left eye.',
      );
      setState(() => _phase = TestPhase.leftEyeInstruction);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _showLeftEyeInstruction();
        }
      });
    } else {
      // Both eyes done
      _completeTest();
    }
  }

  void _completeTest() {
    setState(() => _phase = TestPhase.complete);

    // Analyze results for both eyes
    final rightEyeResult = _analyzeEyeResult(_rightEyeResponses, 'right');
    final leftEyeResult = _analyzeEyeResult(_leftEyeResponses, 'left');

    // Determine overall status
    final overallStatus = _determineOverallStatus(
      rightEyeResult,
      leftEyeResult,
    );
    final deficiencyType = _determineDeficiencyType(
      rightEyeResult,
      leftEyeResult,
    );
    final severity = _determineSeverity(rightEyeResult, leftEyeResult);
    final recommendation = _generateRecommendation(
      overallStatus,
      deficiencyType,
      severity,
    );

    final result = ColorVisionResult(
      rightEye: rightEyeResult,
      leftEye: leftEyeResult,
      overallStatus: overallStatus,
      deficiencyType: deficiencyType,
      severity: severity,
      recommendation: recommendation,
      timestamp: DateTime.now(),
      totalDurationSeconds: 0, // Calculate if needed
    );

    context.read<TestSessionProvider>().setColorVisionResult(result);
    _ttsService.speak('Color vision test complete.');
  }

  ColorVisionEyeResult _analyzeEyeResult(
    List<PlateResponse> responses,
    String eye,
  ) {
    final diagnosticResponses = responses.where((r) => !r.wasDemo).toList();
    final correctAnswers = diagnosticResponses.where((r) => r.isCorrect).length;
    final totalDiagnostic = diagnosticResponses.length;

    ColorVisionStatus status;
    if (correctAnswers >= 12) {
      status = ColorVisionStatus.normal;
    } else if (correctAnswers >= 9) {
      status = ColorVisionStatus.mild;
    } else if (correctAnswers >= 6) {
      status = ColorVisionStatus.moderate;
    } else {
      status = ColorVisionStatus.severe;
    }

    return ColorVisionEyeResult(
      eye: eye,
      correctAnswers: correctAnswers,
      totalDiagnosticPlates: totalDiagnostic,
      responses: responses,
      status: status,
      detectedType: status != ColorVisionStatus.normal
          ? DeficiencyType.redGreenDeficiency
          : null,
    );
  }

  ColorVisionStatus _determineOverallStatus(
    ColorVisionEyeResult right,
    ColorVisionEyeResult left,
  ) {
    final statuses = [right.status, left.status];
    if (statuses.contains(ColorVisionStatus.severe))
      return ColorVisionStatus.severe;
    if (statuses.contains(ColorVisionStatus.moderate))
      return ColorVisionStatus.moderate;
    if (statuses.contains(ColorVisionStatus.mild))
      return ColorVisionStatus.mild;
    return ColorVisionStatus.normal;
  }

  DeficiencyType _determineDeficiencyType(
    ColorVisionEyeResult right,
    ColorVisionEyeResult left,
  ) {
    if (right.status == ColorVisionStatus.normal &&
        left.status == ColorVisionStatus.normal) {
      return DeficiencyType.none;
    }
    // For now, return generic red-green deficiency
    // Advanced classification would analyze specific plate patterns
    return DeficiencyType.redGreenDeficiency;
  }

  DeficiencySeverity _determineSeverity(
    ColorVisionEyeResult right,
    ColorVisionEyeResult left,
  ) {
    final worstStatus = _determineOverallStatus(right, left);
    switch (worstStatus) {
      case ColorVisionStatus.normal:
        return DeficiencySeverity.none;
      case ColorVisionStatus.mild:
        return DeficiencySeverity.mild;
      case ColorVisionStatus.moderate:
        return DeficiencySeverity.moderate;
      case ColorVisionStatus.severe:
        return DeficiencySeverity.severe;
    }
  }

  String _generateRecommendation(
    ColorVisionStatus status,
    DeficiencyType type,
    DeficiencySeverity severity,
  ) {
    if (status == ColorVisionStatus.normal) {
      return 'Your color vision appears normal. No action needed.';
    }
    return 'Color vision deficiency detected. Consult an eye care professional for detailed evaluation.';
  }

  void _proceedToAmslerTest() {
    Navigator.pushReplacementNamed(context, '/amsler-grid-test');
  }

  @override
  void dispose() {
    _plateTimer?.cancel();
    _distanceAutoSkipTimer?.cancel();
    _distanceWarningReenableTimer?.cancel();
    _answerController.dispose();
    _distanceService.dispose();
    _continuousSpeech.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show main UI until we're in test phase
    if (_phase == TestPhase.initialInstructions ||
        _phase == TestPhase.calibration ||
        _phase == TestPhase.rightEyeInstruction ||
        _phase == TestPhase.leftEyeInstruction) {
      return Scaffold(
        backgroundColor: AppColors.testBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_phase == TestPhase.complete) {
      return _buildCompleteView();
    }

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
          title: Text(
            'Color Vision Test - ${_currentEye == 'right' ? 'Right' : 'Left'} Eye',
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              _buildTestView(),
              Positioned(
                right: 12,
                bottom: 12,
                child: _buildDistanceIndicator(),
              ),
              // Mic indicator - Always visible during test
              if (_showingPlate)
                Positioned(top: 12, right: 12, child: _buildMicIndicator()),
              if (_isTestPausedForDistance) _buildDistanceWarningOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestView() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentPlateIndex + 1) / _testPlates.length,
          backgroundColor: AppColors.border,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plate ${_currentPlateIndex + 1} of ${_testPlates.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _timeRemaining <= 3
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: _timeRemaining <= 3
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_timeRemaining}s',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _timeRemaining <= 3
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_currentPlateIndex < _testPlates.length)
                  IshiharaPlateViewer(
                    plateNumber: _testPlates[_currentPlateIndex].plateNumber,
                    imagePath: _testPlates[_currentPlateIndex].svgPath,
                    size: MediaQuery.of(context).size.width - 48,
                  ),
                const SizedBox(height: 12),
                Text(
                  'What number do you see?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Say the number or type it',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _buildNumberInput(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _answerController,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Enter number or X',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _showingPlate
                ? () => _submitAnswer(_answerController.text)
                : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Submit'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteView() {
    final result = context.read<TestSessionProvider>().colorVision;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Test Complete')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              result?.isNormal == true ? Icons.check_circle : Icons.warning,
              size: 80,
              color: result?.isNormal == true
                  ? AppColors.success
                  : AppColors.warning,
            ),
            const SizedBox(height: 24),
            Text(
              'Color Vision Test Complete!',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    result?.summaryText ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Right Eye: ${result?.rightEye.correctAnswers ?? 0}/13',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    'Left Eye: ${result?.leftEye.correctAnswers ?? 0}/13',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToAmslerTest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Continue to Amsler Grid Test'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicIndicator() {
    // Determine state and color - GREEN when recognized!
    final bool hasRecognized =
        _lastDetectedSpeech != null && _lastDetectedSpeech!.isNotEmpty;
    final Color indicatorColor = hasRecognized
        ? AppColors
              .success // GREEN when we hear something
        : (_isListening ? AppColors.primary : AppColors.textSecondary);

    String statusText;
    IconData iconData;

    if (hasRecognized) {
      statusText = 'Heard: $_lastDetectedSpeech';
      iconData = Icons.mic;
    } else if (_isListening) {
      statusText = 'Listening...';
      iconData = Icons.mic;
    } else {
      statusText = 'Mic Ready';
      iconData = Icons.mic_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: indicatorColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              statusText,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      40.0,
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
    final pauseReason = DistanceHelper.getPauseReason(_distanceStatus, 40.0);
    final instruction = DistanceHelper.getDetailedInstruction(40.0);

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
              Icon(Icons.warning_rounded, size: 60, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(
                pauseReason,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _distanceAutoSkipTimer?.cancel();
                  setState(() {
                    _isTestPausedForDistance = false;
                    _userDismissedDistanceWarning = true;
                  });

                  // Re-enable warning after 30 seconds
                  _distanceWarningReenableTimer?.cancel();
                  _distanceWarningReenableTimer = Timer(
                    const Duration(seconds: 30),
                    () {
                      if (mounted) {
                        setState(() => _userDismissedDistanceWarning = false);
                      }
                    },
                  );

                  _ttsService.speak('Resuming test');
                  _restartPlateTimer();
                },
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TestPhase {
  initialInstructions,
  calibration,
  rightEyeInstruction,
  rightEyeTest,
  leftEyeInstruction,
  leftEyeTest,
  complete,
}
