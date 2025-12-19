import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../widgets/color_vision_response_animation.dart';

/// Initial instruction screen for Color Vision Test
/// Explains how the Ishihara plate test works
class ColorVisionInstructionsScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const ColorVisionInstructionsScreen({super.key, required this.onContinue});

  @override
  State<ColorVisionInstructionsScreen> createState() =>
      _ColorVisionInstructionsScreenState();
}

class _ColorVisionInstructionsScreenState
    extends State<ColorVisionInstructionsScreen> {
  final TtsService _ttsService = TtsService();
  int _currentStep = 0;

  final List<_InstructionStep> _steps = [
    _InstructionStep(
      title: 'Color Vision Test',
      description:
          'This test checks your ability to see colors correctly. '
          'You will see circular plates with colored dots forming numbers.',
      icon: Icons.palette,
    ),
    _InstructionStep(
      title: 'How to Respond',
      description:
          'Look at each plate and identify the number. '
          'You will see 4 options: what a normal person sees, what a color deficient person sees, a random number, and "Nothing". '
          'Tap the option that matches what you see.',
      icon: Icons.touch_app,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _ttsService.initialize();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _speakCurrentStep();
      }
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  void _speakCurrentStep() {
    if (_currentStep < _steps.length) {
      _ttsService.stop();
      _ttsService.speak(
        '${_steps[_currentStep].title}. ${_steps[_currentStep].description}',
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _speakCurrentStep();
    } else {
      _ttsService.stop();
      widget.onContinue();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _speakCurrentStep();
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Color Vision Test Instructions'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: Icon(
              _ttsService.isSpeaking ? Icons.volume_up : Icons.volume_off,
            ),
            onPressed: () {
              if (_ttsService.isSpeaking) {
                _ttsService.stop();
              } else {
                _speakCurrentStep();
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Step indicator
                  Text(
                    'Step ${_currentStep + 1} of ${_steps.length}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _steps[_currentStep].icon,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    _steps[_currentStep].title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    _steps[_currentStep].description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  _currentStep == 0
                      ? _buildPlateExample()
                      : _buildResponseExample(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentStep == _steps.length - 1
                            ? 'Start Test'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlateExample() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Simulated plate
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            child: Center(
              child: Text(
                '12',
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Example: Ishihara Plate',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseExample() {
    return const ColorVisionResponseAnimation();
  }
}

class _InstructionStep {
  final String title;
  final String description;
  final IconData icon;

  _InstructionStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
