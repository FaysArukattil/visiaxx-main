import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/models/visiual_acuity_result.dart';
import '../../../data/providers/test_session_provider.dart';

/// Visual Acuity Test using Tumbling E chart with distance monitoring
class VisualAcuityTestScreen extends StatefulWidget {
  const VisualAcuityTestScreen({super.key});

  @override
  State<VisualAcuityTestScreen> createState() => _VisualAcuityTestScreenState();
}

class _VisualAcuityTestScreenState extends State<VisualAcuityTestScreen> {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Test state
  int _currentLevel = 0;
  int _correctAtLevel = 0;
  int _incorrectAtLevel = 0;
  int _totalCorrect = 0;
  int _totalResponses = 0;
  EDirection _currentDirection = EDirection.right;
  final List<EResponseRecord> _responses = [];
  
  // Eye being tested
  String _currentEye = 'right';
  bool _eyeSwitchPending = false;
  
  // Timing
  Timer? _eDisplayTimer;
  Timer? _relaxationTimer;
  int _relaxationCountdown = 10;
  DateTime? _eDisplayStartTime;
  
  // Display states
  bool _showRelaxation = true;
  bool _showE = false;
  bool _showResult = false;
  bool _testComplete = false;
  bool _waitingForResponse = false;
  
  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = false;
  bool _useDistanceMonitoring = false; // Can be enabled when camera is set up
  
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();
    
    _speechService.onResult = _handleVoiceResponse;
    
