import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../constants/app_colors.dart';
import '../services/data_cleanup_service.dart';

class TestExitConfirmationDialog extends StatefulWidget {
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
  State<TestExitConfirmationDialog> createState() =>
      _TestExitConfirmationDialogState();
}

class _TestExitConfirmationDialogState
    extends State<TestExitConfirmationDialog> {
  bool _showConfirmation = false;
  String? _confirmAction; // 'restart' or 'exit'

  void _showConfirm(String action) {
    setState(() {
      _showConfirmation = true;
      _confirmAction = action;
    });
  }

  void _hideConfirm() {
    setState(() {
      _showConfirmation = false;
      _confirmAction = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full Screen Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: _showConfirmation
                ? _buildConfirmationView()
                : _buildMainView(),
          ),
        ),
      ],
    );
  }

  Widget _buildMainView() {
    return Container(
      key: const ValueKey('main'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(28),
      decoration: ShapeDecoration(
        color: AppColors.white.withOpacity(0.98),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium Icon Header
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.pause_circle_filled_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Test Paused',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary.withOpacity(0.6),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            // Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onContinue();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text('Continue Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showConfirm('restart'),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Restart Test'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.warning.withOpacity(0.3),
                      width: 1.5,
                    ),
                    foregroundColor: AppColors.warning,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showConfirm('exit'),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Exit & Lose Progress'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationView() {
    final isExit = _confirmAction == 'exit';
    final actionTitle = isExit ? 'Exit Test?' : 'Restart Test?';
    final actionSub = isExit
        ? 'Are you sure you want to end this session? All unsaved progress will be lost.'
        : 'Are you sure you want to start over? Current progress will be reset.';

    return Container(
      key: const ValueKey('confirm'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(28),
      decoration: ShapeDecoration(
        color: AppColors.white.withOpacity(0.98),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isExit ? AppColors.error : AppColors.warning)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExit ? Icons.dangerous_rounded : Icons.help_outline_rounded,
                color: isExit ? AppColors.error : AppColors.warning,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              actionTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              actionSub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary.withOpacity(0.6),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _hideConfirm,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text(
                      'No, Go Back',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (isExit) {
                        await DataCleanupService.cleanupTestData(context);
                        if (mounted) {
                          Navigator.pop(context);
                          widget.onExit();
                        }
                      } else {
                        Navigator.pop(context);
                        widget.onRestart();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExit
                          ? AppColors.error
                          : AppColors.warning,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isExit ? 'Yes, Exit' : 'Yes, Restart',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
