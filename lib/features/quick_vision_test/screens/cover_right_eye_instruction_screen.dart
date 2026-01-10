import 'package:flutter/material.dart';
import 'package:visiaxx/features/quick_vision_test/screens/visual_acuity_test_screen.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

class CoverRightEyeInstructionScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String ttsMessage;
  final double targetDistance;
  final String startButtonText;
  final String instructionTitle;
  final String instructionDescription;
  final IconData instructionIcon;
  final VoidCallback? onContinue;

  const CoverRightEyeInstructionScreen({
    super.key,
    this.title = 'Test Instructions',
    this.subtitle = 'Focus with your LEFT eye only',
    this.ttsMessage =
        'Cover your right eye with your palm or a paper. Keep your left eye open. Stand at one meter distance from the screen. You will see the letter E pointing in different directions. Say upward, down, left, or right to indicate the direction. If you cannot see clearly, say blurry or nothing.',
    this.targetDistance = 100.0,
    this.startButtonText = 'Start Left Eye Test',
    this.instructionTitle = 'Voice Commands',
    this.instructionDescription =
        'Say the direction the E is pointing:\\nUPPER or UPWARD, DOWN or DOWNWARD, LEFT, RIGHT\\n\\nOr say BLURRY / NOTHING if you can\'t see clearly',
    this.instructionIcon = Icons.mic,
    this.onContinue,
  });

  @override
  State<CoverRightEyeInstructionScreen> createState() =>
      _CoverRightEyeInstructionScreenState();
}

class _CoverRightEyeInstructionScreenState
    extends State<CoverRightEyeInstructionScreen> {
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
    await _ttsService.speak(widget.ttsMessage, speechRate: 0.5);
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
        _handleContinue();
      }
    });
  }

  void _handleContinue() {
    _countdownTimer?.cancel();
    _ttsService.stop();
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      _navigateToTest();
    }
  }

  // NEW: Navigation method
  void _navigateToTest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const VisualAcuityTestScreen(startWithLeftEye: true),
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
    _countdownTimer?.cancel();
    setState(() => _isPaused = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TestExitConfirmationDialog(
        onContinue: () {
          setState(() => _isPaused = false);
          _startCountdown();
        },
        onRestart: () {
          setState(() {
            _isPaused = false;
            _countdown = 3;
          });
          _startCountdown();
          _ttsService.speak(widget.ttsMessage, speechRate: 0.5);
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
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
          title: Text(widget.title),
          backgroundColor: AppColors.leftEye.withValues(alpha: 0.1),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
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
                      color: AppColors.leftEye.withValues(alpha: 0.1),
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
                              color: Colors.black.withValues(alpha: 0.7),
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
                    widget.subtitle,
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
                          'Stand ${widget.targetDistance >= 100 ? 1 : 0.4} meter (${widget.targetDistance.toInt()}cm) from screen',
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionItem(
                          widget.instructionIcon,
                          widget.instructionTitle,
                          widget.instructionDescription,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Button always clickable - tap to skip countdown
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: AppColors.leftEye,
                      ),
                      child: _countdown > 0
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                EyeLoader(
                                  size: 20,
                                  color: Colors.white,
                                  value: 1 - (_countdown / 3),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Starting in $_countdown... (Tap to skip)',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            )
                          : Text(
                              widget.startButtonText,
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
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
