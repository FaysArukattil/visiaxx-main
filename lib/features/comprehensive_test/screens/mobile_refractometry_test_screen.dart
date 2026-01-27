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
// Note: refraction_logic.dart intentionally removed as unused
import './mobile_refractometry_instructions_screen.dart';

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
  final SpeechService _speechService = SpeechService();
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  late ContinuousSpeechManager _continuousSpeech;

  // State Management
  RefractPhase _currentPhase = RefractPhase.instruction;
  String _currentEye = 'right';
  bool _isNearMode = false;
  int _currentRound = 0;
  double _currentBlur = 0.0; // Start with NO blur
  EDirection _currentDirection = EDirection.right;
  bool _waitingForResponse = false;
  bool _showResult = false;
  bool _instructionShown = false;
  EDirection? _lastResponse;
  final DistanceSkipManager _skipManager = DistanceSkipManager();
  DateTime? _eDisplayStartTime;

  // Adaptive blur test state
  int _currentSizeLevel =
      0; // Index into mobileRefractometryLevels (0 = largest 6/60)
  // ignore: unused_field
  int _consecutiveWrongAtLevel = 0; // Track wrong answers at current level

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
  bool _relaxationShownForCurrentEye =
      false; // Only show relaxation once per eye
  bool _isTransitioning = false;

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

    // Check if we are in practitioner mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<TestSessionProvider>();
        if (provider.profileType == 'patient') {
          debugPrint(
            '👨‍⚕️ [MobileRefract] Practitioner mode detected: Silencing Speech globally',
          );
          context.read<SpeechService>().setGloballyDisabled(true);
        }
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

      // START FLOW LOGIC
      if (!widget.showInitialInstructions) {
        // Skip general instructions, go straight to setup
        _instructionShown = true;
        _isTransitioning = true;
        _startDistanceCalibration(TestConstants.mobileRefractometryDistanceCm);
      } else {
        // Standard flow: Start instructions first
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
    _speechActiveTimer?.cancel();
    _speechEraserTimer?.cancel();
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();
    context.read<SpeechService>().setGloballyDisabled(
      false,
    ); // Reset for next session
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

    // Show eye instruction after calibration for the first eye
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
              // Relaxation only at start of eye test, not during distance switch
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
      // Relaxation only at start of eye test, not during distance switch
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

    _continuousSpeech.stop();
    _distanceService.stopMonitoring();

    _isTransitioning = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: targetCm,
          toleranceCm: TestConstants.mobileRefractometryToleranceCm,
          minDistanceCm: targetCm >= 100 ? 60.0 : 35.0,
          maxDistanceCm: 300.0, // Treat as 100+ or 40+
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
      final provider = context.read<TestSessionProvider>();
      if (provider.profileType != 'patient' && !_continuousSpeech.isActive) {
        _continuousSpeech.start();
      }
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
    if (_currentRound >= TestConstants.mobileRefractometryMaxRounds) {
      _finishEye();
      return;
    }

    // Ensure phase is updated to test when round starts
    if (_currentPhase != RefractPhase.test) {
      setState(() => _currentPhase = RefractPhase.test);
    }

    // Get the configuration for the NEXT round (since _currentRound is about to be displayed)
    final nextRoundConfig = TestConstants.getTestRoundConfiguration(
      _currentRound + 1,
      _patientAge,
    );

    final shouldBeNear = nextRoundConfig.testType == TestType.near;

    // Check if we need to switch distance mode
    if (shouldBeNear && !_isNearMode) {
      _showDistanceSwitchOverlay(true);
      return;
    } else if (!shouldBeNear && _isNearMode) {
      _showDistanceSwitchOverlay(false);
      return;
    }

    _generateNewRound();
  }

  // ignore: unused_element
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
    _continuousSpeech
        .clearAccumulated(); // Explicitly clear buffer for new round

    // Generate random direction (different from last)
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
      final provider = context.read<TestSessionProvider>();
      if (provider.profileType != 'patient') {
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
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
    if (!mounted || _currentPhase != RefractPhase.test || !_waitingForResponse)
      return;

    final provider = context.read<TestSessionProvider>();
    if (provider.profileType == 'patient') return;

    // Reject final results arriving too fast after E display (prevent leakage from previous E)
    if (_eDisplayStartTime != null) {
      final sinceStart = DateTime.now().difference(_eDisplayStartTime!);
      if (sinceStart < const Duration(milliseconds: 1500)) {
        debugPrint(
          '[MobileRefract] Ignoring final voice result: arrived too fast after rotation (${sinceStart.inMilliseconds}ms)',
        );
        return;
      }
    }

    final direction = SpeechService.parseDirection(finalResult);
    if (direction != null) {
      _handleResponse(EDirection.fromString(direction));
    }
  }

  void _handleSpeechDetected(String partialResult) {
    if (!mounted) return;

    final provider = context.read<TestSessionProvider>();
    if (provider.profileType == 'patient') return;

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
    _continuousSpeech.clearAccumulated(); // Clear immediately after response
    _speechEraserTimer?.cancel();
    _speechActiveTimer?.cancel();
    setState(() {
      _lastDetectedSpeech = null;
      _isSpeechActive = false;
    });

    final correct = response == _currentDirection;
    final isCantSee = response == EDirection.blurry;

    if (correct) {
      _ttsService.speakCorrect(response?.label ?? 'None');
    } else if (isCantSee) {
      _ttsService.speak('Cannot see');
    } else if (response != null) {
      _ttsService.speakIncorrect(response.label);
    }

    // Get current test configuration
    final testRound = TestConstants.getTestRoundConfiguration(
      _currentRound + 1, // +1 because _currentRound is 0-indexed
      _patientAge,
    );

    final responseRecord = {
      'round': _currentRound + 1,
      'blur': _currentBlur,
      'sizeLevel': _currentSizeLevel,
      'fontSize': testRound.fontSize, // Store actual fontSize used
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

    // ADAPTIVE BLUR LOGIC (like working app)
    if (correct) {
      // Correct: Add blur to make it harder
      _currentBlur = math.min(
        TestConstants.maxBlurLevel,
        _currentBlur + TestConstants.blurIncrementOnCorrect,
      );
      _consecutiveWrongAtLevel = 0;
    } else {
      // Wrong or Can't See: Reduce blur to make it easier
      _consecutiveWrongAtLevel++;
      _currentBlur = math.max(
        TestConstants.minBlurLevel,
        isCantSee
            ? _currentBlur - TestConstants.blurDecrementOnCantSee
            : _currentBlur - TestConstants.blurDecrementOnWrong,
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

      // Check if we should finish this eye
      if (_currentRound >= TestConstants.mobileRefractometryMaxRounds) {
        _finishEye();
      } else {
        _startRound(); // Continue to next round
      }
    });
  }

  void _finishEye() {
    // Prevent duplicate calls if already transitioning or finished
    if (_currentPhase == RefractPhase.complete || _isTransitioning) return;

    _isTransitioning = true;

    if (_currentEye == 'right') {
      if (_currentPhase == RefractPhase.instruction) return;

      setState(() {
        _currentEye = 'left';
        _currentRound = 0;
        _currentBlur = 0.0; // Start with no blur for left eye
        _currentSizeLevel = 0; // Start at largest size
        _consecutiveWrongAtLevel = 0; // Reset consecutive wrong count
        _currentPhase = RefractPhase.instruction;
        _relaxationShownForCurrentEye = false; // Reset for left eye
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
    _continuousSpeech.stop();
    _continuousSpeech.clearAccumulated(); // Clean up before result screen
    setState(() => _currentPhase = RefractPhase.complete);

    final rightResults = _processEyeData(_rightEyeResponses);
    final leftResults = _processEyeData(_leftEyeResponses);

    // Combine all responses for pathology screening
    final allResponses = [..._rightEyeResponses, ..._leftEyeResponses];
    final distResponses = allResponses
        .where((r) => r['isNear'] == false)
        .toList();
    final nearResponses = allResponses
        .where((r) => r['isNear'] == true)
        .toList();

    // Use AdvancedRefractionService for comprehensive screening
    final combinedResult = AdvancedRefractionService.calculateFullAssessment(
      distanceResponses: distResponses,
      nearResponses: nearResponses,
      age: _patientAge,
      eye: 'combined',
    );

    final pathology = combinedResult.diseaseScreening;

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

    // Separate distance and near responses
    final distResponses = responses.where((r) => r['isNear'] == false).toList();
    final nearResponses = responses.where((r) => r['isNear'] == true).toList();

    // Use AdvancedRefractionService for calculation
    final result = AdvancedRefractionService.calculateFullAssessment(
      distanceResponses: distResponses,
      nearResponses: nearResponses,
      age: _patientAge,
      eye: _currentEye,
    );

    final correctResponses = responses
        .where((r) => r['correct'] == true)
        .toList();
    final cantSeeCount = responses.where((r) => r['isCantSee'] == true).length;
    final accuracy = correctResponses.length / responses.length;

    // Extract sphere value for return
    final sphereStr = result.modelResult.sphere;
    // ignore: unused_local_variable
    final sphereVal = double.tryParse(sphereStr.replaceAll('+', '')) ?? 0.0;

    return {
      'sphere': result.modelResult.sphere,
      'cylinder': result.modelResult.cylinder,
      'axis': result.modelResult.axis,
      'accuracy': accuracy,
      'threshold': result.distanceThreshold,
      'add': result.modelResult.addPower,
      'isAccommodating': result.isAccommodating,
      'cantSeeCount': cantSeeCount,
    };
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

  // Formatting moved to AdvancedRefractionService._formatDiopter

  String _getSnellenScore(double fontSize) {
    // Match fontSize to the test configuration levels
    for (final level in TestConstants.mobileRefractometryLevels) {
      if ((fontSize - level.fontSize).abs() < 0.1) {
        // Allow small floating point differences
        return level.snellen;
      }
    }
    // Fallback
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
        backgroundColor: AppColors.testBackground,
        appBar: MediaQuery.of(context).orientation == Orientation.landscape
            ? null
            : AppBar(
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
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              return Stack(
                children: [
                  if (isLandscape)
                    _buildLandscapeLayout()
                  else
                    _buildPortraitLayout(),

                  // Recognized text indicator
                  Positioned(
                    bottom: isLandscape
                        ? 20
                        : (_currentPhase == RefractPhase.test &&
                              _waitingForResponse)
                        ? 150
                        : 50,
                    left: isLandscape ? 20 : 0,
                    right: isLandscape ? null : 0,
                    width: isLandscape ? 300 : null,
                    child: Center(child: _buildRecognizedTextIndicator()),
                  ),

                  // Distance warning overlay
                  DistanceWarningOverlay(
                    isVisible:
                        _isDistanceOk == false &&
                        (_waitingForResponse ||
                            _currentPhase == RefractPhase.relaxation) &&
                        !_isCalibrationActive,
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
        _buildInfoBar(),
        Expanded(child: _buildMainContent()),
        if (_currentPhase == RefractPhase.test && _waitingForResponse)
          _buildDirectionButtons(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    // 50/50 split layout matching Visual Acuity
    return Row(
      children: [
        // Left side: Info bar + Main content (E view or relaxation)
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildInfoBar(),
              Expanded(child: _buildMainContent()),
            ],
          ),
        ),
        // Right side: Direction buttons (when waiting for response)
        if (_currentPhase == RefractPhase.test && _waitingForResponse)
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border(
                  left: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: _buildLandscapeDirectionButtons(),
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_currentPhase) {
      case RefractPhase.instruction:
      case RefractPhase.calibration:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EyeLoader(size: 80),
              SizedBox(height: 24),
              Text(
                'Initializing Test...',
                style: TextStyle(
                  color: AppColors.textSecondary,
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
                  // Left Side: Image and Overlapping Timer
                  Expanded(
                    flex: 12,
                    child: _buildRelaxationHero(isLandscape: true),
                  ),
                  const SizedBox(width: 32),
                  // Right Side: Instructions
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
                  const SizedBox(height: 70), // Space for timer overlap
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
              // Image Card
              Container(
                margin: EdgeInsets.only(
                  right: isLandscape ? 50 : 0, // Room for timer overlap
                  bottom: 0,
                ),
                child: _buildRelaxationImage(
                  isLandscape: isLandscape,
                  height: imageHeight,
                ),
              ),

              // Glassmorphism Timer
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
        return Container(
          width: 100,
          height: 100,
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
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: _relaxationProgressController.value,
                        strokeWidth: 5,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
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
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEView() {
    // Get the EXACT test round configuration
    final testRound = TestConstants.getTestRoundConfiguration(
      _currentRound + 1, // +1 because _currentRound is 0-indexed
      _patientAge,
    );

    final currentFontSize =
        testRound.fontSize; // Use EXACT fontSize from protocol

    return Column(
      children: [
        // Timer and Size indicator row - COMPACT VERSION
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              // Size indicator on LEFT - COMPACT
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _getSnellenScore(currentFontSize),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // Timer on RIGHT - COMPACT
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: _remainingSeconds <= 2
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isTestPausedForDistance
                        ? 'PAUSED'
                        : '${_remainingSeconds}s',
                    style: TextStyle(
                      fontSize: 16,
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
        ),

        // E Display - FULL SCREEN, NO SCALING, OVERFLOW ALLOWED
        Expanded(
          child: Container(
            color: AppColors.white,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
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
                          fontSize:
                              currentFontSize, // EXACT size, no adjustment
                          fontWeight: FontWeight.w900,
                          color: AppColors.black,
                          height: 1.0,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Instruction text - MINIMAL HEIGHT
        Builder(
          builder: (context) {
            final provider = context.watch<TestSessionProvider>();
            final isPractitioner = provider.profileType == 'patient';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_continuousSpeech.isActive && !isPractitioner)
                        Icon(
                          Icons.mic,
                          size: 16,
                          color: _isTestPausedForDistance
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      if (_continuousSpeech.isActive && !isPractitioner)
                        const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _isTestPausedForDistance
                              ? 'Adjust distance'
                              : 'Which way is E pointing?',
                          style: TextStyle(
                            color: _isTestPausedForDistance
                                ? AppColors.warning
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: _isTestPausedForDistance
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecognizedTextIndicator() {
    final provider = context.read<TestSessionProvider>();
    if (provider.profileType == 'patient') return const SizedBox.shrink();

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

  Widget _buildLandscapeDirectionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        // Calculate dynamic button size based on available height
        double calcButtonSize = availableHeight / 5.2;
        final buttonSize = calcButtonSize.clamp(40.0, 72.0);
        final iconSize = buttonSize * 0.5;
        final gap = (buttonSize / 6).clamp(4.0, 12.0);
        final horizontalGap = (buttonSize * 1.2).clamp(40.0, 100.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.white,
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
                      color: AppColors.primary,
                    ),
                    label: Text(
                      "BLURRY",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: (buttonSize < 45) ? 9 : 11,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: (buttonSize < 45) ? 6 : 10,
                      ),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.05,
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
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
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
            child: Icon(_icon, color: AppColors.white, size: iconSize),
          ),
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
      duration: const Duration(milliseconds: 600),
    )..repeat();
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
