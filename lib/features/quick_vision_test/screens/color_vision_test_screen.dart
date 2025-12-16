import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../data/providers/test_session_provider.dart';
import 'distance_calibration_screen.dart';

/// Color Vision Test using Ishihara plates
class ColorVisionTestScreen extends StatefulWidget {
  const ColorVisionTestScreen({super.key});

  @override
  State<ColorVisionTestScreen> createState() => _ColorVisionTestScreenState();
}

class _ColorVisionTestScreenState extends State<ColorVisionTestScreen> {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  final DistanceDetectionService _distanceService = DistanceDetectionService(
    targetDistanceCm: 40.0,
    toleranceCm: 5.0,
  );
  final TextEditingController _answerController = TextEditingController();

  // Test state
  int _currentPlate = 0;
  final List<PlateResponse> _responses = [];
  bool _testComplete = false;
  bool _showingPlate = false;
  bool _showDistanceCalibration = true;

  // Voice recognition feedback
  bool _isListening = false;
  String? _lastDetectedSpeech;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = true; // Start as true to avoid initial blocking
  bool _isTestPausedForDistance = false;
  DistanceStatus? _lastSpokenDistanceStatus;
  Timer? _distanceAutoSkipTimer; // Auto-skip after 10 seconds

  // Timer
  Timer? _plateTimer;
  int _timeRemaining = TestConstants.colorVisionTimePerPlateSeconds;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    // Set up speech service callbacks
    _speechService.onResult = _handleVoiceResponse;
    _speechService.onSpeechDetected = (text) {
      if (mounted) setState(() => _lastDetectedSpeech = text);
    };
    _speechService.onListeningStarted = () {
      if (mounted) setState(() => _isListening = true);
    };
    _speechService.onListeningStopped = () {
      if (mounted) setState(() => _isListening = false);
    };

