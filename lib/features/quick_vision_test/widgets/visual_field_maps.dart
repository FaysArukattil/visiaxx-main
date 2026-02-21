import 'package:flutter/material.dart';
import '../../../data/models/visual_field_result.dart';

/// Renders a grayscale-symbol representation of the visual field.
/// Matches Humphrey GHT/Total Deviation style with discrete patterns.
class VisualFieldGrayscaleMap extends StatelessWidget {
  final VisualFieldResult result;
  final double size;

  const VisualFieldGrayscaleMap({
    super.key,
    required this.result,
    this.size = 135, // Reduced size
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'GHT',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _GrayscaleGridPainter()),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _DenseGrayscalePainter(
                    stimuli: result.stimuliResults,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders a probability symbol map showing deviations from normal.
class VisualFieldPatternDeviationMap extends StatelessWidget {
  final VisualFieldResult result;
  final double size;

  const VisualFieldPatternDeviationMap({
    super.key,
    required this.result,
    this.size = 135, // Reduced size
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'PATTERN DEVIATION',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PatternDeviationGridPainter()),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _HumphreyStylePainter(
                    stimuli: result.stimuliResults,
                    isPatternDeviation: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrayscaleGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws a dense grid of grayscale blocks to represent sensitivity.
class _DenseGrayscalePainter extends CustomPainter {
  final List<Stimulus> stimuli;

  _DenseGrayscalePainter({required this.stimuli});

  @override
  void paint(Canvas canvas, Size size) {
    const int gridSteps = 14; // Slightly more dense for texture
    final blockWidth = size.width / gridSteps;
    final blockHeight = size.height / gridSteps;

    final paint = Paint()..color = Colors.black;

    for (int i = 0; i < gridSteps; i++) {
      for (int j = 0; j < gridSteps; j++) {
        final blockRect = Rect.fromLTWH(
          i * blockWidth,
          j * blockHeight,
          blockWidth,
          blockHeight,
        );
        final blockCenter = blockRect.center;

        // Simple Inverse Distance Weighting interpolation
        double totalWeight = 0;
        double weightedIntensity = 0;

        for (final stimulus in stimuli) {
          final stimPos = Offset(
            stimulus.position.dx * size.width,
            stimulus.position.dy * size.height,
          );
          final distance = (blockCenter - stimPos).distance;

          // Influence radius
          if (distance < size.width * 0.25) {
            final weight = 1.0 / (distance * distance + 5);
            totalWeight += weight;
            weightedIntensity +=
                (stimulus.isDetected ? stimulus.intensity : 1.2) * weight;
          }
        }

        if (totalWeight > 0) {
          final avgIntensity = weightedIntensity / totalWeight;

          if (avgIntensity > 0.35) {
            _drawPattern(canvas, blockRect, avgIntensity, paint);
          }
        }
      }
    }

    // Fixation point
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  void _drawPattern(Canvas canvas, Rect rect, double intensity, Paint paint) {
    paint.style = PaintingStyle.fill;
    paint.color = Colors.black;

    if (intensity > 0.95) {
      // Level 4: Solid Black (Severe)
      canvas.drawRect(rect, paint);
    } else if (intensity > 0.75) {
      // Level 3: Dense Grid (High Moderate)
      final step = rect.width / 3;
      for (double x = rect.left + step / 2; x < rect.right; x += step) {
        for (double y = rect.top + step / 2; y < rect.bottom; y += step) {
          canvas.drawCircle(Offset(x, y), 1.2, paint);
        }
      }
    } else if (intensity > 0.55) {
      // Level 2: Sparse Grid (Moderate)
      final step = rect.width / 2;
      for (double x = rect.left + step / 2; x <= rect.right; x += step) {
        for (double y = rect.top + step / 2; y <= rect.bottom; y += step) {
          canvas.drawCircle(Offset(x, y), 1.0, paint);
        }
      }
    } else if (intensity > 0.45) {
      // Level 1: Cross '+' (Low Moderate / Mild)
      final center = rect.center;
      final size = rect.width * 0.6;
      paint.strokeWidth = 0.8;
      canvas.drawLine(
        Offset(center.dx - size / 2, center.dy),
        Offset(center.dx + size / 2, center.dy),
        paint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - size / 2),
        Offset(center.dx, center.dy + size / 2),
        paint,
      );
    } else {
      // Level 0: Tiny Center Dot (Normal/Mild)
      canvas.drawCircle(rect.center, 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A unified painter that draws discrete Humphrey-style symbols.
class _HumphreyStylePainter extends CustomPainter {
  final List<Stimulus> stimuli;
  final bool isPatternDeviation;

  _HumphreyStylePainter({
    required this.stimuli,
    required this.isPatternDeviation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;

    for (final stimulus in stimuli) {
      final position = Offset(
        stimulus.position.dx * size.width,
        stimulus.position.dy * size.height,
      );

      // Clamp position to ensure no overflow
      final clampedPos = Offset(
        position.dx.clamp(5, size.width - 5),
        position.dy.clamp(5, size.height - 5),
      );

      if (!stimulus.isDetected) {
        // Severe: Large solid black square
        canvas.drawRect(
          Rect.fromCenter(center: clampedPos, width: 7, height: 7),
          paint,
        );
      } else {
        final intensity = stimulus.intensity;

        if (intensity < 0.4) {
          // Normal: Tiny dot
          canvas.drawCircle(clampedPos, 1, paint);
        } else if (intensity < 0.6) {
          // Mild Deviation: Open square with dot
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 0.8;
          canvas.drawRect(
            Rect.fromCenter(center: clampedPos, width: 4, height: 4),
            paint,
          );
          paint.style = PaintingStyle.fill;
          canvas.drawCircle(clampedPos, 0.5, paint);
        } else if (intensity < 0.8) {
          // Moderate Deviation: Gray square
          paint.style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromCenter(center: clampedPos, width: 5, height: 5),
            Paint()..color = Colors.black.withValues(alpha: 0.5),
          );
        } else {
          // Significant Deviation: Darker square
          canvas.drawRect(
            Rect.fromCenter(center: clampedPos, width: 6, height: 6),
            Paint()..color = Colors.black.withValues(alpha: 0.8),
          );
        }
      }
    }

    // Fixation point
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PatternDeviationGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

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

    // Draw central ring as seen in reference image
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
