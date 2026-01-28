import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_colors.dart';

/// Screen showing all individual test options
class IndividualTestsScreen extends StatelessWidget {
  const IndividualTestsScreen({super.key});

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a Vision Test',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose from our comprehensive vision screening tests',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTestsGrid(context, constraints),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTestsGrid(BuildContext context, BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardSpacing = (constraints.maxWidth * 0.035).clamp(10.0, 16.0);

    return Column(
      children: [
        // Add Patient Card (for receptionists in eye camp workflow)
        _AddPatientCard(
          onTap: () =>
              Navigator.pushNamed(context, '/add-patient-questionnaire'),
          screenWidth: screenWidth,
        ),
        SizedBox(height: cardSpacing * 1.5),
        // Divider with text
        Row(
          children: [
            Expanded(
              child: Divider(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Vision Tests',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ],
        ),
        SizedBox(height: cardSpacing),
        _IndividualTestCard(
          icon: Icons.visibility_outlined,
          title: 'Visual Acuity',
          description:
              'Test how clearly you can see at distance using standard eye chart',
          onTap: () => _handleTestSelection(context, 'visual_acuity'),
          screenWidth: screenWidth,
        ),
        SizedBox(height: cardSpacing),
        _IndividualTestCard(
          icon: Icons.palette_outlined,
          title: 'Color Vision',
          description: 'Screen for color blindness and red-green deficiencies',
          onTap: () => _handleTestSelection(context, 'color_vision'),
          screenWidth: screenWidth,
        ),
        SizedBox(height: cardSpacing),
        _IndividualTestCard(
          icon: Icons.grid_4x4_outlined,
          title: 'Amsler Grid',
          description: 'Check for central vision distortions and blind spots',
          onTap: () => _handleTestSelection(context, 'amsler_grid'),
          screenWidth: screenWidth,
        ),
        SizedBox(height: cardSpacing),
        _IndividualTestCard(
          icon: Icons.menu_book_outlined,
          title: 'Reading Test',
          description:
              'Assess your near vision and reading ability at close distance',
          onTap: () => _handleTestSelection(context, 'reading_test'),
          screenWidth: screenWidth,
        ),
        SizedBox(height: cardSpacing),
        _IndividualTestCard(
          icon: Icons.contrast_outlined,
          title: 'Contrast Sensitivity',
          description:
              'Measure ability to distinguish objects in different lighting conditions',
          onTap: () => _handleTestSelection(context, 'contrast_sensitivity'),
          screenWidth: screenWidth,
        ),
        SizedBox(height: cardSpacing),
        _IndividualTestCard(
          icon: Icons.remove_red_eye_rounded,
          title: 'Mobile Refractometry',
          description:
              'Detect refractive errors and estimate prescription strength',
          onTap: () => _handleTestSelection(context, 'mobile_refractometry'),
          screenWidth: screenWidth,
        ),
      ],
    );
  }

  Future<void> _handleTestSelection(
    BuildContext context,
    String testType,
  ) async {
    final authService = AuthService();
    final role = await authService.getCurrentUserRole();

    if (!context.mounted) return;

    if (role == UserRole.examiner) {
      Navigator.pushNamed(
        context,
        '/practitioner-profile-selection',
        arguments: {'testType': testType},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/profile-selection',
        arguments: {'testType': testType},
      );
    }
  }
}

class _IndividualTestCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final double screenWidth;

  const _IndividualTestCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final availableWidth = cardConstraints.maxWidth;
        final iconSize = (availableWidth * 0.055).clamp(24.0, 30.0);
        final titleFontSize = (availableWidth * 0.042).clamp(14.0, 17.0);
        final descriptionFontSize = (availableWidth * 0.032).clamp(10.0, 12.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: AppColors.primary.withOpacity(0.1),
            highlightColor: AppColors.primary.withOpacity(0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primaryLight.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (availableWidth * 0.04).clamp(12.0, 18.0),
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: iconSize + 14,
                      height: iconSize + 14,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primary,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: (availableWidth * 0.03).clamp(12.0, 16.0)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: titleFontSize,
                              color: AppColors.primary,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: descriptionFontSize,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: (availableWidth * 0.02).clamp(8.0, 12.0)),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: (availableWidth * 0.038).clamp(16.0, 20.0),
                        color: AppColors.primary,
                      ),
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

/// Special card for adding a new patient with pre-test questions
/// Used primarily for eye camp workflow where receptionists add patients
class _AddPatientCard extends StatelessWidget {
  final VoidCallback onTap;
  final double screenWidth;

  const _AddPatientCard({required this.onTap, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final iconContainerSize = (availableWidth * 0.11).clamp(42.0, 56.0);
        final iconSize = (iconContainerSize * 0.52).clamp(20.0, 28.0);
        final titleFontSize = (availableWidth * 0.040).clamp(14.0, 18.0);
        final descriptionFontSize = (availableWidth * 0.030).clamp(11.0, 14.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(
                (availableWidth * 0.04).clamp(14.0, 20.0),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withValues(alpha: 0.15),
                    AppColors.success.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success,
                          AppColors.success.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        iconContainerSize * 0.35,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: (availableWidth * 0.03).clamp(12.0, 16.0)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Patient',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: titleFontSize,
                            color: AppColors.success,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Register a new patient with pre-test questionnaire',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: descriptionFontSize,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: (availableWidth * 0.02).clamp(8.0, 12.0)),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: (availableWidth * 0.038).clamp(16.0, 20.0),
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