    // Show distance calibration first
    if (_showDistanceCalibration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCalibrationScreen();
      });
    } else {
      _startTest();
    }
  }

  /// Show distance calibration screen
  void _showCalibrationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: 40.0,
          toleranceCm: 5.0,
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

  /// Start continuous distance monitoring
  Future<void> _startContinuousDistanceMonitoring() async {
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    _distanceService.onError = (msg) => debugPrint('[DistanceMonitor] $msg');

    if (!_distanceService.isReady) {
      await _distanceService.initializeCamera();
    }

    if (!_distanceService.isMonitoring) {
      await _distanceService.startMonitoring();
    }
  }

  /// Handle real-time distance updates
  /// Handle real-time distance updates with auto pause/resume
  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    // ✅ Use centralized helper
    final newIsOk = DistanceHelper.isDistanceAcceptable(distance, 40.0);
    final shouldPause = DistanceHelper.shouldPauseTest(status);

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
      _isDistanceOk = newIsOk;
    });

    // ✅ AUTO PAUSE/RESUME for active test
    if (_showingPlate && !_testComplete) {
      if (shouldPause && !_isTestPausedForDistance) {
        _pauseTestForDistance();
      } else if (!shouldPause && _isTestPausedForDistance) {
        _resumeTestAfterDistance();
      }
    }

    // Speak guidance when paused and status changes
    if (_isTestPausedForDistance && status != _lastSpokenDistanceStatus) {
      _lastSpokenDistanceStatus = status;
      _speakDistanceGuidance(status);
    }
  }

  void _speakDistanceGuidance(DistanceStatus status) {
    switch (status) {
      case DistanceStatus.tooClose:
        _ttsService.speak('Move back, you are too close');
        break;
      case DistanceStatus.tooFar:
        _ttsService.speak('Move closer, you are too far');
        break;
      case DistanceStatus.optimal:
        _ttsService.speak('Good, distance is correct');
        break;
      case DistanceStatus.noFaceDetected:
        _ttsService.speak('Position your face in view');
        break;
    }
  }

  void _pauseTestForDistance() {
    setState(() => _isTestPausedForDistance = true);
    _plateTimer?.cancel();
    _speechService.stopListening();
    _ttsService.speak(
      'Test paused. Please adjust your distance to 40 centimeters.',
    );
    HapticFeedback.heavyImpact();

    // Auto-skip after 10 seconds if distance not corrected
    _distanceAutoSkipTimer?.cancel();
    _distanceAutoSkipTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isTestPausedForDistance) {
        debugPrint('[ColorVisionTest] Auto-skipping distance check after 10s');
        _forceSkipDistanceCheck();
      }
    });
  }

  /// Force skip distance check and resume test
  void _forceSkipDistanceCheck() {
    _distanceAutoSkipTimer?.cancel();
    setState(() {
      _isDistanceOk = true;
      _isTestPausedForDistance = false;
    });
    _ttsService.speak('Resuming test');
    _restartPlateTimer();
    _speechService.startListening(
      listenFor: Duration(seconds: _timeRemaining + 2),
    );
  }

  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;
    _distanceAutoSkipTimer
        ?.cancel(); // Cancel auto-skip since distance is OK now
    setState(() => _isTestPausedForDistance = false);
    _ttsService.speak('Resuming test');
    _restartPlateTimer();
    _speechService.startListening(
      listenFor: Duration(seconds: _timeRemaining + 2),
    );
    HapticFeedback.mediumImpact();
  }

  void _restartPlateTimer() {
    if (_timeRemaining <= 0) {
      _submitAnswer('');
      return;
    }

    _plateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) {
        timer.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        timer.cancel();
        _submitAnswer('');
      }
    });
  }

  void _startTest() {
    // Start the test
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showNextPlate();
    });
  }

  void _showNextPlate() {
    if (_currentPlate >= AppAssets.ishiharaPlates.length) {
      _completeTest();
      return;
    }

    // Clear previous state
    _lastDetectedSpeech = null;
    _answerController.clear();

    setState(() {
      _showingPlate = true;
      _timeRemaining = TestConstants.colorVisionTimePerPlateSeconds;
    });

    _ttsService.speakColorVisionPrompt();

    // Start fresh voice listening for this plate
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _speechService.startListening(
          listenFor: Duration(
            seconds: TestConstants.colorVisionTimePerPlateSeconds + 2,
          ),
        );
      }
    });

    // Start countdown timer
    _plateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _submitAnswer(''); // No response
      }
    });
  }

  void _handleVoiceResponse(String recognized) {
    final number = SpeechService.parseNumber(recognized);
    if (number != null) {
      _answerController.text = number;
      _submitAnswer(number);
    }
  }

  void _submitAnswer(String answer) {
    _plateTimer?.cancel();
    _speechService.stopListening();

    final expectedAnswer = AppAssets.ishiharaExpectedAnswers[_currentPlate];
    final isCorrect = answer.trim() == expectedAnswer;

    final response = PlateResponse(
      plateNumber: _currentPlate + 1,
      expectedAnswer: expectedAnswer,
      userAnswer: answer.isEmpty ? 'No response' : answer,
      isCorrect: isCorrect,
      responseTimeMs:
          (TestConstants.colorVisionTimePerPlateSeconds - _timeRemaining) *
          1000,
    );

    _responses.add(response);

    // Show feedback briefly
    setState(() => _showingPlate = false);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      setState(() {
        _currentPlate++;
      });

      if (_currentPlate < AppAssets.ishiharaPlates.length) {
        _showNextPlate();
      } else {
        _completeTest();
      }
    });
  }

  void _completeTest() {
    final correctAnswers = _responses.where((r) => r.isCorrect).length;
    final incorrectPlates = _responses
        .where((r) => !r.isCorrect)
        .map((r) => r.plateNumber)
        .toList();

    String status;
    String? deficiencyType;

    if (correctAnswers >= (AppAssets.ishiharaPlates.length * 0.75)) {
      status = 'Normal';
    } else if (correctAnswers >= (AppAssets.ishiharaPlates.length * 0.5)) {
      status = 'Mild deficiency';
      deficiencyType = 'Possible color vision deficiency';
    } else {
      status = 'Significant deficiency';
      deficiencyType = 'Color vision deficiency detected';
    }

    final result = ColorVisionResult(
      correctAnswers: correctAnswers,
      totalPlates: AppAssets.ishiharaPlates.length,
      plateResponses: _responses,
      status: status,
      deficiencyType: deficiencyType,
      incorrectPlates: incorrectPlates,
    );

    context.read<TestSessionProvider>().setColorVisionResult(result);

    setState(() => _testComplete = true);
    _ttsService.speak(
      'Color vision test complete. Moving to Amsler grid test.',
    );
  }

  void _proceedToAmslerTest() {
    Navigator.pushReplacementNamed(context, '/amsler-grid-test');
  }

  @override
  void dispose() {
    _plateTimer?.cancel();
    _distanceAutoSkipTimer?.cancel(); // Cancel auto-skip timer
    _answerController.dispose();
    _distanceService.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(title: const Text('Color Vision Test')),
      body: SafeArea(
        child: Stack(
          children: [
            _testComplete ? _buildCompleteView() : _buildTestView(),
            // Distance indicator
            if (!_showDistanceCalibration && !_testComplete)
              Positioned(
                right: 12,
                bottom: 12,
                child: _buildDistanceIndicator(),
              ),
            // Distance warning overlay - only show when explicitly paused
            if (_isTestPausedForDistance && _showingPlate && !_testComplete)
              _buildDistanceWarningOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestView() {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentPlate + 1) / AppAssets.ishiharaPlates.length,
          backgroundColor: AppColors.border,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        // Info bar
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plate ${_currentPlate + 1} of ${AppAssets.ishiharaPlates.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _timeRemaining <= 3
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: _timeRemaining <= 3
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_timeRemaining}s',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _timeRemaining <= 3
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Plate display - use LayoutBuilder to maintain consistent plate size
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate a fixed plate size that won't change with input
              final plateSize = constraints.maxWidth - 48;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Voice listening indicator
                    if (_isListening)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(
                              _lastDetectedSpeech != null
                                  ? 'Heard: $_lastDetectedSpeech'
                                  : 'Listening...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Ishihara plate image - fixed size container
                    SizedBox(
                      width: plateSize,
                      height:
                          plateSize * 0.7, // Smaller to leave room for input
                      child: Container(
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
                        child:
                            _showingPlate &&
                                _currentPlate < AppAssets.ishiharaPlates.length
                            ? Image.asset(
                                AppAssets.ishiharaPlates[_currentPlate],
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    _buildPlaceholderPlate(),
                              )
                            : _buildFeedbackView(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Question
                    Text(
                      'What number do you see?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Say the number or type it',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Number input - compact design
                    _buildNumberInput(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderPlate() {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.palette,
              size: 80,
              color: AppColors.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Ishihara Plate ${_currentPlate + 1}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackView() {
    if (_responses.isEmpty) {
      return _buildPlaceholderPlate();
    }

    final lastResponse = _responses.last;
    final isCorrect = lastResponse.isCorrect;

    return Container(
      color: isCorrect
          ? AppColors.success.withOpacity(0.1)
          : AppColors.error.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              size: 80,
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
            if (!isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                'The answer was: ${lastResponse.expectedAnswer}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput() {
    return Row(
      children: [
        // Text field
        Expanded(
          child: TextField(
            controller: _answerController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Enter number',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Submit button
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _showingPlate
                ? () => _submitAnswer(_answerController.text)
                : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Submit'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteView() {
    final result = context.read<TestSessionProvider>().colorVision;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status icon
          Icon(
            result?.isNormal == true ? Icons.check_circle : Icons.warning,
            size: 80,
            color: result?.isNormal == true
                ? AppColors.success
                : AppColors.warning,
          ),
          const SizedBox(height: 24),
          Text(
            'Color Vision Test Complete!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Result card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Score: ${result?.correctAnswers ?? 0}/${result?.totalPlates ?? 0}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  result?.status ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 16,
                    color: result?.isNormal == true
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (result?.incorrectPlates.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Incorrect plates: ${result?.incorrectPlates.join(", ")}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceedToAmslerTest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Continue to Amsler Grid Test'),
              ),
            ),
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
                  rangeText, // ✅ Dynamic: "Minimum 40 cm"
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

              // ✅ Show timer is paused
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_circle,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Timer paused - ${_timeRemaining}s remaining',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Continue button
              TextButton(
                onPressed: () {
                  setState(() {
                    _isDistanceOk = true;
                    _isTestPausedForDistance = false;
                  });
                  _restartPlateTimer();
                  _speechService.startListening(
                    listenFor: Duration(seconds: _timeRemaining + 2),
                  );
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
}
