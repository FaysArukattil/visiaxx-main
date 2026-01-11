import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

/// Animation showing a well-lit room requirement
class LightingAnimation extends StatefulWidget {
  const LightingAnimation({super.key});

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
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warning.withOpacity(
                0.1 + (_controller.value * 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withOpacity(0.2 * _controller.value),
                  blurRadius: 20 + (20 * _controller.value),
                  spreadRadius: 5 + (10 * _controller.value),
                ),
              ],
            ),
            child: Icon(
              Icons.wb_sunny_rounded,
              size: 80,
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
  const DistanceAnimation({super.key});

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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face_rounded, size: 50, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 120, height: 2, color: AppColors.border),
                      Positioned(
                        left: t * 100,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.phone_android_rounded,
                    size: 50,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '40 cm',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
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
  const IshiharaIntroAnimation({super.key});

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
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(150, 150),
            painter: _IshiharaPainter(_points, _controller.value),
          );
        },
      ),
    );
  }
}

class _IshiharaPainter extends CustomPainter {
  final List<Offset> points;
  final double progress;

  _IshiharaPainter(this.points, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < points.length; i++) {
      // Colors typical of Ishihara plates
      final color = i % 3 == 0
          ? AppColors.success
          : (i % 3 == 1 ? AppColors.error : AppColors.warning);

      paint.color = color.withOpacity(
        0.5 + (0.5 * math.sin(progress * math.pi + i)),
      );

      // Moving dots in a circle
      final radius = 50.0 + (10 * math.sin(progress * 2 * math.pi + i));
      final angle =
          (i / points.length) * 2 * math.pi + (progress * 0.5 * math.pi);

      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);

      canvas.drawCircle(
        Offset(dx, dy),
        5 + (2 * math.sin(i.toDouble())),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IshiharaPainter oldDelegate) => true;
}

/// Animation for "Stay Focused" steps
class StayFocusedAnimation extends StatefulWidget {
  const StayFocusedAnimation({super.key});

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
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(1 - _controller.value),
                    width: 2 + (5 * _controller.value),
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
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
  const AmslerIntroAnimation({super.key});

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
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: 0.3 + (0.7 * _controller.value),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                color: AppColors.white,
              ),
              child: Stack(
                children: [
                  for (int i = 1; i < 6; i++) ...[
                    Positioned(
                      left: i * 25.0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: AppColors.border.withOpacity(0.5),
                      ),
                    ),
                    Positioned(
                      top: i * 25.0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: AppColors.border.withOpacity(0.5),
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
  const AlignmentAnimation({super.key});

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
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // Moving target dot and crosshair
          final dx = 30 * math.sin(t * 2 * math.pi);
          final dy = 20 * math.cos(t * 2 * math.pi);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Crosshair
              Container(
                width: 100,
                height: 100,
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
                    Container(width: 1, height: 40, color: AppColors.success),
                    const SizedBox(height: 20),
                    Container(width: 1, height: 40, color: AppColors.success),
                  ],
                ),
              ),
              // Moving eye icon being centered
              Transform.translate(
                offset: Offset(dx * (1 - t), dy * (1 - t)),
                child: Icon(
                  Icons.remove_red_eye,
                  color: AppColors.success,
                  size: 30,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
