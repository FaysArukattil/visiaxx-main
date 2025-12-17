import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/utils/app_logger.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/core/utils/fuzzy_matcher.dart';
import 'package:visiaxx/widgets/common/snellen_size_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/short_distance_result.dart';

/// Short distance reading test - both eyes open, 40cm distance
/// ✅ ULTRA-RELIABLE voice recognition with continuous listening
class ShortDistanceTestScreen extends StatefulWidget {
  const ShortDistanceTestScreen({super.key});

  @override
  State<ShortDistanceTestScreen> createState() =>
      _ShortDistanceTestScreenState();
}

class _ShortDistanceTestScreenState extends State<ShortDistanceTestScreen> {
  // ✅ ENHANCED: Speech tracking with chunk-based accumulation
  String _accumulatedSpeech = '';
  Timer? _speechBufferTimer;
  List<String> _speechChunks = [];
  static const Duration _speechBufferDelay = Duration(milliseconds: 2000);

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

  // Voice recognition
  bool _isListening = false;
  String? _recognizedText;
  Timer? _listeningTimer;

  // Text input
  final TextEditingController _inputController = TextEditingController();
  bool _showKeyboard = false;

  // Result feedback
  bool _lastResultCorrect = false;
  double _lastSimilarity = 0.0;

  Timer? _autoNavigationTimer;
  int _autoNavigationCountdown = 3;

  @override
  void initState() {
    super.initState();
    _initServices();
    // ✅ Start distance monitoring immediately (don't wait for initServices)
    _startDistanceMonitoring();
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    _speechService.onResult = _handleVoiceResponse;
    _speechService.onSpeechDetected = _handleSpeechDetected;
    _speechService.onListeningStarted = () {
      if (mounted) setState(() => _isListening = true);
    };
    _speechService.onListeningStopped = () {
      if (mounted) setState(() => _isListening = false);
    };

    // Start first sentence
    _showNextSentence();
  }

  Future<void> _startDistanceMonitoring() async {
    try {
      debugPrint('[ShortDistance] 📏 Starting distance monitoring...');

      // ✅ Set up callbacks BEFORE initializing
      _distanceService.onDistanceUpdate = (distance, status) {
        if (!mounted) return;

        debugPrint(
          '[ShortDistance] 📏 Distance: ${distance.toStringAsFixed(0)}cm, Status: $status',
        );

        // ✅ Use centralized helper
        final newIsOk = DistanceHelper.isDistanceAcceptable(distance, 40.0);

        setState(() {
          _currentDistance = distance;
          _distanceStatus = status;
          _isDistanceOk = newIsOk;
        });
      };

      _distanceService.onError = (msg) {
        debugPrint('[ShortDistance] ⚠️ Distance error: $msg');
      };

      // ✅ Initialize camera with proper error handling
      final camera = await _distanceService.initializeCamera();

      if (camera == null) {
        debugPrint('[ShortDistance] ❌ Failed to initialize camera');
        return;
      }

      debugPrint('[ShortDistance] ✅ Camera initialized');

      // ✅ Start monitoring with delay to ensure camera is ready
      await Future.delayed(const Duration(milliseconds: 500));

      await _distanceService.startMonitoring();

      debugPrint('[ShortDistance] ✅ Distance monitoring started');
    } catch (e) {
      debugPrint('[ShortDistance] ❌ Error starting distance monitoring: $e');
    }
  }

