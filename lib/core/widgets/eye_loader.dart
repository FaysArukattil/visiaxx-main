import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A professional, eye-themed custom loading animation.
/// Features a pulsing iris, a scanning arc, and smooth transitions.
class EyeLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double? value; // Added for determinate progress

  const EyeLoader({super.key, this.size = 40.0, this.color, this.value});

  @override
  State<EyeLoader> createState() => _EyeLoaderState();
}

class _EyeLoaderState extends State<EyeLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.value == null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(EyeLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) {
      _controller.stop();
    } else if (oldWidget.value != null) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Theme.of(context).primaryColor;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _EyePainter(
              animationValue: widget.value ?? _controller.value,
              color: themeColor,
              isDeterminate: widget.value != null,
            ),
          );
        },
      ),
    );
  }
}

class _EyePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isDeterminate;

  _EyePainter({
    required this.animationValue,
    required this.color,
    required this.isDeterminate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw Eye Eyelids (Stylized Outline)
    final eyePath = Path();
    final eyeWidth = size.width * 0.9;
    final eyeHeight = size.height * 0.6;

    eyePath.moveTo(center.dx - eyeWidth / 2, center.dy);
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy - eyeHeight,
      center.dx + eyeWidth / 2,
      center.dy,
    );
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy + eyeHeight,
      center.dx - eyeWidth / 2,
      center.dy,
    );
    eyePath.close();

    final outlinePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(eyePath, outlinePaint);

    // 2. Draw Iris (Pulsing)
    final irisPulse = 0.85 + (math.sin(animationValue * 2 * math.pi) * 0.08);
    final irisRadius = radius * 0.45 * irisPulse;

    final irisPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, irisRadius, irisPaint);

    // 3. Draw Pupil
    final pupilRadius = irisRadius * 0.4;
    final pupilPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, pupilRadius, pupilPaint);

    // 4. Draw Shine/Reflection
    final reflectionPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - irisRadius * 0.3, center.dy - irisRadius * 0.3),
      irisRadius * 0.15,
      reflectionPaint,
    );

    // 5. Draw Scanning/Progress Arc (Rotating)
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final startAngle = animationValue * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      startAngle,
      math.pi * 0.6,
      false,
      arcPaint,
    );

    // Draw trailing subtle arc
    final trailPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      startAngle + (math.pi * 0.8),
      math.pi * 0.3,
      false,
      trailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _EyePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
