import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

class EyeBlinkAnimation extends StatefulWidget {
  final double size;
  final bool isFaceDetected;
  final Stream<void>? blinkStream; // Optional stream to trigger blinks

  const EyeBlinkAnimation({
    super.key,
    this.size = 120,
    this.isFaceDetected = true,
    this.blinkStream,
  });

  @override
  State<EyeBlinkAnimation> createState() => _EyeBlinkAnimationState();
}

class _EyeBlinkAnimationState extends State<EyeBlinkAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Rapid but smooth blink
    );

    // Initial state is open (1.0)
    _controller.value = 1.0;

    _setupStream();
  }

  void _setupStream() {
    _subscription?.cancel();
    if (widget.blinkStream != null) {
      _subscription = widget.blinkStream!.listen((_) {
        _triggerBlink();
      });
    }
  }

  @override
  void didUpdateWidget(EyeBlinkAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blinkStream != oldWidget.blinkStream) {
      _setupStream();
    }
  }

  void _triggerBlink() {
    if (!mounted) return;

    // Play a smooth 60fps animation: Open -> Closed -> Open
    // 0.0 is closed, 1.0 is open
    _controller
        .animateTo(
          0.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeIn,
        )
        .then((_) {
          if (mounted) {
            _controller.animateTo(
              1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isFaceDetected
        ? Theme.of(context).primaryColor
        : Colors.grey;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _PremiumEyePainter(
              openFactor: _controller.value,
              color: themeColor,
              scleraColor: Colors.white,
              pupilColor: AppColors.black,
            ),
          ),
        );
      },
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

    // Smooth factor for height - ensure it reaches 0 for full closure
    final currentHeight = baseEyeHeight * openFactor.clamp(0.0, 1.0);

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

    if (openFactor > 0.05) {
      canvas.save();
      canvas.clipPath(eyePath);

      final irisRadius = (size.width / 2) * 0.55;

      // 3. Draw Iris
      final irisPaint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 1.0), color.withValues(alpha: 0.8)],
        ).createShader(Rect.fromCircle(center: center, radius: irisRadius));

      canvas.drawCircle(center, irisRadius, irisPaint);

      // 4. Draw Pupil
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
    }

    // Draw eyelids/lashes line when closing or closed
    if (openFactor < 0.4) {
      final lashesPaint = Paint()
        ..color = color.withValues(alpha: 0.8 * (1.0 - openFactor))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: eyeWidth * 0.8,
          height: size.height * 0.1,
        ),
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
