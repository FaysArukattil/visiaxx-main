import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/continuous_speech_manager.dart';
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
import '../services/refraction_logic.dart';
import './mobile_refractometry_instructions_screen.dart';

/// Refractometry phases
enum RefractPhase { instruction, calibration, relaxation, test, complete }

class MobileRefractometryTestScreen extends StatefulWidget {
  const MobileRefractometryTestScreen({super.key});

  @override
  State<MobileRefractometryTestScreen> createState() =>
      _MobileRefractometryTestScreenState();
}

class _MobileRefractometryTestScreenState
    extends State<MobileRefractometryTestScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Services
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  late ContinuousSpeechManager _continuousSpeech;

  // State Management
  RefractPhase _currentPhase = RefractPhase.instruction;
  String _currentEye = 'right';
  bool _isNearMode = false;
  int _currentRound = 0;
  double _currentBlur = TestConstants.initialBlurLevel;
  EDirection _currentDirection = EDirection.right;
  bool _waitingForResponse = false;
  bool _showResult = false;
  bool _instructionShown = false;
  EDirection? _lastResponse;
  final DistanceSkipManager _skipManager = DistanceSkipManager();
  DateTime? _eDisplayStartTime;

  // Data storage
  final List<Map<String, dynamic>> _rightEyeResponses = [];
  final List<Map<String, dynamic>> _leftEyeResponses = [];

  // Timing
  Timer? _roundTimer;
  int _remainingSeconds = TestConstants.mobileRefractometryTimePerRoundSeconds;

  // Relaxation
  int _relaxationCountdown = TestConstants.mobileRefractometryRelaxationSeconds;
  Timer? _relaxationTimer;
  late AnimationController
  _relaxationProgressController; // … NEW: Smooth animation

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = true;
  final bool _isCalibrationActive = false;
  bool _isTestPausedForDistance = false;
  DateTime? _lastShouldPauseTime;
  static const Duration _distancePauseDebounce = Duration(milliseconds: 1000);

  // Voice recognition feedback
  bool _isSpeechActive = false;
  String? _lastDetectedSpeech;
  Timer? _speechActiveTimer;
  Timer? _speechEraserTimer;

  // Age management
  int _patientAge = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _continuousSpeech = ContinuousSpeechManager(_speechService);

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
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    _continuousSpeech.onFinalResult = _handleVoiceResponse;
    _continuousSpeech.onSpeechDetected = _handleSpeechDetected;
    _continuousSpeech.onListeningStateChanged = (isListening) {
      if (mounted) setState(() {});
    };

    _ttsService.onSpeakingStateChanged = (isSpeaking) {
      if (isSpeaking) {
        _continuousSpeech.pauseForTts();
      } else {
        _continuousSpeech.resumeAfterTts();
      }
    };

    if (mounted) {
      final provider = context.read<TestSessionProvider>();
      _patientAge = provider.profileAge ?? 30;
      _startDistanceCalibration(TestConstants.mobileRefractometryDistanceCm);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relaxationProgressController.dispose();
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _speechActiveTimer?.cancel();
    _speechEraserTimer?.cancel();
    _continuousSpeech.stop();
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
    _continuousSpeech.stop();
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
            Navigator.of(context).pop();
            _onInstructionComplete();
          },
        ),
      ),
    );
  }

  void _onInstructionComplete() {
    // Sequence: Calibration -> General Instruction -> Eye Instruction
    _showEyeInstructionStage();
  }

  void _showEyeInstructionStage() {
    // Show eye instruction after calibration for the first eye
    if (_currentEye == 'right' && _currentRound == 0 && !_isNearMode) {
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
              Navigator.of(context).pop();
              _startRelaxation();
            },
          ),
        ),
      );
    } else {
      _startRelaxation();
    }
  }

  void _startDistanceCalibration(double targetCm) {
    setState(() {
      _currentPhase = RefractPhase.calibration;
      _isNearMode = targetCm <= 45.0;
    });

    _continuousSpeech.stop();
    _distanceService.stopMonitoring();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: targetCm,
          toleranceCm: TestConstants.mobileRefractometryToleranceCm,
          onCalibrationComplete: () {
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

    final testTypeForHelper = _isNearMode ? 'short_distance' : 'visual_acuity';
    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      testTypeForHelper,
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
      _isDistanceOk = false; // Mark distance as not OK when paused
    });
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _continuousSpeech.stop();
    HapticFeedback.mediumImpact();
  }

  void _resumeTestAfterDistance() {
    setState(() {
      _isTestPausedForDistance = false;
      _isDistanceOk = true;
      _lastShouldPauseTime = null;
    });

    // No need to restart distance monitoring as it's already running!
    // Re-initialization (via _startContinuousDistanceMonitoring) causes "Searching..." stall.

    if (_currentPhase == RefractPhase.test && _waitingForResponse) {
      if (!_continuousSpeech.isActive) _continuousSpeech.start();
      _startRoundTimer();
    } else if (_currentPhase == RefractPhase.relaxation) {
      _startRelaxationTimer();
    }
    HapticFeedback.mediumImpact();
  }

  void _startRelaxation() {
    debugPrint('[MobileRefract] Starting relaxation phase');
    _continuousSpeech.stop();
    _continuousSpeech.clearAccumulated();

    setState(() {
      _currentPhase = RefractPhase.relaxation;
      _relaxationCountdown = TestConstants.mobileRefractometryRelaxationSeconds;
      _lastDetectedSpeech = null;
      _isSpeechActive = false;
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

    // Start/Resume smooth animation
    _relaxationProgressController.forward();

    _relaxationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isTestPausedForDistance) {
        _relaxationProgressController.stop();
        return;
      }

      setState(() => _relaxationCountdown--);

      if (_relaxationCountdown <= 0) {
        timer.cancel();
        // … FALLBACK: Transition phase if animation listener fails
        if (_currentPhase == RefractPhase.relaxation) {
          _startRound();
        }
      }
    });
  }

  void _startRound() {
    if (_currentRound > TestConstants.mobileRefractometryMaxRounds) {
      _finishEye();
      return;
    }

    // Ensure phase is updated to test when round starts
    if (_currentPhase != RefractPhase.test) {
      setState(() => _currentPhase = RefractPhase.test);
    }

    final shouldBeNear = _shouldBeNearAtRound(_patientAge, _currentRound);
    if (shouldBeNear && !_isNearMode) {
      _showDistanceSwitchOverlay(true);
      return;
    } else if (!shouldBeNear && _isNearMode) {
      _showDistanceSwitchOverlay(false);
      return;
    }

    _generateNewRound();
  }

  bool _shouldBeNearAtRound(int age, int round) {
    if (age < 40) return false;
    if (age < 50) {
      if (round <= 6) return false;
      if (round <= 12) return true;
      return round % 2 == 0;
    } else if (age < 60) {
      if (round <= 5) return false;
      if (round <= 14) return true;
      return round % 2 == 0;
    } else {
      if (round <= 4) return false;
      if (round <= 16) return true;
      return round % 2 == 0;
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

  void _generateNewRound() {
    _lastDetectedSpeech = null;
    _isSpeechActive = false;
    _eDisplayStartTime = null;

    final directions = [
      EDirection.up,
      EDirection.down,
      EDirection.left,
      EDirection.right,
    ].where((d) => d != _currentDirection).toList();
    _currentDirection = directions[math.Random().nextInt(directions.length)];

    setState(() {
      _currentPhase = RefractPhase.test;
      _remainingSeconds = TestConstants.mobileRefractometryTimePerRoundSeconds;
      _waitingForResponse = true;
      _showResult = false;
      _lastDetectedSpeech = null;
      _isSpeechActive = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _eDisplayStartTime = DateTime.now();
      _startRoundTimer();
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.15,
        bufferMs: 1000,
      );
    });
  }

  void _startRoundTimer() {
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) return;

      setState(() => _remainingSeconds--);

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _generateNewRound();
      }
    });
  }

  void _handleVoiceResponse(String finalResult) {
    if (_currentPhase != RefractPhase.test || !_waitingForResponse) return;
    final direction = SpeechService.parseDirection(finalResult);
    if (direction != null) {
      _handleResponse(EDirection.fromString(direction));
    }
  }

  void _handleSpeechDetected(String partialResult) {
    if (!mounted) return;
    setState(() {
      _lastDetectedSpeech = partialResult;
      _isSpeechActive = true;
    });

    if (_currentPhase == RefractPhase.test && _waitingForResponse) {
      if (_eDisplayStartTime != null) {
        final sinceStart = DateTime.now().difference(_eDisplayStartTime!);
        if (sinceStart < const Duration(milliseconds: 1500)) return;
      }

      final direction = SpeechService.parseDirection(partialResult);
      if (direction != null) {
        _handleResponse(EDirection.fromString(direction));
        return;
      }

      final norm = partialResult.toLowerCase();
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
        if (norm.contains(keyword)) {
          _handleResponse(EDirection.blurry);
          return;
        }
      }
    }

    _speechActiveTimer?.cancel();
    _speechActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isSpeechActive = false);
    });

    _speechEraserTimer?.cancel();
    _speechEraserTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _lastDetectedSpeech = null);
    });
  }

  void _handleResponse(EDirection? response) {
    if (!_waitingForResponse || _showResult) return;
    _waitingForResponse = false;
    _roundTimer?.cancel();

    _continuousSpeech.stop();
    _continuousSpeech.clearAccumulated();
    _speechEraserTimer?.cancel();
    _speechActiveTimer?.cancel();

    final correct = response == _currentDirection;
    final isCantSee = response == EDirection.blurry;

    if (correct) {
      _ttsService.speakCorrect(response?.label ?? 'None');
    } else if (isCantSee) {
      _ttsService.speak('Cannot see');
    } else if (response != null) {
      _ttsService.speakIncorrect(response.label);
    }

    final responseRecord = {
      'round': _currentRound,
      'blur': _currentBlur,
      'correct': correct,
      'isCantSee': isCantSee,
      'isNear': _isNearMode,
      'direction': _currentDirection,
      'responseTime': _eDisplayStartTime != null
          ? DateTime.now().difference(_eDisplayStartTime!).inMilliseconds
          : 0,
    };

    if (_currentEye == 'right') {
      _rightEyeResponses.add(responseRecord);
    } else {
      _leftEyeResponses.add(responseRecord);
    }

    if (correct) {
      _currentBlur = math.min(
        TestConstants.maxBlurLevel,
        _currentBlur + TestConstants.blurIncrementOnCorrect,
      );
    } else if (isCantSee) {
      _currentBlur = math.max(
        TestConstants.minBlurLevel,
        _currentBlur - TestConstants.blurDecrementOnCantSee,
      );
    } else {
      _currentBlur = math.max(
        TestConstants.minBlurLevel,
        _currentBlur - TestConstants.blurDecrementOnWrong,
      );
    }

    setState(() {
      _lastResponse = response;
      _showResult = true;
      _isSpeechActive = false;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _showResult = false;
        _currentRound++;
      });
      _startRelaxation();
    });
  }

  void _finishEye() {
    if (_currentEye == 'right') {
      setState(() {
        _currentEye = 'left';
        _currentRound = 0;
        _currentBlur = TestConstants.initialBlurLevel;
        _currentPhase = RefractPhase.instruction;
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
    setState(() => _currentPhase = RefractPhase.complete);

    final rightResults = _processEyeData(_rightEyeResponses);
    final leftResults = _processEyeData(_leftEyeResponses);

    final pathology = RefractionLogic.screenForPathology(
      ((rightResults['accuracy'] as double) +
              (leftResults['accuracy'] as double)) /
          2,
      ((rightResults['cantSeeCount'] as int) +
          (leftResults['cantSeeCount'] as int)),
      _patientAge,
    );

    final finalResult = MobileRefractometryResult(
      patientAge: _patientAge,
      rightEye: MobileRefractometryEyeResult(
        eye: 'right',
        sphere: rightResults['sphere'] as String,
        cylinder: rightResults['cylinder'] as String,
        axis: rightResults['axis'] as int,
        accuracy: ((rightResults['accuracy'] as double) * 100).toStringAsFixed(
          1,
        ),
        avgBlur: (rightResults['threshold'] as double).toStringAsFixed(2),
        addPower: rightResults['add'] as String,
      ),
      leftEye: MobileRefractometryEyeResult(
        eye: 'left',
        sphere: leftResults['sphere'] as String,
        cylinder: leftResults['cylinder'] as String,
        axis: leftResults['axis'] as int,
        accuracy: ((leftResults['accuracy'] as double) * 100).toStringAsFixed(
          1,
        ),
        avgBlur: (leftResults['threshold'] as double).toStringAsFixed(2),
        addPower: leftResults['add'] as String,
      ),
      isAccommodating:
          (rightResults['isAccommodating'] as bool) ||
          (leftResults['isAccommodating'] as bool),
      healthWarnings: (pathology['identifiedRisks'] as List)
          .map((e) => (e['conditionName'] as String))
          .toList(),
      identifiedRisks: List<Map<String, dynamic>>.from(
        pathology['identifiedRisks'],
      ),
      criticalAlert: pathology['criticalAlert'] as bool,
      overallInterpretation: pathology['interpretation'] as String? ?? 'Normal',
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

  Map<String, dynamic> _processEyeData(List<Map<String, dynamic>> responses) {
    if (responses.isEmpty) return _emptyEyeResult();

    final correctResponses = responses
        .where((r) => r['correct'] == true)
        .toList();
    final cantSeeCount = responses.where((r) => r['isCantSee'] == true).length;
    final accuracy = correctResponses.length / responses.length;

    final distResponses = responses.where((r) => r['isNear'] == false).toList();
    final nearResponses = responses.where((r) => r['isNear'] == true).toList();

    double distThreshold = _calculateThreshold(distResponses);
    double sphere = RefractionLogic.calculateSphereFromThreshold(distThreshold);
    double adj = RefractionLogic.calculateAccommodationAdjustment(
      _patientAge,
      sphere,
      accuracy,
    );
    sphere += adj;

    final hAcc = _calcDirectionalAccuracy(responses, [
      EDirection.left,
      EDirection.right,
    ]);
    final vAcc = _calcDirectionalAccuracy(responses, [
      EDirection.up,
      EDirection.down,
    ]);
    final cylData = RefractionLogic.calculateCylinder(hAcc, vAcc);

    double baseAdd = TestConstants.calculateAddPower(_patientAge);
    double nearAcc = nearResponses.isEmpty
        ? 1.0
        : nearResponses.where((r) => r['correct']).length /
              nearResponses.length;
    double finalAdd = RefractionLogic.refineAddPower(baseAdd, nearAcc);

    return {
      'sphere': _formatDiopter(sphere),
      'cylinder': _formatDiopter(cylData['cylinder'] as double),
      'axis': cylData['axis'] as int,
      'accuracy': accuracy,
      'threshold': distThreshold,
      'add': _formatDiopter(finalAdd),
      'isAccommodating': adj != 0,
      'cantSeeCount': cantSeeCount,
    };
  }

  double _calculateThreshold(List<Map<String, dynamic>> rounds) {
    if (rounds.isEmpty) return 0.0;
    double maxSuccessBlur = 0.0;
    double minFailBlur = TestConstants.maxBlurLevel;
    bool hadFail = false;

    for (var r in rounds) {
      if (r['correct'] == true) {
        maxSuccessBlur = math.max(maxSuccessBlur, r['blur'] as double);
      } else {
        minFailBlur = math.min(minFailBlur, r['blur'] as double);
        hadFail = true;
      }
    }
    return hadFail ? (maxSuccessBlur + minFailBlur) / 2 : maxSuccessBlur;
  }

  double _calcDirectionalAccuracy(
    List<Map<String, dynamic>> responses,
    List<EDirection> dirs,
  ) {
    final filtered = responses
        .where((r) => dirs.contains(r['direction'] as EDirection))
        .toList();
    if (filtered.isEmpty) return 1.0;
    return filtered.where((r) => r['correct'] == true).length / filtered.length;
  }

  Map<String, dynamic> _emptyEyeResult() => {
    'sphere': '0.00',
    'cylinder': '0.00',
    'axis': 0,
    'accuracy': 0.0,
    'threshold': 0.0,
    'add': '0.00',
    'isAccommodating': false,
    'cantSeeCount': 0,
  };

  String _formatDiopter(double val) =>
      (val >= 0 ? '+' : '') + val.toStringAsFixed(2);

  String _getSnellenScore(double fontSize) {
    if (_isNearMode) {
      if (fontSize >= 68) return '6/60';
      if (fontSize >= 55) return '6/36';
      if (fontSize >= 40) return '6/24';
      if (fontSize >= 30) return '6/18';
      if (fontSize >= 20) return '6/12';
      if (fontSize >= 15) return '6/9';
      return '6/6';
    } else {
      if (fontSize >= 145) return '6/60';
      if (fontSize >= 115) return '6/48';
      if (fontSize >= 90) return '6/36';
      if (fontSize >= 70) return '6/24';
      if (fontSize >= 52) return '6/18';
      if (fontSize >= 38) return '6/12';
      if (fontSize >= 28) return '6/9';
      return '6/6';
    }
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
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: Text(
            'Mobile Refractometry - ${_currentEye.toUpperCase()} Eye',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => _showPauseDialog(),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildInfoBar(),
                  Expanded(child: _buildMainContent()),
                  if (_currentPhase == RefractPhase.test && _waitingForResponse)
                    _buildDirectionButtons(),
                ],
              ),

              // Recognized text indicator (center bottom above buttons)
              Positioned(
                bottom:
                    (_currentPhase == RefractPhase.test && _waitingForResponse)
                    ? 150
                    : 50,
                left: 0,
                right: 0,
                child: Center(child: _buildRecognizedTextIndicator()),
              ),

              // distance warning overlay
              DistanceWarningOverlay(
                isVisible:
                    _isDistanceOk == false &&
                    (_waitingForResponse ||
                        _currentPhase == RefractPhase.relaxation) &&
                    !_isCalibrationActive,
                status: _distanceStatus,
                currentDistance: _currentDistance,
                targetDistance: _isNearMode ? 40.0 : 100.0,
                onSkip: () {
                  _skipManager.recordSkip(
                    _isNearMode
                        ? DistanceTestType.shortDistance
                        : DistanceTestType.mobileRefractometry,
                  );
                  _resumeTestAfterDistance();
                },
              ),
              // Distance indicator (bottom right corner) - MATCHES VA (ALWAYS SHOWN)
              if ((_currentPhase == RefractPhase.test ||
                      _currentPhase == RefractPhase.relaxation) &&
                  _currentPhase != RefractPhase.calibration)
                Positioned(
                  right: 12,
                  bottom:
                      (_currentPhase == RefractPhase.test &&
                          _waitingForResponse)
                      ? 120
                      : 55,
                  child: _buildDistanceIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentPhase) {
      case RefractPhase.instruction:
        return _currentEye == 'right'
            ? CoverLeftEyeInstructionScreen(
                title: 'Mobile Refractometry',
                onContinue: _onInstructionComplete,
              )
            : CoverRightEyeInstructionScreen(
                title: 'Mobile Refractometry',
                onContinue: () => _startDistanceCalibration(
                  TestConstants.mobileRefractometryDistanceCm,
                ),
              );
      case RefractPhase.calibration:
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

  Widget _buildInfoBar() {
    // Count total correct responses for this eye
    final responses = _currentEye == 'right'
        ? _rightEyeResponses
        : _leftEyeResponses;
    final correctCount = responses.where((r) => r['correct'] == true).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          // Level/Progress indicator - MATCHES VA (1-indexed)
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
              'ROUND ${_currentRound + 1}/${TestConstants.mobileRefractometryMaxRounds}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Score indicator - MATCHES VA
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
              '$correctCount/${responses.length}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          // Speech waveform
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SpeechWaveform(
                  isListening:
                      _continuousSpeech.shouldBeListening &&
                      !_continuousSpeech.isPausedForTts,
                  isTalking: _isSpeechActive,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.mic_none_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationView() {
    return Container(
      color: AppColors.testBackground,
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Hero Card with Image and Overlapping Timer (Maximized)
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Image Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: MediaQuery.of(context).size.height * 0.65,
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
                ),

                // Glassmorphism Smooth Timer
                Positioned(
                  bottom: -45, // Half of timer height (90/2)
                  child: AnimatedBuilder(
                    animation: _relaxationProgressController,
                    builder: (context, child) {
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.15),
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
                                  color: AppColors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value:
                                          _relaxationProgressController.value,
                                      strokeWidth: 4,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppColors.primary,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '$_relaxationCountdown',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
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
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 60,
            ), // Adjusted spacing for large overlapping timer
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

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildEView() {
    // Calculate E size based on round progression
    final baseSize = _isNearMode ? 70.0 : 150.0;
    final minSize = _isNearMode ? 28.0 : 40.0;
    final currentFontSize =
        baseSize -
        ((baseSize - minSize) *
            (_currentRound / TestConstants.mobileRefractometryMaxRounds));

    return Column(
      children: [
        // ✅ PROMINENT Timer and Size indicator row - MATCHES VA EXACTLY
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              // ✅ Size indicator on LEFT
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
                    _getSnellenScore(currentFontSize),
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
                        color: _remainingSeconds <= 2
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isTestPausedForDistance
                            ? 'PAUSED'
                            : '${_remainingSeconds}s',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _remainingSeconds <= 2
                              ? AppColors.error
                              : AppColors.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // E Display - MATCHES VA (Dedicated Expanded Area with FittedBox to prevent clipping)
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Transform.rotate(
                angle: _currentDirection.rotationDegrees * math.pi / 180,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: _currentBlur,
                    sigmaY: _currentBlur,
                  ),
                  child: Text(
                    'E',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: currentFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Instruction text with voice status - MATCHES VA EXACTLY
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_continuousSpeech.isActive)
                    Icon(
                      Icons.mic,
                      size: 20,
                      color: _isTestPausedForDistance
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  if (_continuousSpeech.isActive) const SizedBox(width: 8),
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

  Widget _buildDirectionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
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
              const SizedBox(width: 80), // MATCHES VA
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
          // Blurry/Can't See Clearly button (Proper Button) - MATCHES VA
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleResponse(EDirection.blurry),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildDistanceIndicator() {
    final target = _isNearMode ? 40.0 : 100.0;
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      target,
      testType: _isNearMode ? 'short_distance' : 'visual_acuity',
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

  void _restartTest() {
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();

    setState(() {
      _currentRound = 0;
      _currentBlur = TestConstants.initialBlurLevel;
      _waitingForResponse = false;
      _showResult = false;
      _lastDetectedSpeech = null;
      _isSpeechActive = false;
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
    _relaxationProgressController.stop(); // … Stop smooth animation
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();

    setState(() {
      _isTestPausedForDistance = true; // … Sync with VA behavior
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TestExitConfirmationDialog(
        onContinue: () {
          setState(() => _isTestPausedForDistance = false);
          _startContinuousDistanceMonitoring();
          if (_currentPhase == RefractPhase.test && _waitingForResponse) {
            _continuousSpeech.start();
            _startRoundTimer();
          } else if (_currentPhase == RefractPhase.relaxation) {
            _startRelaxationTimer();
          }
        },
        onRestart: () {
          _restartTest();
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
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
      case EDirection.blurry:
        return Icons.visibility_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
    if (!widget.isListening && !widget.isTalking) {
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
            final phase = (index * 0.3) + _controller.value;
            final height =
                4.0 + (10.0 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi)));
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
