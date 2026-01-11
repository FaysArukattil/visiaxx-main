import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

/// Animation showing a well-lit room requirement
class LightingAnimation extends StatefulWidget {
  final bool isCompact;
  const LightingAnimation({super.key, this.isCompact = false});

  @override
  State<LightingAnimation> createState() => _LightingAnimationState();
}

class _LightingAnimationState extends State<LightingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.isCompact ? 100 : 150;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warning.withOpacity(
                0.1 + (_controller.value * 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withOpacity(0.2 * _controller.value),
                  blurRadius:
                      (widget.isCompact ? 15 : 20) + (20 * _controller.value),
                  spreadRadius:
                      (widget.isCompact ? 3 : 5) + (10 * _controller.value),
                ),
              ],
            ),
            child: Icon(
              Icons.wb_sunny_rounded,
              size: widget.isCompact ? 50 : 80,
              color: AppColors.warning.withOpacity(
                0.8 + (_controller.value * 0.2),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animation showing the 40cm distance requirement
class DistanceAnimation extends StatefulWidget {
  final bool isCompact;
  const DistanceAnimation({super.key, this.isCompact = false});

  @override
  State<DistanceAnimation> createState() => _DistanceAnimationState();
}

class _DistanceAnimationState extends State<DistanceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final iconSize = widget.isCompact ? 35.0 : 50.0;
          final lineWidth = widget.isCompact ? 80.0 : 120.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.face_rounded,
                    size: iconSize,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: lineWidth,
                        height: 2,
                        color: AppColors.border,
                      ),
                      Positioned(
                        left: t * (lineWidth - 20),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                          size: widget.isCompact ? 20 : 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.phone_android_rounded,
                    size: iconSize,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '40 cm',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: widget.isCompact ? 14 : 16,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Animation for Ishihara Plates intro
class IshiharaIntroAnimation extends StatefulWidget {
  final bool isCompact;
  const IshiharaIntroAnimation({super.key, this.isCompact = false});

  @override
  State<IshiharaIntroAnimation> createState() => _IshiharaIntroAnimationState();
}

class _IshiharaIntroAnimationState extends State<IshiharaIntroAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Offset> _points = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 40; i++) {
      _points.add(Offset(_random.nextDouble(), _random.nextDouble()));
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.isCompact ? 100 : 150;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(size, size),
            painter: _IshiharaPainter(
              _points,
              _controller.value,
              widget.isCompact,
            ),
          );
        },
      ),
    );
  }
}

class _IshiharaPainter extends CustomPainter {
  final List<Offset> points;
  final double progress;
  final bool isCompact;

  _IshiharaPainter(this.points, this.progress, this.isCompact);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < points.length; i++) {
      final color = i % 3 == 0
          ? AppColors.success
          : (i % 3 == 1 ? AppColors.error : AppColors.warning);

      paint.color = color.withOpacity(
        0.5 + (0.5 * math.sin(progress * math.pi + i)),
      );

      final radius =
          (size.width / 3) + (10 * math.sin(progress * 2 * math.pi + i));
      final angle =
          (i / points.length) * 2 * math.pi + (progress * 0.5 * math.pi);

      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);

      canvas.drawCircle(
        Offset(dx, dy),
        (isCompact ? 3 : 5) + (2 * math.sin(i.toDouble())),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IshiharaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Animation for "Stay Focused" steps (Now with custom color support)
class StayFocusedAnimation extends StatefulWidget {
  final bool isCompact;
  final Color color;
  const StayFocusedAnimation({
    super.key,
    this.isCompact = false,
    this.color = AppColors.primary,
  });

  @override
  State<StayFocusedAnimation> createState() => _StayFocusedAnimationState();
}

class _StayFocusedAnimationState extends State<StayFocusedAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.isCompact ? 80 : 120;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(1 - _controller.value),
                    width: (widget.isCompact ? 2 : 3) + (5 * _controller.value),
                  ),
                ),
              ),
              Container(
                width: widget.isCompact ? 8 : 12,
                height: widget.isCompact ? 8 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Animation for Amsler Grid intro
class AmslerIntroAnimation extends StatefulWidget {
  final bool isCompact;
  const AmslerIntroAnimation({super.key, this.isCompact = false});

  @override
  State<AmslerIntroAnimation> createState() => _AmslerIntroAnimationState();
}

class _AmslerIntroAnimationState extends State<AmslerIntroAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.isCompact ? 100 : 150;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: 0.3 + (0.7 * _controller.value),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.black, width: 2),
                color: AppColors.white,
              ),
              child: Stack(
                children: [
                  for (int i = 1; i < 8; i++) ...[
                    Positioned(
                      left: i * (size / 8),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: AppColors.black.withOpacity(0.3),
                      ),
                    ),
                    Positioned(
                      top: i * (size / 8),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: AppColors.black.withOpacity(0.3),
                      ),
                    ),
                  ],
                  Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animation for alignment steps
