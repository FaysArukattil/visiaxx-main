import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

class ColorVisionCoverEyeScreen extends StatefulWidget {
  final String eyeToCover; // 'left' or 'right'
  final VoidCallback onContinue;

  const ColorVisionCoverEyeScreen({
    super.key,
    required this.eyeToCover,
    required this.onContinue,
  });

  @override
  State<ColorVisionCoverEyeScreen> createState() =>
      _ColorVisionCoverEyeScreenState();
}

class _ColorVisionCoverEyeScreenState extends State<ColorVisionCoverEyeScreen> {
  int _countdown = 3;
  bool _isPaused = false;
  Timer? _countdownTimer;
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _isPaused) return;

    final eyeBeingTested = widget.eyeToCover == 'left' ? 'right' : 'left';
    await _ttsService.speak(
      'Cover your ${widget.eyeToCover} eye with your palm or a paper. '
      'Keep your $eyeBeingTested eye open. '
      'Stand at 40 centimeters distance from the screen. '
      'You will see colored plates with numbers. '
      'Tap the correct option that matches what you see on the screen.',
      speechRate: 0.5,
    );

    // ✅ FIX: Start countdown only after TTS completes
    if (mounted && !_isPaused) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isPaused) {
        timer.cancel();
        return;
      }

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
    widget.onContinue();
  }

  void _showExitConfirmation() {
    setState(() => _isPaused = true);
    _countdownTimer?.cancel();
    _ttsService.stop();

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
          _initializeTts();
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eyeBeingTested = widget.eyeToCover == 'left' ? 'right' : 'left';
    final eyeColor = eyeBeingTested == 'right'
        ? AppColors.rightEye
        : AppColors.leftEye;

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
          backgroundColor: eyeColor.withValues(alpha: 0.1),
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
                  // Eye icon with side covered
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: eyeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.visibility, size: 60, color: eyeColor),
                        // Cover appropriate side
                        Positioned(
                          left: widget.eyeToCover == 'left' ? 0 : null,
                          right: widget.eyeToCover == 'right' ? 0 : null,
                          child: Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.only(
                                topLeft: widget.eyeToCover == 'left'
                                    ? const Radius.circular(40)
                                    : Radius.zero,
                                bottomLeft: widget.eyeToCover == 'left'
                                    ? const Radius.circular(40)
                                    : Radius.zero,
                                topRight: widget.eyeToCover == 'right'
                                    ? const Radius.circular(40)
                                    : Radius.zero,
                                bottomRight: widget.eyeToCover == 'right'
                                    ? const Radius.circular(40)
                                    : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'COVER YOUR ${widget.eyeToCover.toUpperCase()} EYE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: eyeColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Focus with your ${eyeBeingTested.toUpperCase()} eye only',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
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
                          'Stand 40 centimeters from screen',
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionItem(
                          Icons.palette,
                          'Color Plates',
                          'Look at colored plates and identify the number',
                        ),
                        const SizedBox(height: 16),
                        _buildInstructionItem(
                          Icons.touch_app,
                          'Tap to Respond',
                          'Identify the number on the plate and tap the corresponding option button',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Countdown and auto-start
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _handleContinue, // ✅ Always enabled for instant skip
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: eyeColor,
                      ),
                      child: _countdown > 0
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
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
                                Flexible(
                                  child: Text(
                                    'Starting in $_countdown... (Tap to skip)',
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Start ${eyeBeingTested.toUpperCase()} Eye Test',
                              style: const TextStyle(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
