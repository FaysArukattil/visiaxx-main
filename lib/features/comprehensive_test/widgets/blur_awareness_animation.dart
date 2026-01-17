import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Animation widget showing 3 E letters with increasing blur levels
/// to explain the "Blurry" option to users
class BlurAwarenessAnimation extends StatelessWidget {
  final bool isCompact;

  const BlurAwarenessAnimation({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    final double eSize = isCompact ? 48.0 : 64.0;

    return Container(
      padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildBlurredE(
                  blur: 0.0,
                  label: 'Clear',
                  fontSize: isCompact ? 36.0 : eSize,
                  labelColor: AppColors.success,
                ),
              ),
              Expanded(
                child: _buildBlurredE(
                  blur: 2.0,
                  label: 'Blur',
                  fontSize: isCompact ? 36.0 : eSize,
                  labelColor: AppColors.warning,
                ),
              ),
              Expanded(
                child: _buildBlurredE(
                  blur: 5.0,
                  label: 'Blurry',
                  fontSize: isCompact ? 36.0 : eSize,
                  labelColor: AppColors.error,
                  isTargetState: true,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 16.0 : 24.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.error,
                  size: isCompact ? 18 : 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'If you can barely make out the E, select "Blurry" or say "Can\'t See"',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: isCompact ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredE({
    required double blur,
    required String label,
    required double fontSize,
    required Color labelColor,
    bool isTargetState = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: fontSize + 24,
          height: fontSize + 24,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isTargetState
                  ? AppColors.error.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
              width: isTargetState ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isTargetState ? AppColors.error : AppColors.black)
                    .withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Text(
                'E',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: labelColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
