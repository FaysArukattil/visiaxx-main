import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

class EyeBlinkAnimation extends StatelessWidget {
  final double size;
  final double blinkProbability; // 1.0 = fully open, 0.0 = fully closed
  final bool isFaceDetected;
  final bool autoBlink; // For use in instructions

  const EyeBlinkAnimation({
    super.key,
    this.size = 120,
    this.blinkProbability = 1.0,
    this.isFaceDetected = true,
    this.autoBlink = false,
  });

  @override
  Widget build(BuildContext context) {
    if (autoBlink) {
      return _AutoBlinkingEye(size: size);
    }

    final themeColor = isFaceDetected
        ? Theme.of(context).primaryColor
        : Colors.grey;

    return SizedBox(
      width: size,
      height: size,
      child: _PremiumEyePainterWidget(
        progress: blinkProbability,
        color: themeColor,
      ),
    );
  }
}

class _AutoBlinkingEye extends StatefulWidget {
  final double size;
  const _AutoBlinkingEye({required this.size});

  @override
  State<_AutoBlinkingEye> createState() => _AutoBlinkingEyeState();
}

class _AutoBlinkingEyeState extends State<_AutoBlinkingEye>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double progress = 1.0;
        final t = _controller.value;

        // Simulating a blink at t=0.5
        if (t > 0.45 && t < 0.55) {
          final blinkT = (t - 0.45) / 0.1;
          progress = (math.sin(blinkT * math.pi)).abs();
          progress = 1.0 - progress;
        }

        return _PremiumEyePainterWidget(
          progress: progress,
          color: Theme.of(context).primaryColor,
        );
      },
    );
  }
}

class _PremiumEyePainterWidget extends StatelessWidget {
  final double progress;
  final Color color;

  const _PremiumEyePainterWidget({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PremiumEyePainter(
        openFactor: progress.clamp(0.0, 1.0),
        color: color,
        scleraColor: Colors.white,
        pupilColor: AppColors.black,
      ),
    );
  }
}

class _PremiumEyePainter extends CustomPainter {
  final double openFactor;
  final Color color;
  final Color scleraColor;
  final Color pupilColor;

  _PremiumEyePainter({
    required this.openFactor,
    required this.color,
    required this.scleraColor,
    required this.pupilColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeWidth = size.width * 0.95;
    final baseEyeHeight = size.height * 0.52;

    // Smooth factor for height
    final currentHeight = baseEyeHeight * openFactor;

    final eyePath = Path();
    eyePath.moveTo(center.dx - eyeWidth / 2, center.dy);
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy - currentHeight,
      center.dx + eyeWidth / 2,
      center.dy,
    );
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy + currentHeight,
      center.dx - eyeWidth / 2,
      center.dy,
    );
    eyePath.close();

    // 1. Draw Sclera
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = scleraColor
        ..style = PaintingStyle.fill,
    );

    // 2. Draw Subtle Inner Shadow/Stroke
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (openFactor > 0.1) {
      canvas.save();
      canvas.clipPath(eyePath);

      final irisRadius = (size.width / 2) * 0.55;

      // 3. Draw Iris
      final irisPaint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 1.0), color.withValues(alpha: 0.8)],
        ).createShader(Rect.fromCircle(center: center, radius: irisRadius));

      canvas.drawCircle(center, irisRadius, irisPaint);

      // 4. Draw Pupil with subtle pulse (not needed here but looks premium)
      canvas.drawCircle(center, irisRadius * 0.42, Paint()..color = pupilColor);

      // 5. High-quality Reflections
      final reflectionPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.45);

      canvas.drawCircle(
        center + Offset(irisRadius * 0.3, -irisRadius * 0.3),
        irisRadius * 0.16,
        reflectionPaint,
      );

      canvas.drawCircle(
        center + Offset(-irisRadius * 0.2, irisRadius * 0.2),
        irisRadius * 0.08,
        Paint()..color = Colors.white.withValues(alpha: 0.2),
      );

      canvas.restore();
    } else {
      // 6. Draw Closed Eye Line (Lashes)
      final lashesPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(center: center, width: eyeWidth * 0.7, height: 10),
        0.1,
        math.pi - 0.2,
        false,
        lashesPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumEyePainter oldDelegate) =>
      oldDelegate.openFactor != openFactor || oldDelegate.color != color;
}
