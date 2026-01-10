import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/navigation_utils.dart';

/// Global service to handle app pause/resume across all test screens
/// Provides consistent pause dialog and behavior throughout the app
class TestPauseHandler {
  // Singleton instance
  static final TestPauseHandler _instance = TestPauseHandler._internal();
  factory TestPauseHandler() => _instance;
  TestPauseHandler._internal();

  // Callbacks
  VoidCallback? _onPause;
  VoidCallback? _onResume;
  bool Function()? _shouldIgnorePause;
  String Function()? _getTestName;

  // State
  bool _isPaused = false;
  BuildContext? _context;

  /// Initialize with callbacks for current test
  void initialize({
    required BuildContext context,
    required VoidCallback onPause,
    required VoidCallback onResume,
    bool Function()? shouldIgnorePause,
    String Function()? getTestName,
  }) {
    _context = context;
    _onPause = onPause;
    _onResume = onResume;
    _shouldIgnorePause = shouldIgnorePause;
    _getTestName = getTestName;
    _isPaused = false;
  }

  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Call this when app goes to background
  void handleAppPaused() {
    if (_shouldIgnorePause?.call() ?? false) {
      debugPrint('[TestPauseHandler] Ignoring pause (in initial phase)');
      return;
    }

    if (_isPaused) {
      debugPrint('[TestPauseHandler] Already paused, ignoring');
      return;
    }

    debugPrint('[TestPauseHandler] App paused - stopping test');
    _isPaused = true;
    _onPause?.call();
  }

  /// Call this when app comes back to foreground
  void handleAppResumed() {
    if (_context == null || !(_context as Element).mounted) {
      debugPrint('[TestPauseHandler] Context not available');
      return;
    }

    if (_shouldIgnorePause?.call() ?? false) {
      debugPrint('[TestPauseHandler] Ignoring resume (in initial phase)');
      return;
    }

    if (!_isPaused) {
      debugPrint('[TestPauseHandler] Not paused, ignoring resume');
      return;
    }

    // Show resume dialog after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_context != null && (_context as Element).mounted && _isPaused) {
        showPauseDialog();
      }
    });
  }

  /// Show the standardized pause dialog
  void showPauseDialog() {
    if (_context == null) return;

    final testName = _getTestName?.call() ?? 'Test';

    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.white,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with gradient background
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pause_circle_outline,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                '$testName Paused',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'The test was paused because the app was minimized.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Would you like to continue?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              Column(
                children: [
                  // Continue button (primary)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _isPaused = false;
                        _onResume?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue Test',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Exit button (secondary)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        _showExitConfirmation(context, testName);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Exit Test',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation(BuildContext dialogContext, String testName) {
    showDialog(
      context: dialogContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_rounded, color: AppColors.error, size: 56),
              const SizedBox(height: 20),
              Text(
                'Exit $testName?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your progress will be lost. Are you sure you want to exit?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (context.mounted) {
                          Navigator.pop(context); // Close confirmation
                          Navigator.pop(dialogContext); // Close pause dialog
                          await NavigationUtils.navigateHome(_context!);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Yes, Exit',
                        style: TextStyle(color: AppColors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dispose/cleanup
  void dispose() {
    _onPause = null;
    _onResume = null;
    _shouldIgnorePause = null;
    _getTestName = null;
    _context = null;
    _isPaused = false;
  }
}
