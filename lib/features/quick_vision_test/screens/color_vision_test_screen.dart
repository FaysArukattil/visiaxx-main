import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/constants/ishihara_plate_data.dart';
import 'package:visiaxx/features/quick_vision_test/screens/color_vision_cover_eye_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../core/services/distance_skip_manager.dart';
import '../../../core/utils/distance_helper.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../widgets/ishihara_plate_viewer.dart';
import 'package:visiaxx/core/widgets/test_exit_confirmation_dialog.dart';
import 'distance_calibration_screen.dart';

import 'color_vision_instructions_screen.dart';
import '../../../core/utils/navigation_utils.dart';

/// Clinical-grade Color Vision Test
/// Tests BOTH eyes separately using Ishihara plates
class ColorVisionTestScreen extends StatefulWidget {
  final void Function(ColorVisionResult)? onComplete;

  const ColorVisionTestScreen({super.key, this.onComplete});

  @override
  State<ColorVisionTestScreen> createState() => _ColorVisionTestScreenState();
}

class _ColorVisionTestScreenState extends State<ColorVisionTestScreen>
    with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();
  final DistanceDetectionService _distanceService = DistanceDetectionService(
    targetDistanceCm: 40.0,
    toleranceCm: 5.0,
  );
  final DistanceSkipManager _skipManager = DistanceSkipManager();

  // Test configuration
  late List<IshiharaPlateConfig> _testPlates;

  // Test state
  TestPhase _phase = TestPhase.initialInstructions;
  String _currentEye = 'right'; // 'right' or 'left'
  int _currentPlateIndex = 0;
  final List<PlateResponse> _rightEyeResponses = [];
  final List<PlateResponse> _leftEyeResponses = [];

  bool _showingPlate = false;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  List<String> _currentOptions = []; // Current plate options
  bool _isTestPausedForDistance = false;
  bool _isPausedForExit =
      false; // ✅ Prevent distance warning during pause dialog
  Timer? _autoNavigationTimer; // ✅ Added timer for cancellable navigation
  bool _userDismissedDistanceWarning = false;
  final bool _isNavigatingToNextTest = false;
  int _secondsRemaining = 5;
  DateTime? _lastShouldPauseTime;
  static const Duration _distancePauseDebounce = Duration(milliseconds: 1000);
  Timer? _distanceAutoSkipTimer;
  Timer? _distanceWarningReenableTimer;

  // Timer
  Timer? _plateTimer;
  int _timeRemaining = TestConstants.colorVisionTimePerPlateSeconds;
  DateTime? _plateStartTime;
  int _selectedOptionIndex = -1; // Added for visual feedback

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _testPlates = IshiharaPlateData.getTestPlates();
    _initServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  void _handleAppPaused() {
    _plateTimer?.cancel();
    _distanceService.stopMonitoring();
    _ttsService.stop();
    setState(() {
      _isPausedForExit = true;
      _isTestPausedForDistance = true;
    });
  }

  void _handleAppResumed() {
    if (!mounted || _phase == TestPhase.calibration) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _phase != TestPhase.calibration) {
        _showPauseDialog(reason: 'minimized');
      }
    });
  }

  /// Unified pause dialog for both back button and app minimization
  void _showPauseDialog({String reason = 'back button'}) {
    // Pause services while dialog is shown
    _distanceService.stopMonitoring();
    _ttsService.stop();
    _autoNavigationTimer?.cancel(); // ✅ Pause auto-navigation timer

    setState(() {
      _isPausedForExit = true;
      _isTestPausedForDistance = true;
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

  /// Alias for back button
  void _showExitConfirmation() => _showPauseDialog();

  /// Resume the test from the pause dialog
  void _resumeTestFromDialog() {
    if (!mounted) return;

    if (_phase == TestPhase.complete) {
      setState(() {
        _isPausedForExit = false;
      });
      // Restart the 5-second timer
      _autoNavigationTimer?.cancel();
      _startAutoNavigationTimer(); // ✅ Resume auto-navigation
      return;
    }

    setState(() {
      _isPausedForExit = false;
      _isTestPausedForDistance = false;
    });

    // Restart distance monitoring
    _startContinuousDistanceMonitoring();

    // Resume plate timer if showing plate
    if (_showingPlate) {
      _restartPlateTimer();
    }
  }

  /// Restart only the current test, preserving other test data
  void _restartCurrentTest() {
    // Reset only Color Vision test data in provider
    context.read<TestSessionProvider>().resetColorVision();

    _plateTimer?.cancel();
    _distanceService.stopMonitoring();
    _ttsService.stop();
    _autoNavigationTimer?.cancel();

    setState(() {
      _phase = TestPhase.initialInstructions;
      _currentEye = 'right';
      _currentPlateIndex = 0;
      _rightEyeResponses.clear();
      _leftEyeResponses.clear();
      _showingPlate = false;
      _timeRemaining = TestConstants.colorVisionTimePerPlateSeconds;
      _isTestPausedForDistance = false;
      _isPausedForExit = false;
    });

    _initServices();
  }

  void _restartPlateTimer() {
    _plateTimer?.cancel();
    if (_timeRemaining <= 0) {
      _submitAnswer('', -1);
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
        _submitAnswer('', -1);
      }
    });
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
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
    // ✅ FIX: Stop monitoring before cover eye instruction
    _distanceService.stopMonitoring();

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

            // ✅ FIX: Resume monitoring AFTER user confirms they've covered eye
            _startContinuousDistanceMonitoring();
            _startEyeTest();
          },
        ),
      ),
    );
  }

  void _showLeftEyeInstruction() {
    // ✅ FIX: Stop monitoring before cover eye instruction
    _distanceService.stopMonitoring();

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

            // ✅ FIX: Resume monitoring AFTER user confirms they've covered eye
            _startContinuousDistanceMonitoring();
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

    // ✅ FIX: Don't process distance updates while pause dialog is showing
    if (_isPausedForExit) return;

    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      'color_vision',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
    });

    if (_showingPlate && !_phase.name.contains('Instruction')) {
      if (shouldPause) {
        _lastShouldPauseTime ??= DateTime.now();
        final durationSinceFirstIssue = DateTime.now().difference(
          _lastShouldPauseTime!,
        );

        if (durationSinceFirstIssue >= _distancePauseDebounce &&
            !_isTestPausedForDistance &&
            !_userDismissedDistanceWarning) {
          _skipManager
              .canShowDistanceWarning(DistanceTestType.colorVision)
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

  void _pauseTestForDistance() {
    setState(() => _isTestPausedForDistance = true);
    _plateTimer?.cancel();
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
  }

  void _resumeTestAfterDistance() {
    _distanceAutoSkipTimer?.cancel();
    setState(() => _isTestPausedForDistance = false);
    _ttsService.speak('Resuming test');
    _restartPlateTimer();
    HapticFeedback.mediumImpact();
  }

  void _startEyeTest() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showNextPlate();
    });
  }

  void _showNextPlate() {
    if (_currentPlateIndex >= _testPlates.length) {
      _onEyeTestComplete();
      return;
    }

    _plateStartTime = DateTime.now();

    setState(() {
      _showingPlate = true;
      _timeRemaining = TestConstants.colorVisionTimePerPlateSeconds;
    });

    final plate = _testPlates[_currentPlateIndex];
    if (plate.isDemo) {
      _ttsService.speak('Demo plate. What number do you see?');
    } else {
      _ttsService.speak('What number do you see?');
    }

    setState(() {
      _currentOptions = _getOptionsForPlate(plate);
      _selectedOptionIndex = -1; // Reset for next plate
    });

    _restartPlateTimer();
  }

  void _submitAnswer(String answer, int index) {
    if (_selectedOptionIndex != -1) return; // Prevent double taps

    setState(() {
      _selectedOptionIndex = index;
    });

    _plateTimer?.cancel();
    HapticFeedback.lightImpact();

    final plate = _testPlates[_currentPlateIndex];
    final responseTime = _plateStartTime != null
        ? DateTime.now().difference(_plateStartTime!).inMilliseconds
        : 0;

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

    if (_currentEye == 'right') {
      _rightEyeResponses.add(response);
    } else {
      _leftEyeResponses.add(response);
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _showingPlate = false;
        _currentPlateIndex++;
      });

      if (_currentPlateIndex < _testPlates.length) {
        _showNextPlate();
      } else {
        _onEyeTestComplete();
      }
    });
  }

  bool _checkAnswer(String answer, IshiharaPlateConfig plate) {
    if (answer.isEmpty) return false;
    final normalized = answer.replaceAll(' ', '').toLowerCase();
    final expected = plate.normalAnswer.replaceAll(' ', '').toLowerCase();
    if (normalized == 'nothing' || normalized == 'none' || normalized == 'x') {
      return expected == 'nothing';
    }
    return normalized == expected;
  }

  void _onEyeTestComplete() {
    if (_currentEye == 'right') {
      _ttsService.stop();
      _ttsService.speak(
        'Right eye test complete. Now we will test your left eye.',
      );

      // Delay to let the TTS finish and show the eye switch view
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _showLeftEyeInstruction();
        }
      });
    } else {
      _completeTest();
    }
  }

  void _completeTest() {
    setState(() => _phase = TestPhase.complete);

    final rightEyeResult = _analyzeEyeResult(_rightEyeResponses, 'right');
    final leftEyeResult = _analyzeEyeResult(_leftEyeResponses, 'left');

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
      totalDurationSeconds: 0,
    );

    context.read<TestSessionProvider>().setColorVisionResult(result);
    _ttsService.speak(
      'Color vision test complete. Please review your results.',
    );
    widget.onComplete?.call(result);

    _startAutoNavigationTimer();
  }

  void _startAutoNavigationTimer() {
    _autoNavigationTimer?.cancel();
    setState(() {
      _secondsRemaining = 5;
    });
    _autoNavigationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          if (!_isNavigatingToNextTest) {
            _proceedToAmslerTest();
          }
        }
      });
    });
  }

  ColorVisionEyeResult _analyzeEyeResult(
    List<PlateResponse> responses,
    String eye,
  ) {
    final correctAnswers = responses.where((r) => r.isCorrect).length;
    final totalPlates = responses.length;

    final classificationPlates = responses.where(
      (r) => r.category == PlateCategory.classification.name,
    );

    ColorVisionStatus status;
    DeficiencyType? detectedType;

    // Standard criteria including 1 demo + 13 diagnostic plates (14 total):
    // Normal: 0-2 errors (12-14 correct)
    // Borderline/Mild: 3-5 errors (9-11 correct)
    // Moderate: 6-8 errors (6-8 correct)
    // Severe: 9+ errors (0-5 correct)
    if (correctAnswers >= 12) {
      status = ColorVisionStatus.normal;
    } else if (correctAnswers >= 9) {
      status = ColorVisionStatus.mild;
    } else if (correctAnswers >= 6) {
      status = ColorVisionStatus.moderate;
    } else {
      status = ColorVisionStatus.severe;
    }

    if (status != ColorVisionStatus.normal) {
      detectedType = DeficiencyType.redGreenDeficiency;

      // Determine Protan vs Deutan from classification plates
      int protanScore = 0;
      int deutanScore = 0;

      for (var response in classificationPlates) {
        final plate = IshiharaPlateData.getPlate(response.plateNumber);
        if (plate != null) {
          if (response.userAnswer == plate.protanStrongAnswer) protanScore++;
          if (response.userAnswer == plate.deutanStrongAnswer) deutanScore++;
        }
      }

      if (protanScore > deutanScore) {
        detectedType = DeficiencyType.protan;
      } else if (deutanScore > protanScore) {
        detectedType = DeficiencyType.deutan;
      }
    }

    return ColorVisionEyeResult(
      eye: eye,
      correctAnswers: correctAnswers,
      totalDiagnosticPlates: totalPlates,
      responses: responses,
      status: status,
      detectedType: detectedType,
    );
  }

  ColorVisionStatus _determineOverallStatus(
    ColorVisionEyeResult right,
    ColorVisionEyeResult left,
  ) {
    final statuses = [right.status, left.status];
    if (statuses.contains(ColorVisionStatus.severe)) {
      return ColorVisionStatus.severe;
    }
    if (statuses.contains(ColorVisionStatus.moderate)) {
      return ColorVisionStatus.moderate;
    }
    if (statuses.contains(ColorVisionStatus.mild)) {
      return ColorVisionStatus.mild;
    }
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

    // If both have specific types, use them. If they differ, generic RG.
    if (right.detectedType == left.detectedType && right.detectedType != null) {
      return right.detectedType!;
    }

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
    final provider = context.read<TestSessionProvider>();

    // If individual test mode, navigate to standard result screen
    if (provider.isIndividualTest) {
      Navigator.pushReplacementNamed(context, '/quick-test-result');
      return;
    }

    // Otherwise continue to next test
    Navigator.pushReplacementNamed(context, '/amsler-grid-test');
  }

  @override
  void dispose() {
    _plateTimer?.cancel();
    _distanceAutoSkipTimer?.cancel();
    _distanceWarningReenableTimer?.cancel();
    _autoNavigationTimer?.cancel(); // Cancel auto-navigation timer
    _distanceService.dispose();
    _ttsService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == TestPhase.initialInstructions ||
        _phase == TestPhase.calibration ||
        _phase == TestPhase.rightEyeInstruction ||
        _phase == TestPhase.leftEyeInstruction) {
      return const Scaffold(
        backgroundColor: AppColors.testBackground,
        body: Center(child: EyeLoader(size: 80)),
      );
    }

    final body = _phase == TestPhase.complete
        ? _buildCompleteView()
        : _buildManualScaffold();

    return PopScope(
      canPop: false, // Prevent accidental exit
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: body,
    );
  }

  Widget _buildManualScaffold() {
    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: Text(
          'Color Vision - ${_currentEye.toUpperCase()} Eye',
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
            Column(
              children: [
                _buildInfoBar(),
                Expanded(child: _buildTestView()),
              ],
            ),
            Positioned(right: 12, bottom: 12, child: _buildDistanceIndicator()),
            // ✅ FIX: Don't show overlay when pause dialog is active
            if (_isTestPausedForDistance && !_isPausedForExit)
              _buildDistanceWarningOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Plate indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'PLATE ${(_currentPlateIndex >= _testPlates.length ? _testPlates.length - 1 : _currentPlateIndex) + 1} OF ${_testPlates.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Timer indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _timeRemaining <= 3
                  ? AppColors.error.withOpacity(0.08)
                  : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: _timeRemaining <= 3
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_timeRemaining}s',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
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
    );
  }

  Widget _buildTestView() {
    return Column(
      children: [
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
                const SizedBox(height: 32),
                _buildOptionButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButtons() {
    if (_currentPlateIndex >= _testPlates.length) {
      return const SizedBox.shrink();
    }

    final plate = _testPlates[_currentPlateIndex];
    final options = _currentOptions.isNotEmpty
        ? _currentOptions
        : _getOptionsForPlate(plate);

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: List.generate(options.length, (index) {
        final option = options[index];
        final isSelected = _selectedOptionIndex == index;

        return SizedBox(
          width: (MediaQuery.of(context).size.width - 64) / 2,
          height: 60,
          child: ElevatedButton(
            onPressed: () {
              _submitAnswer(option, index);
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.transparent,
              shadowColor: AppColors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Builder(
              builder: (context) {
                final isCorrect = _checkAnswer(option, plate);
                final isWrong = isSelected && !isCorrect;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected && !isCorrect
                        ? AppColors.error.withOpacity(0.2)
                        : isSelected && isCorrect
                        ? AppColors.success.withOpacity(0.2)
                        : isSelected
                        ? AppColors.primary.withOpacity(0.2)
                        : AppColors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (isCorrect
                                ? AppColors.success
                                : (isWrong
                                      ? AppColors.error
                                      : AppColors.primary))
                          : AppColors.primary.withOpacity(0.3),
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  (isCorrect
                                          ? AppColors.success
                                          : (isWrong
                                                ? AppColors.error
                                                : AppColors.primary))
                                      .withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isCorrect
                                  ? AppColors.success
                                  : (isWrong
                                        ? AppColors.error
                                        : AppColors.primary))
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }

  List<String> _getOptionsForPlate(IshiharaPlateConfig plate) {
    final List<String> options = [];

    // 1. Normal see number
    options.add(plate.normalAnswer);

    // 2. Color vision see number (deficient)
    if (plate.deficientAnswer != null &&
        plate.deficientAnswer != plate.normalAnswer &&
        plate.deficientAnswer != 'Nothing') {
      options.add(plate.deficientAnswer!);
    } else if (plate.category == PlateCategory.classification) {
      // For classification, use BOTH alternates if available
      if (plate.protanStrongAnswer != null &&
          plate.protanStrongAnswer != plate.normalAnswer) {
        options.add(plate.protanStrongAnswer!);
      }
      if (plate.deutanStrongAnswer != null &&
          plate.deutanStrongAnswer != plate.normalAnswer) {
        if (!options.contains(plate.deutanStrongAnswer)) {
          options.add(plate.deutanStrongAnswer!);
        }
      }
    }

    // Random numbers pool
    final List<String> commonNumbers = [
      '2',
      '3',
      '5',
      '6',
      '7',
      '8',
      '12',
      '15',
      '16',
      '26',
      '29',
      '35',
      '42',
      '45',
      '57',
      '70',
      '73',
      '74',
      '96',
      '97',
    ];

    // User special requirements for specific test plate indices:
    // Plate 13 (Plate 23): replace option 57 with 4
    // Plate 14 (Plate 24): replace option 7 with 3
    final List<String> randomizedPool = List.from(commonNumbers);
    if (plate.plateNumber == 23) randomizedPool.remove('57');
    if (plate.plateNumber == 24) randomizedPool.remove('7');

    randomizedPool.shuffle();
    for (var num in randomizedPool) {
      if (options.length >= 3) break;
      if (!options.contains(num)) {
        options.add(num);
      }
    }

    // 4. "Nothing"
    if (!options.contains('Nothing')) {
      if (plate.normalAnswer == 'Nothing') {
        // If normal is Nothing, then we already have Nothing in options[0]
        options[0] = 'Nothing';
      } else {
        options.add('Nothing');
      }
    }

    // Fill up to 4 if still missing
    for (var num in commonNumbers) {
      if (options.length >= 4) break;
      if (!options.contains(num)) {
        options.add(num);
      }
    }

    options.shuffle();
    return options.take(4).toList();
  }

  Widget _buildCompleteView() {
    final result = context.read<TestSessionProvider>().colorVision;
    final isNormal = result?.isNormal == true;
    // Qualitative feedback integrated into individual cards.

    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: const Text('Color Vision Result'),
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
                        color:
                            (isNormal ? AppColors.success : AppColors.warning)
                                .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              (isNormal ? AppColors.success : AppColors.warning)
                                  .withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  (isNormal
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isNormal
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 40,
                              color: isNormal
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Color Vision Test Completed',
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

                    // Separate Eye Result Cards
                    _buildIndividualEyeCard(
                      'Right Eye',
                      result?.rightEye,
                      AppColors.rightEye,
                    ),
                    const SizedBox(height: 16),
                    _buildIndividualEyeCard(
                      'Left Eye',
                      result?.leftEye,
                      AppColors.leftEye,
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
                  _proceedToAmslerTest();
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
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_secondsRemaining}s',
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
    );
  }

  Widget _buildDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      40.0,
      testType: 'color_vision',
    );

    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'Searching...';

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
                AppColors.white.withOpacity(0.15),
                AppColors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: indicatorColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: indicatorColor.withOpacity(0.1),
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
                      color: indicatorColor.withOpacity(0.6),
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
                      color: indicatorColor.withOpacity(0.8),
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

  Widget _buildDistanceWarningOverlay() {
    // ✅ Dynamic messages based on status
    final instruction = DistanceHelper.getDetailedInstruction(40.0);
    final rangeText = DistanceHelper.getAcceptableRangeText(40.0);

    // ✅ Icon changes based on issue
    final icon = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? Icons.face_retouching_off
        : Icons.warning_rounded;

    final iconColor = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? AppColors.error
        : AppColors.warning;

    return Container(
      color: AppColors.black.withOpacity(0.85),
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
                'Searching for face...',
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
              const SizedBox(height: 16),

              if (DistanceHelper.isFaceDetected(_distanceStatus)) ...[
                Text(
                  'Current: ${_currentDistance.toStringAsFixed(0)}cm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Target: $rangeText',
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
                        'Distance search active',
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

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  _distanceAutoSkipTimer?.cancel();
                  _skipManager.recordSkip(DistanceTestType.colorVision);
                  setState(() {
                    _isTestPausedForDistance = false;
                    _userDismissedDistanceWarning = true;
                    _lastShouldPauseTime = null;
                  });

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

  Widget _buildIndividualEyeCard(
    String eye,
    ColorVisionEyeResult? eyeResult,
    Color color,
  ) {
    final int correct = eyeResult?.correctAnswers ?? 0;
    final int total = eyeResult?.totalDiagnosticPlates ?? 14;
    final String status = eyeResult?.status.displayName ?? 'Unknown';
    final String deficiency = eyeResult?.detectedType?.displayName ?? 'None';
    final bool isNormal = eyeResult?.status == ColorVisionStatus.normal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                        color: isNormal ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isNormal ? AppColors.success : AppColors.warning)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$correct/$total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isNormal ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 12),
          Text(
            'FINDINGS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deficiency,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isNormal ? AppColors.textPrimary : AppColors.warning,
            ),
          ),
        ],
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
