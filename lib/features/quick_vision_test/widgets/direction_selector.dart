import 'package:flutter/material.dart';

/// Direction selector widget for Tumbling E test
class DirectionSelector extends StatelessWidget {
  final Function(int) onDirectionSelected;

  const DirectionSelector({
    super.key,
    required this.onDirectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDirectionButton(0, Icons.arrow_upward),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDirectionButton(270, Icons.arrow_back),
            const SizedBox(width: 80),
            _buildDirectionButton(90, Icons.arrow_forward),
          ],
        ),
        _buildDirectionButton(180, Icons.arrow_downward),
      ],
    );
  }

  Widget _buildDirectionButton(int rotation, IconData icon) {
    return IconButton(
      onPressed: () => onDirectionSelected(rotation),
      icon: Icon(icon, size: 48),
      style: IconButton.styleFrom(
        backgroundColor: Colors.blue.shade100,
        padding: const EdgeInsets.all(20),
      ),
    );
  }
}
