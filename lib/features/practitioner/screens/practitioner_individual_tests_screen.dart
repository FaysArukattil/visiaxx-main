import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/test_session_provider.dart';

/// Screen showing all individual test options with multi-selection capability
class IndividualTestsScreen extends StatefulWidget {
  const IndividualTestsScreen({super.key});

  @override
  State<IndividualTestsScreen> createState() => _IndividualTestsScreenState();
}

class _IndividualTestsScreenState extends State<IndividualTestsScreen> {
  // Track selected tests in order
  final List<String> _selectedTests = [];
  UserRole? _userRole;
  bool _isRoleLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final authService = AuthService();
    final role = await authService.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _isRoleLoading = false;
      });
    }
  }

  void _toggleTestSelection(String testType) {
    setState(() {
      if (_selectedTests.contains(testType)) {
        _selectedTests.remove(testType);
      } else {
        _selectedTests.add(testType);
      }
    });
  }

  void _startSelectedTests() async {
    if (_selectedTests.isEmpty) return;

    List<String> testsToRun = List.from(_selectedTests);

    final authService = AuthService();
    final role = await authService.getCurrentUserRole();

    if (!mounted) return;

    // Start multi-test in provider
    context.read<TestSessionProvider>().startMultiTest(testsToRun);

    if (role == UserRole.examiner) {
      Navigator.pushNamed(
        context,
        '/practitioner-profile-selection',
        arguments: {'multiTest': true},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/profile-selection',
        arguments: {'multiTest': true},
      );
    }
  }

  void _handleBack() {
    if (_selectedTests.isNotEmpty) {
      setState(() => _selectedTests.clear());
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRoleLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: context.scaffoldBackground,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.textPrimary),
            onPressed: _handleBack,
          ),
          title: Text(
            'Individual Tests',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_selectedTests.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _selectedTests.clear()),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth * 0.045,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Vision Tests',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: context.textPrimary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Select a test to start, or press and hold to select multiple tests for a single flow',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildTestsGrid(context, constraints),
                          const SizedBox(
                            height: 100,
                          ), // Space for bottom button
                        ],
                      ),
                    ),
                  ),
                  if (_selectedTests.isNotEmpty)
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: _buildStartButton(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _startSelectedTests(),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Start ${_selectedTests.length} Selected ${_selectedTests.length == 1 ? 'Test' : 'Tests'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.play_arrow_rounded, size: 28),
          ],
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
        if (_userRole == UserRole.examiner) ...[
          _AddPatientCard(
            onTap: () =>
                Navigator.pushNamed(context, '/add-patient-questionnaire'),
            screenWidth: screenWidth,
          ),
          SizedBox(height: cardSpacing * 1.5),
        ],
        // Divider with text
        Row(
          children: [
            Expanded(
              child: Divider(
                color: context.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Vision Tests',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: context.dividerColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        SizedBox(height: cardSpacing),
        _buildTestItem(
          'visual_acuity',
          Icons.visibility_outlined,
          'Visual Acuity',
          'Test how clearly you can see at distance using standard eye chart',
          cardSpacing,
          screenWidth,
        ),
        _buildTestItem(
          'color_vision',
          Icons.palette_outlined,
          'Color Vision',
          'Screen for color blindness and red-green deficiencies',
          cardSpacing,
          screenWidth,
        ),
        _buildTestItem(
          'amsler_grid',
          Icons.grid_4x4_outlined,
          'Amsler Grid',
          'Check for central vision distortions and blind spots',
          cardSpacing,
          screenWidth,
        ),
        _buildTestItem(
          'reading_test',
          Icons.menu_book_outlined,
          'Reading Test',
          'Assess your near vision and reading ability at close distance',
          cardSpacing,
          screenWidth,
        ),
        _buildTestItem(
          'contrast_sensitivity',
          Icons.contrast_outlined,
          'Contrast Sensitivity',
          'Measure ability to distinguish objects in different lighting conditions',
          cardSpacing,
          screenWidth,
        ),
        _buildTestItem(
          'mobile_refractometry',
          Icons.remove_red_eye_rounded,
          'Mobile Refractometry',
          'Detect refractive errors and estimate prescription strength',
          cardSpacing,
          screenWidth,
        ),
        _buildTestItem(
          'eye_hydration',
          Icons.opacity_rounded,
          'Eye Hydration',
          'Screen for blink rate and dry eye symptoms during natural reading',
          cardSpacing,
          screenWidth,
        ),
        if (_userRole == UserRole.examiner) ...[
          _buildTestItem(
            'shadow_test',
            Icons.wb_sunny_outlined,
            'Van Herick Shadow Test',
            'Assess anterior chamber depth and glaucoma risk using shadow analysis',
            cardSpacing,
            screenWidth,
          ),
          _buildTestItem(
            'stereopsis',
            Icons.threed_rotation_rounded,
            'Stereopsis Test',
            'Assess depth perception and binocular vision using 3D anaglyph patterns',
            cardSpacing,
            screenWidth,
          ),
          _buildTestItem(
            'visual_field',
            Icons.track_changes_outlined,
            'Visual Field',
            'Test your peripheral vision sensitivity across four quadrants',
            cardSpacing,
            screenWidth,
          ),
          _buildTestItem(
            'cover_test',
            Icons.visibility_outlined,
            'Cover-Uncover Test',
            'Assess eye alignment and detect strabismus through cover test',
            cardSpacing,
            screenWidth,
          ),
          _buildTestItem(
            'torchlight',
            Icons.highlight_rounded,
            'Torchlight Examination',
            'Check pupil reflexes and extraocular muscle movements using torchlight',
            0, // Last item
            screenWidth,
          ),
        ],
      ],
    );
  }

  Widget _buildTestItem(
    String type,
    IconData icon,
    String title,
    String description,
    double spacing,
    double screenWidth,
  ) {
    final int selectionIndex = _selectedTests.indexOf(type);
    return Column(
      children: [
        _IndividualTestCard(
          icon: icon,
          title: title,
          description: description,
          isSelected: selectionIndex != -1,
          selectionIndex: selectionIndex != -1 ? selectionIndex + 1 : null,
          onTap: () {
            if (_selectedTests.isNotEmpty) {
              _toggleTestSelection(type);
            } else {
              _handleTestSelection(context, type);
            }
          },
          onLongPress: () => _toggleTestSelection(type),
          onCheckboxChanged: (val) => _toggleTestSelection(type),
          screenWidth: screenWidth,
        ),
        if (spacing > 0) SizedBox(height: spacing),
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

    // Start as a single individual test
    context.read<TestSessionProvider>().startIndividualTest(testType);

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
  final bool isSelected;
  final int? selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool?> onCheckboxChanged;
  final double screenWidth;

  const _IndividualTestCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    this.selectionIndex,
    required this.onTap,
    required this.onLongPress,
    required this.onCheckboxChanged,
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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: context.primary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(20),
              splashColor: context.primary.withValues(alpha: 0.1),
              highlightColor: context.primary.withValues(alpha: 0.05),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? [
                            context.primary.withValues(alpha: 0.15),
                            context.primary.withValues(alpha: 0.08),
                          ]
                        : [
                            context.primary.withValues(alpha: 0.08),
                            context.primary.withValues(alpha: 0.03),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? context.primary
                        : context.primary.withValues(alpha: 0.15),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (availableWidth * 0.04).clamp(12.0, 18.0),
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      _buildLeading(context, iconSize),
                      SizedBox(
                        width: (availableWidth * 0.03).clamp(12.0, 16.0),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: titleFontSize,
                                      color: context.primary,
                                      letterSpacing: -0.3,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected && selectionIndex != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '#$selectionIndex',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: descriptionFontSize,
                                color: context.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: (availableWidth * 0.02).clamp(8.0, 12.0)),
                      _buildTrailing(context, availableWidth),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeading(BuildContext context, double iconSize) {
    if (isSelected) {
      return Container(
        width: iconSize + 14,
        height: iconSize + 14,
        decoration: BoxDecoration(
          color: context.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
      );
    }
    return Container(
      width: iconSize + 14,
      height: iconSize + 14,
      decoration: BoxDecoration(
        color: context.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: context.primary, size: iconSize),
    );
  }

  Widget _buildTrailing(BuildContext context, double availableWidth) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isSelected
            ? context.primary.withValues(alpha: 0.2)
            : context.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isSelected ? Icons.check_box_rounded : Icons.arrow_forward_rounded,
        size: (availableWidth * 0.038).clamp(16.0, 20.0),
        color: context.primary,
      ),
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
                    context.success.withValues(alpha: 0.15),
                    context.success.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.success.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.success.withValues(alpha: 0.08),
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
                          context.success,
                          context.success.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        iconContainerSize * 0.35,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.success.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: iconSize,
                      color: AppColors.white,
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
                            color: context.success,
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
                            color: context.textSecondary,
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
                      color: context.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: (availableWidth * 0.038).clamp(16.0, 20.0),
                      color: context.success,
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
