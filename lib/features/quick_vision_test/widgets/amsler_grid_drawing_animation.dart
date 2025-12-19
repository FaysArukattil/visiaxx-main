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

          // Indicator of what's happening
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, child) {
                  String label = "";
                  if (_progress.value < 0.45) {
                    label = "Draw over wavy lines";
                  } else if (_progress.value < 0.9) {
                    label = "Mark missing areas";
                  } else {
                    label = "Try again";
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.primary,
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
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final handPaint = Paint()..color = AppColors.secondary;

    // Phase 1: Tracing wavy line (0.0 to 0.4)
    if (progress < 0.45) {
      final subProgress = math.min(1.0, progress / 0.4);
      final path = Path();
      const startX = 20.0;
      final endX = 20.0 + (60.0 * subProgress);

      path.moveTo(startX, 40);
      for (double x = startX; x <= endX; x++) {
        final y = 40 + 5 * math.sin(x / 5);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, drawingPaint);

      // Draw hand
      final lastX = endX;
      final lastY = 40 + 5 * math.sin(lastX / 5);
      _drawHand(canvas, Offset(lastX, lastY), handPaint);
    }
    // Phase 2: Marking missing area (0.5 to 0.9)
    else if (progress < 0.95) {
      final subProgress = math.min(1.0, (progress - 0.5) / 0.4);

      // Missing area simulation (blurry/grey circle)
      final missingPaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(150, 150), 20, missingPaint);

      // Drawing over it
      final center = const Offset(150, 150);
      final radius = 22 * subProgress;

      if (subProgress > 0) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = Colors.blue.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(center, radius, drawingPaint..color = Colors.blue);
      }

      // Draw hand moving in a circle or just to center
      _drawHand(canvas, center, handPaint);
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
