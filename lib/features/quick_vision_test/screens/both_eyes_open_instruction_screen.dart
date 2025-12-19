import 'package:flutter/material.dart';
import 'package:visiaxx/features/quick_vision_test/screens/distance_calibration_screen.dart';
import 'package:visiaxx/features/quick_vision_test/screens/short_distance_test_screen.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';

class BothEyesOpenInstructionScreen extends StatefulWidget {
  const BothEyesOpenInstructionScreen({super.key});

  @override
  State<BothEyesOpenInstructionScreen> createState() =>
      _BothEyesOpenInstructionScreenState();
}

class _BothEyesOpenInstructionScreenState
    extends State<BothEyesOpenInstructionScreen> {
  int _countdown = 3; // Changed from _buttonEnabled to _countdown
  final TtsService _ttsService = TtsService();
  Timer? _countdownTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _startCountdown(); // Start countdown instead of single timer
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    await Future.delayed(const Duration(milliseconds: 500));
    await _ttsService.speak(
      'Now we will test your near vision for reading. '
      'Keep both eyes open. '
      'Hold your device at 40 centimeters from your eyes. '
      'That is about the length from your elbow to your fingertips. '
      'You will see sentences on the screen. '
      'Read each sentence aloud clearly and completely.',
      speechRate: 0.5,
    );
  }

  // NEW: Countdown timer that auto-navigates
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isPaused) return;

      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _navigateToTest();
      }
    });
  }

  // Navigate directly to calibration for the reading test
  void _navigateToTest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: 40.0,
          toleranceCm: 5.0,
          onCalibrationComplete: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ShortDistanceTestScreen(),
              ),
            );
          },
          onSkip: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ShortDistanceTestScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ttsService.dispose();
    super.dispose();
  }

  void _showExitConfirmation() {
    _ttsService.stop();
    setState(() => _isPaused = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text(
          'Your progress will be lost. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isPaused = false);
            },
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          title: const Text('Reading Test Instructions'),
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Both eyes open icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.visibility,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'KEEP BOTH EYES OPEN',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Reading Test - Near Vision',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Instructions
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionItem(
                        Icons.straighten,
                        'Testing Distance',
                        'Hold device 40cm from your eyes',
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionItem(
                        Icons.record_voice_over,
                        'Read Aloud',
                        'Read each sentence clearly and completely',
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionItem(
                        Icons.hearing,
                        'Voice Recognition',
                        'The app will listen and verify your reading',
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // UPDATED: Button with countdown
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _countdown == 0 ? _navigateToTest : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppColors.primary,
                    ),
                    child: _countdown > 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                  value: 1 - (_countdown / 3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Starting in $_countdown...',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : const Text(
                            'Start Reading Test',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
