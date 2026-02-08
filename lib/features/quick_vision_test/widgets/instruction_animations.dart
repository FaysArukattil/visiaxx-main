import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../../core/constants/app_colors.dart';

/// Premium animation for Step 3 of Eye Hydration Test
/// Shows a person reading, eyes blinking, and a counter incrementing
class BlinkReadingAnimation extends StatefulWidget {
  final bool isCompact;
  const BlinkReadingAnimation({super.key, this.isCompact = false});

  @override
  State<BlinkReadingAnimation> createState() => _BlinkReadingAnimationState();
}

class _BlinkReadingAnimationState extends State<BlinkReadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _blinkCount = 0;
  bool _lastIsClosed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 4000,
      ), // Slower for smoother observation
    )..repeat();

    _controller.addListener(() {
      final t = _controller.value;
      // Precise blink windows for a slower cycle
      bool isClosed = (t > 0.25 && t < 0.35) || (t > 0.75 && t < 0.85);
      if (isClosed && !_lastIsClosed) {
        setState(() => _blinkCount++);
      }
      _lastIsClosed = isClosed;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.isCompact ? 200 : 250,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          // Head Figure (Circular)
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.6),
                  width: 3,
                ),
              ),
            ),
          ),

          // Background - Paragraph visual
          Positioned(
            left: 25,
            right: 25,
            top: 45,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(6, (i) {
                      final isActive = (i == (_controller.value * 6).floor());
                      return Container(
                        height: 6,
                        width: i == 5 ? 100 : double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),

          // Face & Eyes
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              double blinkFactor = 1.0;
              // Smooth blink timing with full range
              if ((t > 0.22 && t < 0.38) || (t > 0.72 && t < 0.88)) {
                double localT;
                if (t < 0.5) {
                  localT = (t - 0.22) / 0.16;
                } else {
                  localT = (t - 0.72) / 0.16;
                }
                // Sina curve for natural eyelid motion
                blinkFactor = Curves.easeInOut.transform(
                  1.0 - math.sin(localT * math.pi),
                );
              }

              final mouthOpenFactor =
                  (math.sin(t * math.pi * 10).abs() * 0.6) + 0.2;

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildEye(blinkFactor),
                        const SizedBox(width: 20),
                        _buildEye(blinkFactor),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Animated Mouth (Reading Aloud)
                    Container(
                      width: 24,
                      height: 4 + (6 * mouthOpenFactor),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Massive Pulsating Blink Counter HUD
          Positioned(
            bottom: 20,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 300),
              tween: Tween(begin: 1.0, end: 1.2),
              key: ValueKey(_blinkCount),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$_blinkCount',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              curve: Curves.elasticOut,
            ),
          ),

          // "Reading" scanning line
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                left: 10 + (_controller.value * 180),
                top: 30,
                bottom: 30,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.success.withValues(alpha: 0),
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEye(double factor) {
    return SizedBox(
      width: 60,
      height: 35,
      child: CustomPaint(
        painter: _PremiumEyePainter(
          blinkFactor: factor,
          irisColor: AppColors.primary,
        ),
      ),
    );
  }
}

class _PremiumEyePainter extends CustomPainter {
  final double blinkFactor;
  final Color irisColor;

  _PremiumEyePainter({required this.blinkFactor, required this.irisColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeWidth = size.width * 0.95;
    final baseEyeHeight = size.height * 0.52;

    // Smooth factor for height - ensure it reaches 0 for full closure
    final currentHeight = baseEyeHeight * blinkFactor.clamp(0.0, 1.0);

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
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // 2. Draw Subtle Inner Shadow/Stroke
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = irisColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (blinkFactor > 0.05) {
      canvas.save();
      canvas.clipPath(eyePath);

      final irisRadius = (size.width / 2) * 0.55;

      // 3. Draw Iris
      final irisPaint = Paint()
        ..shader = RadialGradient(
          colors: [irisColor.withValues(alpha: 0.8), irisColor],
        ).createShader(Rect.fromCircle(center: center, radius: irisRadius));

      canvas.drawCircle(center, irisRadius, irisPaint);

      // 4. Draw Pupil
      canvas.drawCircle(
        center,
        irisRadius * 0.42,
        Paint()..color = Colors.black,
      );

      // 5. High-quality Reflections
      canvas.drawCircle(
        center + Offset(irisRadius * 0.3, -irisRadius * 0.3),
        irisRadius * 0.16,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );

      canvas.restore();
    }

    // 6. Draw eyelids/lashes line when closing or closed
    if (blinkFactor < 0.4) {
      final lashesPaint = Paint()
        ..color = irisColor.withValues(alpha: 0.8 * (1.0 - blinkFactor))
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
      oldDelegate.blinkFactor != blinkFactor ||
      oldDelegate.irisColor != irisColor;
}

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
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double size = widget.isCompact ? 100 : 150;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warning.withValues(
                  alpha: 0.1 + (_controller.value * 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withValues(
                      alpha: 0.2 * _controller.value,
                    ),
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
                color: AppColors.warning.withValues(
                  alpha: 0.8 + (_controller.value * 0.2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Animation showing the 40cm distance requirement
class DistanceAnimation extends StatefulWidget {
  final bool isCompact;
  final String? distanceText;
  const DistanceAnimation({
    super.key,
    this.isCompact = false,
    this.distanceText,
  });

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
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
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
                    widget.distanceText ?? (widget.isCompact ? '40 cm' : '1 m'),
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
        ),
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
    double size = widget.isCompact ? 180 : 210;
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 10 : 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
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

      paint.color = color.withValues(
        alpha: 0.5 + (0.5 * math.sin(progress * math.pi + i)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double size = widget.isCompact ? 80 : 120;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.color.withValues(
                              alpha: 1 - _controller.value,
                            ),
                            width:
                                (widget.isCompact ? 2 : 3) +
                                (5 * _controller.value),
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
            ),
          ),
        );
      },
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
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double size = widget.isCompact ? 100 : 150;
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
                          color: AppColors.black.withValues(alpha: 0.3),
                        ),
                      ),
                      Positioned(
                        top: i * (size / 8),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: AppColors.black.withValues(alpha: 0.3),
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
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double size = widget.isCompact ? 80 : 100;
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
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5),
                    ),
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
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double size = widget.isCompact ? 100 : 140;
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
      ..color = AppColors.success.withValues(alpha: 0.6 * pulse)
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

/// Animation for Step 4 of Pelli-Robson: Reading the triplet inside a blue box
class ReadingTripletsAnimation extends StatefulWidget {
  final bool isCompact;
  const ReadingTripletsAnimation({super.key, this.isCompact = false});

  @override
  State<ReadingTripletsAnimation> createState() =>
      _ReadingTripletsAnimationState();
}

class _ReadingTripletsAnimationState extends State<ReadingTripletsAnimation>
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
    // Wrap in FittedBox to ensure it never overflows regardless of internal content size
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 250, // Standard base width for the animation
          height: 200, // Standard base height
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Triplets moving through
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Scrolling logic: move from -50 to 50
                  double scrollOffset = -50 + (100 * (1.0 - _controller.value));
                  return Positioned(
                    top: scrollOffset,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTriplet('V S K', 0.1),
                        _buildTriplet('N H Z', 0.3),
                        _buildTriplet('D R V', 1.0),
                        _buildTriplet('K S O', 0.3),
                        _buildTriplet('H N Z', 0.1),
                      ],
                    ),
                  );
                },
              ),
              // The fixed highlight box in the center (matches test screen)
              Center(
                child: Container(
                  width: 220,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriplet(String text, double opacity) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}

/// Animation for Step 5 of Pelli-Robson: Fading Triplets
class FadingTripletsAnimation extends StatefulWidget {
  final bool isCompact;
  const FadingTripletsAnimation({super.key, this.isCompact = false});

  @override
  State<FadingTripletsAnimation> createState() =>
      _FadingTripletsAnimationState();
}

class _FadingTripletsAnimationState extends State<FadingTripletsAnimation>
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
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 250,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFadingRow('V S K', 1.0),
                  _buildFadingRow('N H Z', 0.4),
                  _buildFadingRow('O R D', 0.15),
                  _buildFadingRow('K S V', 0.05),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFadingRow(String text, double targetOpacity) {
    // Subtle breathing effect for animation
    final pulse = 0.9 + (0.1 * math.sin(_controller.value * 2 * math.pi));
    return Opacity(
      opacity: (targetOpacity * pulse).clamp(0.02, 1.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

/// Animation Concept: "Visual Pathway Demonstration" for Amsler Grid
/// Shows how light rays travel through the eye and hit the macula
class AmslerPathwayAnimation extends StatefulWidget {
  final bool isCompact;
  const AmslerPathwayAnimation({super.key, this.isCompact = false});

  @override
  State<AmslerPathwayAnimation> createState() => _AmslerPathwayAnimationState();
}

class _AmslerPathwayAnimationState extends State<AmslerPathwayAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // 4s for each scene
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.isCompact ? 280 : 340;
    double height = widget.isCompact ? 160 : 220;

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _AmslerPathwayPainter(
                      progress: _controller.value,
                      isCompact: widget.isCompact,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final isNormal = _controller.value < 0.5;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isNormal ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isNormal
                        ? "Normal Vision Pathway"
                        : "Macular Distortion Pathway",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isNormal ? AppColors.success : AppColors.error,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AmslerPathwayPainter extends CustomPainter {
  final double progress;
  final bool isCompact;

  _AmslerPathwayPainter({required this.progress, required this.isCompact});

  @override
  void paint(Canvas canvas, Size size) {
    final bool isNormal = progress < 0.5;
    final double sceneProgress = (progress < 0.5
        ? progress * 2
        : (progress - 0.5) * 2);

    // Smooth transition factor for the "damage" area
    final double damageAlpha = progress < 0.4
        ? 0
        : (progress < 0.6 ? (progress - 0.4) * 5 : 1.0);

    final eyeCenter = Offset(size.width * 0.7, size.height * 0.5);
    final sunPos = Offset(size.width * 0.15, size.height * 0.5);

    final eyeRadius = size.height * 0.4;

    // 1. Draw the Eye Cross-section
    final eyePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Sclera/Main Eye Ball
    canvas.drawCircle(eyeCenter, eyeRadius, eyePaint);

    // Cornea (bulge at the front)
    final corneaPath = Path();
    corneaPath.addArc(
      Rect.fromCircle(
        center: eyeCenter - Offset(eyeRadius * 0.9, 0),
        radius: eyeRadius * 0.3,
      ),
      -math.pi * 0.4,
      math.pi * 0.8,
    );
    canvas.drawPath(corneaPath, eyePaint);

    // Retina (back of the eye)
    final retinaPath = Path();
    retinaPath.addArc(
      Rect.fromCircle(center: eyeCenter, radius: eyeRadius - 2),
      -math.pi * 0.3,
      math.pi * 0.6,
    );
    final retinaPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawPath(retinaPath, retinaPaint);

    // Macula Highlight (at the very back)
    final maculaPaint = Paint()
      ..color = Color.lerp(
        Colors.orange,
        Colors.red,
        damageAlpha,
      )!.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      eyeCenter + Offset(eyeRadius - 2, 0),
      isCompact ? 10 : 15,
      maculaPaint,
    );

    // If damaged, add some distortion pulses to the macula
    if (damageAlpha > 0) {
      final pulse = math.sin(progress * 20) * 2;
      canvas.drawCircle(
        eyeCenter + Offset(eyeRadius - 2, 0),
        (isCompact ? 10 : 15) + pulse,
        Paint()
          ..color = Colors.red.withValues(alpha: 0.3 * damageAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // 2. Draw the Sun (Source of Light)
    _drawSunSource(canvas, sunPos, isCompact ? 30 : 40);

    // 3. Draw Light Rays
    _drawLightRays(
      canvas,
      sunPos,
      eyeCenter,
      eyeRadius,
      sceneProgress,
      isNormal,
    );

    // 4. Draw Perception Overlay (What the user sees)
    _drawPerceptionOverlay(
      canvas,
      Offset(size.width * 0.7, size.height * 0.2),
      isCompact ? 40 : 50,
      isNormal,
    );
  }

  void _drawSunSource(Canvas canvas, Offset pos, double radius) {
    // Sun body
    final sunPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, radius * 0.6, sunPaint);

    // Sun rays
    final rayPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 8; i++) {
      double angle = (i * math.pi * 2) / 8;
      canvas.drawLine(
        pos +
            Offset(
              math.cos(angle) * radius * 0.7,
              math.sin(angle) * radius * 0.7,
            ),
        pos + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        rayPaint,
      );
    }

    // Subtle glow
    canvas.drawCircle(
      pos,
      radius * 0.6,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawLightRays(
    Canvas canvas,
    Offset start,
    Offset eyeCenter,
    double eyeRadius,
    double t,
    bool isNormal,
  ) {
    final rayPaint = Paint()
      ..color = isNormal
          ? AppColors.info.withValues(alpha: 0.6)
          : Colors.orange.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final pupilPos = eyeCenter - Offset(eyeRadius, 0);
    final retinaPos = eyeCenter + Offset(eyeRadius - 2, 0);

    // Particles/Ray segments
    for (int i = 0; i < 5; i++) {
      final offset = (i - 2) * 10.0;
      final rayStart = start + Offset(0, offset);
      final rayRetina =
          retinaPos +
          Offset(
            0,
            isNormal ? offset * 0.3 : offset * 0.5 + math.sin(t * 10 + i) * 5,
          );

      // Calculate path with a slight bend at the pupil (lens effect)
      final path = Path();
      path.moveTo(rayStart.dx, rayStart.dy);
      path.quadraticBezierTo(
        pupilPos.dx,
        pupilPos.dy + offset * 0.1,
        rayRetina.dx,
        rayRetina.dy,
      );

      // Animate dash
      final p1 = path.computeMetrics().first;
      final extract = p1.extractPath(
        p1.length * t,
        p1.length * (t + 0.1).clamp(0.0, 1.0),
      );

      canvas.drawPath(extract, rayPaint);

      // If not normal, add some scattered rays
      if (!isNormal && t > 0.6) {
        canvas.drawLine(
          rayRetina - Offset(10, 0),
          rayRetina +
              Offset(math.cos(i.toDouble()) * 10, math.sin(i.toDouble()) * 10),
          Paint()
            ..color = Colors.red.withValues(alpha: 0.4)
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _drawPerceptionOverlay(
    Canvas canvas,
    Offset pos,
    double size,
    bool isNormal,
  ) {
    // Background for overlay
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: size * 1.2, height: size * 1.2),
        Radius.circular(8),
      ),
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    final paint = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = Rect.fromCenter(center: pos, width: size, height: size);

    if (isNormal) {
      // Normal straight grid
      int lines = 5;
      double step = size / lines;
      for (int i = 0; i <= lines; i++) {
        canvas.drawLine(
          Offset(rect.left + i * step, rect.top),
          Offset(rect.left + i * step, rect.bottom),
          paint,
        );
        canvas.drawLine(
          Offset(rect.left, rect.top + i * step),
          Offset(rect.right, rect.top + i * step),
          paint,
        );
      }
    } else {
      // Distorted grid
      int lines = 5;
      double step = size / lines;
      for (int i = 0; i <= lines; i++) {
        final pathH = Path();
        final pathV = Path();
        pathH.moveTo(rect.left, rect.top + i * step);
        pathV.moveTo(rect.left + i * step, rect.top);

        for (int j = 1; j <= 10; j++) {
          double tx = j / 10.0;
          double dist = math.sin(tx * math.pi + progress * 5) * 3;
          pathH.lineTo(rect.left + tx * size, rect.top + i * step + dist);
          pathV.lineTo(rect.left + i * step + dist, rect.top + tx * size);
        }
        canvas.drawPath(
          pathH,
          paint..color = paint.color.withValues(alpha: 0.7),
        );
        canvas.drawPath(
          pathV,
          paint..color = paint.color.withValues(alpha: 0.7),
        );
      }

      // Add a "blind spot" or scotoma
      canvas.drawCircle(
        pos + const Offset(5, -5),
        size * 0.2,
        Paint()
          ..color = Colors.black87
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Label for perception
    final textPainter = TextPainter(
      text: TextSpan(
        text: "Vision",
        style: TextStyle(
          color: isNormal ? AppColors.success : AppColors.error,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      pos - Offset(textPainter.width / 2, size * 0.5 + 10),
    );
  }

  @override
  bool shouldRepaint(covariant _AmslerPathwayPainter oldDelegate) => true;
}

/// Animation showing reading aloud (Focus on text/speech visual without mic)
class ReadAloudAnimation extends StatefulWidget {
  final bool isCompact;
  const ReadAloudAnimation({super.key, this.isCompact = false});

  @override
  State<ReadAloudAnimation> createState() => _ReadAloudAnimationState();
}

class _ReadAloudAnimationState extends State<ReadAloudAnimation>
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
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Displaying text to be read
                  Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      "The quick brown fox jumps over the lazy dog",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Reading visual (Face + Speech waves)
                  Column(
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 44,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final wave = math.sin(t * 10 + i) * 6;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 3,
                            height: 10 + wave.abs(),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "READING ALOUD",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Animation showing text size reduction and blur for threshold awareness
class BlurryReadingAnimation extends StatefulWidget {
  final bool isCompact;
  const BlurryReadingAnimation({super.key, this.isCompact = false});

  @override
  State<BlurryReadingAnimation> createState() => _BlurryReadingAnimationState();
}

class _BlurryReadingAnimationState extends State<BlurryReadingAnimation>
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
    return Container(
      height: widget.isCompact ? 200 : 240,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              // Scale from 1.0 to 0.4, blur from 0 to 4
              final fontSize = 24.0 * (1.1 - (t * 0.7));
              final blurLevel = t * 5.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 220,
                    height:
                        100, // Reduced height to fit in container with buttons
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: blurLevel,
                          sigmaY: blurLevel,
                        ),
                        child: Text(
                          "The quick brown fox jumps over the lazy dog",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildButtonMock(
                        "CAN READ",
                        Icons.check_circle_outline_rounded,
                        AppColors.success,
                        highlight: t < 0.6,
                      ),
                      const SizedBox(width: 16),
                      _buildButtonMock(
                        "CANNOT READ",
                        Icons.visibility_off_rounded,
                        AppColors.error,
                        highlight: t >= 0.6,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildButtonMock(
    String label,
    IconData icon,
    Color color, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: const BoxConstraints(minHeight: 32),
      decoration: BoxDecoration(
        color: highlight ? color : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlight ? AppColors.white : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: highlight ? AppColors.white : color,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}

/// Animation showing keyboard typing
class KeyboardTypingAnimation extends StatefulWidget {
  final bool isCompact;
  const KeyboardTypingAnimation({super.key, this.isCompact = false});

  @override
  State<KeyboardTypingAnimation> createState() =>
      _KeyboardTypingAnimationState();
}

class _KeyboardTypingAnimationState extends State<KeyboardTypingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final String _typedText = 'Typing some text...';

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
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          int charsToShow = (_controller.value * _typedText.length).toInt();
          String displayText = _typedText.substring(0, charsToShow);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text Field simulation
              Container(
                width: 200,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary, width: 1),
                ),
                child: Row(
                  children: [
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: widget.isCompact ? 12 : 14,
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (_controller.value % 0.5 < 0.25)
                      Container(width: 2, height: 14, color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Keyboard simulation
              Container(
                width: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: List.generate(
                    3,
                    (row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(row == 2 ? 6 : 7, (col) {
                          // Highlight a random key in sync with typing
                          bool isHot =
                              (charsToShow > 0 &&
                              (row * 7 + col) == (charsToShow * 7) % 20);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isHot
                                  ? AppColors.primary
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withValues(
                                    alpha: 0.05,
                                  ),
                                  blurRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Animation showing a dim room requirement (Bright to Dim transition)
class DimLightingAnimation extends StatefulWidget {
  final bool isCompact;
  const DimLightingAnimation({super.key, this.isCompact = false});

  @override
  State<DimLightingAnimation> createState() => _DimLightingAnimationState();
}

class _DimLightingAnimationState extends State<DimLightingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _brightness;
  late Animation<double> _switchPos;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _brightness = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 30,
      ), // Stay bright
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.2),
        weight: 20,
      ), // Turn off
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 0.2),
        weight: 40,
      ), // Stay dim
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.0),
        weight: 10,
      ), // Reset
    ]).animate(_controller);

    _switchPos = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final color = Color.lerp(
              Colors.white,
              const Color(0xFF121212),
              1 - _brightness.value,
            )!;

            return Container(
              padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Light bulb
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_brightness.value > 0.5)
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 40,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          Icon(
                            _brightness.value > 0.5
                                ? Icons.lightbulb_rounded
                                : Icons.lightbulb_outline_rounded,
                            size: widget.isCompact ? 60 : 80,
                            color: _brightness.value > 0.5
                                ? AppColors.warning
                                : Colors.grey.shade700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Switch
                      Container(
                        width: 40,
                        height: 70,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              top: _switchPos.value * 30,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Animation showing side illumination (Professional Eye version)
class SideIlluminationAnimation extends StatefulWidget {
  final bool isCompact;
  const SideIlluminationAnimation({super.key, this.isCompact = false});

  @override
  State<SideIlluminationAnimation> createState() =>
      _SideIlluminationAnimationState();
}

class _SideIlluminationAnimationState extends State<SideIlluminationAnimation>
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(200, 160),
                    painter: _ProfessionalSideIlluminationPainter(
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfessionalSideIlluminationPainter extends CustomPainter {
  final double progress;

  _ProfessionalSideIlluminationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw Professional Eye (Front Facing)
    final eyePos = center + const Offset(0, -10);
    final eyeWidth = 100.0;
    final eyeHeight = 60.0;

    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Eye shape
    final eyePath = Path();
    eyePath.moveTo(eyePos.dx - eyeWidth / 2, eyePos.dy);
    eyePath.quadraticBezierTo(
      eyePos.dx,
      eyePos.dy - eyeHeight / 2 - 10,
      eyePos.dx + eyeWidth / 2,
      eyePos.dy,
    );
    eyePath.quadraticBezierTo(
      eyePos.dx,
      eyePos.dy + eyeHeight / 2 + 10,
      eyePos.dx - eyeWidth / 2,
      eyePos.dy,
    );

    canvas.drawPath(eyePath, eyePaint);
    canvas.drawPath(eyePath, borderPaint);

    // Iris
    final irisPaint = Paint()
      ..color = Colors.brown.shade700
      ..style = PaintingStyle.fill;
    canvas.drawCircle(eyePos, 22, irisPaint);

    // Pupil
    final pupilPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(eyePos, 10, pupilPaint);

    // Reflection (Catchlight)
    canvas.drawCircle(
      eyePos - const Offset(4, 4),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );

    // 2. Smartphone/Flashlight coming from the side
    // Loop the flashlight movement
    final t = progress;
    final flashlightAlpha = t < 0.1 ? t / 0.1 : (t > 0.9 ? (1 - t) / 0.1 : 1.0);

    final double angle =
        math.pi /
        6; // 30 degrees from horizontal = 60 degrees from optical axis
    final double dist = 100.0;
    final flashlightCenter =
        eyePos + Offset(-math.cos(angle) * dist, math.sin(angle) * dist * 0.2);

    canvas.save();
    canvas.translate(flashlightCenter.dx, flashlightCenter.dy);
    canvas.rotate(-math.pi / 4); // Angle of the phone itself

    final phonePaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: flashlightAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final phoneFill = Paint()
      ..color = AppColors.surface.withValues(alpha: flashlightAlpha)
      ..style = PaintingStyle.fill;

    final phoneRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -25, 24, 50),
      const Radius.circular(4),
    );
    canvas.drawRRect(phoneRect, phoneFill);
    canvas.drawRRect(phoneRect, phonePaint);

    // Flash light beam
    final flashPos = const Offset(0, -18);
    final flashPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: flashlightAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(flashPos, 4, flashPaint);

    // Light beam towards eye
    if (flashlightAlpha > 0.5) {
      final beamPaint = Paint()
        ..shader = ui.Gradient.linear(flashPos, const Offset(50, 40), [
          AppColors.warning.withValues(alpha: 0.4),
          AppColors.warning.withValues(alpha: 0.0),
        ]);

      final beamPath = Path();
      beamPath.moveTo(flashPos.dx, flashPos.dy);
      beamPath.lineTo(60, 20);
      beamPath.lineTo(40, 60);
      beamPath.close();
      canvas.drawPath(beamPath, beamPaint);
    }
    canvas.restore();

    // 3. Shadow on the eye (Anatomically representation of Van Herick)
    if (flashlightAlpha > 0.8) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;

      // Represent a slit of light and a shadow on the nasal side
      final slitWidth = 4.0;
      canvas.drawRect(
        Rect.fromLTWH(eyePos.dx - 18, eyePos.dy - 12, slitWidth, 24),
        Paint()..color = AppColors.warning.withValues(alpha: 0.5),
      );

      // Shadow (the "Van Herick space")
      canvas.drawRect(
        Rect.fromLTWH(eyePos.dx - 14, eyePos.dy - 12, 8, 24),
        shadowPaint,
      );
    }

    // Label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: "SIDE ILLUMINATION (60\u00B0)",
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, size.height - 20),
    );
  }

  @override
  bool shouldRepaint(
    covariant _ProfessionalSideIlluminationPainter oldDelegate,
  ) => true;
}
