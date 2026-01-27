import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/features/comprehensive_test/widgets/speech_waveform.dart';
import 'package:visiaxx/features/quick_vision_test/screens/cover_right_eye_instruction_screen.dart';
import 'package:visiaxx/features/quick_vision_test/screens/cover_left_eye_instruction_screen.dart';
import 'package:visiaxx/features/quick_vision_test/screens/distance_calibration_screen.dart';
import 'package:visiaxx/core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/continuous_speech_manager.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../core/services/distance_skip_manager.dart';
import '../../../core/utils/distance_helper.dart';
import '../../../core/utils/pelli_robson_scoring.dart';
import '../../../core/utils/pelli_robson_fuzzy_matcher.dart';
import 'pelli_robson_result_screen.dart';
import '../../../data/models/pelli_robson_result.dart';
import '../../../data/providers/test_session_provider.dart';
import 'pelli_robson_instructions_screen.dart';
import '../../quick_vision_test/screens/distance_transition_screen.dart';
import '../../../core/widgets/distance_warning_overlay.dart';

/// Pelli-Robson Contrast Sensitivity Test Screen
/// Clinical-grade test with 8 screens of decreasing contrast triplets
class PelliRobsonTestScreen extends StatefulWidget {
  final bool showInitialInstructions;

  const PelliRobsonTestScreen({super.key, this.showInitialInstructions = true});

  @override
  State<PelliRobsonTestScreen> createState() => _PelliRobsonTestScreenState();
}

