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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return Container(
          padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBlurredCharacter(
                              blur: 0.0,
                              label: 'Clear',
                              fontSize: isCompact ? 36.0 : eSize,
                              labelColor: AppColors.success,
                              character: 'E',
                            ),
                            const SizedBox(width: 12),
                            _buildBlurredCharacter(
                              blur: 2.0,
                              label: 'Blur',
                              fontSize: isCompact ? 36.0 : eSize,
                              labelColor: AppColors.warning,
                              character: 'E',
                            ),
                            const SizedBox(width: 12),
                            _buildBlurredCharacter(
                              blur:
                                  9.0, // Fully blurry (center line not visible)
                              label: 'Blurry',
                              fontSize: isCompact ? 36.0 : eSize,
                              labelColor: AppColors.error,
                              isTargetState: true,
                              character: 'E',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBlurredCharacter(
                              blur: 0.0,
                              label: 'Clear',
                              fontSize: isCompact ? 36.0 : eSize,
                              labelColor: AppColors.success,
                              character: 'C',
                            ),
                            const SizedBox(width: 12),
                            _buildBlurredCharacter(
                              blur: 2.0,
                              label: 'Blur',
                              fontSize: isCompact ? 36.0 : eSize,
                              labelColor: AppColors.warning,
                              character: 'C',
                            ),
                            const SizedBox(width: 12),
                            _buildBlurredCharacter(
                              blur: 9.0, // Fully blurry (looks like O)
                              label: 'Blurry',
                              fontSize: isCompact ? 36.0 : eSize,
                              labelColor: AppColors.error,
                              isTargetState: true,
                              character: 'C',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 280, // Constrain width for FittedBox scaling
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isLandscape && isCompact ? 6 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.error,
                          size: isCompact ? 16 : 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'If you can barely make out the E, select "Blurry" or say "Can\'t See"',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: isCompact ? 11 : 14,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlurredCharacter({
    required double blur,
    required String label,
    required double fontSize,
    required Color labelColor,
    bool isTargetState = false,
    String character = 'E',
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
                character,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                  fontFamily: 'Roboto', // For consistent C shape
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
