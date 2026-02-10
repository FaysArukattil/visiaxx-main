import 'package:flutter/material.dart';
import '../../../data/models/visual_field_result.dart';
import '../../../core/constants/app_colors.dart';

class VisualFieldSensitivityMap extends StatelessWidget {
  final VisualFieldResult result;
  final double size;

  const VisualFieldSensitivityMap({
    Key? key,
    required this.result,
    this.size = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Grid
          Positioned.fill(
            child: CustomPaint(painter: _SensitivityGridPainter()),
          ),
          // Fixation crosshair
          Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Center(
                child: Icon(Icons.add, size: 10, color: Colors.white),
              ),
            ),
          ),
          // Stimuli
          Positioned.fill(
            child: CustomPaint(
              painter: _StimuliPainter(stimuli: result.stimuliResults),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensitivityGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw concentric circles
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, (size.width / 2) * (i / 3), paint);
    }

    // Draw cross lines
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Draw diagonal lines
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StimuliPainter extends CustomPainter {
  final List<Stimulus> stimuli;

  _StimuliPainter({required this.stimuli});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stimulus in stimuli) {
      final position = Offset(
        stimulus.position.dx * size.width,
        stimulus.position.dy * size.height,
      );

      final paint = Paint()
        ..color = stimulus.isDetected
            ? AppColors.success.withValues(alpha: 0.8)
            : AppColors.error.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      // Glow effect for detected
      if (stimulus.isDetected) {
        final shadowPaint = Paint()
          ..color = AppColors.success.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(position, 6, shadowPaint);
      }

      canvas.drawCircle(position, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