class _PelliRobsonTestScreenState extends State<PelliRobsonTestScreen>
    with WidgetsBindingObserver {
  // Services
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  late final ContinuousSpeechManager _continuousSpeech;
  final PelliRobsonFuzzyMatcher _fuzzyMatcher = PelliRobsonFuzzyMatcher();
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final DistanceSkipManager _skipManager = DistanceSkipManager();

  // Test state
  String _currentEye = 'right'; // 'right', 'left', 'both'
  String _currentMode = 'short'; // 'short' (40cm) or 'long' (1m)
  int _currentScreenIndex = 0;
  int _currentTripletIndex = 0;
  bool _isTestActive = false;
  bool _isListening = false;
  bool _isSpeechActive = false;
  bool _showingInstructions = false; // Changed initial to false
  bool _showDistanceCalibration = true;
  bool _mainInstructionsShown = false; // Track if general PR instructions shown

  bool _isTestPausedForDistance = false;
  bool _isPausedForExit =
      false; // … Prevent distance warning during pause dialog
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  DateTime? _lastShouldPauseTime;
  final Duration _distancePauseDebounce = const Duration(milliseconds: 1000);

  // Auto-scrolling
  final ScrollController _scrollController = ScrollController();

  // Results tracking
  final Map<String, List<TripletResponse>> _shortResponses = {
    'right': [],
    'left': [],
    'both': [],
  };
  final Map<String, List<TripletResponse>> _longResponses = {
    'right': [],
    'left': [],
    'both': [],
  };
  DateTime? _tripletStartTime;
  String _recognizedText = '';
  bool _speechDetected = false;

  // Timers
  Timer? _silenceTimer;
  Timer? _autoAdvanceTimer;

  // Constants
  static const int _silenceThresholdMs = 1500;
  static const int _autoAdvanceDelayMs = 6000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
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

    // Check if we are in practitioner mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<TestSessionProvider>();
        if (provider.profileType == 'patient') {
          debugPrint(
            '👨‍⚕️ [PelliRobson] Practitioner mode detected: Silencing Speech globally',
          );
          _speechService.setGloballyDisabled(true);
        }
      }
    });

    // Start distance monitoring
    _startContinuousDistanceMonitoring();

    // First time - show general instructions then calibration
    if (widget.showInitialInstructions && !_mainInstructionsShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTestInstructions();
      });
    } else if (_showDistanceCalibration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCalibrationScreen();
      });
    } else {
      _startTest();
    }
  }

  void _startContinuousDistanceMonitoring() async {
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    _distanceService.onError = (msg) => debugPrint('[DistanceMonitor] $msg');

    if (!_distanceService.isReady) {
      await _distanceService.initializeCamera();
    }
    await _distanceService.startMonitoring();
  }

  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    // … FIX: Don't process distance updates while pause dialog is showing
    if (_isPausedForExit) return;

    // Use appropriate test type for distance checking
    // short_distance: minimum 35cm, no upper limit
    // visual_acuity: minimum 80cm for 1m test
    final testType = _currentMode == 'short'
        ? 'short_distance'
        : 'visual_acuity';
    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      testType,
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
      // … FIX: Reset state when distance becomes good
      if (!shouldPause && _isTestPausedForDistance) {
        _resumeTestAfterDistance();
      }
    });

    if (_isTestActive) {
      if (shouldPause) {
        _lastShouldPauseTime ??= DateTime.now();
        final durationSinceFirstIssue = DateTime.now().difference(
          _lastShouldPauseTime!,
        );
        if (durationSinceFirstIssue >= _distancePauseDebounce &&
            !_isTestPausedForDistance) {
          _skipManager
              .canShowDistanceWarning(DistanceTestType.pelliRobson)
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
    setState(() {
      _isTestPausedForDistance = true;
    });
    // … FIX: Actually stop speech and timers to pause test
    _continuousSpeech.stop();
    _autoAdvanceTimer?.cancel();
    _silenceTimer?.cancel();
    setState(() => _isListening = false);

    // TTS guidance
    final target = _currentMode == 'short' ? 40.0 : 100.0;
    _ttsService.speak(
      'Test paused. Please adjust your distance to ${target.toInt()} centimeters.',
    );
    HapticFeedback.mediumImpact();
  }

  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;
    setState(() {
      _isTestPausedForDistance = false;
      _lastShouldPauseTime = null;
    });
    if (_isTestActive) {
      _startListeningForTriplet();
    }
  }

  void _showCalibrationScreen() {
    // … FIX: Stop background monitoring before starting calibration to avoid black screen
    _distanceService.stopMonitoring();
    _ttsService.stop();

    final targetDistance = _currentMode == 'short' ? 40.0 : 100.0;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: targetDistance,
          toleranceCm: _currentMode == 'short' ? 5.0 : 8.0,
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
    });
    _startContinuousDistanceMonitoring();
    _startTest();
  }

  // List of phrases indicating the user cannot see the letters
  static const List<String> negativePhrases = [
    'not visible',
    'nothing',
    'cannot',
    "can't",
    'skip',
    'none',
    'cannot see',
    "can't see",
    'invisible',
    'no',
  ];

  Timer? _speechActiveTimer;
  void _handleSpeechDetected(String partialResult) {
    if (!mounted || !_isTestActive) return;

    final provider = context.read<TestSessionProvider>();
    if (provider.profileType == 'patient') return;

    setState(() {
      _recognizedText = partialResult;
      _speechDetected = partialResult.isNotEmpty;
      _isSpeechActive = true;
    });

    _speechActiveTimer?.cancel();
    _speechActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isSpeechActive = false);
    });

    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      const Duration(milliseconds: _silenceThresholdMs),
      () {
        if (mounted && _isTestActive && _recognizedText.isNotEmpty) {
          final normalized = _recognizedText.toLowerCase();

          bool isNegativePhrase = false;
          for (var phrase in negativePhrases) {
            if (normalized.contains(phrase)) {
              isNegativePhrase = true;
              break;
            }
          }

          if (isNegativePhrase) {
            _submitCurrentTriplet('Not visible');
          } else {
            _submitCurrentTriplet(_recognizedText);
          }
        }
      },
    );
  }

  void _handleVoiceResponse(String result) {
    if (!mounted || !_isTestActive) return;

    final provider = context.read<TestSessionProvider>();
    if (provider.profileType == 'patient') return;

    setState(() => _recognizedText = result);
    if (result.isNotEmpty) {
      final normalized = result.toLowerCase();

      bool isNegativePhrase = false;
      for (var phrase in negativePhrases) {
        if (normalized.contains(phrase)) {
          isNegativePhrase = true;
          break;
        }
      }

      if (isNegativePhrase) {
        _submitCurrentTriplet('Not visible');
      } else {
        _submitCurrentTriplet(result);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // … FIX: Handle both paused and inactive states
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isTestActive) {
        _pauseTest();
      }
    } else if (state == AppLifecycleState.resumed) {
      // … FIX: Only show pause dialog if test is active and we were paused
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isTestActive && _isPausedForExit) {
          _showPauseDialog(reason: 'minimized');
        }
      });
    }
  }

  void _pauseTest() {
    _silenceTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    // … FIX: Stop continuous speech manager (not just speechService)
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();
    _ttsService.stop();
    setState(() {
      _isPausedForExit = true;
      _isListening = false;
    });
  }

  void _resumeTest() {
    if (_isTestActive) {
      setState(() {
        _isPausedForExit = false;
      });
      _startContinuousDistanceMonitoring();
      _startListeningForTriplet();
    }
  }

  void _showTestInstructions() {
    setState(() => _mainInstructionsShown = true);

    // Stop background distance monitoring during instructions
    _distanceService.stopMonitoring();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PelliRobsonInstructionsScreen(
          testMode: _currentMode,
          onContinue: () {
            Navigator.of(context).pop();
            // Start calibration immediately
            _showCalibrationScreen();
          },
        ),
      ),
    );
  }

  void _startTest() {
    _fuzzyMatcher.reset();

    // … FIX: Stop background monitoring during "Cover Eye" instructions
    _distanceService.stopMonitoring();

    Widget instructionScreen;
    final String commonTitle = _currentMode == 'short'
        ? 'Near Contrast Test'
        : 'Long Distance Contrast Test';
    final String commonSubtitle = _currentMode == 'short'
        ? 'Contrast Sensitivity - 40cm'
        : 'Contrast Sensitivity - 1 Meter';
    final double targetDistance = _currentMode == 'short' ? 40.0 : 100.0;

    if (_currentEye == 'right') {
      instructionScreen = CoverLeftEyeInstructionScreen(
        title: commonTitle,
        subtitle: 'Right Eye: $commonSubtitle',
        ttsMessage: _currentMode == 'short'
            ? 'Cover your left eye. Focus with your right eye only. Hold the device at 40 centimeters and read the triplets of letters aloud.'
            : 'Cover your left eye. Focus with your right eye only. Sit at 1 meter from the screen and read the triplets of letters aloud.',
        targetDistance: targetDistance,
        startButtonText: 'Start Right Eye Test',
        instructionTitle: 'Contrast Test',
        instructionDescription:
            'Read the three letters in each row aloud. The letters will get fainter as you go.',
        instructionIcon: Icons.record_voice_over,
        onContinue: () {
          Navigator.of(context).pop();
          // … FIX: Resume monitoring AFTER user confirms they've covered eye
          _actuallyStartTest();
        },
      );
    } else {
      instructionScreen = CoverRightEyeInstructionScreen(
        title: commonTitle,
        subtitle: 'Left Eye: $commonSubtitle',
        ttsMessage: _currentMode == 'short'
            ? 'Cover your right eye. Focus with your left eye only. Hold the device at 40 centimeters and read the triplets of letters aloud.'
            : 'Cover your right eye. Focus with your left eye only. Sit at 1 meter from the screen and read the triplets of letters aloud.',
        targetDistance: targetDistance,
        startButtonText: 'Start Left Eye Test',
        instructionTitle: 'Contrast Test',
        instructionDescription:
            'Read the three letters in each row aloud. The letters will get fainter as you go.',
        instructionIcon: Icons.record_voice_over,
        onContinue: () {
          Navigator.of(context).pop();
          // … FIX: Resume monitoring AFTER user confirms they've covered eye
          _actuallyStartTest();
        },
      );
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => instructionScreen));
  }

  void _actuallyStartTest() {
    // Resume distance monitoring as the test is now active
    _startContinuousDistanceMonitoring();

    setState(() {
      _showingInstructions = false;
      _isTestActive = true;
      _currentScreenIndex = 0;
      _currentTripletIndex = 0;
    });
    _ttsService.speak('Starting contrast test. Read the letters aloud.');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isTestActive) {
        _showNextTriplet();
      }
    });
  }

  void _showNextTriplet() {
    final triplets = PelliRobsonScoring.getTripletsForScreen(
      _currentScreenIndex,
    );
    if (_currentTripletIndex >= triplets.length) {
      // Move to next screen
      _currentTripletIndex = 0;
      _currentScreenIndex++;

      if (_currentScreenIndex >= PelliRobsonScoring.totalScreens) {
        _completeCurrentMode();
        return;
      }
    }

    _tripletStartTime = DateTime.now();
    _recognizedText = '';
    _speechDetected = false;
    setState(() {});

    _scrollToCurrentTriplet();
    _startListeningForTriplet();
  }

  void _scrollToCurrentTriplet() {
    if (!_scrollController.hasClients) return;

    // Each triplet row is roughly 100-150 pixels in height (padding + content)
    // We want to center the active one.
    final offset = _currentTripletIndex * 120.0;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _startListeningForTriplet() {
    final provider = context.read<TestSessionProvider>();
    if (provider.profileType != 'patient' && !_continuousSpeech.isActive) {
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.05,
        bufferMs: 300,
      );
    }
    setState(() => _isListening = provider.profileType != 'patient');

    // Cancel existing timers
    _silenceTimer?.cancel();
    _autoAdvanceTimer?.cancel();

    // Auto-advance timer (6 seconds of no speech)
    _autoAdvanceTimer = Timer(
      const Duration(milliseconds: _autoAdvanceDelayMs),
      () {
        if (mounted && _isTestActive && !_speechDetected) {
          _submitCurrentTriplet('');
        }
      },
    );
  }

  void _submitCurrentTriplet(String heardLetters) {
    _continuousSpeech.stop();
    _silenceTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    setState(() => _isListening = false);

    final triplets = PelliRobsonScoring.getTripletsForScreen(
      _currentScreenIndex,
    );
    if (_currentTripletIndex >= triplets.length) {
      _showNextTriplet();
      return;
    }

    final triplet = triplets[_currentTripletIndex];
    final responseTime = _tripletStartTime != null
        ? DateTime.now().difference(_tripletStartTime!).inMilliseconds
        : 0;

    // Use fuzzy matcher to count correct letters
    // Special case: If user said 'not visible', they get 0
    final bool isNotVisible = heardLetters == 'Not visible';
    final matchResult = isNotVisible
        ? (count: 0, matches: [false, false, false])
        : _fuzzyMatcher.matchTriplet(heardLetters, triplet.letters);

    final response = TripletResponse(
      tripletCode: triplet.code,
      logCSValue: triplet.logCS,
      expectedLetters: triplet.letters,
      heardLetters: heardLetters.isEmpty || heardLetters == 'Not visible'
          ? 'Not visible'
          : heardLetters,
      correctLetters: matchResult.count,
      responseTimeMs: responseTime,
      wasAutoAdvanced: heardLetters.isEmpty,
    );

    // Add to appropriate map
    if (_currentMode == 'short') {
      _shortResponses[_currentEye]?.add(response);
    } else {
      _longResponses[_currentEye]?.add(response);
    }

    // Visual feedback
    HapticFeedback.lightImpact();

    // Move to next triplet
    _currentTripletIndex++;

    // Small delay before next triplet
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isTestActive) {
        _showNextTriplet();
      }
    });
  }

  void _completeCurrentMode() {
    setState(() => _isTestActive = false);

    if (_currentMode == 'short') {
      if (_currentEye == 'right') {
        _transitionToEye('left', 'short');
      } else {
        // Left eye complete at short distance. Now transition to long distance for Right eye.
        // Left eye complete at short distance. Now transition to long distance for Right eye.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DistanceTransitionScreen(
              title: 'Contrast Sensitivity',
              headline: 'Switching to Distance Vision',
              currentDistance: '40cm',
              targetDistance: '1 Meter',
              instruction:
                  'Short distance testing complete. Now we will do the 1 meter distance test. Please move back to 1 meter.',
              onContinue: () {
                Navigator.of(context).pop();
                _transitionToEye('right', 'long');
              },
            ),
          ),
        );
      }
    } else {
      // Mode long
      if (_currentEye == 'right') {
        _transitionToEye('left', 'long');
      } else {
        // All tests complete (Right and Left for both distances)
        _completeAllTests();
      }
    }
  }

  void _transitionToEye(String eye, String mode) {
    // Only calibrate if the distance mode changes (short->long or initial)
    final bool modeChanged = mode != _currentMode;

    setState(() {
      _currentEye = eye;
      _currentMode = mode;
      _showingInstructions = true;
      // Only show calibration if mode actually changed
      _showDistanceCalibration = modeChanged;
    });

    // Custom transition message
    String msg = '';
    if (mode == 'short') {
      msg =
          'Next, we will test the ${eye == 'right' ? 'right' : 'left'} eye at 40 centimeters.';
    } else {
      msg =
          'Next, we will test the ${eye == 'right' ? 'right' : 'left'} eye at 1 meter.';
    }

    _ttsService.speak(msg);

    // Navigate immediately to instructions or calibration
    if (_showDistanceCalibration) {
      _showCalibrationScreen();
    } else {
      _startTest();
    }
  }

  void _completeAllTests() {
    // Calculate results for each eye
    PelliRobsonEyeResult calculateEyeResult(String eye) {
      final shortRes = (_shortResponses[eye]?.isNotEmpty == true)
          ? _calculateSingleResult(_shortResponses[eye]!, 'short')
          : null;
      final longRes = (_longResponses[eye]?.isNotEmpty == true)
          ? _calculateSingleResult(_longResponses[eye]!, 'long')
          : null;

      return PelliRobsonEyeResult(
        shortDistance: shortRes,
        longDistance: longRes,
      );
    }

    final rightEyeResult = calculateEyeResult('right');
    final leftEyeResult = calculateEyeResult('left');

    final result = PelliRobsonResult(
      rightEye: rightEyeResult,
      leftEye: leftEyeResult,
      bothEyes: null, // Not tested in comprehensive mode
      timestamp: DateTime.now(),
    );

    // Save to provider
    context.read<TestSessionProvider>().setPelliRobsonResult(result);

    _ttsService.speak(
      'Contrast sensitivity test complete. Proceeding to results.',
    );

    // Navigate to results
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final provider = context.read<TestSessionProvider>();
        if (provider.isIndividualTest) {
          Navigator.pushReplacementNamed(context, '/quick-test-result');
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const PelliRobsonResultScreen(),
            ),
          );
        }
      }
    });
  }

  PelliRobsonSingleResult _calculateSingleResult(
    List<TripletResponse> responses,
    String mode,
  ) {
    // Analyze responses to find last full triplet and correct in next
    final analysisData = responses
        .map((r) => (code: r.tripletCode, correctLetters: r.correctLetters))
        .toList();

    final analysis = PelliRobsonScoring.analyzeResponses(analysisData);

    final score = PelliRobsonScoring.calculateScore(
      lastFullTriplet: analysis.lastFull,
      correctInNextTriplet: analysis.correctInNext,
      isShortDistance: mode == 'short',
    );

    final category = PelliRobsonScoring.getCategory(score);

    // Calculate duration from responses
    final totalTime = responses.fold<int>(
      0,
      (sum, r) => sum + r.responseTimeMs,
    );

    return PelliRobsonSingleResult(
      testMode: mode,
      lastFullTriplet: analysis.lastFull ?? '',
      correctInNextTriplet: analysis.correctInNext,
      uncorrectedScore: score + (mode == 'short' ? 0.15 : 0),
      adjustedScore: score,
      category: category,
      tripletResponses: responses,
      durationSeconds: totalTime ~/ 1000,
    );
  }

  /// Unified pause dialog for both back button and app minimization
  void _showPauseDialog({String reason = 'back button'}) {
    _pauseTest();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TestExitConfirmationDialog(
        onContinue: () {
          _resumeTest();
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
        _resumeTest();
      }
    });
  }

  /// Alias for back button
  void _showExitConfirmation() => _showPauseDialog();

  /// Restart only the current test, preserving other test data
  void _restartCurrentTest() {
    // Reset only Pelli-Robson test data in provider
    context.read<TestSessionProvider>().resetPelliRobson();

    _silenceTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _speechService.cancel();
    _distanceService.stopMonitoring();
    _continuousSpeech.stop();
    _ttsService.stop();
    _fuzzyMatcher.reset();

    // … FIX: Preserve the current mode (short or long) - only restart in that mode
    final preservedMode = _currentMode;

    setState(() {
      _currentEye = 'right';
      _currentMode = preservedMode; // … Keep the current distance mode
      _currentScreenIndex = 0;
      _currentTripletIndex = 0;
      _isTestActive = false;
      _isListening = false;
      _isSpeechActive = false;
      _showingInstructions = false;
      _showDistanceCalibration = true;
      _mainInstructionsShown = true; // … Skip general instructions on restart
      _isTestPausedForDistance = false;
      _isPausedForExit = false;
      // … Only clear responses for the current mode
      if (preservedMode == 'short') {
        _shortResponses.forEach((_, list) => list.clear());
      } else {
        _longResponses.forEach((_, list) => list.clear());
      }
      _recognizedText = '';
      _speechDetected = false;
    });

    // Go directly to calibration screen (callbacks already set in _initServices)
    _showCalibrationScreen();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _silenceTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _speechService.setGloballyDisabled(false); // Reset for next session
    _speechService.dispose();
    _ttsService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingInstructions) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: SizedBox.shrink(),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.white, // Pure white for clinical accuracy
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: Text(
            'Contrast Test - ${_currentMode == 'short' ? '40cm' : '1m'}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isLandscape =
                      MediaQuery.of(context).orientation ==
                      Orientation.landscape;

                  if (isLandscape &&
                      _isTestActive &&
                      !_isTestPausedForDistance) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildInfoBar(isLandscape: true),
                              Expanded(child: _buildTripletsDisplay()),
                              _buildRecognizedTextIndicator(),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          color: AppColors.border.withValues(alpha: 0.2),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildLandscapeControlsSidePanel(),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _buildInfoBar(),
                      // Triplets display
                      Expanded(child: _buildTripletsDisplay()),

                      // Recognized text banner (Reading test style)
                      _buildRecognizedTextIndicator(),

                      // Visible / Not Visible buttons
                      if (_isTestActive && !_isTestPausedForDistance)
                        _buildVisibleButtons(),

                      // Integrated Speech indicator
                      _buildSpeechIndicator(),

                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // Distance indicator - Repositioned to top-right overlapping info bar
              Positioned(
                right: 8,
                top: 8, // Overlapping the InfoBar area
                child: _buildDistanceIndicator(),
              ),

              // Distance warning overlay
              // ✅ Standardized: Using the universal DistanceWarningOverlay
              DistanceWarningOverlay(
                isVisible: _isTestPausedForDistance && !_isPausedForExit,
                status: _distanceStatus,
                currentDistance: _currentDistance,
                targetDistance: _currentMode == 'short' ? 40.0 : 100.0,
                onSkip: () {
                  _skipManager.recordSkip(DistanceTestType.pelliRobson);
                  _resumeTestAfterDistance();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ NEW: Visible / Not Visible buttons for tap-based input
  Widget _buildVisibleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Visible button - submit all letters
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final triplets = PelliRobsonScoring.getTripletsForScreen(
                  _currentScreenIndex,
                );
                if (_currentTripletIndex < triplets.length) {
                  final triplet = triplets[_currentTripletIndex];
                  _submitCurrentTriplet(triplet.letters);
                }
              },
              icon: const Icon(Icons.visibility, size: 20),
              label: const Text('Visible'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                elevation: 0,
                shadowColor: AppColors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Not Visible button - submit empty
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _submitCurrentTriplet('Not visible');
              },
              icon: const Icon(Icons.visibility_off, size: 20),
              label: const Text('Not Visible'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripletsDisplay() {
    final triplets = PelliRobsonScoring.getTripletsForScreen(
      _currentScreenIndex,
    );
    final isLongDistance = _currentMode == 'long';
    final fontSize = isLongDistance ? 110.0 : 50.0;

    return Center(
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: triplets.asMap().entries.map((entry) {
            final index = entry.key;
            final triplet = entry.value;
            final isCurrent = index == _currentTripletIndex;
            final isCompleted = index < _currentTripletIndex;
            // ✅ FIX: Show next triplet with actual opacity (preview)
            final isNext = index == _currentTripletIndex + 1;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _buildTripletRow(
                triplet,
                fontSize,
                isCurrent,
                isCompleted,
                isNext: isNext,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTripletRow(
    PelliRobsonTriplet triplet,
    double fontSize,
    bool isCurrent,
    bool isCompleted, {
    bool isNext = false,
  }) {
    // … FIX: Next triplet shows actual opacity (preview)
    // Current: full opacity, Completed: dimmed, Next: actual opacity preview, Others: hidden
    double rowOpacity;
    if (isCurrent) {
      rowOpacity = triplet.opacity;
    } else if (isCompleted) {
      rowOpacity = 0.05;
    } else if (isNext) {
      rowOpacity = triplet.opacity; // Show actual contrast for preview
    } else {
      rowOpacity = 0.0; // Hide future triplets (except next)
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.12) // Slightly more subtle
            : AppColors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: AppColors.primary, width: 2.5)
            : null,
      ),
      child: Opacity(
        opacity: rowOpacity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: triplet.letters.split('').map((letter) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Sloan',
                    color: AppColors.black,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeechIndicator() {
    final provider = context.watch<TestSessionProvider>();
    if (provider.profileType == 'patient') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: _buildVoiceActionButton(
        icon: _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
        label: _isListening ? 'LISTENING' : 'VOICE',
        isActive: _isListening,
        color: AppColors.primary,
        onTap: () {
          if (_isListening) {
            _continuousSpeech.stop();
            // Small delay then restart to ensure a fresh session
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && _isTestActive) _startListeningForTriplet();
            });
          } else {
            _startListeningForTriplet();
          }
        },
      ),
    );
  }

  /// Premium action button for voice control with integrated waveform
  Widget _buildVoiceActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.2),
            width: 2.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive)
              SpeechWaveform(
                isListening: _isListening,
                isTalking: _isSpeechActive,
                color: AppColors.white,
              )
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.white : color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Optimized recognized text display (Matches reading test requirement for visibility)
  Widget _buildRecognizedTextIndicator() {
    final provider = context.read<TestSessionProvider>();
    if (provider.profileType == 'patient') return const SizedBox.shrink();

    final bool hasRecognized = _recognizedText.isNotEmpty;

    if (!hasRecognized && !_isListening) {
      return const SizedBox(height: 40);
    }

    return AnimatedOpacity(
      opacity: (hasRecognized || _isListening) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
        ),
        child: Text(
          hasRecognized ? _recognizedText : 'Listening...',
          style: TextStyle(
            fontSize: 18,
            color: hasRecognized
                ? AppColors.textPrimary
                : AppColors.primary.withValues(alpha: 0.7),
            fontWeight: FontWeight.bold,
            fontStyle: hasRecognized ? FontStyle.normal : FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    final target = _currentMode == 'short' ? 40.0 : 100.0;
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      target,
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

  Widget _buildLandscapeControlsSidePanel() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
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
          const SizedBox(height: 16),
          // Large buttons - use Flexible to prevent overflow
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 60,
                      maxHeight: 80,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final triplets =
                              PelliRobsonScoring.getTripletsForScreen(
                                _currentScreenIndex,
                              );
                          if (_currentTripletIndex < triplets.length) {
                            final triplet = triplets[_currentTripletIndex];
                            _submitCurrentTriplet(triplet.letters);
                          }
                        },
                        icon: const Icon(Icons.visibility, size: 24),
                        label: const Text(
                          'VISIBLE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 60,
                      maxHeight: 80,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _submitCurrentTriplet('Not visible');
                        },
                        icon: const Icon(Icons.visibility_off, size: 24),
                        label: const Text(
                          'NOT VISIBLE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSpeechIndicator(),
        ],
      ),
    );
  }

  Widget _buildInfoBar({bool isLandscape = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Screen indicator (Leftmost)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  size: 13,
                  color: AppColors.info,
                ),
                const SizedBox(width: 6),
                Text(
                  'SCREEN ${_currentScreenIndex + 1}/${PelliRobsonScoring.totalScreens}',
                  style: const TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Eye/Mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'EYE: ${_currentEye.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