  /// ✅ UPDATED: Enhanced sentence flow with longer timeout
  void _showNextSentence() {
    if (_currentScreen >= TestConstants.shortDistanceSentences.length) {
      _completeTest();
      return;
    }

    // Reset ALL speech state
    _accumulatedSpeech = '';
    _speechChunks.clear();
    _speechBufferTimer?.cancel();

    setState(() {
      _showSentence = true;
      _waitingForResponse = true;
      _showResult = false;
      _recognizedText = null;
      _inputController.clear();
      _showKeyboard = false;
    });

    _ttsService.speak('Read the sentence on screen');

    // Start listening after delay
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _waitingForResponse && !_showKeyboard) {
        _startListening();
      }
    });

    // ✅ INCREASED timeout to 35 seconds for longer sentences
    _listeningTimer = Timer(const Duration(seconds: 35), () {
      if (_waitingForResponse) {
        final finalText = _accumulatedSpeech.trim();

        if (finalText.isNotEmpty) {
          debugPrint('[ShortDistance] ⏱️ Timeout - using: "$finalText"');
          _processSentence(finalText);
        } else if (_inputController.text.trim().isNotEmpty) {
          _processSentence(_inputController.text.trim());
        } else {
          debugPrint('[ShortDistance] ⏱️ Timeout - NO RESPONSE');
          _processSentence(''); // No response
        }
      }
    });
  }

  /// ✅ ULTRA-RELIABLE: Start listening with optimal settings
  Future<void> _startListening() async {
    _accumulatedSpeech = '';
    _speechChunks.clear();

    debugPrint('[ShortDistance] 🎤 Starting ULTRA-RELIABLE voice recognition');

    await _speechService.startListening(
      listenFor: const Duration(seconds: 30), // ✅ LONGER duration
      pauseFor: const Duration(seconds: 5), // ✅ LONGER pause tolerance
      bufferMs: 2000, // ✅ LONGER buffer (2 seconds)
      autoRestart: true, // ✅ Keep listening continuously
      minConfidence: 0.1, // ✅ VERY LOW threshold - accept almost anything
    );
  }

  /// ✅ Handle final voice response
  void _handleVoiceResponse(String recognized) {
    if (!_waitingForResponse) return;

    _speechBufferTimer?.cancel();

    // Use accumulated speech if available, otherwise use recognized result
    final finalText = _accumulatedSpeech.isNotEmpty
        ? _accumulatedSpeech.trim()
        : recognized.trim();

    if (finalText.isNotEmpty) {
      debugPrint('[ShortDistance] 🎤 Final recognized: "$finalText"');
      _processSentence(finalText);
    }
  }

  /// ✅ IMPROVED: Smart speech accumulation with word merging
  void _handleSpeechDetected(String partialResult) {
    if (!mounted || !_waitingForResponse) return;

    debugPrint('[ShortDistance] 🎤 Detected: "$partialResult"');

    // Cancel existing buffer timer
    _speechBufferTimer?.cancel();

    if (partialResult.trim().isEmpty) return;

    // Clean the input
    final cleaned = partialResult.trim().toLowerCase();

    // Add to chunks if it's new content
    if (_speechChunks.isEmpty || !_speechChunks.last.contains(cleaned)) {
      _speechChunks.add(cleaned);
    }

    // Smart merging: combine all unique words from chunks
    final allWords = <String>[];
    final seenWords = <String>{};

    for (final chunk in _speechChunks) {
      for (final word in chunk.split(' ')) {
        final cleanWord = word.trim();
        if (cleanWord.isNotEmpty && !seenWords.contains(cleanWord)) {
          allWords.add(cleanWord);
          seenWords.add(cleanWord);
        }
      }
    }

    // Build accumulated speech from unique words
    _accumulatedSpeech = allWords.join(' ');

    debugPrint('[ShortDistance] 📝 Accumulated: "$_accumulatedSpeech"');

    setState(() {
      _recognizedText = _accumulatedSpeech;
    });

    // Set timer to process after user stops speaking
    _speechBufferTimer = Timer(_speechBufferDelay, () {
      if (_accumulatedSpeech.trim().isNotEmpty && _waitingForResponse) {
        debugPrint('[ShortDistance] ✅ Processing final: "$_accumulatedSpeech"');
        _processSentence(_accumulatedSpeech.trim());
      }
    });
  }

  /// Process the sentence response
  void _processSentence(String userSaid) {
    _listeningTimer?.cancel();
    _speechService.cancel();

    if (!_waitingForResponse) return;

    setState(() => _waitingForResponse = false);

    final sentence = TestConstants.shortDistanceSentences[_currentScreen];
    final matchResult = FuzzyMatcher.getMatchResult(
      sentence.sentence,
      userSaid,
      threshold: 70.0,
    );

    final isCorrect = matchResult.passed;
    if (isCorrect) _correctCount++;

    // Store result as SentenceResponse
    final result = SentenceResponse(
      screenNumber: _currentScreen + 1,
      expectedSentence: sentence.sentence,
      userResponse: userSaid,
      similarity: matchResult.similarity,
      passed: isCorrect,
      snellen: sentence.snellen,
      fontSize: sentence.fontSize,
    );
    _results.add(result);

    // Log to file
    AppLogger.logShortDistance(
      screenNumber: _currentScreen + 1,
      snellen: sentence.snellen,
      fontSize: sentence.fontSize,
      expected: sentence.sentence,
      userSaid: userSaid,
      similarity: matchResult.similarity,
      pass: isCorrect,
    );

    // Voice feedback
    if (isCorrect) {
      _ttsService.speak('Correct');
    } else {
      _ttsService.speak('Not quite right');
    }

    // Show result
    setState(() {
      _showResult = true;
      _lastResultCorrect = isCorrect;
      _lastSimilarity = matchResult.similarity;
    });

    // Move to next after brief delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _currentScreen++;
      _showNextSentence();
    });
  }

  void _startAutoNavigationTimer() {
    _autoNavigationTimer?.cancel();

    _autoNavigationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _autoNavigationCountdown--;
      });

      if (_autoNavigationCountdown <= 0) {
        timer.cancel();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/color-vision-test');
        }
      }
    });
  }

  void _completeTest() {
    setState(() {
      _testComplete = true;
      _showSentence = false;
      _autoNavigationCountdown = 3; // Initialize countdown
    });

    // Calculate best acuity
    String bestAcuity = '6/60';
    for (final result in _results.reversed) {
      if (result.passed) {
        bestAcuity = result.snellen;
        break;
      }
    }

    // Calculate average similarity
    final avgSimilarity = _results.isEmpty
        ? 0.0
        : _results.map((r) => r.similarity).reduce((a, b) => a + b) /
              _results.length;

    // Determine status
    String status;
    if (avgSimilarity >= 85.0) {
      status = 'Excellent';
    } else if (avgSimilarity >= 70.0) {
      status = 'Good';
    } else if (avgSimilarity >= 50.0) {
      status = 'Fair';
    } else {
      status = 'Needs Improvement';
    }

    // Create result object
    final result = ShortDistanceResult(
      correctSentences: _correctCount,
      totalSentences: TestConstants.shortDistanceSentences.length,
      averageSimilarity: avgSimilarity,
      bestAcuity: bestAcuity,
      durationSeconds: 0,
      responses: _results,
      status: status,
    );

    // Save to provider
    final provider = context.read<TestSessionProvider>();
    provider.setShortDistanceResult(result);

    _ttsService.speak('Reading test complete');

    // Start auto-navigation timer
    _startAutoNavigationTimer();
  }

  @override
  void dispose() {
    debugPrint('[ShortDistance] 🧹 Disposing resources...');
    _listeningTimer?.cancel();
    _speechBufferTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _speechChunks.clear();
    _inputController.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    _distanceService.stopMonitoring().then((_) {
      _distanceService.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_testComplete) {
      return _buildCompleteView();
    }

    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: const Text('Reading Test'),
        backgroundColor: AppColors.primary.withOpacity(0.1),
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
                _buildProgressBar(),
                Expanded(
                  child: _showSentence
                      ? _buildSentenceView()
                      : const Center(child: CircularProgressIndicator()),
                ),
                if (_isListening && !_showKeyboard) _buildListeningIndicator(),
                if (_showResult) _buildResultFeedback(),
              ],
            ),

            // Distance indicator in bottom right
            Positioned(right: 12, bottom: 12, child: _buildDistanceIndicator()),

            // ✅ Distance warning overlay (voice continues in background)
            if (_isDistanceOk == false && _showSentence && _waitingForResponse)
              _buildDistanceWarningOverlay(),
          ],
        ),
      ),
    );
  }

  /// ✅ FIXED: Distance warning that doesn't stop voice recognition
  Widget _buildDistanceWarningOverlay() {
    // ✅ Dynamic messages based on status
    final pauseReason = DistanceHelper.getPauseReason(_distanceStatus, 40.0);
    final instruction = DistanceHelper.getDetailedInstruction(40.0);
    final rangeText = DistanceHelper.getAcceptableRangeText(40.0);

    // ✅ Icon changes based on issue
    final icon = _distanceStatus == DistanceStatus.noFaceDetected
        ? Icons.face_retouching_off
        : Icons.warning_rounded;

    final iconColor = _distanceStatus == DistanceStatus.noFaceDetected
        ? AppColors.error
        : AppColors.warning;

    return Container(
      color: Colors.black.withOpacity(0.85),
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
                pauseReason, // ✅ Dynamic
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                instruction, // ✅ Dynamic
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // ✅ Only show distance if face is detected
              if (_distanceStatus != DistanceStatus.noFaceDetected) ...[
                Text(
                  _currentDistance > 0
                      ? 'Current: ${_currentDistance.toStringAsFixed(0)}cm'
                      : 'Measuring...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  rangeText, // ✅ Dynamic
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
                        'Position your face in the camera',
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

              const SizedBox(height: 20),

              // ✅ Voice indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
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
              const SizedBox(height: 16),

              // Skip button
              TextButton(
                onPressed: () {
                  setState(() {
                    _isDistanceOk = true;
                  });
                  // Voice continues in background - no need to restart
                },
                child: Text(
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

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Text(
            'Screen ${_currentScreen + 1}/${TestConstants.shortDistanceSentences.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            '$_correctCount/${_results.length} correct',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// ✅ IMPROVED: Better sentence view with prominent size indicator
  /// ✅ FIXED: No overflow when keyboard appears
  Widget _buildSentenceView() {
    final sentence = TestConstants.shortDistanceSentences[_currentScreen];

    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ Calculate available space dynamically
        final hasKeyboard = MediaQuery.of(context).viewInsets.bottom > 0;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: hasKeyboard ? 24 : 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ Size indicator - more compact when keyboard is open
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: hasKeyboard ? 16 : 20,
                    vertical: hasKeyboard ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.straighten,
                        size: hasKeyboard ? 16 : 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sentence.snellen,
                        style: TextStyle(
                          fontSize: hasKeyboard ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: hasKeyboard ? 16 : 32),

                // The sentence - smaller when keyboard is open
                Text(
                  sentence.sentence,
                  style: TextStyle(
                    fontSize: hasKeyboard
                        ? sentence.fontSize * 0.8
                        : sentence.fontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: hasKeyboard ? 24 : 48),

                // Instruction
                if (_waitingForResponse) ...[
                  Text(
                    'Read this sentence aloud or type it',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: hasKeyboard ? 12 : 14,
                    ),
                  ),
                  SizedBox(height: hasKeyboard ? 12 : 24),

                  // ✅ FIXED: Compact toggle buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      // Voice button
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showKeyboard = false;
                            _inputController.clear();
                          });
                          if (!_isListening) {
                            _startListening();
                          }
                        },
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 18,
                        ),
                        label: Text(
                          _isListening ? 'Listening...' : 'Speak',
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening
                              ? AppColors.success
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),

                      // Type button - changes to "Hide" when keyboard is open
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showKeyboard = !_showKeyboard;
                          });
                          if (_showKeyboard) {
                            _speechService.cancel();
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () {
                                FocusScope.of(
                                  context,
                                ).requestFocus(FocusNode());
                              },
                            );
                          }
                        },
                        icon: Icon(
                          _showKeyboard ? Icons.keyboard_hide : Icons.keyboard,
                          size: 18,
                        ),
                        label: Text(
                          _showKeyboard ? 'Hide' : 'Type',
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ✅ FIXED: Compact text input field
                  if (_showKeyboard) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth - 48,
                      ),
                      child: TextField(
                        controller: _inputController,
                        autofocus: true,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Type here...',
                          hintStyle: const TextStyle(fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _processSentence(value.trim());
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_inputController.text.trim().isNotEmpty) {
                          _processSentence(_inputController.text.trim());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListeningIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.success.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _recognizedText ?? 'Listening...',
              style: const TextStyle(color: AppColors.success, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultFeedback() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: _lastResultCorrect
          ? AppColors.success.withOpacity(0.1)
          : AppColors.error.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _lastResultCorrect ? Icons.check_circle : Icons.cancel,
            color: _lastResultCorrect ? AppColors.success : AppColors.error,
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _lastResultCorrect ? 'Correct!' : 'Not quite right',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _lastResultCorrect
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              Text(
                'Match: ${_lastSimilarity.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      40.0,
    );
    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'No face';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.15),
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

  Widget _buildCompleteView() {
    final avgSimilarity = _results.isEmpty
        ? 0.0
        : _results.map((r) => r.similarity).reduce((a, b) => a + b) /
              _results.length;

    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: const Text('Test Complete'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppColors.success),
            const SizedBox(height: 24),
            const Text(
              'Reading Test Complete!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Results card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildStatRow('Sentences', '$_correctCount/7'),
                  const Divider(height: 24),
                  _buildStatRow(
                    'Average Match',
                    '${avgSimilarity.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Auto-continue countdown indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: Center(
                      child: Text(
                        '$_autoNavigationCountdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Auto-continuing in $_autoNavigationCountdown second${_autoNavigationCountdown != 1 ? 's' : ''}...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Continue button (can click immediately or wait)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _autoNavigationTimer?.cancel();
                  Navigator.pushReplacementNamed(context, '/color-vision-test');
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Continue Now'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
