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
        color: AppColors.white,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.35),
          side: BorderSide(color: themeColor, width: 2.5),
        ),
        shadows:
            shadows ??
            [
              BoxShadow(
                color: themeColor.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: Center(
        child: Text(
          '$seconds',
          style: TextStyle(
            color: themeColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'Inter', // Ensuring premium typography if available
          ),
        ),
      ),
    );
  }
}
