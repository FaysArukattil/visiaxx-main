import 'package:flutter/material.dart';
import 'package:visiaxx/features/results/widgets/how_to_respond_animation.dart';
import 'package:visiaxx/features/results/widgets/wear_specs_animation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/tts_service.dart';

/// Test instructions screen with TTS and relaxation image
class TestInstructionsScreen extends StatefulWidget {
  const TestInstructionsScreen({super.key});

  @override
  State<TestInstructionsScreen> createState() => _TestInstructionsScreenState();
}

class _TestInstructionsScreenState extends State<TestInstructionsScreen> {
  final TtsService _ttsService = TtsService();
  int _currentStep = 0;

  final List<_InstructionStep> _steps = [
    _InstructionStep(
      title: 'Prepare Your Space',
      description:
          'Find a well-lit room and sit comfortably. '
          'Make sure your screen brightness is at maximum.',
      icon: Icons.light_mode,
      type: _StepType.basic,
    ),
    _InstructionStep(
      title: 'Maintain Distance',
      description:
          'Position yourself 100cm (approximately 1 meter) away from the screen. '
          'The app will use your camera to monitor distance.',
      icon: Icons.straighten,
      type: _StepType.distance,
    ),
    _InstructionStep(
      title: 'How to Respond',
      description:
          'You will see the letter E pointing in different directions. '
          'Tap the arrow button in that direction or use voice commands.',
      icon: Icons.touch_app,
      type: _StepType.howToRespond,
    ),
    _InstructionStep(
      title: 'Wear Your Specs',
      description:
          'If you normally wear glasses or contact lenses, please wear them now. '
          'This ensures accurate testing.',
      icon: Icons.visibility,
      type: _StepType.wearSpecs,
    ),
    _InstructionStep(
      title: 'Relax Your Eyes',
      description:
          'Before each test, look at the relaxation image for 10 seconds. '
          'Focus on the distant horizon to rest your eyes.',
      icon: Icons.self_improvement,
      type: _StepType.relaxation,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _ttsService.initialize();
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
      Navigator.pushReplacementNamed(context, '/visual-acuity-test');
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
        content: const Text(
          'Your progress will be lost. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Test Instructions'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
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
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),

            // Main content (responsive layout)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  final isCompact = availableHeight < 600;

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: availableHeight),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isCompact ? 8 : 16,
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
                                fontSize: isCompact ? 12 : 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isCompact ? 12 : 16),

                            // Step icon (hidden for relaxation to give more space)
                            if (_steps[_currentStep].type !=
                                _StepType.relaxation)
                              Container(
                                width: isCompact ? 60 : 70,
                                height: isCompact ? 60 : 70,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _steps[_currentStep].icon,
                                  size: isCompact ? 30 : 35,
                                  color: AppColors.primary,
                                ),
                              ),
                            if (_steps[_currentStep].type !=
                                _StepType.relaxation)
                              SizedBox(height: isCompact ? 12 : 16),

                            // Step title
                            Text(
                              _steps[_currentStep].title,
                              style: TextStyle(
                                fontSize: isCompact ? 20 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isCompact ? 8 : 12),

                            // Step description
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                _steps[_currentStep].description,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: isCompact ? 13 : 15,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: isCompact ? 16 : 24),

                            // Step-specific content
                            _buildStepContent(isCompact),

                            SizedBox(height: isCompact ? 12 : 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Fixed navigation buttons at bottom
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Back'),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      flex: _currentStep == 0 ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _currentStep == _steps.length - 1
                                ? 'Start Test'
                                : 'Next',
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

  Widget _buildStepContent(bool isCompact) {
    final step = _steps[_currentStep];

    switch (step.type) {
      case _StepType.distance:
        return _buildDistanceDiagram(isCompact);

      case _StepType.howToRespond:
        return HowToRespondAnimation(isCompact: isCompact);

      case _StepType.wearSpecs:
        return WearSpecsAnimation(isCompact: isCompact);

      case _StepType.relaxation:
        return _buildRelaxationPreview(isCompact);

      case _StepType.basic:
        return const SizedBox(height: 100);
    }
  }

  Widget _buildDistanceDiagram(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: isCompact ? 32 : 40),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: CustomPaint(painter: _DashedLinePainter()),
                ),
              ),
              Icon(Icons.phone_android, size: isCompact ? 32 : 40),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1 metre / 3 feet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 16 : 18,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationPreview(bool isCompact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate image height based on available space
        // Leave room for title, description, and buttons
        final maxImageHeight = isCompact ? 250.0 : 350.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large relaxation image
            Container(
              constraints: BoxConstraints(
                maxHeight: maxImageHeight,
                maxWidth: constraints.maxWidth,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  AppAssets.relaxationImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surface,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.landscape,
                            size: isCompact ? 60 : 80,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Relaxation Image',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instruction card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye,
                    color: AppColors.success,
                    size: isCompact ? 20 : 24,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Focus on the distant horizon for 10 seconds',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: isCompact ? 13 : 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _StepType { basic, distance, howToRespond, wearSpecs, relaxation }

class _InstructionStep {
  final String title;
  final String description;
  final IconData icon;
  final _StepType type;

  _InstructionStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
  });
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.info
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
