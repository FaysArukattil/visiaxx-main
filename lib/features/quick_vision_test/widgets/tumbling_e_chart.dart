import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget displaying Tumbling E chart for visual acuity testing
class TumblingEChart extends StatelessWidget {
  final double fontSize;
  final int rotation; // 0, 90, 180, 270 degrees

  const TumblingEChart({
    super.key,
    required this.fontSize,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: Text(
        'E',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
