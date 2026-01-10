import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Animation showing user wearing glasses/specs
class WearSpecsAnimation extends StatefulWidget {
  final bool isCompact;

  const WearSpecsAnimation({super.key, this.isCompact = false});

  @override
  State<WearSpecsAnimation> createState() => _WearSpecsAnimationState();
}

class _WearSpecsAnimationState extends State<WearSpecsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _controller.repeat(reverse: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final containerHeight = widget.isCompact ? 200.0 : 240.0;
    final faceSize = widget.isCompact ? 80.0 : 100.0;
    final eyeSize = widget.isCompact ? 12.0 : 15.0;
    final glassesScale = widget.isCompact ? 0.8 : 1.0;

    return Container(
      height: containerHeight,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Face (always visible) - centered
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: faceSize,
                    height: faceSize,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.warning, width: 3),
                    ),
                    child: Stack(
                      children: [
                        // Eyes
                        Positioned(
                          top: faceSize * 0.35,
                          left: faceSize * 0.25,
                          child: Container(
                            width: eyeSize,
                            height: eyeSize,
                            decoration: const BoxDecoration(
                              color: AppColors.textPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          top: faceSize * 0.35,
                          right: faceSize * 0.25,
                          child: Container(
                            width: eyeSize,
                            height: eyeSize,
                            decoration: const BoxDecoration(
                              color: AppColors.textPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Smile
                        Positioned(
                          bottom: faceSize * 0.25,
                          left: faceSize * 0.30,
                          child: Container(
                            width: faceSize * 0.40,
                            height: faceSize * 0.20,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.textPrimary,
                                  width: 3,
                                ),
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Glasses sliding in - positioned relative to center
              Positioned.fill(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value - 10),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: glassesScale,
                        child: CustomPaint(
                          size: const Size(120, 40),
                          painter: _GlassesPainter(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Checkmark when glasses are on
              if (_controller.value > 0.7)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Opacity(
                    opacity: ((_controller.value - 0.7) / 0.3).clamp(0.0, 1.0),
                    child: Container(
                      padding: EdgeInsets.all(widget.isCompact ? 3 : 4),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppColors.surface,
                        size: widget.isCompact ? 16 : 20,
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

class _GlassesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.info.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Left lens
    final leftLens = Rect.fromLTWH(10, 5, 35, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftLens, const Radius.circular(5)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftLens, const Radius.circular(5)),
      paint,
    );

    // Right lens
    final rightLens = Rect.fromLTWH(75, 5, 35, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightLens, const Radius.circular(5)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightLens, const Radius.circular(5)),
      paint,
    );

    // Bridge
    canvas.drawLine(const Offset(45, 20), const Offset(75, 20), paint);

    // Arms
    canvas.drawLine(const Offset(10, 20), const Offset(0, 15), paint);
    canvas.drawLine(const Offset(110, 20), const Offset(120, 15), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
