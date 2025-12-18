import 'package:flutter/material.dart';

/// Pelli-Robson contrast sensitivity test screen
class PelliRobsonTestScreen extends StatefulWidget {
  const PelliRobsonTestScreen({super.key});

  @override
  State<PelliRobsonTestScreen> createState() => _PelliRobsonTestScreenState();
}

class _PelliRobsonTestScreenState extends State<PelliRobsonTestScreen> {
  int _currentRow = 0;
  final int _totalRows = 8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contrast Sensitivity Test')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('1. Read the letters from left to right'),
                    Text('2. Continue until you can no longer see the letters'),
                    Text('3. Maintain consistent viewing distance'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Row ${_currentRow + 1} of $_totalRows',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            // TODO: Add Pelli-Robson chart widget here
            const Expanded(child: Placeholder()),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentRow > 0
                        ? () {
                            setState(() {
                              _currentRow--;
                            });
                          }
                        : null,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Previous'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentRow < _totalRows - 1) {
                        setState(() {
                          _currentRow++;
                        });
                      } else {
                        Navigator.pushNamed(context, '/comprehensive-result');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _currentRow < _totalRows - 1 ? 'Next' : 'Finish',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
