import 'package:flutter/material.dart';

/// Calibration dialog for screen calibration
class CalibrationDialog extends StatefulWidget {
  const CalibrationDialog({super.key});

  @override
  State<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog> {
  final double _creditCardWidth = 85.6; // Standard credit card width in mm
  double _screenWidth = 150.0; // Default screen width in mm

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Screen Calibration'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To ensure accurate test results, please calibrate your screen:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Place a credit card on the rectangle below',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '2. Adjust the slider until the rectangle matches the card size',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: _creditCardWidth * (_screenWidth / 85.6),
                height: 54 * (_screenWidth / 85.6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Credit Card Size',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _screenWidth,
              min: 100,
              max: 200,
              divisions: 100,
              label: '${_screenWidth.toStringAsFixed(1)} mm',
              onChanged: (value) {
                setState(() {
                  _screenWidth = value;
                });
              },
            ),
            Center(
              child: Text(
                'Screen Width: ${_screenWidth.toStringAsFixed(1)} mm',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _screenWidth);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
