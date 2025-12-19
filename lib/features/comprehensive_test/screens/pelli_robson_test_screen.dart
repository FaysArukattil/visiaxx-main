import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/features/comprehensive_test/widgets/speech_waveform.dart';
import 'package:visiaxx/features/quick_vision_test/screens/both_eyes_open_instruction_screen.dart';
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
  String _currentMode = 'short'; // 'short' (40cm) or 'long' (1m)
  int _currentScreenIndex = 0;
  int _currentTripletIndex = 0;
  bool _isTestActive = false;
  bool _isListening = false;
  bool _isSpeechActive = false;
  bool _showingInstructions = true;
  bool _showDistanceCalibration = true;

  bool _isTestPausedForDistance = false;
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  DateTime? _lastShouldPauseTime;
  static const Duration _distancePauseDebounce = Duration(milliseconds: 1000);

  // Results tracking
  final List<TripletResponse> _shortDistanceResponses = [];
  final List<TripletResponse> _longDistanceResponses = [];
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

    // First time - show calibration if needed
    if (_showDistanceCalibration) {
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
      _currentMode == 'short' ? 'near_vision' : 'visual_acuity',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
    });

    if (_isTestActive && !_showingInstructions) {
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
    _autoAdvanceTimer?.cancel();
    _silenceTimer?.cancel();
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PelliRobsonInstructionsScreen(
          testMode: _currentMode,
          onContinue: () {
            Navigator.of(context).pop();
            _startTest();
          },
        ),
      ),
    );
  }

  void _startTest() {
    _fuzzyMatcher.reset();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BothEyesOpenInstructionScreen(
          title: _currentMode == 'short'
              ? 'Near Contrast Test'
              : 'Long Distance Contrast Test',
          subtitle: _currentMode == 'short'
              ? 'Contrast Sensitivity - 40cm'
              : 'Contrast Sensitivity - 1 Meter',
          ttsMessage: _currentMode == 'short'
              ? 'Now we will test your contrast sensitivity at near distance. Keep both eyes open. Hold the device at 40 centimeters and read the triplets of letters aloud.'
              : 'Now we will test your contrast sensitivity at distance. Keep both eyes open. Sit at 1 meter from the screen and read the triplets of letters aloud.',
          targetDistance: _currentMode == 'short' ? 40.0 : 100.0,
          startButtonText: 'Start Contrast Test',
          instructionTitle: 'Read Aloud',
          instructionDescription:
              'Read the three letters in each group clearly',
          instructionIcon: Icons.record_voice_over,
          onContinue: () {
            Navigator.of(context).pop();
            _actuallyStartTest();
          },
        ),
      ),
    );
  }

  void _actuallyStartTest() {
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
    _startListeningForTriplet();
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

    // Add to appropriate list
    if (_currentMode == 'short') {
      _shortDistanceResponses.add(response);
    } else {
      _longDistanceResponses.add(response);
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
      // Switch to long distance mode
      _ttsService.speak(
        'Short distance test complete. Now we will test at 1 meter distance.',
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _currentMode = 'long';
            _showingInstructions = true;
            _showDistanceCalibration = true;
          });
          _showCalibrationScreen();
        }
      });
    } else {
      // Both tests complete
      _completeAllTests();
    }
  }

  void _completeAllTests() {
    // Calculate results
    final shortResult = _calculateSingleResult(
      _shortDistanceResponses,
      'short',
    );
    final longResult = _calculateSingleResult(_longDistanceResponses, 'long');

    final result = PelliRobsonResult(
      shortDistance: shortResult,
      longDistance: longResult,
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
      // Show loading while instructions screen is being pushed
      // CRITICAL: Set to false IMMEDIATELY to prevent infinite push loops
      _showingInstructions = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTestInstructions();
        }
      });
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
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
          title: Text(
            'Contrast Test - ${_currentMode == 'short' ? '40cm' : '1m'}',
            style: const TextStyle(color: Colors.black87),
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
    final fontSize = _currentMode == 'short' ? 50.0 : 125.0;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: triplets.asMap().entries.map((entry) {
            final index = entry.key;
            final triplet = entry.value;
            final isCurrent = index == _currentTripletIndex;
            final isCompleted = index < _currentTripletIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
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
                  opacity: triplet.opacity,
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
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto',
                            color: isCompleted
                                ? Colors.grey[400]
                                : const Color(0xFF000000), // Pure black
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                'Adjust Distance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
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
