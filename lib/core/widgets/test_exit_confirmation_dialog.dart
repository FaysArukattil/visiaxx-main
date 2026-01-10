import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/data_cleanup_service.dart';

class TestExitConfirmationDialog extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final String title;
  final String content;

  const TestExitConfirmationDialog({
    super.key,
    required this.onContinue,
    required this.onRestart,
    required this.onExit,
    this.title = 'Exit Test?',
    this.content = 'Your progress will be lost. What would you like to do?',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text(content, style: TextStyle(color: AppColors.textSecondary)),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onContinue();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continue Test'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                onRestart();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.warning),
                foregroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Restart Current Test'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                // Clear test-specific data before exiting
                await DataCleanupService.cleanupTestData(context);
                if (context.mounted) {
                  Navigator.pop(context);
                  onExit();
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Exit and Lose Progress'),
            ),
          ],
        ),
      ],
    );
  }
}
