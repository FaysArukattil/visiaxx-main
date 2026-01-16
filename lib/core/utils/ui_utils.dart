import 'package:flutter/material.dart';
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
          backgroundColor: AppColors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                const LinearProgressIndicator(
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
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
}

