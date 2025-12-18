import 'package:flutter/material.dart';

/// Comprehensive test result screen
class ComprehensiveResultScreen extends StatelessWidget {
  const ComprehensiveResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprehensive Results'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprehensive Assessment Results',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildResultSection(
                    context,
                    title: 'Visual Acuity',
                    results: ['Right Eye: 20/25', 'Left Eye: 20/30'],
                    status: 'Good',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildResultSection(
                    context,
                    title: 'Contrast Sensitivity',
                    results: ['Score: 1.65 log units'],
                    status: 'Normal',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildResultSection(
                    context,
                    title: 'Color Vision',
                    results: ['Ishihara Test: 5/5'],
                    status: 'Normal',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medical_services, color: Colors.blue),
                              SizedBox(width: 12),
                              Text(
                                'Recommendations',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text('• Continue regular eye examinations annually'),
                          SizedBox(height: 8),
                          Text('• Maintain good lighting when reading'),
                          SizedBox(height: 8),
                          Text(
                            '• Consider consulting an optometrist for prescription update',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf),
                          SizedBox(width: 8),
                          Text('Download PDF'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Done'),
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

  Widget _buildResultSection(
    BuildContext context, {
    required String title,
    required List<String> results,
    required String status,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