class AlignmentAnimation extends StatefulWidget {
  final bool isCompact;
  const AlignmentAnimation({super.key, this.isCompact = false});

  @override
  State<AlignmentAnimation> createState() => _AlignmentAnimationState();
}

class _AlignmentAnimationState extends State<AlignmentAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.isCompact ? 80 : 100;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final dx = (widget.isCompact ? 20 : 30) * math.sin(t * 2 * math.pi);
          final dy = (widget.isCompact ? 15 : 20) * math.cos(t * 2 * math.pi);

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.success.withOpacity(0.5)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(height: 1, color: AppColors.success),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Container(height: 1, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 1,
                      height: size * 0.4,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 1,
                      height: size * 0.4,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(dx * (1 - t), dy * (1 - t)),
                child: Icon(
                  Icons.remove_red_eye,
                  color: AppColors.success,
                  size: widget.isCompact ? 24 : 30,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Animation showing staying steady at a reading distance
class SteadyReadingAnimation extends StatefulWidget {
  final bool isCompact;
  const SteadyReadingAnimation({super.key, this.isCompact = false});

  @override
  State<SteadyReadingAnimation> createState() => _SteadyReadingAnimationState();
}

class _SteadyReadingAnimationState extends State<SteadyReadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  late Animation<double> _handMovement;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _handMovement = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 5.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.isCompact ? 100 : 140;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(size * 1.5, size),
            painter: _SteadyReadingPainter(
              progress: _controller.value,
              pulse: _pulse.value,
              shake: _handMovement.value,
              isCompact: widget.isCompact,
            ),
          );
        },
      ),
    );
  }
}

