import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A calm, themed eye loading animation.
/// Features a gentle 4s cycle, smooth iris transitions, and subtle breathing pupil pulse.
class EyeLoader extends StatefulWidget {
  final double size;
  final Color? color; // Iris color (defaults to theme primary)
  final Color? scleraColor; // Background eye color (defaults to white)
  final Color? pupilColor; // Pupil color (defaults to black)
  final double? value;

  const EyeLoader({
    super.key,
    this.size = 40.0,
    this.color,
    this.scleraColor,
    this.pupilColor,
    this.value,
  });

  /// Constructor for button usage - larger and more visible
  const EyeLoader.button({super.key, this.color})
    : size = 28.0, // Larger for buttons
      scleraColor = null,
      pupilColor = null,
      value = null;

  /// Constructor for full screen usage - even larger
  const EyeLoader.fullScreen({super.key, this.color})
    : size = 80.0,
      scleraColor = null,
      pupilColor = null,
      value = null;

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
      duration: const Duration(milliseconds: 4000),
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
    final fallbackSclera = Colors.white;
    final fallbackPupil = Colors.black;

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
              scleraColor: widget.scleraColor ?? fallbackSclera,
              pupilColor: widget.pupilColor ?? fallbackPupil,
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
  final Color scleraColor;
  final Color pupilColor;

  _EyePainter({
    required this.progress,
    required this.color,
    required this.scleraColor,
    required this.pupilColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeWidth = size.width * 0.95;
    double baseEyeHeight = size.height * 0.52;

    double irisXOffset = 0;
    double blinkFactor = 1.0;

    const curve = Curves.easeInOutCubic;
    if (progress < 0.15) {
      irisXOffset = 0;
    } else if (progress < 0.35) {
      double t = curve.transform((progress - 0.15) / 0.2);
      irisXOffset = -t * (eyeWidth * 0.28);
    } else if (progress < 0.65) {
      double t = curve.transform((progress - 0.35) / 0.3);
      irisXOffset = -(eyeWidth * 0.28) + (t * eyeWidth * 0.56);
    } else if (progress < 0.85) {
      double t = curve.transform((progress - 0.65) / 0.2);
      irisXOffset = (eyeWidth * 0.28) - (t * eyeWidth * 0.28);
    }

    double pulseScale = 1.0;
    if (progress < 0.15) {
      final t = progress / 0.15;
      pulseScale = 1.8 - (Curves.easeOutExpo.transform(t) * 0.8);
    }

    final blinkMarkers = [0.2, 0.5, 0.8];
    const blinkHalfWindow = 0.07;
    for (final marker in blinkMarkers) {
      if (progress > marker - blinkHalfWindow &&
          progress < marker + blinkHalfWindow) {
        final t =
            (progress - (marker - blinkHalfWindow)) / (blinkHalfWindow * 2);
        final easedT = math.sin(t * math.pi);
        blinkFactor = 1.0 - easedT;
        break;
      }
    }

    final blinkAdjustment = (1.0 - blinkFactor) * 0.45;
    pulseScale += blinkAdjustment;

    final currentHeight = baseEyeHeight * blinkFactor;
    final scleraCenter = center + Offset(irisXOffset * 0.22, 0);

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

    canvas.drawPath(
      eyePath,
      Paint()
        ..color = scleraColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      eyePath,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    if (blinkFactor > 0.1) {
      canvas.save();
      canvas.clipPath(eyePath);

      final irisCenter = center + Offset(irisXOffset, 0);
      final irisRadius = (size.width / 2) * 0.5;

      canvas.drawCircle(irisCenter, irisRadius, Paint()..color = color);

      canvas.drawCircle(
        irisCenter,
        irisRadius * 0.48 * pulseScale,
        Paint()..color = pupilColor,
      );

      final baseReflectionOffset = Offset(
        irisRadius * 0.25,
        -irisRadius * 0.25,
      );
      final reactiveReflectionOffset =
          baseReflectionOffset + Offset(irisXOffset * 0.14, 0);

      canvas.drawCircle(
        irisCenter + reactiveReflectionOffset,
        irisRadius * 0.15,
        Paint()..color = Colors.white.withOpacity(0.42),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _EyePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.scleraColor != scleraColor ||
      oldDelegate.pupilColor != pupilColor;
}
