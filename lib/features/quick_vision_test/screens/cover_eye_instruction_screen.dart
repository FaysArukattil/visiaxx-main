import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable screen for eye-covering instructions
/// Used before testing each eye in visual acuity, color vision, etc.
class CoverEyeInstructionScreen extends StatelessWidget {
  final String eyeToCover; // 'left' or 'right'
  final String eyeBeingTested; // 'right' or 'left'
  final String testName; // 'Visual Acuity', 'Color Vision', etc.
  final VoidCallback onContinue;

  const CoverEyeInstructionScreen({
    super.key,
    required this.eyeToCover,
    required this.eyeBeingTested,
    required this.testName,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large visual showing which eye to cover
              _buildEyeCoverVisual(),

              const SizedBox(height: 40),

              // Instruction text
              Text(
                'Cover Your ${_capitalize(eyeToCover)} Eye',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'We will now test your ${_capitalize(eyeBeingTested)} eye',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Text(
                'Use your hand to completely cover your $eyeToCover eye. '
                'Keep both eyes open behind your hand.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Start $testName Test',
                    style: const TextStyle(
                      fontSize: 18,
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
    );
  }

  Widget _buildEyeCoverVisual() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Eye icon representation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left eye
                _buildEyeIcon(isCovered: eyeToCover == 'left', label: 'LEFT'),
                const SizedBox(width: 60),
                // Right eye
                _buildEyeIcon(isCovered: eyeToCover == 'right', label: 'RIGHT'),
              ],
            ),
            const SizedBox(height: 24),
            // Instruction text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Cover ${_capitalize(eyeToCover)} Eye',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeIcon({required bool isCovered, required String label}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Eye
            Icon(
              isCovered ? Icons.visibility_off : Icons.visibility,
              size: 60,
              color: isCovered ? AppColors.error : AppColors.success,
            ),
            // Hand overlay for covered eye
            if (isCovered)
              Positioned(
                child: Icon(
                  Icons.back_hand,
                  size: 40,
                  color: AppColors.error.withOpacity(0.8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isCovered ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
