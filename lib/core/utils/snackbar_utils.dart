import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Centralized utility for showing professional, consistent snackbars throughout the app
class SnackbarUtils {
  /// Show a success snackbar with green color and checkmark icon
  static void showSuccess(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.check_circle,
      backgroundColor: AppColors.success,
    );
  }

  /// Show an error snackbar with red color and error icon
  static void showError(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.error,
      backgroundColor: AppColors.error,
    );
  }

  /// Show a warning snackbar with orange color and warning icon
  static void showWarning(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.warning_amber,
      backgroundColor: AppColors.warning,
    );
  }

  /// Show an info snackbar with blue color and info icon
  static void showInfo(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.info,
      backgroundColor: AppColors.info,
    );
  }

  /// Private method to show a floating snackbar with professional styling
  static void _showSnackbar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        elevation: 6,
      ),
    );
  }
}
