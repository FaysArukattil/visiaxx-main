import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PractitionerIndividualTestsScreen extends StatelessWidget {
  const PractitionerIndividualTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Individual Tests',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.045,
                  vertical: 16,
                ),
                child: _buildTestsGrid(context, constraints),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTestsGrid(BuildContext context, BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = (constraints.maxHeight * 0.18).clamp(100.0, 130.0);
    final cardSpacing = (constraints.maxWidth * 0.035).clamp(10.0, 16.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _IndividualTestCard(
                icon: Icons.visibility_outlined,
                title: 'Visual Acuity',
                color: AppColors.primary,
                onTap: () =>
                    _navigateToPatientSelection(context, 'visual_acuity'),
                height: cardHeight,
                screenWidth: screenWidth,
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _IndividualTestCard(
                icon: Icons.palette_outlined,
                title: 'Color Vision',
                color: const Color(0xFFE91E63),
                onTap: () =>
                    _navigateToPatientSelection(context, 'color_vision'),
                height: cardHeight,
                screenWidth: screenWidth,
              ),
            ),
          ],
        ),
        SizedBox(height: cardSpacing),
        Row(
          children: [
            Expanded(
              child: _IndividualTestCard(
                icon: Icons.grid_4x4_outlined,
                title: 'Amsler Grid',
                color: const Color(0xFF00BCD4),
                onTap: () =>
                    _navigateToPatientSelection(context, 'amsler_grid'),
                height: cardHeight,
                screenWidth: screenWidth,
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _IndividualTestCard(
                icon: Icons.menu_book_outlined,
                title: 'Reading Test',
                color: const Color(0xFF4CAF50),
                onTap: () =>
                    _navigateToPatientSelection(context, 'reading_test'),
                height: cardHeight,
                screenWidth: screenWidth,
              ),
            ),
          ],
        ),
        SizedBox(height: cardSpacing),
        Row(
          children: [
            Expanded(
              child: _IndividualTestCard(
                icon: Icons.contrast_outlined,
                title: 'Contrast',
                color: const Color(0xFFFF9800),
                onTap: () => _navigateToPatientSelection(
                  context,
                  'contrast_sensitivity',
                ),
                height: cardHeight,
                screenWidth: screenWidth,
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _IndividualTestCard(
                icon: Icons.remove_red_eye_rounded,
                title: 'Refractometry',
                color: const Color(0xFF9C27B0),
                onTap: () => _navigateToPatientSelection(
                  context,
                  'mobile_refractometry',
                ),
                height: cardHeight,
                screenWidth: screenWidth,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToPatientSelection(BuildContext context, String testType) {
    Navigator.pushNamed(
      context,
      '/practitioner-profile-selection',
      arguments: {'testType': testType},
    );
  }
}

class _IndividualTestCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final double height;
  final double screenWidth;

  const _IndividualTestCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    required this.height,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final availableWidth = cardConstraints.maxWidth;
        final iconSize = (availableWidth * 0.18).clamp(28.0, 36.0);
        final titleFontSize = (availableWidth * 0.08).clamp(13.0, 16.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: color.withOpacity(0.1),
            highlightColor: color.withOpacity(0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.08), color.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                height: height,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: iconSize + 14,
                      height: iconSize + 14,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: iconSize),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: titleFontSize,
                        color: color,
                        height: 1.1,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
