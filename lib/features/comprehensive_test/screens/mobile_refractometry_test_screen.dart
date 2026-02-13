import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/services/advanced_refraction_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/distance_warning_overlay.dart';
import '../../../core/utils/distance_helper.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/test_feedback_overlay.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../quick_vision_test/screens/distance_transition_screen.dart';
import '../../../data/models/mobile_refractometry_result.dart';
import '../../../data/providers/test_session_provider.dart';
import 'package:visiaxx/core/services/distance_skip_manager.dart';
import '../../quick_vision_test/screens/distance_calibration_screen.dart';
import '../../quick_vision_test/screens/cover_left_eye_instruction_screen.dart';
import '../../quick_vision_test/screens/cover_right_eye_instruction_screen.dart';
import './mobile_refractometry_instructions_screen.dart';
import '../../../core/widgets/voice_input_overlay.dart';
import '../../../core/providers/voice_recognition_provider.dart';
import '../../../core/services/voice_recognition_service.dart';

/// Refractometry phases
enum RefractPhase { instruction, calibration, relaxation, test, complete }

class MobileRefractometryTestScreen extends StatefulWidget {
  final bool showInitialInstructions;

  const MobileRefractometryTestScreen({
    super.key,
    this.showInitialInstructions = true,
  });

  @override
  State<MobileRefractometryTestScreen> createState() =>
      _MobileRefractometryTestScreenState();
}

