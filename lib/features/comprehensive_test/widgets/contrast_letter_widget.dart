import 'package:flutter/material.dart';

/// Contrast letter widget for displaying letters with varying contrast
class ContrastLetterWidget extends StatelessWidget {
  final String letter;
  final double contrastLevel; // 0.0 to 1.0

  const ContrastLetterWidget({
    super.key,
    required this.letter,
    required this.contrastLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      letter,
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.black.withValues(alpha: contrastLevel.clamp(0.0, 1.0)),
      ),
    );
  }
}