class _SteadyReadingPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final double shake;
  final bool isCompact;

  _SteadyReadingPainter({
    required this.progress,
    required this.pulse,
    required this.shake,
    required this.isCompact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final lineStart = Offset(20, center.dy);
    final lineEnd = Offset(size.width - 20, center.dy);

    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(lineStart, lineEnd, linePaint);

    canvas.drawLine(
      lineStart + const Offset(0, -5),
      lineStart + const Offset(0, 5),
      linePaint,
    );
    canvas.drawLine(
      lineEnd + const Offset(0, -5),
      lineEnd + const Offset(0, 5),
      linePaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '40 cm',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: isCompact ? 10 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, isCompact ? 20 : 25),
    );

    final phoneCenter = center + Offset(size.width * 0.3, shake * 0.5);
    final phoneWidth = isCompact ? 30.0 : 40.0;
    final phoneHeight = isCompact ? 50.0 : 70.0;

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: phoneCenter,
        width: phoneWidth,
        height: phoneHeight,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      phoneRect,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(phoneRect, paint);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final r = math.Random(42);
    for (int i = 0; i < 8; i++) {
      dotPaint.color = [
        AppColors.primary,
        AppColors.success,
        AppColors.warning,
      ][r.nextInt(3)];
      canvas.drawCircle(
        phoneCenter +
            Offset(r.nextDouble() * 20 - 10, r.nextDouble() * 30 - 15),
        2,
        dotPaint,
      );
    }

    final eyeCenter = center - Offset(size.width * 0.35, 0);
    final eyeWidth = isCompact ? 25.0 : 35.0;

    final eyePath = Path();
    eyePath.moveTo(eyeCenter.dx - eyeWidth / 2, eyeCenter.dy);
    eyePath.quadraticBezierTo(
      eyeCenter.dx,
      eyeCenter.dy - 15,
      eyeCenter.dx + eyeWidth / 2,
      eyeCenter.dy,
    );
    eyePath.quadraticBezierTo(
      eyeCenter.dx,
      eyeCenter.dy + 15,
      eyeCenter.dx - eyeWidth / 2,
      eyeCenter.dy,
    );

    canvas.drawPath(eyePath, paint);
    canvas.drawCircle(eyeCenter, 5, paint..style = PaintingStyle.fill);

    final bracketPaint = Paint()
      ..color = AppColors.success.withOpacity(0.6 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final bSize = isCompact ? 10.0 : 15.0;
    final bDist = isCompact ? 6.0 : 10.0;

    void drawBracket(Offset p, double dx, double dy) {
      canvas.drawLine(p, p + Offset(dx, 0), bracketPaint);
      canvas.drawLine(p, p + Offset(0, dy), bracketPaint);
    }

    drawBracket(
      phoneCenter + Offset(-phoneWidth / 2 - bDist, -phoneHeight / 2 - bDist),
      bSize,
      0,
    );
    drawBracket(
      phoneCenter + Offset(-phoneWidth / 2 - bDist, -phoneHeight / 2 - bDist),
      0,
      bSize,
    );
    drawBracket(
      phoneCenter + Offset(phoneWidth / 2 + bDist, -phoneHeight / 2 - bDist),
      -bSize,
      0,
    );
    drawBracket(
      phoneCenter + Offset(phoneWidth / 2 + bDist, -phoneHeight / 2 - bDist),
      0,
      bSize,
    );
    drawBracket(
      phoneCenter + Offset(-phoneWidth / 2 - bDist, phoneHeight / 2 + bDist),
      bSize,
      0,
    );
    drawBracket(
      phoneCenter + Offset(-phoneWidth / 2 - bDist, phoneHeight / 2 + bDist),
      0,
      -bSize,
    );
    drawBracket(
      phoneCenter + Offset(phoneWidth / 2 + bDist, phoneHeight / 2 + bDist),
      -bSize,
      0,
    );
    drawBracket(
      phoneCenter + Offset(phoneWidth / 2 + bDist, phoneHeight / 2 + bDist),
      0,
      -bSize,
    );
  }

  @override
  bool shouldRepaint(covariant _SteadyReadingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.shake != shake;
}

/// Animation for Pelli-Robson Contrast Sensitivity
class ContrastTripletAnimation extends StatefulWidget {
  final bool isCompact;
  const ContrastTripletAnimation({super.key, this.isCompact = false});

  @override
  State<ContrastTripletAnimation> createState() =>
      _ContrastTripletAnimationState();
}

class _ContrastTripletAnimationState extends State<ContrastTripletAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.isCompact ? 140 : 200;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: size,
            height: size * 0.6,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildTripletRow('V S K', 0.0, 0.25),
                _buildTripletRow('N H Z', 0.25, 0.5),
                _buildTripletRow('O R D', 0.5, 0.75),
                _buildTripletRow('K S V', 0.75, 1.0),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTripletRow(String letters, double start, double end) {
    final t = (_controller.value - start) / (end - start);
    if (t < 0 || t > 1) return const SizedBox.shrink();

    // Opacity reduces as it "fades"
    final opacity = (1.0 - t).clamp(0.05, 1.0);
    final scale = 0.8 + (0.2 * t);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Text(
          letters,
          style: TextStyle(
            fontSize: widget.isCompact ? 24 : 32,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}
