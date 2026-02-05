import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../data/models/mobile_refractometry_result.dart';
import '../../../data/models/refraction_prescription_model.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/refraction_prescription_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/models/user_model.dart';
import '../../practitioner/widgets/refraction_table_widgets.dart';

class MobileRefractometryQuickResultScreen extends StatefulWidget {
  const MobileRefractometryQuickResultScreen({super.key});

  @override
  State<MobileRefractometryQuickResultScreen> createState() =>
      _MobileRefractometryQuickResultScreenState();
}

class _MobileRefractometryQuickResultScreenState
    extends State<MobileRefractometryQuickResultScreen> {
  final RefractionPrescriptionService _refractionService =
      RefractionPrescriptionService();
  final AuthService _authService = AuthService();

  UserRole? _userRole;
  RefractionPrescriptionModel? _prescription;
  bool _includeInResults = true;
  bool _isSaving = false;
  bool _isSaved = false;
  bool _rightEyeVerified = false;
  bool _leftEyeVerified = false;
  bool _finalVerified = false;
  Timer? _saveTimer;
  int _patientAge = 30; // Default age, updated from provider

  @override
  void initState() {
    super.initState();
    _initializeAge();
    _checkUserRole();
  }

  void _initializeAge() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TestSessionProvider>();
      setState(() {
        _patientAge = provider.profileAge ?? 30;
      });
    });
  }

  Future<void> _checkUserRole() async {
    final role = await _authService.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });

      // Load prescription for ALL users (read-only for normal users)
      await _loadExistingPrescription();

      // Only initialize new prescription for examiners
      if (role == UserRole.examiner && _prescription == null) {
        _initializePrescription();
      }
    }
  }

  Future<void> _loadExistingPrescription() async {
    final provider = context.read<TestSessionProvider>();
    final testResultId = provider.currentTestId;
    final currentUser = _authService.currentUser;

    if (testResultId != null && currentUser != null) {
      try {
        final existingPrescription = await _refractionService.getPrescription(
          currentUser.uid,
          testResultId,
        );

        if (existingPrescription != null && mounted) {
          setState(() {
            _prescription = existingPrescription;
            _includeInResults = existingPrescription.includeInResults;
          });
        }
      } catch (e) {
        debugPrint('[QuickResult] Error loading prescription: $e');
      }
    }
  }

  void _initializePrescription() {
    final provider = context.read<TestSessionProvider>();
    final result = provider.mobileRefractometry;
    if (result != null) {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _authService.getUserData(currentUser.uid).then((user) {
          if (mounted && user != null) {
            setState(() {
              _prescription = _refractionService.createInitialPrescription(
                result,
                user.id,
                user.fullName,
              );
            });
          }
        });
      }
    }
  }

  void _onRightEyeChanged(SubjectiveRefractionData data) {
    if (_prescription != null) {
      setState(() {
        _prescription = _prescription!.copyWith(
          rightEyeSubjective: data,
          finalPrescription: _prescription!.finalPrescription.copyWith(
            right: data,
          ),
          hasManualEdits: true,
        );
        _isSaved = false;
      });
      _debouncedSave();
    }
  }

  void _onLeftEyeChanged(SubjectiveRefractionData data) {
    if (_prescription != null) {
      setState(() {
        _prescription = _prescription!.copyWith(
          leftEyeSubjective: data,
          finalPrescription: _prescription!.finalPrescription.copyWith(
            left: data,
          ),
          hasManualEdits: true,
        );
        _isSaved = false;
      });
      _debouncedSave();
    }
  }

  void _onFinalPrescriptionChanged(FinalPrescriptionData data) {
    if (_prescription != null) {
      setState(() {
        _prescription = _prescription!.copyWith(
          finalPrescription: data,
          hasManualEdits: true,
        );
        _isSaved = false;
      });
      _debouncedSave();
    }
  }

  void _onRightEyeVerified(bool verified) {
    if (_rightEyeVerified != verified) {
      setState(() => _rightEyeVerified = verified);
    }
  }

  void _onLeftEyeVerified(bool verified) {
    if (_leftEyeVerified != verified) {
      setState(() => _leftEyeVerified = verified);
    }
  }

  void _onFinalVerified(bool verified) {
    if (_finalVerified != verified) {
      setState(() => _finalVerified = verified);
    }
  }

  void _debouncedSave() {
    if (!_includeInResults) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      _savePrescription(true);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _savePrescription(bool include) async {
    if (_prescription == null) return;

    setState(() {
      _isSaving = true;
      _includeInResults = include;
    });

    try {
      final currentUser = _authService.currentUser;
      final provider = context.read<TestSessionProvider>();
      final testResultId = provider.currentTestId;

      if (currentUser != null && testResultId != null) {
        // Update prescription with accuracy metrics
        final updatedPrescription = _refractionService
            .updateWithManualEdits(
              _prescription!,
              _prescription!.rightEyeSubjective,
              _prescription!.leftEyeSubjective,
            )
            .copyWith(includeInResults: _includeInResults);

        await _refractionService.savePrescriptionToFirebase(
          currentUser.uid,
          testResultId,
          updatedPrescription,
        );

        if (mounted) {
          context.read<TestSessionProvider>().setRefractionPrescription(
            updatedPrescription,
          );

          setState(() {
            _isSaving = false;
            _isSaved = true;
            _prescription = updatedPrescription;
          });

          SnackbarUtils.showSuccess(context, 'Prescription saved successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        SnackbarUtils.showError(context, 'Error saving prescription: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    final result = provider.mobileRefractometry;

    if (result == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.error),
              const SizedBox(height: 16),
              const Text('No result data found'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => NavigationUtils.navigateHome(context),
                child: const Text('Return Home'),
              ),
            ],
          ),
        ),
      );
    }

    final overallStatus = _getOverallStatus(result, context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final provider = context.read<TestSessionProvider>();
            return TestExitConfirmationDialog(
              onContinue: () {
                // Just close the dialog
              },
              onRestart: () {
                context.read<TestSessionProvider>().resetKeepProfile();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/mobile-refractometry-test',
                  (route) => false,
                );
              },
              onExit: () {
                NavigationUtils.navigateHome(context);
              },
              hasCompletedTests: provider.hasAnyCompletedTest,
              onSaveAndExit: provider.hasAnyCompletedTest
                  ? () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/comprehensive-test-result',
                      );
                    }
                  : null,
            );
          },
        );
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Refractometry Result'),
          backgroundColor: context.scaffoldBackground,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _buildStatusHeader(overallStatus),
                    const SizedBox(height: 16),
                    if (result.rightEye != null)
                      _buildEyeCard('Right', result.rightEye!, context.primary),
                    if (result.leftEye != null) ...[
                      const SizedBox(height: 12),
                      _buildEyeCard('Left', result.leftEye!, context.success),
                    ],
                    const SizedBox(height: 16),
                    _buildClinicalInsights(result),
                    // Lens recommendations based on age
                    const SizedBox(height: 16),
                    _buildLensRecommendation(),
                    // Professional consultation advice
                    const SizedBox(height: 16),
                    _buildProfessionalAdvice(),
                    // Show prescription to ALL users if it exists and is included in results
                    if (_prescription != null &&
                        _prescription!.includeInResults) ...[
                      const SizedBox(height: 16),
                      _userRole == UserRole.examiner
                          ? _buildPractitionerPrescriptionSection(result)
                          : _buildReadOnlyPrescriptionSection(result),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Sticky Bottom Button Area
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildActionButtons(context, result),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(Map<String, dynamic> statusInfo) {
    final Color color = statusInfo['color'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(statusInfo['icon'], color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            statusInfo['label'],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            'Refraction Screening Complete',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeCard(
    String side,
    MobileRefractometryEyeResult res,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEyeLabel(side, accentColor),
              _buildAccuracyBadge(res.accuracy, accentColor),
            ],
          ),
          const SizedBox(height: 16),
          _buildRefractionGrid(res),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildInterpretation(res, accentColor, context),
        ],
      ),
    );
  }

  Widget _buildEyeLabel(String side, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_red_eye_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            side.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyBadge(String accuracy, Color color) {
    final double accValue = double.tryParse(accuracy) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${accValue.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          'CONSISTENCY',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRefractionGrid(MobileRefractometryEyeResult res) {
    final showAdd =
        _patientAge >= 40 &&
        double.tryParse(res.addPower) != null &&
        double.parse(res.addPower) > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildValueItem('SPHERE', res.sphere, 'Distance'),
        _buildValueItem('CYLINDER', res.cylinder, 'Focus'),
        _buildValueItem('AXIS', '${res.axis}°', 'Angle'),
        if (showAdd)
          _buildValueItem(
            'READING',
            '+${res.addPower.replaceFirst(RegExp(r'^\++'), '')}',
            'Add Power',
          ),
      ],
    );
  }

  Widget _buildValueItem(String label, String value, String subLabel) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: context.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subLabel,
            style: TextStyle(
              fontSize: 9,
              color: context.textSecondary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretation(
    MobileRefractometryEyeResult res,
    Color color,
    BuildContext context,
  ) {
    final interpretation = _getInterpretationDetails(res);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(interpretation['icon'], size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              interpretation['condition'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          interpretation['description'],
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalInsights(MobileRefractometryResult result) {
    if (result.healthWarnings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: context.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Professional Insights',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: context.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.healthWarnings.join('. '),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds lens recommendation based on patient age
  Widget _buildLensRecommendation() {
    final bool isPresbyopic = _patientAge >= 40;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.primary.withValues(alpha: 0.08),
            context.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: context.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lens Recommendation',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: context.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isPresbyopic) ...[
            // 40+ years: Progressive or Bifocal
            _buildLensOption(
              icon: Icons.gradient_rounded,
              title: 'Progressive Lenses',
              subtitle: 'Recommended - seamless vision at all distances',
              isRecommended: true,
            ),
            const SizedBox(height: 12),
            _buildLensOption(
              icon: Icons.view_agenda_rounded,
              title: 'Bifocal Lenses',
              subtitle: 'Alternative if progressive lenses are not convenient',
              isRecommended: false,
            ),
          ] else ...[
            // Under 40: Single Vision
            _buildLensOption(
              icon: Icons.lens_rounded,
              title: 'Single Vision Lenses',
              subtitle: 'Optimal for your age group',
              isRecommended: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLensOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isRecommended,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRecommended
            ? context.success.withValues(alpha: 0.08)
            : context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended
              ? context.success.withValues(alpha: 0.3)
              : context.dividerColor.withValues(alpha: 0.3),
          width: isRecommended ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRecommended
                  ? context.success.withValues(alpha: 0.15)
                  : context.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isRecommended ? context.success : context.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ADVISABLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds professional consultation advice section
  Widget _buildProfessionalAdvice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_services_rounded,
                color: context.info,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Professional Consultation',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAdviceItem(
            icon: Icons.storefront_rounded,
            text: 'Please refer to an optician for glasses',
          ),
          const SizedBox(height: 10),
          _buildAdviceItem(
            icon: Icons.health_and_safety_rounded,
            text:
                'Consult an eye doctor or optometrist for a more detailed eye checkup',
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.info),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: context.textPrimary,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    MobileRefractometryResult result,
  ) {
    final bool isRightEyeRequired = result.rightEye != null;
    final bool isLeftEyeRequired = result.leftEye != null;

    bool isBlocked = false;
    // ONLY block examiners/practitioners if they haven't verified tables.
    // Patients/Normal users (UserRole.user) should NOT be blocked by verification.
    if (_userRole == UserRole.examiner && _includeInResults) {
      if (isRightEyeRequired && !_rightEyeVerified) isBlocked = true;
      if (isLeftEyeRequired && !_leftEyeVerified) isBlocked = true;
      if (!_finalVerified) isBlocked = true;
    }

    return Column(
      children: [
        if (isBlocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: context.warning, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Verify all tables to enable results',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isBlocked
                  ? [context.dividerColor, context.dividerColor]
                  : [context.primary, context.primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isBlocked
                ? []
                : [
                    BoxShadow(
                      color: context.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: ElevatedButton(
            onPressed: isBlocked
                ? null
                : () async {
                    final navigator = Navigator.of(context);
                    await _savePrescription(true);
                    navigator.pushReplacementNamed('/quick-test-result');
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.transparent,
              shadowColor: AppColors.transparent,
              disabledBackgroundColor: AppColors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'View Detailed Results',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isBlocked ? context.textSecondary : context.surface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyPrescriptionSection(MobileRefractometryResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verified Prescription Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Verified by: ${_prescription!.practitionerName}',
          style: TextStyle(
            fontSize: 12,
            color: context.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // SUBJECTIVE REFRACTION (VERIFIED BY PRACTITIONER)
        Text(
          'Subjective Refraction (Verified)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (result.rightEye != null)
          _buildReadOnlyRefractionTable(
            'Right Eye',
            _prescription!.rightEyeSubjective,
            context.primary,
          ),
        const SizedBox(height: 16),
        if (result.leftEye != null)
          _buildReadOnlyRefractionTable(
            'Left Eye',
            _prescription!.leftEyeSubjective,
            context.success,
          ),

        const SizedBox(height: 24),

        // FINAL PRESCRIPTION
        Text(
          'Final Prescription (Rx)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildFinalPrescriptionTable(_prescription!.finalPrescription),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: context.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This prescription has been verified by ${_prescription!.practitionerName}. Take this to your optometrist for glasses fitting.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyRefractionTable(
    String title,
    SubjectiveRefractionData data,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  children: [
                    _buildTableHeader('SPH'),
                    _buildTableHeader('CYL'),
                    _buildTableHeader('AXIS'),
                    _buildTableHeader('VN'),
                  ],
                ),
                TableRow(
                  children: [
                    _buildTableValue(data.sph),
                    _buildTableValue(data.cyl),
                    _buildTableValue(data.axis),
                    _buildTableValue(data.vn),
                  ],
                ),
                if (data.add != '0.00' && data.add.isNotEmpty) ...[
                  TableRow(
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      _buildTableHeader('ADD'),
                      const SizedBox(),
                      const SizedBox(),
                      const SizedBox(),
                    ],
                  ),
                  TableRow(
                    children: [
                      _buildTableValue(data.add),
                      const SizedBox(),
                      const SizedBox(),
                      const SizedBox(),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPrescriptionTable(FinalPrescriptionData data) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment, size: 16, color: context.primary),
                const SizedBox(width: 8),
                Text(
                  'Prescription for Glasses',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(0.8),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  children: [
                    _buildTableHeader('EYE'),
                    _buildTableHeader('SPH'),
                    _buildTableHeader('CYL'),
                    _buildTableHeader('AXIS'),
                    _buildTableHeader('VN'),
                  ],
                ),
                TableRow(
                  children: [
                    _buildTableHeader('Right', isEyeLabel: true),
                    _buildTableValue(data.right.sph),
                    _buildTableValue(data.right.cyl),
                    _buildTableValue(data.right.axis),
                    _buildTableValue(data.right.vn),
                  ],
                ),
                TableRow(
                  children: [
                    _buildTableHeader('Left', isEyeLabel: true),
                    _buildTableValue(data.left.sph),
                    _buildTableValue(data.left.cyl),
                    _buildTableValue(data.left.axis),
                    _buildTableValue(data.left.vn),
                  ],
                ),
                if (data.right.add != '0.00' || data.left.add != '0.00') ...[
                  TableRow(
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      _buildTableHeader('ADD'),
                      _buildTableValue(data.right.add),
                      _buildTableValue(data.left.add),
                      const SizedBox(),
                      const SizedBox(),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {bool isEyeLabel = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isEyeLabel ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: isEyeLabel ? context.primary : context.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTableValue(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
    );
  }

  Widget _buildPractitionerPrescriptionSection(
    MobileRefractometryResult result,
  ) {
    final shouldShowAdd = _patientAge >= 40;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prescription Details (Suggested)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review and verify prescription details',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Save Prescription',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                if (_isSaved && !_isSaving)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.check_circle,
                      color: context.success,
                      size: 18,
                    ),
                  ),
                Checkbox(
                  value: _includeInResults,
                  activeColor: context.primary,
                  onChanged: (val) {
                    _savePrescription(val ?? true);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _includeInResults
                ? context.warning.withValues(alpha: 0.1)
                : context.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _includeInResults
                  ? context.warning.withValues(alpha: 0.2)
                  : context.dividerColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _includeInResults
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: _includeInResults
                    ? context.warning
                    : context.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _includeInResults
                      ? 'Mandatory Verification: Please verify all values (accept suggestions or edit) to enable Detailed Results and PDF generation.'
                      : 'Prescription saving is disabled. You can proceed to results without verifying these tables.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _includeInResults
                        ? context.warning
                        : context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (result.rightEye != null)
          RefractionTableWidget(
            title: 'Subjective Refraction - Right Eye',
            initialData: _prescription!.rightEyeSubjective,
            onDataChanged: _onRightEyeChanged,
            onVerifiedChanged: _onRightEyeVerified,
            showAddColumn: shouldShowAdd,
          ),
        if (result.leftEye != null)
          RefractionTableWidget(
            title: 'Subjective Refraction - Left Eye',
            initialData: _prescription!.leftEyeSubjective,
            onDataChanged: _onLeftEyeChanged,
            onVerifiedChanged: _onLeftEyeVerified,
            showAddColumn: shouldShowAdd,
          ),
        FinalPrescriptionTableWidget(
          initialData: _prescription!.finalPrescription,
          onDataChanged: _onFinalPrescriptionChanged,
          onVerifiedChanged: _onFinalVerified,
          showAddColumn: shouldShowAdd,
        ),
        const SizedBox(height: 32),
        if (_isSaved)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: context.success, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'All changes saved to result',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Map<String, dynamic> _getOverallStatus(
    MobileRefractometryResult result,
    BuildContext context,
  ) {
    if (result.criticalAlert) {
      return {
        'label': 'Urgent Care',
        'color': context.error,
        'icon': Icons.emergency_rounded,
      };
    }

    final rSph = double.tryParse(result.rightEye?.sphere ?? '0') ?? 0;
    final lSph = double.tryParse(result.leftEye?.sphere ?? '0') ?? 0;
    final rCyl = double.tryParse(result.rightEye?.cylinder ?? '0') ?? 0;
    final lCyl = double.tryParse(result.leftEye?.cylinder ?? '0') ?? 0;

    // High values or high astigmatism
    if (rSph.abs() > 3.0 ||
        lSph.abs() > 3.0 ||
        rCyl.abs() > 2.0 ||
        lCyl.abs() > 2.0) {
      return {
        'label': 'Review Needed',
        'color': context.warning,
        'icon': Icons.warning_amber_rounded,
      };
    }

    // Check if vision is within "Normal" range (minimal refraction)
    final isNormal =
        rSph.abs() <= 0.25 &&
        lSph.abs() <= 0.25 &&
        rCyl.abs() <= 0.5 &&
        lCyl.abs() <= 0.5;

    if (isNormal) {
      return {
        'label': 'Normal Vision',
        'color': context.success,
        'icon': Icons.check_circle_rounded,
      };
    }

    // Detected some level of refraction (Myopia, Hyperopia, etc.)
    return {
      'label': 'Refraction Detected',
      'color': context.primary,
      'icon': Icons.visibility_outlined,
    };
  }

  Map<String, dynamic> _getInterpretationDetails(
    MobileRefractometryEyeResult res,
  ) {
    final sph = double.tryParse(res.sphere) ?? 0.0;
    final cyl = double.tryParse(res.cylinder) ?? 0.0;

    if (sph < -0.25) {
      return {
        'condition': 'Myopia (Nearsighted)',
        'description':
            'Distance objects may appear blurry. Reading and close work are usually clear.',
        'icon': Icons.remove_red_eye_outlined,
      };
    } else if (sph > 0.25) {
      return {
        'condition': 'Hyperopia (Farsighted)',
        'description':
            'Close objects may cause strain or appear blurry. Distance vision is usually better.',
        'icon': Icons.visibility_outlined,
      };
    } else if (cyl.abs() > 0.5) {
      return {
        'condition': 'Astigmatism',
        'description':
            'Vision may be distorted or blurred at all distances due to irregular eye shape.',
        'icon': Icons.blur_on_rounded,
      };
    }

    return {
      'condition': 'Healthy Refraction',
      'description':
          'No significant refractive issues detected. Light focuses correctly on your retina.',
      'icon': Icons.check_circle_outline_rounded,
    };
  }
}
