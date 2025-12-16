import 'package:flutter/material.dart';
import 'package:visiaxx/features/quick_vision_test/screens/visual_acuity_test_screen.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';

class CoverRightEyeInstructionScreen extends StatefulWidget {
  const CoverRightEyeInstructionScreen({super.key});

  @override
  State<CoverRightEyeInstructionScreen> createState() =>
      _CoverRightEyeInstructionScreenState();
}

class _CoverRightEyeInstructionScreenState
    extends State<CoverRightEyeInstructionScreen> {
  bool _buttonEnabled = false;
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();

    // Initialize TTS and speak instructions
    _initializeTts();

    // Enable button after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _buttonEnabled = true);
      }
    });
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();

    // Wait a moment for screen to settle
    await Future.delayed(const Duration(milliseconds: 500));

    // Speak the instructions
    await _ttsService.speak(
      'Cover your right eye with your palm or a paper. '
      'Keep your left eye open. '
      'Stand at one meter distance from the screen. '
      'You will see the letter E pointing in different directions. '
      'Say upward, down, left, or right to indicate the direction.',
      speechRate: 0.5,
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: const Text('Test Instructions'),
        backgroundColor: AppColors.leftEye.withOpacity(0.1),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Eye icon with right side covered
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.leftEye.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.visibility,
                      size: 60,
                      color: AppColors.leftEye,
                    ),
                    // Cover right side
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'COVER YOUR RIGHT EYE',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.leftEye,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Focus with your LEFT eye only',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
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
                      'Stand 1 meter (100cm) from screen',
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionItem(
                      Icons.mic,
                      'Voice Commands',
                      'Say the direction the E is pointing:\nUPPER or UPWARD, DOWN OR DOWNWARD, LEFT, RIGHT',
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Start button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _buttonEnabled
                      ? () {
                          // Navigate with startWithLeftEye flag
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const VisualAcuityTestScreen(
                                    startWithLeftEye: true,
                                  ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppColors.leftEye,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_buttonEnabled)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        _buttonEnabled
                            ? 'Start Left Eye Test'
                            : 'Please wait...',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
            color: AppColors.primary.withOpacity(0.1),
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
