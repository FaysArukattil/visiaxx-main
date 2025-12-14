import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/utils/app_logger.dart';
import 'package:visiaxx/core/utils/fuzzy_matcher.dart';
import 'package:visiaxx/widgets/common/snellen_size_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/short_distance_result.dart';
import '../../../core/services/distance_detection_service.dart';

/// Short distance reading test - both eyes open, 40cm distance
class ShortDistanceTestScreen extends StatefulWidget {
  const ShortDistanceTestScreen({super.key});

  @override
  State<ShortDistanceTestScreen> createState() =>
      _ShortDistanceTestScreenState();
}

class _ShortDistanceTestScreenState extends State<ShortDistanceTestScreen> {
  String _accumulatedSpeech =
      ''; // Accumulate speech across multiple detections
  Timer? _speechBufferTimer; // Timer to detect end of speech
  static const Duration _speechBufferDelay = Duration(milliseconds: 1500);
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

  @override
  void initState() {
    super.initState();
    _initServices();
    _startDistanceMonitoring();
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    _speechService.onResult = _handleVoiceResponse;
    _speechService.onSpeechDetected = (text) {
      if (mounted) {
        setState(() => _recognizedText = text);
      }
    };
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
    _distanceService.onDistanceUpdate = (distance, status) {
      if (!mounted) return;
      setState(() {
        _currentDistance = distance;
        _distanceStatus = status;
        _isDistanceOk = status == DistanceStatus.optimal;
      });
    };

    _distanceService.onError = (msg) => debugPrint('[ShortDistance] $msg');

    await _distanceService.initializeCamera();
    await _distanceService.startMonitoring();
  }

