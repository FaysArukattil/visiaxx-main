import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Canvas widget for Amsler grid test
class AmslerGridCanvas extends StatelessWidget {
  final double size;

  const AmslerGridCanvas({super.key, this.size = 300});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _AmslerGridPainter());
  }
}

class _AmslerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.amslerGridLine
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw grid lines
    const gridSize = 20;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    // Vertical lines
    for (int i = 0; i <= gridSize; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (int i = 0; i <= gridSize; i++) {
      final y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw center dot
    final centerPaint = Paint()
      ..color = AppColors.amslerGridLine
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
