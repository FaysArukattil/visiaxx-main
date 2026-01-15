import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Pelli-Robson contrast sensitivity chart widget
class PelliRobsonChart extends StatelessWidget {
  final int rowIndex;
  final Function(String) onLetterRead;

  const PelliRobsonChart({
    super.key,
    required this.rowIndex,
    required this.onLetterRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Read the letters below:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _generateLetters(rowIndex),
          ),
        ],
      ),
    );
  }

  List<Widget> _generateLetters(int row) {
    // Sample letters for demonstration
    final letters = ['R', 'S', 'K'];
    final contrast = 1.0 - (row * 0.15);

    return letters.map((letter) {
      return Text(
        letter,
        style: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: AppColors.black.withOpacity(contrast.clamp(0.1, 1.0)),
        ),
      );
    }).toList();
  }
}
