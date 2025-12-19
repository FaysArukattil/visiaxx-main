import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';

class CoverLeftEyeInstructionScreen extends StatefulWidget {
  const CoverLeftEyeInstructionScreen({super.key});

  @override
  State<CoverLeftEyeInstructionScreen> createState() =>
      _CoverLeftEyeInstructionScreenState();
}

class _CoverLeftEyeInstructionScreenState
    extends State<CoverLeftEyeInstructionScreen> {
  int _countdown = 3;
  final TtsService _ttsService = TtsService();
  Timer? _countdownTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _startCountdown();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    await Future.delayed(const Duration(milliseconds: 500));
    await _ttsService.speak(
      'Cover your left eye with your palm or a paper. '
      'Keep your right eye open. '
      'Stand at one meter distance from the screen. '
      'You will see the letter E pointing in different directions. '
      'Say upward, down, left, or right to indicate the direction.',
      speechRate: 0.5,
    );
  }

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

  void _navigateToTest() {
    Navigator.pushReplacementNamed(context, '/visual-acuity-test');
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
          title: const Text('Test Instructions'),
          backgroundColor: AppColors.rightEye.withValues(alpha: 0.1),
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
                // Eye icon with left side covered
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.rightEye.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.visibility,
                        size: 60,
                        color: AppColors.rightEye,
                      ),
                      Positioned(
                        left: 0,
                        child: Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(40),
                              bottomLeft: Radius.circular(40),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'COVER YOUR LEFT EYE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.rightEye,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                Text(
                  'Focus with your RIGHT eye only',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

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
                        'Stand 1 meter (100cm) from screen',
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionItem(
                        Icons.mic,
                        'Voice Commands',
                        'Say the direction the E is pointing:\nUPPER or UPWARD, DOWN or DOWNWARD, LEFT, RIGHT',
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Countdown and auto-start
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _countdown == 0 ? _navigateToTest : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppColors.rightEye,
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
                            'Start Right Eye Test',
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
