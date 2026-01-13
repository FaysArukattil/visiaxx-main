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
import '../../../core/utils/distance_helper.dart';
import '../../../core/widgets/eye_loader.dart';
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
    with WidgetsBindingObserver {
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

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
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
    if (!mounted || _currentPhase == RefractPhase.complete) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _currentPhase != RefractPhase.complete) {
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
              .canShowDistanceWarning(DistanceTestType.shortDistance)
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
    setState(() => _isTestPausedForDistance = true);
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _continuousSpeech.stop();
    HapticFeedback.mediumImpact();
  }

  void _resumeTestAfterDistance() {
    setState(() => _isTestPausedForDistance = false);

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
    // ✅ Stop mic during relaxation (matches VA)
    _continuousSpeech.stop();
    _continuousSpeech.clearAccumulated();

    setState(() {
      _currentPhase = RefractPhase.relaxation;
      _relaxationCountdown = TestConstants.relaxationDurationSeconds;
      _lastDetectedSpeech = null;
      _isSpeechActive = false;
    });

    _ttsService.speak(TtsService.relaxationInstruction);
    _startRelaxationTimer();
  }

  void _startRelaxationTimer() {
    _relaxationTimer?.cancel();
    _relaxationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isTestPausedForDistance) return; // Don't decrement if paused

      setState(() => _relaxationCountdown--);

      if (_relaxationCountdown <= 0) {
        timer.cancel();
        _startRound(); // Check completion and distance before generating E
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
    // ✅ Clear state before generating new E (mic already stopped in relaxation)
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

    // ✅ MATCHES VA: Small delay then start mic
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
        // ✅ MATCHES VA: Rotate E at same size instead of scoring as incorrect
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

    // ✅ ULTRA-CRITICAL: STOP MICROPHONE IMMEDIATELY to prevent carryover
    _continuousSpeech.stop();
    _continuousSpeech.clearAccumulated();
    _speechEraserTimer?.cancel();
    _speechActiveTimer?.cancel();

    final correct = response == _currentDirection;
    final isCantSee = response == EDirection.blurry;

    // ✅ TTS Feedback - MATCHES VA EXACTLY
    if (correct) {
      _ttsService.speakCorrect(response?.label ?? 'None');
    } else if (isCantSee) {
      // For blurry, just say the response was heard but don't say correct/incorrect
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
      // Don't clear _lastDetectedSpeech immediately so it stays visible during result display
      _isSpeechActive = false;
    });

    // ✅ MATCHES VA: 400ms result display, then relaxation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _showResult = false;
        _currentRound++;
      });
      // ✅ Start relaxation BEFORE next E (matches VA flow)
      _startRelaxation();
    });
  }

  void _finishEye() {
    if (_currentEye == 'right') {
      // Reset for left eye
      setState(() {
        _currentEye = 'left';
        _currentRound = 0;
        _currentBlur = TestConstants.initialBlurLevel;
        _currentPhase = RefractPhase.instruction;
      });

      // Show left eye instruction AFTER state update
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CoverRightEyeInstructionScreen(
              title: 'Mobile Refractometry',
              subtitle: 'Focus with your LEFT eye only',
              ttsMessage:
                  'Cover your right eye. Keep your left eye open. We will measure your refraction.',
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
      overallInterpretation: pathology['interpretation'] as String,
    );

    context.read<TestSessionProvider>().setMobileRefractometryResult(
      finalResult,
    );
    Navigator.of(context).pushReplacementNamed('/quick-test-result');
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
    VisualAcuityLevel closest = TestConstants.visualAcuityLevels[0];
    double minDiff = (fontSize - closest.flutterFontSize).abs();

    for (var level in TestConstants.visualAcuityLevels) {
      double diff = (fontSize - level.flutterFontSize).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = level;
      }
    }
    return closest.snellen;
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
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Mobile Refractometry ${_currentEye.toUpperCase()}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          centerTitle: true,
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
              if (_isTestPausedForDistance) _buildDistanceWarningOverlay(),
              // Distance indicator (bottom right corner) - MATCHES VA
              if (_currentPhase == RefractPhase.test &&
                  !_isTestPausedForDistance)
                Positioned(
                  right: 12,
                  bottom: _waitingForResponse ? 120 : 12,
                  child: _buildDistanceIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    // Count total correct responses for this eye
    final responses = _currentEye == 'right'
        ? _rightEyeResponses
        : _leftEyeResponses;
    final correctCount = responses.where((r) => r['correct'] == true).length;

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
          // Level/Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_currentEye[0].toUpperCase()}$_currentRound/${TestConstants.mobileRefractometryMaxRounds}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Score indicator
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
              '$correctCount/${responses.length}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          // Speech waveform
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
                  isListening:
                      _continuousSpeech.shouldBeListening &&
                      !_continuousSpeech.isPausedForTts,
                  isTalking: _isSpeechActive,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                const Icon(Icons.mic, size: 14, color: AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceWarningOverlay() {
    final targetDistance = _isNearMode ? 40.0 : 100.0;
    final pauseReason = DistanceHelper.getPauseReason(
      _distanceStatus,
      targetDistance,
    );
    final instruction = DistanceHelper.getDetailedInstruction(targetDistance);

    final icon = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? Icons.face_retouching_off
        : Icons.warning_rounded;

    final iconColor = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? AppColors.error
        : AppColors.warning;

    return Container(
      color: AppColors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 60, color: iconColor),
              const SizedBox(height: 16),
              Text(
                pauseReason,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (DistanceHelper.isFaceDetected(_distanceStatus)) ...[
                Text(
                  _currentDistance > 0
                      ? 'Current: ${_currentDistance.toStringAsFixed(0)}cm'
                      : 'Calculating distance...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Target: ${targetDistance.toStringAsFixed(0)}cm',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else
                const Text(
                  'Please face the camera',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error,
                  ),
                ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  _skipManager.recordSkip(DistanceTestType.shortDistance);
                  setState(() => _isTestPausedForDistance = false);
                  if (_currentPhase == RefractPhase.test &&
                      _waitingForResponse) {
                    _startRoundTimer();
                    _continuousSpeech.start();
                  } else if (_currentPhase == RefractPhase.relaxation) {
                    _startRelaxationTimer();
                  }
                },
                child: const Text(
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

  Widget _buildMainContent() {
    if (_isTestPausedForDistance) return _buildDistanceWarning();

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
        return const Center(child: EyeLoader(size: 60));
      case RefractPhase.relaxation:
        return _buildRelaxationView();
      case RefractPhase.test:
        return _buildEView();
      case RefractPhase.complete:
        return const Center(child: EyeLoader(size: 80));
    }
  }

  Widget _buildDistanceWarning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: AppColors.warning),
          const SizedBox(height: 24),
          const Text(
            'Check Distance',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please hold the device at ${_isNearMode ? "40" : "100"} cm',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 32),
          Text(
            'Current Distance: ${_currentDistance.toStringAsFixed(1)} cm',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationView() {
    return Container(
      color: AppColors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
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
                        Icon(
                          Icons.landscape,
                          size: 80,
                          color: AppColors.primary,
                        ),
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
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Relax and focus on the distance',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: Center(
                    child: Text(
                      '$_relaxationCountdown',
                      style: const TextStyle(
                        color: AppColors.white,
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
        // Timer and Distance indicator row - MATCHES VA
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.surface.withValues(alpha: 0.9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Distance/Mode indicator on LEFT
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
                    const Icon(
                      Icons.straighten,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getSnellenScore(currentFontSize),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          _isNearMode ? 'NEAR (40cm)' : 'LONG (100cm)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
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
                    color: _remainingSeconds <= 1
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_remainingSeconds}s',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds <= 1
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // E Display - MATCHES VA (no extra container, just centered)
        Expanded(
          child: _showResult
              ? Center(
                  child: Icon(
                    _lastResponse == _currentDirection
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: _lastResponse == _currentDirection
                        ? AppColors.success
                        : AppColors.error,
                    size: 100,
                  ),
                )
              : Center(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: _currentBlur,
                      sigmaY: _currentBlur,
                    ),
                    child: Transform.rotate(
                      angle: _currentDirection.rotationDegrees * math.pi / 180,
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
        // Speech recognition bubble - MATCHES VA
        if (_lastDetectedSpeech != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
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
              ),
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
              const SizedBox(width: 60),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleResponse(EDirection.blurry),
              icon: const Icon(Icons.visibility_off, size: 20),
              label: const Text(
                "Can't See Clearly / Blurry",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
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

  void _showPauseDialog({String reason = 'back button'}) {
    _roundTimer?.cancel();
    _relaxationTimer?.cancel();
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Test Paused'),
          ],
        ),
        content: Text(
          reason == 'minimized'
              ? 'The test was paused because the app was minimized.'
              : 'What would you like to do?',
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  setState(() => _isTestPausedForDistance = false);
                  _startContinuousDistanceMonitoring();
                  if (_currentPhase == RefractPhase.test &&
                      _waitingForResponse) {
                    _continuousSpeech.start();
                    _startRoundTimer();
                  } else if (_currentPhase == RefractPhase.relaxation) {
                    _startRelaxationTimer();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Continue Test'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await NavigationUtils.navigateHome(context);
                },
                child: const Text(
                  'Exit and Lose Progress',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
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
      case EDirection.blurry:
        return Icons.visibility_off;
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
          child: Icon(_icon, color: AppColors.white, size: 32),
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
