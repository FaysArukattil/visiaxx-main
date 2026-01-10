import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';

/// Pelli-Robson Contrast Sensitivity Test Instructions Screen
class PelliRobsonInstructionsScreen extends StatefulWidget {
  final String testMode; // 'short' (40cm) or 'long' (1m)
  final VoidCallback onContinue;

  const PelliRobsonInstructionsScreen({
    super.key,
    required this.testMode,
    required this.onContinue,
  });

  @override
  State<PelliRobsonInstructionsScreen> createState() =>
      _PelliRobsonInstructionsScreenState();
}

class _PelliRobsonInstructionsScreenState
    extends State<PelliRobsonInstructionsScreen> {
  final TtsService _ttsService = TtsService();
  int _currentStep = 0;

  late final List<_InstructionStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = [
      // ✅ NEW: Brightness instruction as first step
      _InstructionStep(
        title: 'Adjust Screen Brightness',
        description:
            'Please increase your screen brightness to maximum for accurate results. '
            'This test measures subtle differences in contrast.',
        icon: Icons.brightness_high,
      ),
      _InstructionStep(
        title: 'Contrast Sensitivity Test',
        description:
            'This test measures how well you can distinguish objects from their background. '
            'It is crucial for driving, reading, and seeing in low light.',
        icon: Icons.palette_outlined,
      ),
      _InstructionStep(
        title: 'Reading Letters',
        description:
            'You will see groups of 3 letters (triplets) inside a blue box. Read the triplets inside the blue box aloud from left to right.',
        icon: Icons.record_voice_over_outlined,
      ),
      _InstructionStep(
        title: 'Decreasing Contrast',
        description:
            'The letters will become fainter and harder to see. '
            'Read as many as you can. If you can\'t see any, say "nothing" or "skip".',
        icon: Icons.gradient_outlined,
      ),
    ];
    _initialize();
  }

  Future<void> _initialize() async {
    await _ttsService.initialize();
    // ✅ FIX: Add delay to ensure TTS engine is fully ready
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _speakCurrentStep();
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

  void _showExitConfirmation() {
    _ttsService.stop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text('Your progress will be lost. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await NavigationUtils.navigateHome(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = widget.testMode == 'short'
        ? 'Short Distance (40cm)'
        : 'Long Distance (1m)';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Contrast Test - $distanceLabel'),
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _ttsService.isSpeaking ? Icons.volume_up : Icons.volume_off,
                color: AppColors.primary,
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
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Step indicator
                    Text(
                      'Step ${_currentStep + 1} of ${_steps.length}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _steps[_currentStep].icon,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      _steps[_currentStep].title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      _steps[_currentStep].description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Visual aid/Example for current step
                    _buildStepVisualAid(),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentStep == _steps.length - 1
                              ? 'Start Test'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildStepVisualAid() {
    switch (_currentStep) {
      case 0: // Intro
        return _buildExampleTriplet('VRS', 1.0);
      case 1: // Distance
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 40, color: AppColors.info),
              const SizedBox(width: 20),
              Container(height: 2, width: 60, color: AppColors.info),
              const SizedBox(width: 20),
              Icon(Icons.phone_android, size: 40, color: AppColors.info),
            ],
          ),
        );
      case 2: // Reading
        return _buildExampleTriplet('KDR', 0.6);
      case 3: // Decreasing contrast
        return Column(
          children: [
            _buildExampleTriplet('NHC', 0.4),
            const SizedBox(height: 12),
            _buildExampleTriplet('SOK', 0.15),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildExampleTriplet(String letters, double opacity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: letters
            .split('')
            .map(
              (l) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    l,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Sloan',
                    ),
                  ),
                ),
              ),
            )
            .toList(),
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
