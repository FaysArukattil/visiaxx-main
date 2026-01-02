import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

class AmslerGridDrawingAnimation extends StatefulWidget {
  const AmslerGridDrawingAnimation({super.key});

  @override
  State<AmslerGridDrawingAnimation> createState() =>
      _AmslerGridDrawingAnimationState();
}

class _AmslerGridDrawingAnimationState extends State<AmslerGridDrawingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _progress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Amsler Grid background (Simulated)
          Center(
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _MockAmslerGridPainter(),
            ),
          ),

          // Animation layer
          Center(
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(200, 200),
                  painter: _AnimationPainter(progress: _progress.value),
                );
              },
            ),
          ),

          // Indicator of what's happening - NEW: Show mode selection
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, child) {
                  String label = "";
                  Color color = AppColors.primary;
                  
                  if (_progress.value < 0.15) {
                    label = "Select 'Wavy'";
                    color = Colors.red;
                  } else if (_progress.value < 0.35) {
                    label = "Draw wavy lines";
                    color = Colors.red;
                  } else if (_progress.value < 0.45) {
                    label = "Select 'Missing'";
                    color = Colors.blue;
                  } else if (_progress.value < 0.65) {
                    label = "Mark missing area";
                    color = Colors.blue;
                  } else if (_progress.value < 0.75) {
                    label = "Select 'Blurry'";
                    color = Colors.orange;
                  } else if (_progress.value < 0.95) {
                    label = "Mark blurry area";
                    color = Colors.orange;
                  } else {
                    label = "Try again";
                    color = AppColors.primary;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockAmslerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final step = size.width / 10;

    // Draw grid
    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw center dot
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      3,
      Paint()..color = Colors.black,
    );

    // Draw a wavy area (simulated distortion)
    final wavyPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    const startX = 20.0;
    const endX = 80.0;
    path.moveTo(startX, 40);
    for (double x = startX; x <= endX; x++) {
      final y = 40 + 5 * math.sin(x / 5);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, wavyPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimationPainter extends CustomPainter {
  final double progress;
  _AnimationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final drawingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final handPaint = Paint()..color = AppColors.secondary;

    // Phase 1: Select/Draw Wavy (0.0 to 0.35)
    if (progress < 0.35) {
      if (progress < 0.15) {
        _drawModeSelector(canvas, size, 'wavy');
        _drawHand(canvas, const Offset(40, 180), handPaint);
      } else {
        final subProgress = (progress - 0.15) / 0.2;
        drawingPaint.color = Colors.red;
        final path = Path();
        const startX = 20.0;
        final endX = 20.0 + (60.0 * subProgress);
        path.moveTo(startX, 40);
        for (double x = startX; x <= endX; x++) {
          final y = 40 + 5 * math.sin(x / 5);
          path.lineTo(x, y);
        }
        canvas.drawPath(path, drawingPaint);
        _drawHand(canvas, Offset(endX, 40 + 5 * math.sin(endX / 5)), handPaint);
      }
    }
    // Phase 2: Select/Draw Missing (0.35 to 0.65)
    else if (progress < 0.65) {
      if (progress < 0.45) {
        _drawModeSelector(canvas, size, 'missing');
        _drawHand(canvas, const Offset(100, 180), handPaint);
      } else {
        final subProgress = (progress - 0.45) / 0.2;
        final center = const Offset(150, 150);
        
        final missingPaint = Paint()
          ..color = Colors.grey.withAlpha(128)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 20, missingPaint);

        if (subProgress > 0) {
          canvas.drawCircle(center, 22 * subProgress, Paint()..color = Colors.blue.withAlpha(76));
          canvas.drawCircle(center, 22 * subProgress, drawingPaint..color = Colors.blue);
        }
        _drawHand(canvas, center, handPaint);
      }
    }
    // Phase 3: Select/Draw Blurry (0.65 to 0.95)
    else if (progress < 0.95) {
      if (progress < 0.75) {
        _drawModeSelector(canvas, size, 'blurry');
        _drawHand(canvas, const Offset(160, 180), handPaint);
      } else {
        final subProgress = (progress - 0.75) / 0.2;
        final center = const Offset(60, 140);
        
        final blurryPaint = Paint()
          ..color = Colors.orange.withAlpha(76)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 18, blurryPaint);

        if (subProgress > 0) {
          canvas.drawCircle(center, 20 * subProgress, Paint()..color = Colors.orange.withAlpha(102));
          canvas.drawCircle(center, 20 * subProgress, drawingPaint..color = Colors.orange);
        }
        _drawHand(canvas, center, handPaint);
      }
    }
  }

  void _drawModeSelector(Canvas canvas, Size size, String selectedMode) {
    const buttonY = 180.0;
    final modes = [
      {'name': 'wavy', 'x': 40.0, 'color': Colors.red},
      {'name': 'missing', 'x': 100.0, 'color': Colors.blue},
      {'name': 'blurry', 'x': 160.0, 'color': Colors.orange},
    ];

    for (var mode in modes) {
      final isSelected = mode['name'] == selectedMode;
      final color = mode['color'] as Color;
      final x = mode['x'] as double;

      final buttonPaint = Paint()
        ..color = isSelected ? color.withAlpha(76) : Colors.grey.withAlpha(51)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = isSelected ? color : Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.0 : 1.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, buttonY), width: 40, height: 24),
          const Radius.circular(6),
        ),
        buttonPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, buttonY), width: 40, height: 24),
          const Radius.circular(6),
        ),
        borderPaint,
      );
    }
  }

  void _drawHand(Canvas canvas, Offset position, Paint paint) {
    canvas.save();
    canvas.translate(position.dx, position.dy);

    // Simple hand/finger icon
    final iconPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    // Draw a circle for finger tip
    canvas.drawCircle(Offset.zero, 8, iconPaint);
    // Draw a "trail" or "arm"
    canvas.drawRect(const Rect.fromLTWH(-4, 0, 8, 20), iconPaint);

    // Add white dot for touch feedback
    canvas.drawCircle(Offset.zero, 3, Paint()..color = Colors.white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnimationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
