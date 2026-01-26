import 'dart:async';
import 'dart:ui' as ui;
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
import 'dart:math' as math;

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
  bool _waitingForResponse = false;
  bool _showResult = false;
  bool _testComplete = false;
  bool _isPausedForExit = false;

  // Voice recognition
  bool _isListening = false;
  bool _isSpeechActive = false;
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
    _speechService.setGloballyDisabled(false); // Reset for next session
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

    _ttsService.onSpeakingStateChanged = (isSpeaking) {
      if (!mounted) return;
      if (isSpeaking) {
        if (_isListening) {
          _speechService.stopListening();
        }
      } else if (_waitingForResponse &&
          !_showResult &&
          !_testComplete &&
          !_isPausedForExit) {
        _startListening();
      }
    };

    // Check if we are in practitioner mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<TestSessionProvider>();
        if (provider.profileType == 'patient') {
          debugPrint(
            '👨‍⚕️ [ShortDistance] Practitioner mode detected: Silencing Speech globally',
          );
          _speechService.setGloballyDisabled(true);
        }
      }
    });

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
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _resetTest() {
    setState(() {
      _currentScreen = 0;
      _correctCount = 0;
      _results.clear();
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
      _waitingForResponse = true;
      _showResult = false;
      _recognizedText = null;
      _readingCountdown = 35;
      _showKeyboard = false;
      _inputController.clear();
    });

    _startReadingCountdown();

    String textToSpeak =
        'Level ${_currentScreen + 1}. Please read the sentence aloud.';
    _ttsService.speak(textToSpeak);
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
    _processSentence('');
  }

  void _startListening() async {
    final provider = context.read<TestSessionProvider>();
    if (_isPausedForExit ||
        !_isDistanceOk ||
        provider.profileType == 'patient') {
      return;
    }

    // If already listening, restart the session
    if (_isListening) {
      _speechService.stopListening();
      _listeningTimer?.cancel();
      setState(() {
        _isListening = false;
        _isSpeechActive = false;
        _recognizedText = null;
      });
      // Small delay before restarting
      await Future.delayed(const Duration(milliseconds: 100));
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
          setState(() {
            _recognizedText = text;
            _isSpeechActive = true;
          });

          _speechActiveTimer?.cancel();
          _speechActiveTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _isSpeechActive = false);
          });
        }
      };
      _speechService.onError = (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _isSpeechActive = false;
            _recognizedText = 'Speech Error: $error';
          });
        }
      };

      await _speechService.startListening();

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

    Future.delayed(const Duration(milliseconds: 1000), () {
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
      durationSeconds: 0,
      responses: _results,
      status: status,
    );

    final provider = context.read<TestSessionProvider>();
    provider.setShortDistanceResult(result);

    // Navigate to intermediate result screen
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/short-distance-quick-result');
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
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 140),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            _buildSentenceView(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Fixed bottom controls
              Positioned(left: 0, right: 0, bottom: 0, child: _buildControls()),
              // Distance indicator positioned over top bar
              Positioned(
                top: 12,
                right: 16,
                child: _buildDistanceMiniIndicator(),
              ),
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
              if (_showResult)
                Positioned.fill(
                  child: TestFeedbackOverlay(
                    isCorrect: _lastResultCorrect,
                    label: _lastResultCorrect ? 'EXCELLENT' : 'NOT CLEAR',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: _showExitConfirmation,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: ShapeDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'LEVEL ${_currentScreen + 1}/${TestConstants.shortDistanceSentences.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: ShapeDecoration(
              color:
                  (_readingCountdown < 10 ? AppColors.error : AppColors.primary)
                      .withValues(alpha: 0.08),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: _readingCountdown < 10
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_readingCountdown}s',
                  style: TextStyle(
                    color: _readingCountdown < 10
                        ? AppColors.error
                        : AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDistanceMiniIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      40.0,
      testType: 'short_distance',
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
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.4,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.read<TestSessionProvider>().profileType == 'patient'
                ? 'Ask the patient to read the sentence below'
                : 'Read the sentence aloud or type below',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isListening ||
              (_recognizedText != null &&
                  _recognizedText != 'Listening...')) ...[
            const SizedBox(height: 32),
            if (_isListening &&
                (_recognizedText == null || _recognizedText == 'Listening...'))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SpeechWaveform(
                      isListening: _isListening,
                      isTalking: _isSpeechActive,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Listening...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            if (_recognizedText != null && _recognizedText != 'Listening...')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _recognizedText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallHeight = screenHeight < 500;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            isSmallHeight ? 8 : 16,
            16,
            isSmallHeight
                ? 8
                : (MediaQuery.of(context).padding.bottom > 0 ? 8 : 24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showKeyboard)
                Padding(
                  padding: EdgeInsets.only(bottom: isSmallHeight ? 8 : 16),
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Type what you read...',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: isSmallHeight
                          ? const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: AppColors.primary),
                        onPressed: () =>
                            _processSentence(_inputController.text),
                      ),
                    ),
                    onSubmitted: _processSentence,
                  ),
                ),
              Builder(
                builder: (context) {
                  final provider = context.watch<TestSessionProvider>();
                  final isPractitioner = provider.profileType == 'patient';

                  if (isPractitioner) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildPremiumActionButton(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'CAN READ',
                            gradient: AppColors.successGradient,
                            height: isSmallHeight ? 50 : 64,
                            onTap: () {
                              final sentence = TestConstants
                                  .shortDistanceSentences[_currentScreen];
                              _processSentence(sentence.sentence);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPremiumActionButton(
                            icon: Icons.highlight_off_rounded,
                            label: 'UNABLE TO READ',
                            gradient: AppColors.errorGradient,
                            height: isSmallHeight ? 50 : 64,
                            onTap: () => _processSentence('blurry'),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _buildLargeActionButton(
                          icon: Icons.keyboard_rounded,
                          label: 'KEYBOARD',
                          isActive: _showKeyboard,
                          compact: isSmallHeight,
                          color: AppColors.textSecondary,
                          onTap: () {
                            setState(() => _showKeyboard = !_showKeyboard);
                            if (_showKeyboard) _inputFocusNode.requestFocus();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: _buildLargeActionButton(
                          icon: Icons.mic_rounded,
                          label: _isListening ? 'LISTENING' : 'VOICE',
                          isActive: _isListening,
                          compact: isSmallHeight,
                          color: AppColors.primary,
                          onTap: _startListening,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: _buildLargeActionButton(
                          icon: Icons.visibility_off_rounded,
                          label: 'BLURRY',
                          isActive: false,
                          compact: isSmallHeight,
                          color: AppColors.warning,
                          onTap: () => _processSentence('blurry'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
    double height = 64,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 16 : 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: BoxConstraints(
          minWidth: compact ? 70 : 90,
          maxWidth: compact ? 100 : 120,
        ),
        height: compact ? 60 : 80,
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 16 : 24),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? AppColors.white : color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isActive ? AppColors.white : color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCompleteView() {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(child: EyeLoader(size: 80)),
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
    final shouldAnimate = widget.isListening || widget.isTalking;

    if (!shouldAnimate) {
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
