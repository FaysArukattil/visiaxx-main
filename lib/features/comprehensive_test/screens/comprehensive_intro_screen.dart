import 'package:flutter/material.dart';

/// Introduction screen for comprehensive test
class ComprehensiveIntroScreen extends StatelessWidget {
  const ComprehensiveIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprehensive Eye Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprehensive Vision Assessment',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'This comprehensive test includes:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            _buildTestComponent(
              context,
              icon: Icons.quiz,
              title: 'Health Questionnaire',
              description: 'Answer questions about your eye health history',
              duration: '5 min',
            ),
            _buildTestComponent(
              context,
              icon: Icons.visibility,
              title: 'Visual Acuity Tests',
              description: 'Detailed assessment of your vision clarity',
              duration: '10 min',
            ),
            _buildTestComponent(
              context,
              icon: Icons.contrast,
              title: 'Pelli-Robson Contrast Test',
              description: 'Measure your contrast sensitivity',
              duration: '5 min',
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.amber.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Total duration: approximately 20 minutes',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/questionnaire');
                },
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Begin Assessment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestComponent(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String duration,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