    // Start the test
    _startEyeTest();
  }

  void _startEyeTest() {
    _ttsService.speakEyeInstruction(_currentEye);
    
    // Wait a moment then start
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _startRelaxation();
      }
    });
  }

  void _startRelaxation() {
    setState(() {
      _showRelaxation = true;
      _showE = false;
      _relaxationCountdown = TestConstants.relaxationDurationSeconds;
    });

    _ttsService.speak(TtsService.relaxationInstruction);

    _relaxationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _relaxationCountdown--;
      });

      if (_relaxationCountdown <= 3 && _relaxationCountdown > 0) {
        _ttsService.speakCountdown(_relaxationCountdown);
      }

      if (_relaxationCountdown <= 0) {
        timer.cancel();
        _showTumblingE();
      }
    });
  }

  void _showTumblingE() {
    // Generate random direction
    final directions = EDirection.values;
    _currentDirection = directions[_random.nextInt(directions.length)];
    
    setState(() {
      _showRelaxation = false;
      _showE = true;
      _waitingForResponse = true;
    });

    _eDisplayStartTime = DateTime.now();

    // Start listening for voice input
    _speechService.startListening();

    // Auto-advance if no response
    _eDisplayTimer = Timer(
      Duration(seconds: TestConstants.eDisplayDurationSeconds),
      () {
        if (_waitingForResponse) {
          _recordResponse(null); // No response
        }
      },
    );
  }

  void _handleVoiceResponse(String recognized) {
    if (!_waitingForResponse) return;
    
    final direction = SpeechService.parseDirection(recognized);
    if (direction != null) {
      _recordResponse(direction);
    }
  }

  void _handleButtonResponse(EDirection direction) {
    if (!_waitingForResponse) return;
    _recordResponse(direction.label.toLowerCase());
  }

  void _recordResponse(String? userResponse) {
    _eDisplayTimer?.cancel();
    _speechService.stopListening();
    
    final responseTime = _eDisplayStartTime != null
        ? DateTime.now().difference(_eDisplayStartTime!).inMilliseconds
        : 0;
    
    final isCorrect = userResponse?.toLowerCase() == 
        _currentDirection.label.toLowerCase();
    
    final record = EResponseRecord(
      level: _currentLevel,
      eSize: TestConstants.visualAcuityLevels[_currentLevel].size,
      expectedDirection: _currentDirection.label,
      userResponse: userResponse ?? 'No response',
      isCorrect: isCorrect,
      responseTimeMs: responseTime,
    );
    
    _responses.add(record);
    _totalResponses++;
    
    if (isCorrect) {
      _correctAtLevel++;
      _totalCorrect++;
      _playFeedbackSound(true);
    } else {
      _incorrectAtLevel++;
      _playFeedbackSound(false);
    }

    setState(() {
      _waitingForResponse = false;
      _showE = false;
      _showResult = true;
    });

    // Show result briefly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _evaluateAndContinue();
    });
  }

  void _playFeedbackSound(bool correct) async {
    // Simple beep feedback
    try {
      // Using system sounds would be ideal, but for now we'll rely on TTS
      if (correct) {
        _ttsService.speak('Correct');
      }
    } catch (_) {}
  }

  void _evaluateAndContinue() {
    setState(() => _showResult = false);

    // Check if we should advance, stay, or stop
    if (_correctAtLevel >= TestConstants.minCorrectToAdvance) {
      // Advance to next level
      _currentLevel++;
      _correctAtLevel = 0;
      _incorrectAtLevel = 0;

      if (_currentLevel >= TestConstants.visualAcuityLevels.length) {
        // Test complete for this eye
        _completeEyeTest();
      } else {
        _startRelaxation();
      }
    } else if (_incorrectAtLevel >= TestConstants.maxTriesPerLevel - TestConstants.minCorrectToAdvance + 1) {
      // Failed this level, test complete for this eye
      _completeEyeTest();
    } else if (_correctAtLevel + _incorrectAtLevel >= TestConstants.maxTriesPerLevel) {
      // Max tries at this level
      if (_correctAtLevel >= TestConstants.minCorrectToAdvance) {
        _currentLevel++;
        if (_currentLevel >= TestConstants.visualAcuityLevels.length) {
          _completeEyeTest();
        } else {
          _correctAtLevel = 0;
          _incorrectAtLevel = 0;
          _startRelaxation();
        }
      } else {
        _completeEyeTest();
      }
    } else {
      // Continue at same level
      _startRelaxation();
    }
  }

  void _completeEyeTest() {
    // Calculate final score
    final level = _currentLevel > 0 ? _currentLevel - 1 : 0;
    final vaLevel = TestConstants.visualAcuityLevels[level];
    
    String status;
    if (vaLevel.logMAR <= 0.0) {
      status = 'Normal';
    } else if (vaLevel.logMAR <= 0.3) {
      status = 'Mild reduction';
    } else {
      status = 'Significant reduction';
    }

    final result = VisualAcuityResult(
      eye: _currentEye,
      snellenScore: vaLevel.snellen,
      logMAR: vaLevel.logMAR,
      correctResponses: _totalCorrect,
      totalResponses: _totalResponses,
      durationSeconds: _responses.isNotEmpty 
          ? (_responses.map((r) => r.responseTimeMs).reduce((a, b) => a + b) / 1000).round()
          : 0,
      responses: _responses.toList(),
      status: status,
    );

    // Save result
    final provider = context.read<TestSessionProvider>();
    provider.setVisualAcuityResult(result);

    if (_currentEye == 'right') {
      // Switch to left eye
      setState(() {
        _eyeSwitchPending = true;
      });
    } else {
      // Both eyes complete
      setState(() {
        _testComplete = true;
      });
    }
  }

  void _switchToLeftEye() {
    setState(() {
      _currentEye = 'left';
      _eyeSwitchPending = false;
      _currentLevel = 0;
      _correctAtLevel = 0;
      _incorrectAtLevel = 0;
      _totalCorrect = 0;
      _totalResponses = 0;
      _responses.clear();
    });
    
    final provider = context.read<TestSessionProvider>();
    provider.switchEye();
    
    _startEyeTest();
  }

  void _proceedToColorTest() {
    Navigator.pushReplacementNamed(context, '/color-vision-test');
  }

  @override
  void dispose() {
    _eDisplayTimer?.cancel();
    _relaxationTimer?.cancel();
    _ttsService.dispose();
    _speechService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: Text('Visual Acuity - ${_currentEye.toUpperCase()} Eye'),
        backgroundColor: _currentEye == 'right' 
            ? AppColors.rightEye.withOpacity(0.1)
            : AppColors.leftEye.withOpacity(0.1),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress and info bar
            _buildInfoBar(),
            
            // Main content
            Expanded(
              child: _buildMainContent(),
            ),
            
            // Direction buttons (when showing E)
            if (_showE && _waitingForResponse) _buildDirectionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Eye indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _currentEye == 'right' 
                  ? AppColors.rightEye.withOpacity(0.1)
                  : AppColors.leftEye.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: _currentEye == 'right' 
                      ? AppColors.rightEye 
                      : AppColors.leftEye,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_currentEye.toUpperCase()} EYE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _currentEye == 'right' 
                        ? AppColors.rightEye 
                        : AppColors.leftEye,
                  ),
                ),
              ],
            ),
          ),
          // Level indicator
          Text(
            'Level ${_currentLevel + 1}/${TestConstants.visualAcuityLevels.length}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          // Score
          Text(
            'Score: $_totalCorrect/$_totalResponses',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_testComplete) {
      return _buildTestCompleteView();
    }
    
    if (_eyeSwitchPending) {
      return _buildEyeSwitchView();
    }
    
    if (_showRelaxation) {
      return _buildRelaxationView();
    }
    
    if (_showE) {
      return _buildEView();
    }
    
    if (_showResult) {
      return _buildResultFeedback();
    }
    
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildRelaxationView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Relaxation image
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
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
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary.withOpacity(0.1),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.landscape, size: 80, color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Focus on the distance...', 
                          style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Countdown
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: Center(
                  child: Text(
                    '$_relaxationCountdown',
                    style: const TextStyle(
                      color: Colors.white,
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
    );
  }

  Widget _buildEView() {
    final eSize = TestConstants.visualAcuityLevels[_currentLevel].size;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Current level info
          Text(
            'Size: ${TestConstants.visualAcuityLevels[_currentLevel].snellen}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          // The Tumbling E
          Transform.rotate(
            angle: _currentDirection.rotationDegrees * pi / 180,
            child: Text(
              'E',
              style: TextStyle(
                fontSize: eSize,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Instruction
          Text(
            'Which way is the E pointing?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use buttons below or say: Up, Down, Left, Right',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up button
          _DirectionButton(
            direction: EDirection.up,
            onPressed: () => _handleButtonResponse(EDirection.up),
          ),
          const SizedBox(height: 12),
          // Left, Right buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DirectionButton(
                direction: EDirection.left,
                onPressed: () => _handleButtonResponse(EDirection.left),
              ),
              const SizedBox(width: 60),
              _DirectionButton(
                direction: EDirection.right,
                onPressed: () => _handleButtonResponse(EDirection.right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Down button
          _DirectionButton(
            direction: EDirection.down,
            onPressed: () => _handleButtonResponse(EDirection.down),
          ),
        ],
      ),
    );
  }

  Widget _buildResultFeedback() {
    final lastResponse = _responses.isNotEmpty ? _responses.last : null;
    final isCorrect = lastResponse?.isCorrect ?? false;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 100,
            color: isCorrect ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? 'Correct!' : 'Incorrect',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isCorrect ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeSwitchView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.visibility_off,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Right Eye Complete!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Now let\'s test your left eye.\n\nCover your RIGHT eye and tap Continue when ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _switchToLeftEye,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Continue with Left Eye'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCompleteView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: AppColors.success,
          ),
          const SizedBox(height: 24),
          Text(
            'Visual Acuity Test Complete!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Summary cards
          _buildSummaryCard(
            'Right Eye',
            context.read<TestSessionProvider>().visualAcuityRight?.snellenScore ?? 'N/A',
            AppColors.rightEye,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Left Eye',
            context.read<TestSessionProvider>().visualAcuityLeft?.snellenScore ?? 'N/A',
            AppColors.leftEye,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceedToColorTest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Continue to Color Vision Test'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String eye, String score, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.visibility, color: color),
              const SizedBox(width: 12),
              Text(
                eye,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            score,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final EDirection direction;
  final VoidCallback onPressed;

  const _DirectionButton({
    required this.direction,
    required this.onPressed,
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
        child: Container(
          width: 70,
          height: 70,
          child: Icon(
            _icon,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
