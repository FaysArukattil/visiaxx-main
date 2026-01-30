import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/theme_extension.dart';

class TestFeedbackOverlay extends StatelessWidget {
  final bool isCorrect;
  final String? label;
  final bool isBlurry;

  const TestFeedbackOverlay({
    super.key,
    required this.isCorrect,
    this.label,
    this.isBlurry = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    if (isBlurry) {
      color = AppColors.primary;
      icon = Icons.visibility_off_rounded;
      text = label ?? 'CANNOT SEE';
    } else if (isCorrect) {
      color = AppColors.success;
      icon = Icons.check_rounded;
      text = label ?? 'CORRECT';
    } else {
      color = AppColors.error;
      icon = Icons.close_rounded;
      text = label ?? 'INCORRECT';
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: context.surface, // Theme-aware background
          child: Stack(
            children: [
              // Subtle background pulse or tint
              Opacity(
                opacity: 0.1 * value,
                child: Container(color: color),
              ),
              Center(
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with subtle glow and premium border
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: context.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4 * value),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: color.withValues(alpha: 0.3 * value),
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Icon(icon, size: 80, color: color),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Premium Typography
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 6,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtle accent line
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.3 * value),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
