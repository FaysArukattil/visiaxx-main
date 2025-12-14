import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/utils/app_logger.dart';
import 'package:visiaxx/core/utils/fuzzy_matcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/short_distance_result.dart';

/// Short distance reading test - both eyes open, 40cm distance
class ShortDistanceTestScreen extends StatefulWidget {
  const ShortDistanceTestScreen({super.key});

  @override
  State<ShortDistanceTestScreen> createState() =>
      _ShortDistanceTestScreenState();
}

class _ShortDistanceTestScreenState extends State<ShortDistanceTestScreen> {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();

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

  // Result feedback
  bool _lastResultCorrect = false;
  double _lastSimilarity = 0.0;

  @override
  void initState() {
    super.initState();
    _initServices();
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
    });

    // Speak instruction
    _ttsService.speak('Read the sentence on screen');

    // Start listening
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _waitingForResponse) {
        _startListening();
      }
    });

    // Auto-timeout after 10 seconds
    _listeningTimer = Timer(const Duration(seconds: 10), () {
      if (_waitingForResponse) {
        final lastValue = _speechService.finalizeWithLastValue();
        if (lastValue != null && lastValue.isNotEmpty) {
          _processSentence(lastValue);
        } else {
          _processSentence(''); // No response
        }
      }
    });
  }

  Future<void> _startListening() async {
    await _speechService.startListening(
      listenFor: const Duration(seconds: 10),
      bufferMs: 500,
      autoRestart: false,
      minConfidence: 0.3,
    );
  }

  void _handleVoiceResponse(String recognized) {
    if (!_waitingForResponse) return;

    // Process the sentence
    _processSentence(recognized);
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

    // Calculate best acuity (smallest font size where user passed)
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
    _ttsService.dispose();
    _speechService.dispose();
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
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: _showSentence
                  ? _buildSentenceView()
                  : const Center(child: CircularProgressIndicator()),
            ),
            if (_isListening) _buildListeningIndicator(),
            if (_showResult) _buildResultFeedback(),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Snellen notation
            Text(
              sentence.snellen,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

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
            if (_waitingForResponse)
              Text(
                'Read this sentence aloud',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
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
