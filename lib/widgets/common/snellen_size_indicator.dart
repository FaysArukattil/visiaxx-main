import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Widget to display Snellen notation indicator for visual acuity tests
/// Shows small, unobtrusive text like "6/60", "6/36" etc.
class SnellenSizeIndicator extends StatelessWidget {
  final String snellenNotation;
  final bool showInCorner;

  const SnellenSizeIndicator({
    super.key,
    required this.snellenNotation,
    this.showInCorner = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        snellenNotation,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
