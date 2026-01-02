import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/features/comprehensive_test/widgets/speech_waveform.dart';
import 'package:visiaxx/features/quick_vision_test/screens/cover_right_eye_instruction_screen.dart';
import 'package:visiaxx/features/quick_vision_test/screens/cover_left_eye_instruction_screen.dart';
import 'package:visiaxx/features/quick_vision_test/screens/distance_calibration_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
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

/// Pelli-Robson Contrast Sensitivity Test Screen
/// Clinical-grade test with 8 screens of decreasing contrast triplets
class PelliRobsonTestScreen extends StatefulWidget {
  const PelliRobsonTestScreen({super.key});

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
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  DateTime? _lastShouldPauseTime;
  final Duration _distancePauseDebounce = const Duration(milliseconds: 100);

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

    // Start distance monitoring
    _startContinuousDistanceMonitoring();

    // First time - show general instructions then calibration
    if (!_mainInstructionsShown) {
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

    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      _currentMode == 'short' ? 'short_distance' : 'visual_acuity',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
    });

    if (_isTestActive) {
      if (shouldPause) {
        _lastShouldPauseTime ??= DateTime.now();
        final durationSinceFirstIssue = DateTime.now().difference(_lastShouldPauseTime!);
        if (durationSinceFirstIssue >= _distancePauseDebounce && !_isTestPausedForDistance) {
          _skipManager.canShowDistanceWarning(DistanceTestType.pelliRobson).then((canShow) {
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
    // ✅ FIX: Actually stop speech and timers to pause test
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
    // ✅ FIX: Stop background monitoring before starting calibration to avoid black screen
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

  Timer? _speechActiveTimer;
  void _handleSpeechDetected(String partialResult) {
    if (!mounted || !_isTestActive) return;

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
          final skipWords = [
            'nothing',
            'cannot',
            'can\'t',
            'skip',
            'none',
            'cannot see',
            'can\'t see',
          ];

          bool shouldSkip = false;
          for (var word in skipWords) {
            if (normalized.contains(word)) {
              shouldSkip = true;
              break;
            }
          }

          if (shouldSkip) {
            _submitCurrentTriplet('');
          } else {
            _submitCurrentTriplet(_recognizedText);
          }
        }
      },
    );
  }

  void _handleVoiceResponse(String result) {
    if (!mounted || !_isTestActive) return;

    setState(() => _recognizedText = result);
    if (result.isNotEmpty) {
      final normalized = result.toLowerCase();
      final skipWords = [
        'nothing',
        'cannot',
        'can\'t',
        'skip',
        'none',
        'cannot see',
        'can\'t see',
      ];

      bool shouldSkip = false;
      for (var word in skipWords) {
        if (normalized.contains(word)) {
          shouldSkip = true;
          break;
        }
      }

      if (shouldSkip) {
        _submitCurrentTriplet('');
      } else {
        _submitCurrentTriplet(result);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseTest();
    } else if (state == AppLifecycleState.resumed && _isTestActive) {
      _resumeTest();
    }
  }

  void _pauseTest() {
    _silenceTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _speechService.stopListening();
    setState(() => _isListening = false);
  }

  void _resumeTest() {
    if (_isTestActive) {
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

    // Stop background monitoring during "Cover Eye" instructions
    _distanceService.stopMonitoring();

    Widget instructionScreen;
    final String commonTitle = _currentMode == 'short' ? 'Near Contrast Test' : 'Long Distance Contrast Test';
    final String commonSubtitle = _currentMode == 'short' ? 'Contrast Sensitivity - 40cm' : 'Contrast Sensitivity - 1 Meter';
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
        instructionDescription: 'Read the three letters in each row aloud. The letters will get fainter as you go.',
        instructionIcon: Icons.record_voice_over,
        onContinue: () {
          Navigator.of(context).pop();
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
        instructionDescription: 'Read the three letters in each row aloud. The letters will get fainter as you go.',
        instructionIcon: Icons.record_voice_over,
        onContinue: () {
          Navigator.of(context).pop();
          _actuallyStartTest();
        },
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => instructionScreen),
    );
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
    if (!_continuousSpeech.isActive) {
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.05,
        bufferMs: 300,
      );
    }
    setState(() => _isListening = true);

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
    final matchResult = _fuzzyMatcher.matchTriplet(
      heardLetters,
      triplet.letters,
    );

    final response = TripletResponse(
      tripletCode: triplet.code,
      logCSValue: triplet.logCS,
      expectedLetters: triplet.letters,
      heardLetters: heardLetters.isEmpty ? 'No response' : heardLetters,
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
        // Mode short: Right -> Left
        _transitionToEye('left', 'short');
      } else {
        // Both eyes done at short distance. Now transition to long distance for Right eye.
        _ttsService.speak(
          'Short distance testing complete. Now we will do the 1 meter distance test. Please move back.',
        );
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            _transitionToEye('right', 'long');
          }
        });
      }
    } else {
      // Mode long
      if (_currentEye == 'right') {
        // Mode long: Right -> Left
        _transitionToEye('left', 'long');
      } else {
        // All tests complete (Right-Long and Left-Long)
        _completeAllTests();
      }
    }
  }

  void _transitionToEye(String eye, String mode) {
    setState(() {
      _currentEye = eye;
      _currentMode = mode;
      _showingInstructions = true;
      _showDistanceCalibration = true;
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

    setState(() {
      _currentEye = eye;
      _currentMode = mode;
      _showingInstructions = true;
      if (mode == 'long') {
        _showDistanceCalibration = true;
      }
    });

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
    final bothEyesResult = calculateEyeResult('both');

    final result = PelliRobsonResult(
      rightEye: rightEyeResult,
      leftEye: leftEyeResult,
      bothEyes: bothEyesResult,
      timestamp: DateTime.now(),
    );

    // Save to provider
    context.read<TestSessionProvider>().setPelliRobsonResult(result);

    _ttsService.speak(
      'Contrast sensitivity test complete. Proceeding to results.',
    );

    // Navigate to individual contrast results
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PelliRobsonResultScreen(),
          ),
        );
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

  void _showExitConfirmation() {
    _pauseTest();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeTest();
            },
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _silenceTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _speechService.dispose();
    _ttsService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingInstructions) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.shrink(),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: const Color(
          0xFFFFFFFF,
        ), // Pure white for clinical accuracy
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Contrast Test - ${_currentMode == 'short' ? '40cm' : '1m'}',
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
              Text(
                '${_currentEye.toUpperCase()} EYE',
                style: TextStyle(
                  color: _currentEye == 'right' ? AppColors.rightEye : AppColors.leftEye,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: _showExitConfirmation,
          ),
          actions: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Screen ${_currentScreenIndex + 1}/${PelliRobsonScoring.totalScreens}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Progress bar
                  LinearProgressIndicator(
                    value:
                        (_currentScreenIndex + 1) /
                        PelliRobsonScoring.totalScreens,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),

                  // Triplets display
                  Expanded(child: _buildTripletsDisplay()),

                  // Speech indicator
                  _buildSpeechIndicator(),

                  const SizedBox(height: 20),
                ],
              ),

              // Distance indicator
              Positioned(right: 16, top: 16, child: _buildDistanceIndicator()),

              // Distance warning overlay
              if (_isTestPausedForDistance) _buildDistanceWarningOverlay(),
            ],
          ),
        ),
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

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _buildTripletRow(triplet, fontSize, isCurrent, isCompleted),
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
    bool isCompleted,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
              )
            : null,
      ),
      child: Opacity(
        opacity: isCurrent ? triplet.opacity : (isCompleted ? 0.05 : 0.2),
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
                  color: Colors.black,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSpeechIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // Waveform
          SizedBox(
            height: 60,
            child: SpeechWaveform(
              isListening: _isListening,
              isTalking: _isSpeechActive,
              color: _speechDetected ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Recognized text
          if (_recognizedText.isNotEmpty)
            Text(
              'Heard: $_recognizedText',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            )
          else if (_isListening)
            Text(
              'Listening...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
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
    final target = _currentMode == 'short' ? 40.0 : 100.0;
    final pauseReason = DistanceHelper.getPauseReason(_distanceStatus, target);
    final instruction = DistanceHelper.getDetailedInstruction(target);

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
              const Icon(
                Icons.warning_rounded,
                size: 60,
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
              const Text(
                'Test Paused',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 12),
              // ✅ Real-time distance display
              Builder(builder: (context) {
                final target = _currentMode == 'short' ? 40.0 : 100.0;
                final distanceText = _currentDistance > 0
                    ? '${_currentDistance.toStringAsFixed(0)}cm'
                    : 'No face detected';
                final distanceColor = DistanceHelper.getDistanceColor(_currentDistance, target);
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: distanceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: distanceColor, width: 2),
                  ),
                  child: Text(
                    'Current: $distanceText',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: distanceColor,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                pauseReason,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
                    const Text(
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _skipManager.recordSkip(DistanceTestType.pelliRobson);
                  _resumeTestAfterDistance();
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
