import 'package:flutter/material.dart';
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
    ),
    _InstructionStep(
      title: 'Maintain Distance',
      description:
          'Position yourself 40cm (approximately 16 inches) away from the screen. '
          'The app will use your camera to monitor distance.',
      icon: Icons.straighten,
    ),
    _InstructionStep(
      title: 'Cover One Eye',
      description:
          'You will test each eye separately. '
          'Cover one eye gently without pressing on it.',
      icon: Icons.visibility_off,
    ),
    _InstructionStep(
      title: 'Relax Your Eyes',
      description:
          'Before each test item, look at the relaxation image for 10 seconds. '
          'This helps reduce eye strain for accurate results.',
      icon: Icons.self_improvement,
    ),
    _InstructionStep(
      title: 'How to Respond',
      description:
          'Use the arrow buttons or voice commands (Upward, Bottom, Left, Right) '
          'to indicate the direction the E is pointing.',
      icon: Icons.touch_app,
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
      Navigator.pushNamed(context, '/visual-acuity-test');
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
      appBar: AppBar(
        title: const Text('Test Instructions'),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step indicator
                  Text(
                    'Step ${_currentStep + 1} of ${_steps.length}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Step icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _steps[_currentStep].icon,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Step title
                  Text(
                    _steps[_currentStep].title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Step description
                  Text(
                    _steps[_currentStep].description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Relaxation image preview (on step 4)
                  if (_currentStep == 3) ...[
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        AppAssets.relaxationImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.landscape,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: 8),
                                Text('Relaxation Image'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Focus on the horizon in the distance',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  // Distance diagram (on step 2)
                  if (_currentStep == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person, size: 40),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: CustomPaint(
                                    painter: _DashedLinePainter(),
                                  ),
                                ),
                              ),
                              const Icon(Icons.phone_android, size: 40),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1 metre / 3 feet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(24),
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
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
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
                      padding: const EdgeInsets.all(16),
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
        ],
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
