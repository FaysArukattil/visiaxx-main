import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../widgets/amsler_grid_drawing_animation.dart';

/// Initial instruction screen for Amsler Grid Test
class AmslerGridInstructionsScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const AmslerGridInstructionsScreen({super.key, required this.onContinue});

  @override
  State<AmslerGridInstructionsScreen> createState() =>
      _AmslerGridInstructionsScreenState();
}

class _AmslerGridInstructionsScreenState
    extends State<AmslerGridInstructionsScreen> {
  final TtsService _ttsService = TtsService();
  int _currentStep = 0;

  final List<_InstructionStep> _steps = [
    _InstructionStep(
      title: 'Amsler Grid Test',
      description:
          'This test checks for distortions in your central vision. '
          'Hold the device at a normal reading distance (about 30-40cm).',
      icon: Icons.grid_on,
    ),
    _InstructionStep(
      title: 'Cover One Eye',
      description:
          'Test one eye at a time. Start by covering your LEFT eye '
          'to test your RIGHT eye first.',
      icon: Icons.visibility_off,
    ),
    _InstructionStep(
      title: 'Focus on Center',
      description:
          'Focus purely on the black dot in the center. '
          'While looking at the dot, check if any lines appear wavy, blurry, or missing.',
      icon: Icons.center_focus_strong,
    ),
    _InstructionStep(
      title: 'Trace Distortions',
      description:
          'If you see any wavy or missing areas, use your finger to '
          'trace directly over them on the screen.',
      icon: Icons.gesture,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _ttsService.initialize();
    // Add a small delay to ensure TTS engine is ready
    await Future.delayed(const Duration(milliseconds: 500));
    _speakCurrentStep();
  }

  void _speakCurrentStep() {
    if (_currentStep < _steps.length) {
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
        title: const Text('Amsler Grid Instructions'),
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
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Step ${_currentStep + 1} of ${_steps.length}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  Text(
                    _steps[_currentStep].title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _steps[_currentStep].description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Animation or Static Preview
                  _currentStep == 3
                      ? const AmslerGridDrawingAnimation()
                      : _buildGridPreview(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildGridPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Image.network(
        'https://upload.wikimedia.org/wikipedia/commons/e/e0/Amsler_grid.png',
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 180,
          color: Colors.grey.shade200,
          child: const Icon(Icons.grid_on, size: 50, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
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
                  _currentStep == _steps.length - 1 ? 'Start Test' : 'Next',
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
    );
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
