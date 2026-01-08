import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A high-speed, dynamic eye loading animation with integrated theme support.
/// Features rapid iris sliding, snappy pupil pulsing, and smooth but fast blinks.
class EyeLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double? value;

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
      duration: const Duration(milliseconds: 3000), // Enhanced 3s cycle
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
              progress: widget.value ?? _controller.value,
              color: themeColor,
            ),
          );
        },
      ),
    );
  }
}

class _EyePainter extends CustomPainter {
  final double progress;
  final Color color;

  _EyePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeWidth = size.width * 0.95;
    double baseEyeHeight = size.height * 0.52;

    // --- ENHANCED TIMING LOGIC ---
    double irisXOffset = 0;
    double blinkFactor = 1.0;

    // 1. High-Speed Sliding (Snappier 3000ms Loop)
    if (progress < 0.15) {
      // Resting center
      irisXOffset = 0;
    } else if (progress < 0.3) {
      // FAST move to Left
      double t = Curves.easeInOut.transform((progress - 0.15) / 0.15);
      irisXOffset = -t * (eyeWidth * 0.3);
    } else if (progress < 0.55) {
      // FAST slide all the way to Right
      double t = Curves.easeInOut.transform((progress - 0.3) / 0.25);
      irisXOffset = -(eyeWidth * 0.3) + (t * eyeWidth * 0.6);
    } else if (progress < 0.75) {
      // FAST return to center
      double t = Curves.easeInOut.transform((progress - 0.55) / 0.2);
      irisXOffset = (eyeWidth * 0.3) - (t * eyeWidth * 0.3);
    }

    // 2. Focused Pupil Pulsing (Huge size difference: transitions from tiny to very large)
    final pulseScale = 0.8 + (math.sin(progress * 8 * math.pi) * 0.45);

    // 3. Refined Blink Rhythm (Exactly 3 smooth blinks per cycle)
    final blinkMarkers = [0.2, 0.5, 0.8];
    const blinkHalfWindow = 0.08; // Increased for a smoother, slower feel
    for (final marker in blinkMarkers) {
      if (progress > marker - blinkHalfWindow &&
          progress < marker + blinkHalfWindow) {
        final t =
            (progress - (marker - blinkHalfWindow)) / (blinkHalfWindow * 2);
        // Using easeInOut curve instead of pure sin for more controlled smoothing
        final easedT = math.sin(t * math.pi);
        blinkFactor = 1.0 - easedT;
        break;
      }
    }

    // --- DRAWING ---
    final currentHeight = baseEyeHeight * blinkFactor;

    // Sclera Movement (Follows iris for dynamic feel)
    final scleraCenter = center + Offset(irisXOffset * 0.25, 0);

    final eyePath = Path();
    eyePath.moveTo(scleraCenter.dx - eyeWidth / 2, scleraCenter.dy);
    eyePath.quadraticBezierTo(
      scleraCenter.dx,
      scleraCenter.dy - currentHeight,
      scleraCenter.dx + eyeWidth / 2,
      scleraCenter.dy,
    );
    eyePath.quadraticBezierTo(
      scleraCenter.dx,
      scleraCenter.dy + currentHeight,
      scleraCenter.dx - eyeWidth / 2,
      scleraCenter.dy,
    );
    eyePath.close();

    // Sclera (Dark Portion)
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = const Color(0xFF14142B)
        ..style = PaintingStyle.fill,
    );

    // Iris & Pupil (Clipped)
    if (blinkFactor > 0.1) {
      canvas.save();
      canvas.clipPath(eyePath);

      final irisCenter = center + Offset(irisXOffset, 0);
      final irisRadius = (size.width / 2) * 0.5;

      // Theme-matched Iris (Steady size)
      canvas.drawCircle(irisCenter, irisRadius, Paint()..color = color);

      // Black Pupil (Huge dynamic pulse)
      canvas.drawCircle(
        irisCenter,
        irisRadius * 0.45 * pulseScale,
        Paint()..color = Colors.black,
      );

      // Reactive White Reflection (Opposite side and reactive to movement)
      final baseReflectionOffset = Offset(
        irisRadius * 0.25,
        -irisRadius * 0.25,
      );
      // Shifts slightly in same direction as iris to simulate sphere depth
      final reactiveReflectionOffset =
          baseReflectionOffset + Offset(irisXOffset * 0.15, 0);

      canvas.drawCircle(
        irisCenter + reactiveReflectionOffset,
        irisRadius * 0.15,
        Paint()..color = Colors.white.withOpacity(0.45),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _EyePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
