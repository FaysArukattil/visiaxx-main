import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A premium squircle-shaped countdown timer widget.
class SquircleTimer extends StatelessWidget {
  final int seconds;
  final double size;
  final double fontSize;
  final Color? color;
  final List<BoxShadow>? shadows;

  const SquircleTimer({
    super.key,
    required this.seconds,
    this.size = 80,
    this.fontSize = 32,
    this.color,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.primary;

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: themeColor,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.42),
        ),
        shadows:
            shadows ??
            [
              BoxShadow(
                color: themeColor.withOpacity(0.24),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: themeColor.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: Center(
        child: Text(
          '$seconds',
          style: TextStyle(
            color: AppColors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'Inter',
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}