class _MobileRefractometryTestScreenState
    extends State<MobileRefractometryTestScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Services
  final TtsService _ttsService = TtsService();
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final DistanceSkipManager _skipManager = DistanceSkipManager();

  // State Management
  RefractPhase _currentPhase = RefractPhase.instruction;
  String _currentEye = 'right';
  bool _isNearMode = false;
  int _currentRound = 0;
  double _currentBlur = 0.0;
  RefractCharacter _currentCharacter = RefractCharacter.e;
  String _activeRoundLabel = 'E';
  EDirection _currentDirection = EDirection.right;
  bool _waitingForResponse = false;
  bool _showResult = false;
  bool _instructionShown = false;
  EDirection? _lastResponse;
  bool? _isLastCorrect;
  DateTime? _eDisplayStartTime;

  // Protocol
  late List<SimplifiedTestRound> _simplifiedProtocol;

  // Data storage
  final List<Map<String, dynamic>> _rightEyeResponses = [];
  final List<Map<String, dynamic>> _leftEyeResponses = [];

  // Timing
  Timer? _roundTimer;
  int _remainingSeconds = TestConstants.mobileRefractometryTimePerRoundSeconds;

  // Relaxation
  int _relaxationCountdown = TestConstants.mobileRefractometryRelaxationSeconds;
  Timer? _relaxationTimer;
  late AnimationController _relaxationProgressController;
  bool _relaxationShownForCurrentEye = false;
  bool _isTransitioning = false;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = true;
  bool _isTestPausedForDistance = false;
  DateTime? _lastShouldPauseTime;
  static const Duration _distancePauseDebounce = Duration(milliseconds: 1000);

  // Age management
  int _patientAge = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize relaxation animation controller
    _relaxationProgressController = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: TestConstants.mobileRefractometryRelaxationSeconds,
      ),
    );

    _relaxationProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          _currentPhase == RefractPhase.relaxation) {
        _startRound();
      }
    });

    _initServices();
    _patientAge = context.read<TestSessionProvider>().profileAge ?? 30;
    _simplifiedProtocol = _patientAge < 40
        ? TestConstants.getSimplifiedRefractometryProtocolYoung()
        : TestConstants.getSimplifiedRefractometryProtocolPresbyope();
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();

    if (mounted) {
      final provider = context.read<TestSessionProvider>();
      _patientAge = provider.profileAge ?? 30;

      // PROACTIVE VOICE INITIALIZATION
      // Same pattern as working VisualAcuityTestScreen
      final voiceProvider = context.read<VoiceRecognitionProvider>();
      if (voiceProvider.isEnabled) {
        debugPrint('[MobileRefract] Proactively initializing voice service');
        await voiceProvider.initialize();
      }

      // START FLOW LOGIC
      if (!widget.showInitialInstructions) {
        _instructionShown = true;
        _isTransitioning = true;
        // Ensure distance state is clean before starting calibration
        setState(() {
          _isDistanceOk = true;
          _isTestPausedForDistance = false;
        });
        _startDistanceCalibration(TestConstants.mobileRefractometryDistanceCm);
      } else {
        _isTransitioning = true;
        _startInstruction();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relaxationProgressController.dispose();
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _distanceService.stopMonitoring();
    _ttsService.dispose();
    super.dispose();
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
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _distanceService.stopMonitoring();
    setState(() => _isTestPausedForDistance = true);
  }

  void _handleAppResumed() {
    if (!mounted || _currentPhase == RefractPhase.calibration) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _currentPhase != RefractPhase.calibration) {
        _showPauseDialog(reason: 'minimized');
      }
    });
  }

  // --- Phase Transitions ---

  void _startInstruction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MobileRefractometryInstructionsScreen(
          onContinue: () {
            _isTransitioning = false;
            Navigator.of(context).pop();
            _onInstructionComplete();
          },
        ),
      ),
    );
  }

  void _onInstructionComplete() {
    _isTransitioning = false;
    _instructionShown = true;
    _startDistanceCalibration(TestConstants.mobileRefractometryDistanceCm);
  }

  void _showEyeInstructionStage() {
    if (_isTransitioning) return;

    if (_currentEye == 'right' && _currentRound == 0 && !_isNearMode) {
      _isTransitioning = true;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CoverLeftEyeInstructionScreen(
            title: 'Mobile Refractometry',
            subtitle: 'Focus with your RIGHT eye only',
            ttsMessage:
                'Cover your left eye. Keep your right eye open. We will measure your refraction at 1 meter and 40 centimeters.',
            targetDistance: TestConstants.mobileRefractometryDistanceCm,
            startButtonText: 'Start Right Eye Test',
            onContinue: () {
              _isTransitioning = false;
              Navigator.of(context).pop();
              if (!_relaxationShownForCurrentEye) {
                _relaxationShownForCurrentEye = true;
                _startRelaxation();
              } else {
                _startRound();
              }
            },
          ),
        ),
      );
    } else {
      if (!_relaxationShownForCurrentEye) {
        _relaxationShownForCurrentEye = true;
        _startRelaxation();
      } else {
        _startRound();
      }
    }
  }

  void _startDistanceCalibration(double targetCm) {
    setState(() {
      _currentPhase = RefractPhase.calibration;
      _isNearMode = targetCm <= 45.0;
    });

    _distanceService.stopMonitoring();

    _isTransitioning = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: targetCm,
          toleranceCm: TestConstants.mobileRefractometryToleranceCm,
          minDistanceCm: targetCm >= 100 ? 60.0 : 35.0,
          maxDistanceCm: 300.0,
          onCalibrationComplete: () {
            _isTransitioning = false;
            Navigator.of(context).pop();
            _onCalibrationComplete();
          },
        ),
      ),
    );
  }

  void _onCalibrationComplete() {
    _startContinuousDistanceMonitoring();
    if (!_instructionShown) {
      _instructionShown = true;
      _startInstruction();
    } else {
      _showEyeInstructionStage();
    }
  }

  Future<void> _startContinuousDistanceMonitoring() async {
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    await _distanceService.initializeCamera();
    if (!_distanceService.isMonitoring) {
      await _distanceService.startMonitoring();
    }
  }

  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    final testTypeForHelper = _isNearMode
        ? 'refraction_near'
        : 'refraction_distance';
    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      testTypeForHelper,
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
      if (!shouldPause) {
        _isDistanceOk = true;
      }
    });

    if (shouldPause) {
      _lastShouldPauseTime ??= DateTime.now();
      final durationSinceFirstIssue = DateTime.now().difference(
        _lastShouldPauseTime!,
      );

      if (durationSinceFirstIssue >= _distancePauseDebounce &&
          !_isTestPausedForDistance) {
        if (_currentPhase == RefractPhase.test ||
            _currentPhase == RefractPhase.relaxation) {
          _skipManager
              .canShowDistanceWarning(
                _isNearMode
                    ? DistanceTestType.shortDistance
                    : DistanceTestType.mobileRefractometry,
              )
              .then((canShow) {
                if (mounted && canShow) {
                  _pauseTestForDistance();
                }
              });
        }
      }
    } else {
      _lastShouldPauseTime = null;
      if (_isTestPausedForDistance) {
        _resumeTestAfterDistance();
      }
    }
  }

  void _pauseTestForDistance() {
    setState(() {
      _isTestPausedForDistance = true;
      _isDistanceOk = false;
    });
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    HapticFeedback.mediumImpact();
  }

  void _resumeTestAfterDistance() {
    setState(() {
      _isTestPausedForDistance = false;
      _isDistanceOk = true;
      _lastShouldPauseTime = null;
    });

    if (_currentPhase == RefractPhase.test && _waitingForResponse) {
      _startRoundTimer();
    } else if (_currentPhase == RefractPhase.relaxation) {
      _startRelaxationTimer();
    }
    HapticFeedback.mediumImpact();
  }

  void _startRelaxation() {
    debugPrint('[MobileRefract] Starting relaxation phase');

    // Ensure we are monitoring distance and state is reset
    _startContinuousDistanceMonitoring();

    setState(() {
      _currentPhase = RefractPhase.relaxation;
      _relaxationCountdown = TestConstants.mobileRefractometryRelaxationSeconds;
      _isTestPausedForDistance = false; // Force resume for relaxation start
      _isDistanceOk = true;
    });

    _ttsService.speak(TtsService.relaxationInstruction);
    _relaxationProgressController.reset();
    _startRelaxationTimer();
  }

  void _startRelaxationTimer() {
    _relaxationTimer?.cancel();

    if (_isTestPausedForDistance) {
      _relaxationProgressController.stop();
      return;
    }

    _relaxationProgressController.forward();

    _relaxationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // If paused during high-level check, stop everything
      if (_isTestPausedForDistance) {
        timer.cancel();
        _relaxationProgressController.stop();
        return;
      }

      setState(() => _relaxationCountdown--);

      if (_relaxationCountdown <= 0) {
        timer.cancel();
        if (_currentPhase == RefractPhase.relaxation) {
          _startRound();
        }
      }
    });

    // Safety fallback: if stuck for more than relaxation + 2s, force start
    Future.delayed(
      Duration(seconds: TestConstants.mobileRefractometryRelaxationSeconds + 2),
      () {
        if (mounted &&
            _currentPhase == RefractPhase.relaxation &&
            !_isTestPausedForDistance) {
          _startRound();
        }
      },
    );
  }

  void _startRound() {
    if (_currentRound >= _simplifiedProtocol.length) {
      _finishEye();
      return;
    }

    final round = _simplifiedProtocol[_currentRound];

    final newIsNearMode = round.testType == TestType.near;
    if (newIsNearMode != _isNearMode) {
      _isNearMode = newIsNearMode;
      _showDistanceSwitchOverlay(newIsNearMode);
      return;
    }

    if (_currentPhase != RefractPhase.test) {
      setState(() => _currentPhase = RefractPhase.test);
    }

    _currentCharacter = round.characterType;
    _currentDirection = round.getRandomDirection();

    final String actualLabel = _currentCharacter.getActualLabel();
    _activeRoundLabel = actualLabel;

    _eDisplayStartTime = null;

    setState(() {
      _currentPhase = RefractPhase.test;
      _remainingSeconds = TestConstants.mobileRefractometryTimePerRoundSeconds;
      _waitingForResponse = true;
      _showResult = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _eDisplayStartTime = DateTime.now();
      _startRoundTimer();
    });
  }

  void _finishRound() {
    setState(() {
      _currentRound++;
    });

    if (_currentRound >= _simplifiedProtocol.length) {
      _finishEye();
    } else {
      _startRound();
    }
  }

  void _showDistanceSwitchOverlay(bool toNear) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceTransitionScreen(
          title: 'Mobile Refractometry',
          headline: toNear
              ? 'Switching to Near Vision'
              : 'Switching to Distance Vision',
          currentDistance: toNear ? '100 cm' : '40 cm',
          targetDistance: toNear ? '40 cm' : '100 cm',
          instruction: toNear
              ? 'Please move closer to 40 centimeters for near vision testing.'
              : 'Please move back to 100 centimeters for distance vision testing.',
          onContinue: () {
            Navigator.of(context).pop();
            _startDistanceCalibration(toNear ? 40.0 : 100.0);
          },
        ),
      ),
    );
  }

  void _startRoundTimer() {
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) return;

      setState(() => _remainingSeconds--);

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _handleResponse(null);
      }
    });
  }

  void _handleVoiceResponse(String recognizedText, bool isFinal) {
    if (!mounted ||
        _currentPhase != RefractPhase.test ||
        !_waitingForResponse) {
      return;
    }

    // SUDDEN ACTION: Process both partial and final results
    // This makes the app respond immediately without waiting for the "final" pause

    // REMOVED: profileType == 'patient' check as it was blocking valid input
    // The user should be able to use voice regardless of profile type

    // Check if voice recognition is enabled and listening
    final voiceProvider = context.read<VoiceRecognitionProvider>();
    if (!voiceProvider.isEnabled) return;

    // If we're in error state, don't try to parse garbage
    if (voiceProvider.state == VoiceRecognitionState.error) {
      debugPrint('[MobileRefract] Voice in error state, ignoring input');
      return;
    }

    // Minimum display time guard - reduced for even more responsiveness
    if (_eDisplayStartTime != null) {
      final sinceStart = DateTime.now().difference(_eDisplayStartTime!);
      if (sinceStart < const Duration(milliseconds: 200)) {
        return;
      }
    }

    // Parse direction from recognized text
    final direction = _parseDirection(recognizedText);
    if (direction != null) {
      debugPrint(
        '[MobileRefract] ✅ SUDDEN Voice match: ${direction.label} from "$recognizedText"',
      );
      // Clear immediately to prevent leaking into next round
      context.read<VoiceRecognitionProvider>().clearRecognizedText();
      _handleResponse(direction);
    } else {
      // Enhanced logging to see why it's not matching
      debugPrint('[MobileRefract] ⚠️ Voice mismatch: "$recognizedText"');
    }
  }

  EDirection? _parseDirection(String text) {
    final normalized = text.toLowerCase().trim();

    // Check for "blurry" keywords
    final blurryKeywords = [
      'blurry',
      'blur',
      'bloody',
      'cannot see',
      'can\'t see',
      'kanchi',
      'cannot see clearly',
      'can\'t see clearly',
      'too blurry',
      'not clear',
      'nothing',
      'country',
      'zero',
    ];

    for (var keyword in blurryKeywords) {
      if (normalized.contains(keyword)) {
        return EDirection.blurry;
      }
    }

    // Check for direction keywords
    if (normalized.contains('up') || normalized.contains('top')) {
      return EDirection.up;
    }
    if (normalized.contains('down') || normalized.contains('bottom')) {
      return EDirection.down;
    }
    if (normalized.contains('left')) {
      return EDirection.left;
    }
    if (normalized.contains('right')) {
      return EDirection.right;
    }

    return null;
  }

  void _handleResponse(EDirection? response) {
    if (!_waitingForResponse || _showResult) return;

    // Proactively clear recognized text to avoid persistence in next round
    context.read<VoiceRecognitionProvider>().clearRecognizedText();

    final roundConfig = _simplifiedProtocol[_currentRound];

    // HANDLE NO RESPONSE (Timeout): Pick new rotation, stay in same round
    if (response == null) {
      debugPrint('[MobileRefract] Timeout - Rotating and retrying same round');

      // Update direction for visual rotation
      _currentDirection = roundConfig.getRandomDirection();

      setState(() {
        _waitingForResponse = false; // Briefly stop for mic restart
        _showResult = false;
        _remainingSeconds =
            TestConstants.mobileRefractometryTimePerRoundSeconds;
      });

      // Clear recognized text for fresh start
      context.read<VoiceRecognitionProvider>().clearRecognizedText();

      // Moderate delay for rotation feel
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _waitingForResponse = true; // Mic restarts here
          });
          _eDisplayStartTime = DateTime.now();
          _startRoundTimer();
        }
      });
      return;
    }

    _waitingForResponse = false;
    _roundTimer?.cancel();

    final correct = response == _currentDirection;
    final isCantSee = response == EDirection.blurry;

    if (correct) {
      _ttsService.speakCorrect(response.label);
    } else if (isCantSee) {
      _ttsService.speak('Cannot see');
    } else {
      _ttsService.speakIncorrect(response.label);
    }

    final responseRecord = {
      'roundNumber': _currentRound + 1,
      'characterIndex': 0,
      'characterType': _currentCharacter.label,
      'snellenSize': roundConfig.snellen,
      'fontSize': roundConfig.fontSize,
      'correct': correct,
      'isCantSee': isCantSee,
      'isNear': _isNearMode,
      'direction': _currentDirection,
      'blurLevel': _currentBlur,
      'userResponseIndex': response.rotationDegrees,
      'responseTime': _eDisplayStartTime != null
          ? DateTime.now().difference(_eDisplayStartTime!).inMilliseconds
          : 0,
    };

    if (_currentEye == 'right') {
      _rightEyeResponses.add(responseRecord);
    } else {
      _leftEyeResponses.add(responseRecord);
    }

    // ADAPTIVE BLUR LOGIC
    if (correct) {
      _currentBlur = math.min(
        TestConstants.maxBlurLevel,
        _currentBlur + TestConstants.blurIncrementOnCorrect,
      );
    } else {
      _currentBlur = math.max(
        TestConstants.minBlurLevel,
        isCantSee
            ? _currentBlur - TestConstants.blurDecrementOnCantSee
            : _currentBlur - TestConstants.blurDecrementOnWrong,
      );
    }

    setState(() {
      _lastResponse = response;
      _isLastCorrect = correct;
      _showResult = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showResult = false);
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _finishRound();
    });
  }

  void _finishEye() {
    if (_currentPhase == RefractPhase.complete || _isTransitioning) return;

    _isTransitioning = true;

    if (_currentEye == 'right') {
      if (_currentPhase == RefractPhase.instruction) return;

      setState(() {
        _currentEye = 'left';
        _currentRound = 0;
        _currentBlur = 0.0;
        _isNearMode = false;
        _currentPhase = RefractPhase.instruction;
        _relaxationShownForCurrentEye = false;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CoverRightEyeInstructionScreen(
              title: 'Mobile Refractometry',
              subtitle: 'Focus with your LEFT eye only',
              ttsMessage: 'Cover your right eye. Keep your left eye open.',
              targetDistance: TestConstants.mobileRefractometryDistanceCm,
              startButtonText: 'Start Left Eye Test',
              onContinue: () {
                Navigator.of(context).pop();
                _isTransitioning = false;
                _startRelaxation();
              },
            ),
          ),
        );
      });
    } else {
      _calculateResults();
    }
  }

  void _calculateResults() {
    _isTransitioning = false;
    setState(() => _currentPhase = RefractPhase.complete);

    final rightResults = _processEyeData(_rightEyeResponses);
    final leftResults = _processEyeData(_leftEyeResponses);

    final allResponses = [..._rightEyeResponses, ..._leftEyeResponses];
    final distResponses = allResponses
        .where((r) => r['isNear'] == false)
        .toList();
    final nearResponses = allResponses
        .where((r) => r['isNear'] == true)
        .toList();

    final combinedResult = AdvancedRefractionService.calculateFullAssessment(
      distanceResponses: distResponses,
      nearResponses: nearResponses,
      age: _patientAge,
      eye: 'combined',
    );

    final pathology = combinedResult.diseaseScreening;

    final finalResult = MobileRefractometryResult(
      patientAge: _patientAge,
      rightEye: rightResults,
      leftEye: leftResults,
      isAccommodating: combinedResult.isAccommodating,
      healthWarnings: (pathology['identifiedRisks'] as List)
          .map((e) => (e['conditionName'] as String))
          .toList(),
      identifiedRisks: List<Map<String, dynamic>>.from(
        pathology['identifiedRisks'],
      ),
      criticalAlert: pathology['criticalAlert'] as bool,
      overallInterpretation: pathology['interpretation'] as String? ?? 'Normal',
      detectedConditions: List<Map<String, dynamic>>.from(
        pathology['identifiedRisks'] ?? [],
      ),
      reliabilityScore: combinedResult.modelResult.visualAcuity == '6/6'
          ? 0.95
          : 0.85,
      recommendedFollowUp: combinedResult.recommendation,
    );

    context.read<TestSessionProvider>().setMobileRefractometryResult(
      finalResult,
    );

    final prov = context.read<TestSessionProvider>();
    if (prov.isIndividualTest) {
      Navigator.pushReplacementNamed(context, '/quick-test-result');
    } else {
      Navigator.of(
        context,
      ).pushReplacementNamed('/mobile-refractometry-result');
    }
  }

  MobileRefractometryEyeResult _processEyeData(
    List<Map<String, dynamic>> responses,
  ) {
    if (responses.isEmpty) {
      return MobileRefractometryEyeResult(
        eye: _currentEye,
        sphere: '0.00',
        cylinder: '0.00',
        axis: 0,
        accuracy: '0.0',
        avgBlur: '0.00',
        addPower: '0.00',
      );
    }

    final distResponses = responses.where((r) => r['isNear'] == false).toList();
    final nearResponses = responses.where((r) => r['isNear'] == true).toList();

    final result = AdvancedRefractionService.calculateFullAssessment(
      distanceResponses: distResponses,
      nearResponses: nearResponses,
      age: _patientAge,
      eye: _currentEye,
    );

    return result.modelResult;
  }

  String _getSnellenScore(double fontSize) {
    for (final level in TestConstants.mobileRefractometryLevels) {
      if ((fontSize - level.fontSize).abs() < 0.1) {
        return level.snellen;
      }
    }
    return '6/6';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showPauseDialog();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        appBar: MediaQuery.of(context).orientation == Orientation.landscape
            ? null
            : AppBar(
                backgroundColor: context.surface,
                elevation: 0,
                title: Text(
                  'Mobile Refractometry - ${_currentEye.toUpperCase()} Eye',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                centerTitle: false,
                leading: IconButton(
                  icon: Icon(Icons.close, color: context.textPrimary),
                  onPressed: () => _showPauseDialog(),
                ),
              ),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              return Stack(
                children: [
                  if (isLandscape)
                    _buildLandscapeLayout()
                  else
                    _buildPortraitLayout(),

                  // Distance warning overlay
                  DistanceWarningOverlay(
                    isVisible:
                        _isDistanceOk == false &&
                        (_waitingForResponse ||
                            _currentPhase == RefractPhase.relaxation),
                    status: _distanceStatus,
                    currentDistance: _currentDistance,
                    targetDistance: _isNearMode ? 40.0 : 100.0,
                    testType: _isNearMode
                        ? 'refraction_near'
                        : 'refraction_distance',
                    onSkip: () {
                      _skipManager.recordSkip(
                        _isNearMode
                            ? DistanceTestType.shortDistance
                            : DistanceTestType.mobileRefractometry,
                      );
                      _resumeTestAfterDistance();
                    },
                  ),

                  // Distance indicator
                  if ((_currentPhase == RefractPhase.test ||
                          _currentPhase == RefractPhase.relaxation) &&
                      _currentPhase != RefractPhase.calibration)
                    Positioned(
                      right: 12,
                      bottom: isLandscape
                          ? 12
                          : (_currentPhase == RefractPhase.test &&
                                _waitingForResponse)
                          ? 120
                          : 55,
                      child: _buildDistanceIndicator(),
                    ),

                  // Voice Input Overlay
                  if (_currentPhase == RefractPhase.test)
                    VoiceInputOverlay(
                      isActive: _waitingForResponse,
                      vocabulary: const [
                        'up',
                        'down',
                        'left',
                        'right',
                        'blurry',
                        'cannot see',
                      ],
                      onVoiceResult: (text, isFinal) {
                        if (mounted && _waitingForResponse) {
                          _handleVoiceResponse(text, isFinal);
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildInfoBar(isLandscape: false),
        Expanded(child: _buildMainContent()),
        if (_currentPhase == RefractPhase.test) _buildDirectionButtons(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Column(
      children: [
        _buildInfoBar(isLandscape: true),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildMainContent()),
              if (_currentPhase == RefractPhase.test)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.surface,
                      border: Border(
                        left: BorderSide(
                          color: context.border.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: _buildLandscapeDirectionButtons(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_currentPhase) {
      case RefractPhase.instruction:
      case RefractPhase.calibration:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EyeLoader(size: 80),
              const SizedBox(height: 24),
              Text(
                'Initializing Test...',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case RefractPhase.relaxation:
        return _buildRelaxationView();
      case RefractPhase.test:
        if (_showResult) {
          return TestFeedbackOverlay(
            isCorrect: _lastResponse == _currentDirection,
            isBlurry: _lastResponse == EDirection.blurry,
            label: _lastResponse == EDirection.blurry ? 'BLURRY' : null,
          );
        }
        return _buildEView();
      case RefractPhase.complete:
        return const Center(child: EyeLoader(size: 80));
    }
  }

  Widget _buildInfoBar({bool isLandscape = false}) {
    final responses = _currentEye == 'right'
        ? _rightEyeResponses
        : _leftEyeResponses;
    final correctCount = responses.where((r) => r['correct'] == true).length;

    double? currentFontSize;
    if (isLandscape && _currentPhase == RefractPhase.test && !_showResult) {
      final round = _simplifiedProtocol[_currentRound];
      currentFontSize = round.fontSize;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(
          bottom: BorderSide(
            color: context.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (isLandscape && currentFontSize != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color: context.primary.withValues(alpha: 0.08),
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getSnellenScore(currentFontSize),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: context.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: ShapeDecoration(
              color: context.primary.withValues(alpha: 0.08),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'ROUND ${_currentRound + 1}/${_simplifiedProtocol.length}',
              style: TextStyle(
                color: context.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: ShapeDecoration(
              color: context.success.withValues(alpha: 0.08),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '$correctCount/${responses.length}',
              style: TextStyle(
                color: context.success,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: _remainingSeconds <= 2 ? context.error : context.primary,
              ),
              const SizedBox(width: 4),
              Text(
                _isTestPausedForDistance ? 'PAUSED' : '${_remainingSeconds}s',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _remainingSeconds <= 2
                      ? context.error
                      : context.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationView() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
                  Expanded(
                    flex: 12,
                    child: _buildRelaxationHero(isLandscape: true),
                  ),
                  const SizedBox(width: 32),
                  Expanded(flex: 5, child: _buildRelaxationInstructions()),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildRelaxationHero(isLandscape: false),
                  const SizedBox(height: 70),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildRelaxationInstructions(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRelaxationHero({required bool isLandscape}) {
    return Builder(
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final imageHeight = isLandscape
            ? screenHeight * 0.8
            : screenHeight * 0.68;

        return Align(
          alignment: isLandscape ? Alignment.centerLeft : Alignment.topCenter,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: isLandscape
                ? Alignment.centerRight
                : Alignment.bottomCenter,
            children: [
              Container(
                margin: EdgeInsets.only(right: isLandscape ? 50 : 0),
                child: _buildRelaxationImage(
                  isLandscape: isLandscape,
                  height: imageHeight,
                ),
              ),
              Positioned(
                right: isLandscape ? 0 : null,
                bottom: isLandscape ? null : -50,
                child: _buildRelaxationTimer(),
              ),
            ],
          ),
        );
      },
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

  Widget _buildRelaxationInstructions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Relax and focus on the distance',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEView() {
    final round = _simplifiedProtocol[_currentRound];
    final currentFontSize = round.fontSize;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        Column(
          children: [
            if (!isLandscape)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: context.border.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: context.primary.withValues(alpha: 0.08),
                        shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        round.snellen,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.primary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: _remainingSeconds <= 2
                              ? context.error
                              : context.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_remainingSeconds}s',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _remainingSeconds <= 2
                                ? context.error
                                : context.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                color: AppColors.white,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.2, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: KeyedSubtree(
                      key: ValueKey('${_currentRound}_$_isNearMode'),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Transform.rotate(
                            angle:
                                _currentDirection.rotationDegrees *
                                math.pi /
                                180,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: _currentBlur,
                                sigmaY: _currentBlur,
                              ),
                              child: _buildRefractCharacter(
                                _activeRoundLabel,
                                currentFontSize,
                                _currentBlur,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildInstructionText(),
          ],
        ),
        if (_showResult)
          Positioned(
            top: 20,
            right: 20,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value * 1.2,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (_isLastCorrect ?? false)
                          ? AppColors.success.withValues(alpha: 0.9)
                          : AppColors.error.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      (_isLastCorrect ?? false) ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildInstructionText() {
    final provider = context.watch<TestSessionProvider>();
    final isPractitioner = provider.profileType == 'patient';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isPractitioner)
            Icon(
              Icons.mic,
              size: 16,
              color: _isTestPausedForDistance
                  ? AppColors.warning
                  : AppColors.success,
            ),
          if (!isPractitioner) const SizedBox(width: 8),
          Text(
            _isTestPausedForDistance
                ? 'Adjust distance'
                : 'Which way is the gap pointing?',
            style: TextStyle(
              color: _isTestPausedForDistance
                  ? AppColors.warning
                  : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: _isTestPausedForDistance
                  ? FontWeight.bold
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefractCharacter(String label, double fontSize, double blur) {
    final bool isHighBlur = blur >= 3.0;

    if (label == 'E' && isHighBlur) {
      return Text(
        'E',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: AppColors.black,
          height: 0.8,
          letterSpacing: -fontSize * 0.1,
          fontFamily: 'Inter',
        ),
      );
    }

    if (label == 'C' && isHighBlur) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'C',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
              height: 1.0,
              fontFamily: 'Inter',
            ),
          ),
          Transform.rotate(
            angle: 8 * math.pi / 180,
            child: Text(
              'C',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
                height: 1.0,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Transform.rotate(
            angle: -8 * math.pi / 180,
            child: Text(
              'C',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
                height: 1.0,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: AppColors.black,
        height: 1.0,
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _buildDirectionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
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
          _DirectionButton(
            direction: EDirection.up,
            onPressed: () => _handleResponse(EDirection.up),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DirectionButton(
                direction: EDirection.left,
                onPressed: () => _handleResponse(EDirection.left),
              ),
              const SizedBox(width: 80),
              _DirectionButton(
                direction: EDirection.right,
                onPressed: () => _handleResponse(EDirection.right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DirectionButton(
            direction: EDirection.down,
            onPressed: () => _handleResponse(EDirection.down),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleResponse(EDirection.blurry),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
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
        double calcButtonSize = availableHeight / 5.2;
        final buttonSize = calcButtonSize.clamp(40.0, 72.0);
        final iconSize = buttonSize * 0.5;
        final gap = (buttonSize / 6).clamp(4.0, 12.0);
        final horizontalGap = (buttonSize * 1.2).clamp(40.0, 100.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: context.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DirectionButton(
                  direction: EDirection.up,
                  size: buttonSize,
                  iconSize: iconSize,
                  onPressed: () => _handleResponse(EDirection.up),
                ),
                SizedBox(height: gap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DirectionButton(
                      direction: EDirection.left,
                      size: buttonSize,
                      iconSize: iconSize,
                      onPressed: () => _handleResponse(EDirection.left),
                    ),
                    SizedBox(width: horizontalGap),
                    _DirectionButton(
                      direction: EDirection.right,
                      size: buttonSize,
                      iconSize: iconSize,
                      onPressed: () => _handleResponse(EDirection.right),
                    ),
                  ],
                ),
                SizedBox(height: gap),
                _DirectionButton(
                  direction: EDirection.down,
                  size: buttonSize,
                  iconSize: iconSize,
                  onPressed: () => _handleResponse(EDirection.down),
                ),
                SizedBox(height: gap * 2),
                SizedBox(
                  width: buttonSize * 3.5,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleResponse(EDirection.blurry),
                    icon: Icon(
                      Icons.visibility_off_rounded,
                      size: iconSize * 0.6,
                      color: context.primary,
                    ),
                    label: Text(
                      "BLURRY",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      side: BorderSide(
                        color: context.primary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: context.primary.withValues(alpha: 0.05),
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

  Widget _buildDistanceIndicator() {
    final target = _isNearMode ? 40.0 : 100.0;
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      target,
      testType: _isNearMode ? 'refraction_near' : 'refraction_distance',
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

  void _restartTest() {
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _distanceService.stopMonitoring();

    setState(() {
      _currentRound = 0;
      _currentBlur = TestConstants.initialBlurLevel;
      _waitingForResponse = false;
      _showResult = false;
      _isTestPausedForDistance = false;
      _lastShouldPauseTime = null;

      if (_currentEye == 'right') {
        _rightEyeResponses.clear();
      } else {
        _leftEyeResponses.clear();
      }
    });

    _startContinuousDistanceMonitoring();
    _startRelaxation();
  }

  void _showPauseDialog({String reason = 'back button'}) {
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _relaxationProgressController.stop();
    _distanceService.stopMonitoring();

    setState(() {
      _isTestPausedForDistance = true;
    });

    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissal by tapping outside
      builder: (dialogContext) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          onContinue: () {
            Navigator.of(
              dialogContext,
            ).pop(); // Ensure manual pop triggers .then
          },
          onRestart: () {
            _restartTest();
          },
          onExit: () async {
            await NavigationUtils.navigateHome(context);
          },
          hasCompletedTests: provider.hasAnyCompletedTest,
          onSaveAndExit: provider.hasAnyCompletedTest
              ? () {
                  Navigator.pushReplacementNamed(context, '/quick-test-result');
                }
              : null,
        );
      },
    ).then((_) {
      // Act like "Continue" was clicked upon dismissal
      if (mounted && _isTestPausedForDistance) {
        setState(() => _isTestPausedForDistance = false);
        _startContinuousDistanceMonitoring();
        if (_currentPhase == RefractPhase.test && _waitingForResponse) {
          _startRoundTimer();
        } else if (_currentPhase == RefractPhase.relaxation) {
          _startRelaxationTimer();
        }
      }
    });
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
        return Icons.visibility_off;
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
            blurRadius: size * 0.15,
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
