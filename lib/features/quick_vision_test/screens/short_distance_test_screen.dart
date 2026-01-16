import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/utils/app_logger.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/core/utils/fuzzy_matcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/test_feedback_overlay.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/short_distance_result.dart';
import '../../../core/services/distance_skip_manager.dart';
import 'package:visiaxx/core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/widgets/distance_warning_overlay.dart';

/// Short distance reading test - both eyes open, 40cm distance
class ShortDistanceTestScreen extends StatefulWidget {
  const ShortDistanceTestScreen({super.key});

  @override
  State<ShortDistanceTestScreen> createState() =>
      _ShortDistanceTestScreenState();
}

class _ShortDistanceTestScreenState extends State<ShortDistanceTestScreen>
    with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();

  // Distance monitoring service
  final DistanceDetectionService _distanceService = DistanceDetectionService(
    targetDistanceCm: 40.0,
    toleranceCm: 5.0,
  );

  // Distance monitoring state
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = true;

  // Test state
  int _currentScreen = 0;
  int _correctCount = 0;
  final List<SentenceResponse> _results = [];

  // Display states
  bool _showSentence = false;
  bool _waitingForResponse = false;
  bool _showResult = false;
  bool _testComplete = false;
  bool _isPausedForExit = false;

  // Voice recognition
  bool _isListening = false;
  Timer? _speechActiveTimer;
  String? _recognizedText;
  Timer? _listeningTimer;

  final DistanceSkipManager _skipManager = DistanceSkipManager();

  // Text input
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _showKeyboard = false;

  // Result feedback
  bool _lastResultCorrect = false;

  // Countdown timer for individual screen
  int _readingCountdown = 35;
  Timer? _readingCountdownTimer;

  Timer? _autoNavigationTimer;
  bool _isNavigatingToNextTest = false;
  int _secondsRemaining = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
    _startDistanceMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readingCountdownTimer?.cancel();
    _listeningTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _speechService.dispose();
    _ttsService.dispose();
    _distanceService.stopMonitoring();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isPausedForExit = true;
      _speechService.stopListening();
      _distanceService.stopMonitoring();
    } else if (state == AppLifecycleState.resumed) {
      _isPausedForExit = false;
      _distanceService.startMonitoring();
    }
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();
    _showNextSentence();
  }

  void _startDistanceMonitoring() async {
    await _distanceService.initializeCamera();
    _distanceService.onDistanceUpdate = (distance, status) {
      if (!mounted) {
        return;
      }
      final isCorrect = DistanceHelper.isDistanceCorrect(status);
      if (isCorrect) {
        setState(() {
          _currentDistance = distance;
          _distanceStatus = status;
          _isDistanceOk = true;
        });
      } else {
        _skipManager
            .canShowDistanceWarning(DistanceTestType.shortDistance)
            .then((canShow) {
              if (mounted) {
                setState(() {
                  _currentDistance = distance;
                  _distanceStatus = status;
                  if (canShow) {
                    _isDistanceOk = false;
                  }
                });
              }
            });
      }
    };
    await _distanceService.startMonitoring();
  }

  void _showExitConfirmation() {
    _isPausedForExit = true;
    _speechService.stopListening();
    setState(() => _isListening = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TestExitConfirmationDialog(
        title: 'Exit Reading Test?',
        onContinue: () {
          _isPausedForExit = false;
        },
        onRestart: () {
          _isPausedForExit = false;
          _resetTest();
        },
        onExit: () {
          _distanceService.stopMonitoring();
          Navigator.of(context).pop(); // Exit screen
        },
      ),
    );
  }

  void _resetTest() {
    setState(() {
      _currentScreen = 0;
      _correctCount = 0;
      _results.clear();
      _showSentence = false;
      _waitingForResponse = false;
      _showResult = false;
      _testComplete = false;
    });
    _showNextSentence();
  }

  void _showNextSentence() {
    if (_currentScreen >= TestConstants.shortDistanceSentences.length) {
      _completeTest();
      return;
    }

    setState(() {
      _showSentence = true;
      _waitingForResponse = true;
      _showResult = false;
      _recognizedText = null;
      _readingCountdown = 35;
      _showKeyboard = false;
      _inputController.clear();
    });

    _startReadingCountdown();
  }

  void _startReadingCountdown() {
    _readingCountdownTimer?.cancel();
    _readingCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_readingCountdown > 0) {
          _readingCountdown--;
        } else {
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  void _handleTimeout() {
    if (!_waitingForResponse) {
      return;
    }
    _processSentence(''); // Treat as skip/incorrect
  }

  void _startListening() async {
    if (_isListening || _isPausedForExit || !_isDistanceOk) {
      return;
    }

    final available = await _speechService.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _recognizedText = 'Listening...';
        _showKeyboard = false;
      });

      _speechService.onResult = (text) {
        _handleVoiceResponse(text, true);
      };
      _speechService.onSpeechDetected = (text) {
        if (mounted) {
          setState(() => _recognizedText = text);
        }
      };
      _speechService.onError = (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _recognizedText = 'Speech Error: $error';
          });
        }
      };

      await _speechService.startListening();

      // Timeout if nothing recognized for a while
      _listeningTimer?.cancel();
      _listeningTimer = Timer(const Duration(seconds: 15), () {
        if (_isListening && mounted) {
          _speechService.stopListening();
          setState(() => _isListening = false);
        }
      });
    }
  }

  void _handleVoiceResponse(String text, bool isFinal) {
    if (!mounted || !_waitingForResponse) {
      return;
    }

    setState(() {
      _recognizedText = text;
    });

    // Reset speech active indicator after delay
    _speechActiveTimer?.cancel();
    _speechActiveTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });

    if (isFinal && text.trim().isNotEmpty) {
      _processSentence(text);
    }
  }

  void _processSentence(String userSaid) {
    if (!_waitingForResponse) {
      return;
    }

    _readingCountdownTimer?.cancel();
    _speechService.stopListening();

    final sentence = TestConstants.shortDistanceSentences[_currentScreen];

    // Handle "blurry" or "can't see"
    bool isBlurry =
        userSaid.toLowerCase().contains('blurry') ||
        userSaid.toLowerCase().contains("can't read") ||
        userSaid.toLowerCase().contains("cannot read") ||
        userSaid.toLowerCase().contains("can't see");

    double similarity = 0.0;
    bool isCorrect = false;

    if (!isBlurry && userSaid.isNotEmpty) {
      similarity = FuzzyMatcher.getSimilarity(sentence.sentence, userSaid);
      isCorrect = similarity >= 70.0;
    }

    _handleResult(sentence, userSaid, similarity, isCorrect);
  }

  void _handleResult(
    ShortDistanceSentence sentence,
    String userSaid,
    double similarity,
    bool isCorrect,
  ) {
    if (isCorrect) {
      _correctCount++;
    }

    final result = SentenceResponse(
      screenNumber: _currentScreen + 1,
      expectedSentence: sentence.sentence,
      userResponse: userSaid,
      similarity: similarity,
      passed: isCorrect,
      snellen: sentence.snellen,
      fontSize: sentence.fontSize,
    );
    _results.add(result);

    AppLogger.logShortDistance(
      screenNumber: _currentScreen + 1,
      snellen: sentence.snellen,
      fontSize: sentence.fontSize,
      expected: sentence.sentence,
      userSaid: userSaid,
      similarity: similarity,
      pass: isCorrect,
    );

    if (isCorrect) {
      _ttsService.speak('Correct');
    } else if (userSaid.isNotEmpty) {
      _ttsService.speak('Not quite right');
    }

    setState(() {
      _showResult = true;
      _waitingForResponse = false;
      _isListening = false;
      _showKeyboard = false;
      _lastResultCorrect = isCorrect;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }
      _currentScreen++;
      _showNextSentence();
    });
  }

  void _completeTest() {
    setState(() {
      _testComplete = true;
      _showSentence = false;
      _secondsRemaining = 5;
    });

    String bestAcuity = '6/60';
    for (final result in _results.reversed) {
      if (result.passed) {
        bestAcuity = result.snellen;
        break;
      }
    }

    final avgSimilarity = _results.isEmpty
        ? 0.0
        : _results.map((r) => r.similarity).reduce((a, b) => a + b) /
              _results.length;

    String status = 'Needs Improvement';
    if (avgSimilarity >= 85.0) {
      status = 'Excellent';
    } else if (avgSimilarity >= 70.0) {
      status = 'Good';
    } else if (avgSimilarity >= 50.0) {
      status = 'Fair';
    }

    final result = ShortDistanceResult(
      correctSentences: _correctCount,
      totalSentences: TestConstants.shortDistanceSentences.length,
      averageSimilarity: avgSimilarity,
      bestAcuity: bestAcuity,
      durationSeconds: 0, // Mock for now
      responses: _results,
      status: status,
    );

    final provider = context.read<TestSessionProvider>();
    provider.setShortDistanceResult(result);

    _startAutoNavigationTimer();
  }

  void _startAutoNavigationTimer() {
    _autoNavigationTimer?.cancel();
    setState(() => _secondsRemaining = 5);
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
            _navigateToColorVision();
          }
        }
      });
    });
  }

  void _navigateToColorVision() {
    if (_isNavigatingToNextTest || !mounted) return;
    final provider = context.read<TestSessionProvider>();
    setState(() => _isNavigatingToNextTest = true);
    if (provider.isIndividualTest) {
      Navigator.pushReplacementNamed(context, '/quick-test-result');
    } else {
      Navigator.pushReplacementNamed(context, '/color-vision-test');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_testComplete) return _buildTestCompleteView();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: Center(
                      child: _showSentence
                          ? _buildSentenceView()
                          : const EyeLoader(),
                    ),
                  ),
                  _buildControls(),
                ],
              ),

              // âœ… UNIVERSAL Distance warning overlay
              DistanceWarningOverlay(
                isVisible: !_isDistanceOk && _waitingForResponse,
                status: _distanceStatus,
                currentDistance: _currentDistance,
                targetDistance: 40.0,
                onSkip: () {
                  _skipManager.recordSkip(DistanceTestType.shortDistance);
                  setState(() => _isDistanceOk = true);
                },
              ),

              // Feedback Overlay
              if (_showResult)
                TestFeedbackOverlay(
                  isCorrect: _lastResultCorrect,
                  label: _lastResultCorrect ? 'EXCELLENT' : 'NOT CLEAR',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: _showExitConfirmation,
          ),
          // Grouped Chips
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              children: [
                _buildChip(
                  icon: Icons.timer_outlined,
                  label: '${_readingCountdown}s',
                  color: _readingCountdown < 10
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(width: 4),
                _buildChip(
                  icon: Icons.auto_graph,
                  label:
                      '${_currentScreen + 1}/${TestConstants.shortDistanceSentences.length}',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          _buildDistanceMiniIndicator(),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceMiniIndicator() {
    final color = DistanceHelper.getDistanceColor(_currentDistance, 40.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '${_currentDistance.toStringAsFixed(0)}cm',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceView() {
    final sentence = TestConstants.shortDistanceSentences[_currentScreen];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sentence.sentence,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sentence.fontSize,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.4,
              letterSpacing: 0.2,
            ),
          ),
          if (_recognizedText != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _recognizedText!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_showKeyboard)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type what you read...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: () => _processSentence(_inputController.text),
                  ),
                ),
                onSubmitted: _processSentence,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLargeActionButton(
                icon: Icons.mic_rounded,
                label: _isListening ? 'LISTENING' : 'VOICE',
                isActive: _isListening,
                color: AppColors.primary,
                onTap: _startListening,
              ),
              const SizedBox(width: 16),
              _buildLargeActionButton(
                icon: Icons.keyboard_rounded,
                label: 'KEYBOARD',
                isActive: _showKeyboard,
                color: AppColors.textSecondary,
                onTap: () {
                  setState(() => _showKeyboard = !_showKeyboard);
                  if (_showKeyboard) _inputFocusNode.requestFocus();
                },
              ),
              const SizedBox(width: 16),
              _buildLargeActionButton(
                icon: Icons.visibility_off_rounded,
                label: 'BLURRY',
                isActive: false,
                color: AppColors.warning,
                onTap: () => _processSentence('blurry'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppColors.white : color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isActive ? AppColors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCompleteView() {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EyeLoader(color: AppColors.white, size: 80),
            const SizedBox(height: 32),
            const Text(
              'READING TEST COMPLETE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Navigating in ${_secondsRemaining}s...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _navigateToColorVision,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'CONTINUE NOW',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