  void _showNextSentence() {
    if (_currentScreen >= TestConstants.shortDistanceSentences.length) {
      _completeTest();
      return;
    }

    // Reset speech state
    _accumulatedSpeech = '';
    _speechBufferTimer?.cancel();

    setState(() {
      _showSentence = true;
      _waitingForResponse = true;
      _showResult = false;
      _recognizedText = null;
      _inputController.clear();
      _showKeyboard = false;
    });

    // Speak instruction
    _ttsService.speak('Read the sentence on screen');

    // Start listening after a delay
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _waitingForResponse && !_showKeyboard) {
        _startListening();
      }
    });

    // Auto-timeout after 20 seconds (increased from 15)
    _listeningTimer = Timer(const Duration(seconds: 20), () {
      if (_waitingForResponse) {
        // Use accumulated speech if available
        final finalText = _accumulatedSpeech.trim();

        if (finalText.isNotEmpty) {
          debugPrint(
            '[ShortDistance] ⏱️ Timeout - using accumulated: $finalText',
          );
          _processSentence(finalText);
        } else if (_inputController.text.trim().isNotEmpty) {
          _processSentence(_inputController.text.trim());
        } else {
          _processSentence(''); // No response
        }
      }
    });
  }

  Future<void> _startListening() async {
    _accumulatedSpeech = ''; // Clear accumulated speech

    await _speechService.startListening(
      listenFor: const Duration(seconds: 20), // Longer duration
      bufferMs: 800, // Longer buffer to capture pauses
      autoRestart: true, // CRITICAL: Auto-restart on silence
      minConfidence: 0.2, // Lower confidence threshold
    );
  }

  void _handleVoiceResponse(String recognized) {
    if (!_waitingForResponse) return;

    _speechBufferTimer?.cancel();

    // If we have accumulated speech, use that; otherwise use the recognized result
    final finalText = _accumulatedSpeech.isNotEmpty
        ? _accumulatedSpeech.trim()
        : recognized.trim();

    if (finalText.isNotEmpty) {
      debugPrint('[ShortDistance] 🎤 Final recognized: $finalText');
      _processSentence(finalText);
    }
  }

  void _handleSpeechDetected(String partialResult) {
    if (!mounted || !_waitingForResponse) return;

    // Cancel existing buffer timer
    _speechBufferTimer?.cancel();

    // Accumulate speech intelligently
    if (partialResult.isNotEmpty) {
      // If accumulated speech is empty or new result is longer, update it
      if (_accumulatedSpeech.isEmpty ||
          partialResult.length > _accumulatedSpeech.length) {
        _accumulatedSpeech = partialResult;
      } else {
        // Try to merge: if new result contains words not in accumulated, append them
        final accWords = _accumulatedSpeech.toLowerCase().split(' ').toSet();
        final newWords = partialResult.toLowerCase().split(' ');

        for (final word in newWords) {
          if (!accWords.contains(word) && word.length > 2) {
            _accumulatedSpeech += ' $word';
          }
        }
      }

      setState(() {
        _recognizedText = _accumulatedSpeech.trim();
      });

      // Set a timer to process the accumulated speech after user stops talking
      _speechBufferTimer = Timer(_speechBufferDelay, () {
        if (_accumulatedSpeech.trim().isNotEmpty && _waitingForResponse) {
          debugPrint(
            '[ShortDistance] 📝 Processing accumulated: $_accumulatedSpeech',
          );
          _processSentence(_accumulatedSpeech.trim());
        }
      });
    }
  }

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

  void _completeTest() {
    setState(() {
      _testComplete = true;
      _showSentence = false;
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
  }

  @override
  void dispose() {
    _listeningTimer?.cancel();
    _speechBufferTimer?.cancel();
    _inputController.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    _distanceService.stopMonitoring();
    _distanceService.dispose();
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
            // 🆕 Distance warning overlay - ADDED THIS
            if (_isDistanceOk == false && _showSentence && _waitingForResponse)
              _buildDistanceWarningOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceWarningOverlay() {
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
              Icon(Icons.warning_rounded, size: 60, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(
                'Please Adjust Distance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maintain 40cm distance for accurate results',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                _currentDistance > 0
                    ? 'Current: ${_currentDistance.toStringAsFixed(0)}cm'
                    : 'Face not detected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _currentDistance > 0
                      ? AppColors.primary
                      : AppColors.error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Acceptable range: 35cm - 45cm',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              // Skip button
              TextButton(
                onPressed: () {
                  setState(() {
                    _isDistanceOk = true;
                  });
                  // Resume listening if it was stopped
                  if (!_isListening && !_showKeyboard) {
                    _startListening();
                  }
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

  Widget _buildSentenceView() {
    final sentence = TestConstants.shortDistanceSentences[_currentScreen];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🆕 Snellen indicator positioned above sentence
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SnellenSizeIndicator(snellenNotation: sentence.snellen),
              ],
            ),
            const SizedBox(height: 16),

            // The sentence
            Text(
              sentence.sentence,
              style: TextStyle(
                fontSize: sentence.fontSize,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Instruction
            if (_waitingForResponse) ...[
              Text(
                'Read this sentence aloud or type it',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Toggle buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    label: Text(_isListening ? 'Listening...' : 'Speak'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? AppColors.success : null,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Type button
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showKeyboard = !_showKeyboard;
                      });
                      if (_showKeyboard) {
                        _speechService.cancel();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          FocusScope.of(context).requestFocus(FocusNode());
                        });
                      }
                    },
                    icon: const Icon(Icons.keyboard),
                    label: Text(_showKeyboard ? 'Hide Keyboard' : 'Type'),
                  ),
                ],
              ),

              // Text input field
              if (_showKeyboard) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _inputController,
                    autofocus: true,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Type the sentence here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _processSentence(value.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (_inputController.text.trim().isNotEmpty) {
                      _processSentence(_inputController.text.trim());
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text('Submit'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
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
    Color indicatorColor;
    String distanceText;

    if (_currentDistance > 0) {
      distanceText = '${_currentDistance.toStringAsFixed(0)}cm';

      // 40cm ±5cm = 35-45cm acceptable range
      if (_currentDistance >= 35 && _currentDistance <= 45) {
        indicatorColor = AppColors.success;
      } else if (_currentDistance >= 30 && _currentDistance <= 50) {
        indicatorColor = AppColors.warning;
      } else {
        indicatorColor = AppColors.error;
      }
    } else {
      distanceText = 'No face';
      indicatorColor = AppColors.error;
    }

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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/color-vision-test',
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Continue to Color Vision Test'),
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
