import 'package:flutter/material.dart';

/// Introduction screen for quick vision test
class QuickTestIntroScreen extends StatelessWidget {
  const QuickTestIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Vision Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Vision Screening',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildInstructionCard(
              context,
              icon: Icons.visibility,
              title: 'Visual Acuity Test',
              description: 'Test your ability to see fine details',
            ),
            const SizedBox(height: 16),
            _buildInstructionCard(
              context,
              icon: Icons.palette,
              title: 'Color Vision Test',
              description: 'Screen for color vision deficiencies',
            ),
            const SizedBox(height: 16),
            _buildInstructionCard(
              context,
              icon: Icons.grid_on,
              title: 'Amsler Grid Test',
              description: 'Check for macular degeneration',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/visual-acuity-test');
                },
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Start Test'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
      ),
    );
  }
}
