import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import 'distance_calibration_screen.dart';
import 'short_distance_test_screen.dart';

/// Instruction screen before short distance reading test
class ShortDistanceInstructionScreen extends StatefulWidget {
  const ShortDistanceInstructionScreen({super.key});

  @override
  State<ShortDistanceInstructionScreen> createState() =>
      _ShortDistanceInstructionScreenState();
}

class _ShortDistanceInstructionScreenState
    extends State<ShortDistanceInstructionScreen> {
  final TtsService _ttsService = TtsService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    setState(() => _isInitialized = true);

    // Speak instructions
    _ttsService.speak(
      'This is a reading test at 40 centimeters. '
      'You will see sentences of different sizes. '
      'Read each sentence aloud or type your response.',
    );
  }

  void _startCalibration() {
    Navigator.push(
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
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: const Text('Reading Test Instructions'),
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Title
              const Text(
                'Short Distance Reading Test',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Instructions card
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
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
                          'Distance',
                          'Position yourself 40cm (about 16 inches) from the screen',
                        ),
                        const SizedBox(height: 20),
                        _buildInstructionItem(
                          Icons.text_fields,
                          'Reading Task',
                          'You will see 7 sentences of different sizes, from large to small',
                        ),
                        const SizedBox(height: 20),
                        _buildInstructionItem(
                          Icons.mic,
                          'Voice Response',
                          'Read each sentence aloud clearly. The app will listen to your response',
                        ),
                        const SizedBox(height: 20),
                        _buildInstructionItem(
                          Icons.keyboard,
                          'Type Option',
                          'If voice recognition isn\'t working, you can type your response',
                        ),
                        const SizedBox(height: 20),
                        _buildInstructionItem(
                          Icons.timer,
                          'Time Limit',
                          'You have 35 seconds per sentence. Speak clearly and at a normal pace',
                        ),
                        const SizedBox(height: 20),
                        _buildInstructionItem(
                          Icons.visibility,
                          'Eye Position',
                          'Keep both eyes open during this test',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tips section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Speak naturally and clearly. Don\'t rush!',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInitialized ? _startCalibration : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isInitialized)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      if (_isInitialized)
                        const Icon(Icons.arrow_forward, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        _isInitialized
                            ? 'Start Calibration'
                            : 'Initializing...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
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
