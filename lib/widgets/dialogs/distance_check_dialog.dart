import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Distance check dialog to ensure proper viewing distance
class DistanceCheckDialog extends StatelessWidget {
  final double recommendedDistance; // in cm

  const DistanceCheckDialog({super.key, this.recommendedDistance = 40.0});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.straighten, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Viewing Distance'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For accurate results, maintain a viewing distance of approximately ${recommendedDistance.toInt()} cm from the screen.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.primary.withValues(alpha: 0.05),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips for proper distance:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('â€¢ Sit comfortably with your back straight'),
                  Text('â€¢ Keep the screen at eye level'),
                  Text('â€¢ Ensure good lighting in the room'),
                  Text('â€¢ Remove any glare from the screen'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can use a ruler or measuring tape to verify the distance.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('I\'m Ready'),
        ),
      ],
    );
  }
}

