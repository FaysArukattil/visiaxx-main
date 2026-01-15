import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Screen showing all individual test options
class IndividualTestsScreen extends StatelessWidget {
  const IndividualTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Individual Tests'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a Test',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take individual tests and get instant results',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _IndividualTestCard(
              icon: Icons.visibility_outlined,
              title: 'Visual Acuity',
              subtitle: 'Distance vision test',
              color: AppColors.primary,
              onTap: () {
                Navigator.pushNamed(context, '/visual-acuity-standalone');
              },
            ),
            const SizedBox(height: 16),
            _IndividualTestCard(
              icon: Icons.palette_outlined,
              title: 'Color Vision',
              subtitle: 'Ishihara plates test',
              color: const Color(0xFFE91E63),
              onTap: () {
                Navigator.pushNamed(context, '/color-vision-standalone');
              },
            ),
            const SizedBox(height: 16),
            _IndividualTestCard(
              icon: Icons.grid_4x4_outlined,
              title: 'Amsler Grid',
              subtitle: 'Macular health test',
              color: const Color(0xFF00BCD4),
              onTap: () {
                Navigator.pushNamed(context, '/amsler-grid-standalone');
              },
            ),
            const SizedBox(height: 16),
            _IndividualTestCard(
              icon: Icons.menu_book_outlined,
              title: 'Reading Test',
              subtitle: 'Near vision assessment',
              color: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.pushNamed(context, '/reading-test-standalone');
              },
            ),
            const SizedBox(height: 16),
            _IndividualTestCard(
              icon: Icons.contrast_outlined,
              title: 'Contrast Sensitivity',
              subtitle: 'Pelli-Robson test',
              color: const Color(0xFFFF9800),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/contrast-sensitivity-standalone',
                );
              },
            ),
            const SizedBox(height: 16),
            _IndividualTestCard(
              icon: Icons.remove_red_eye_rounded,
              title: 'Mobile Refractometry',
              subtitle: 'Prescription detection',
              color: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/mobile-refractometry-standalone',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IndividualTestCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _IndividualTestCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
