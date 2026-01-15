import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Direction selector widget for Tumbling E test
class DirectionSelector extends StatelessWidget {
  final Function(int) onDirectionSelected;

  const DirectionSelector({super.key, required this.onDirectionSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDirectionButton(0, 'Upward'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDirectionButton(270, 'Left'),
            const SizedBox(width: 40),
            _buildDirectionButton(90, 'Right'),
          ],
        ),
        const SizedBox(height: 12),
        _buildDirectionButton(180, 'Down'),
      ],
    );
  }

  Widget _buildDirectionButton(int rotation, String label) {
    return ElevatedButton(
      onPressed: () => onDirectionSelected(rotation),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary.withOpacity(0.2),
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(100, 50),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
