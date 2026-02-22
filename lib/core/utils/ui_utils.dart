import 'package:flutter/material.dart';
import '../extensions/theme_extension.dart';
import '../constants/app_colors.dart';

class UIUtils {
  UIUtils._();

  /// Shows an aesthetic progress dialog with a linear indicator
  static Future<void> showProgressDialog({
    required BuildContext context,
    required String message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  backgroundColor: context.dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(context.primary),
                  minHeight: 6,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait...',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Closes a dialog if it is currently showing
  static void hideProgressDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Shows a premium logout confirmation dialog
  static Future<bool?> showLogoutConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.dividerColor.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to sign out from your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w900),
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
}
