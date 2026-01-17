import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:visiaxx/core/providers/network_connectivity_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/eye_loader.dart';
import 'package:visiaxx/core/constants/app_colors.dart';
import 'package:visiaxx/core/services/review_service.dart';
import 'package:visiaxx/core/services/test_result_service.dart';
import 'package:visiaxx/core/services/pdf_export_service.dart';
import 'package:visiaxx/core/utils/ui_utils.dart';
import 'package:visiaxx/core/utils/snackbar_utils.dart';
import 'package:visiaxx/core/utils/navigation_utils.dart';
import 'package:visiaxx/core/widgets/test_exit_confirmation_dialog.dart';
import 'package:visiaxx/core/widgets/download_success_dialog.dart';
import 'package:visiaxx/data/models/test_result_model.dart';
import 'package:visiaxx/data/providers/test_session_provider.dart';
import 'package:visiaxx/data/models/color_vision_result.dart';
import 'package:visiaxx/data/models/pelli_robson_result.dart';
import 'package:visiaxx/data/models/mobile_refractometry_result.dart';
import 'package:visiaxx/data/models/refraction_prescription_model.dart';
import 'package:visiaxx/features/home/widgets/review_dialog.dart';

/// Comprehensive results screen displaying all test data
class QuickTestResultScreen extends StatefulWidget {
  final TestResultModel? historicalResult;
  const QuickTestResultScreen({super.key, this.historicalResult});

  @override
  State<QuickTestResultScreen> createState() => _QuickTestResultScreenState();
}

class _QuickTestResultScreenState extends State<QuickTestResultScreen> {
  final PdfExportService _pdfExportService = PdfExportService();
  final TestResultService _testResultService = TestResultService();

  bool _hasSaved = false;
  TestResultModel? _savedResult;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    // Only save results to Firebase if this is a new test (just completed)
    if (widget.historicalResult == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _saveResultsToFirebase(),
      );
    } else {
      _hasSaved = true;
      _savedResult = widget.historicalResult;
    }
  }

  Future<void> _saveResultsToFirebase() async {
    if (_hasSaved) return;

    final user = FirebaseAuth.instance.currentUser;
    debugPrint('[QuickTestResult] Current user: ${user?.uid}');

    if (user == null) {
      debugPrint(
        '[QuickTestResult] ERROR: No user logged in, cannot save results',
      );
      return;
    }

    try {
      final provider = context.read<TestSessionProvider>();
      final result = provider.buildTestResult(user.uid);

      // DEBUG: Check if prescription is in the result
      debugPrint(
        '[QuickTestResult] 🔍 Prescription in result: ${result.refractionPrescription != null}',
      );
      if (result.refractionPrescription != null) {
        debugPrint(
          '[QuickTestResult] 📋 Prescription includeInResults: ${result.refractionPrescription!.includeInResults}',
        );
        debugPrint(
          '[QuickTestResult] 👨‍⚕️ Practitioner: ${result.refractionPrescription!.practitionerName}',
        );
      }

      final connectivity = Provider.of<NetworkConnectivityProvider>(
        context,
        listen: false,
      );

      // 1. Generate local PDF (ALWAYS do this, even offline)
      debugPrint('[QuickTestResult] Generating local PDF for report...');
      final String pdfPath = await _pdfExportService.generateAndDownloadPdf(
        result,
      );
      final File pdfFile = File(pdfPath);

      if (!connectivity.isOnline) {
        debugPrint(
          '[QuickTestResult] 📶 Device is OFFLINE. Saving locally and queuing sync...',
        );

        // Save offline using the service which handles queuing internally
        final offlineId = await _testResultService.saveResultOffline(
          userId: user.uid,
          result: result,
          connectivity: connectivity,
          pdfFile: pdfFile,
        );

        if (mounted) {
          setState(() {
            _hasSaved = true;
            _savedResult = result.copyWith(id: offlineId);
          });
          SnackbarUtils.showInfo(
            context,
            'Saved locally. Results will upload automatically when online.',
          );
          await _checkAndShowReviewDialog();
        }
        return;
      }

      // 2. Online path: Save result and trigger background AWS upload
      debugPrint('[QuickTestResult] Triggering background save...');
      final resultId = await _testResultService.saveTestResult(
        userId: user.uid,
        result: result,
        pdfFile: pdfFile,
      );

      debugPrint(
        '[QuickTestResult] ✅ Result saved successfully with ID: $resultId',
      );

      if (mounted) {
        setState(() {
          _hasSaved = true;
          _savedResult = result.copyWith(id: resultId);
        });

        SnackbarUtils.showSuccess(
          context,
          'Results & Report saved successfully!',
        );

        await _checkAndShowReviewDialog();
      }
    } catch (e) {
      debugPrint('[QuickTestResult] ❌ ERROR saving results: $e');

      if (mounted) {
        // Show error message
        SnackbarUtils.showError(context, 'Failed to save results: $e');
      }
    }
  }

  Future<void> _checkAndShowReviewDialog() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final reviewService = ReviewService();

      // Check if user already reviewed
      final hasReviewed = await reviewService.hasUserReviewed(user.uid);
      if (hasReviewed) {
        debugPrint('[QuickTestResult] User already reviewed, skipping dialog');
        return;
      }

      // Check if this is first test
      final isFirst = await reviewService.isFirstTest(user.uid);
      if (!isFirst) {
        debugPrint('[QuickTestResult] Not first test, skipping review dialog');
        return;
      }

      // Mark first test as completed
      await reviewService.markFirstTestCompleted(user.uid);

      // Show review dialog after a short delay
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.transparent,
            isDismissible: false,
            builder: (context) => const ReviewDialog(),
          );
        }
      }
    } catch (e) {
      debugPrint('[QuickTestResult] Error checking review dialog: $e');
    }
  }

  Future<void> _navigateHome() async {
    await NavigationUtils.navigateHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    final isHistorical = widget.historicalResult != null;

    // Use historical data if available, otherwise use current session data
    final overallStatus = isHistorical
        ? widget.historicalResult!.overallStatus
        : provider.getOverallStatus();
    final timestamp = isHistorical
        ? widget.historicalResult!.timestamp
        : DateTime.now();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isHistorical) {
          Navigator.pop(context);
        } else {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => TestExitConfirmationDialog(
              onContinue: () {
                // Just close the dialog
              },
              onRestart: () {
                provider.reset();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/quick-test',
                  (route) => false,
                );
              },
              onExit: () async {
                await _navigateHome();
                if (mounted) {
                  provider.reset();
                }
              },
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Results'),
          automaticallyImplyLeading: isHistorical,
          actions: [
            if (!isHistorical)
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: () {
                  // Navigate away FIRST, then reset provider to avoid showing null data
                  _navigateHome().then((_) => provider.reset());
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overall status header
                    _buildStatusHeader(overallStatus, timestamp),
                    const SizedBox(height: 20),

                    // Patient info card
                    _buildPatientInfoCard(provider),
                    const SizedBox(height: 20),

                    // Visual Acuity Results
                    if (_hasVAData(provider)) ...[
                      _buildSectionTitle('Visual Acuity', Icons.visibility),
                      _buildVisualAcuityCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Short Distance Results
                    if (_hasShortDistanceData(provider)) ...[
                      _buildSectionTitle(
                        'Reading Test (Near Vision)',
                        Icons.text_fields,
                      ),
                      _buildShortDistanceCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Color Vision Results
                    if (_hasColorVisionData(provider)) ...[
                      _buildSectionTitle('Color Vision', Icons.palette),
                      _buildColorVisionCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Amsler Grid Results
                    if (_hasAmslerData(provider)) ...[
                      _buildSectionTitle('Amsler Grid', Icons.grid_on),
                      _buildAmslerGridCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Pelli-Robson Contrast Sensitivity Results
                    if (_hasPelliRobsonResults(provider)) ...[
                      _buildSectionTitle(
                        'Contrast Sensitivity',
                        Icons.contrast,
                      ),
                      _buildPelliRobsonCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Mobile Refractometry Results
                    if (_hasRefractometryResults(provider)) ...[
                      _buildSectionTitle(
                        'Mobile Refractometry',
                        Icons.phone_android_rounded,
                      ),
                      _buildRefractometryCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Verified Prescription Results
                    if (_hasPrescription(provider)) ...[
                      _buildSectionTitle(
                        'Verified Prescription',
                        Icons.assignment_turned_in_rounded,
                      ),
                      _buildPrescriptionCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Recommendation
                    _buildRecommendationCard(provider),
                    const SizedBox(height: 32),

                    // Action buttons
                    _buildDisclaimer(),
                    const SizedBox(height: 32), // ⚡ Spacing after disclaimer
                    _buildActionButtons(provider),
                    const SizedBox(height: 80), // ⚡ Fixes bottom overflow
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(TestStatus status, DateTime timestamp) {
    Color primaryColor;
    Color secondaryColor;
    Color textColor;
    IconData statusIcon;

    switch (status) {
      case TestStatus.normal:
        primaryColor = AppColors.success;
        secondaryColor = AppColors.successDark;
        textColor = AppColors.textOnPrimary;
        statusIcon = Icons.check_circle_rounded;
        break;
      case TestStatus.review:
        primaryColor = AppColors.warning;
        secondaryColor = AppColors.warningDark;
        textColor = AppColors.textOnPrimary;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case TestStatus.urgent:
        primaryColor = AppColors.error;
        secondaryColor = AppColors.errorDark;
        textColor = AppColors.textOnPrimary;
        statusIcon = Icons.error_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(24), // ⚡ Now rounded
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon with background circle
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white.withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(statusIcon, size: 52, color: textColor),
          ),
          const SizedBox(height: 24),
          Text(
            '${status.emoji} ${status.label}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: textColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    DateFormat('MMM dd, yyyy • h:mm a').format(timestamp),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard(TestSessionProvider provider) {
    String name;
    int? age;
    String? sex;
    String testDate;
    bool isFamily = false;

    if (widget.historicalResult != null) {
      name = widget.historicalResult!.profileName.isEmpty
          ? (provider.profileName.isEmpty ? 'User' : provider.profileName)
          : widget.historicalResult!.profileName;
      testDate = DateFormat(
        'MMM dd, yyyy • h:mm a',
      ).format(widget.historicalResult!.timestamp);
      isFamily = widget.historicalResult!.profileType == 'family';
    } else {
      final familyMember = provider.selectedFamilyMember;
      name =
          familyMember?.firstName ??
          (provider.profileName.isEmpty ? 'User' : provider.profileName);
      age = familyMember?.age;
      sex = familyMember?.sex;
      testDate = DateFormat('MMM dd, yyyy • h:mm a').format(DateTime.now());
      isFamily = familyMember != null;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white, // ⚡ Pure white
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04), // ⚡ Neutal shadow
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: 0.1,
                  ), // ⚡ Soft background
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.transparent,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900, // ⚡ Stronger weight
                      color: AppColors.primary, // ⚡ Use primary color
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (age != null || sex != null)
                      Text(
                        [
                          if (age != null) '$age years',
                          if (sex != null) sex,
                        ].join(' • '),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isFamily ? AppColors.info : AppColors.primary)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100), // ⚡ Pill shape
                ),
                child: Text(
                  isFamily ? 'Family Member' : 'Primary Account',
                  style: TextStyle(
                    color: isFamily ? AppColors.info : AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Test Date
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                testDate,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualAcuityCard(TestSessionProvider provider) {
    final rightResult =
        widget.historicalResult?.visualAcuityRight ??
        provider.visualAcuityRight;
    final leftResult =
        widget.historicalResult?.visualAcuityLeft ?? provider.visualAcuityLeft;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Eyes comparison
          Row(
            children: [
              Expanded(
                child: _buildEyeResult(
                  'Right Eye',
                  rightResult?.snellenScore ?? 'N/A',
                  rightResult?.status ?? 'N/A',
                  AppColors.primary,
                ),
              ),
              Container(
                width: 1.5,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.divider.withValues(alpha: 0.1),
                      AppColors.divider,
                      AppColors.divider.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildEyeResult(
                  'Left Eye',
                  leftResult?.snellenScore ?? 'N/A',
                  leftResult?.status ?? 'N/A',
                  AppColors.secondary,
                ),
              ),
            ],
          ),
          const Divider(height: 48, thickness: 1),
          // Clinical Interpretation
          _buildClinicalInfoSection(
            'Clinical Interpretation',
            _getAcuityClinicalExplanation(
              rightResult?.snellenScore,
              leftResult?.snellenScore,
            ),
          ),
          const SizedBox(height: 16),
          // Accuracy stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Responses',
                '${(rightResult?.totalResponses ?? 0) + (leftResult?.totalResponses ?? 0)}',
              ),
              _buildStatItem(
                'Correct',
                '${(rightResult?.correctResponses ?? 0) + (leftResult?.correctResponses ?? 0)}',
              ),
              _buildStatItem(
                'Duration',
                '${(rightResult?.durationSeconds ?? 0) + (leftResult?.durationSeconds ?? 0)}s',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalInfoSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Text(
            description,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  String _getAcuityClinicalExplanation(String? right, String? left) {
    if (right == null && left == null) return 'N/A';

    final best = (right != null && right != 'Worse than 6/60') ? right : left;
    if (best == '6/6') {
      return 'Excellent. You see at 6 meters what a normal eye sees at 6 meters (20/20 equivalent).';
    }
    if (best == '6/9') {
      return 'Good. You see at 6 meters what a normal eye sees at 9 meters.';
    }
    if (best == '6/12') {
      return 'Mild reduction. You see at 6 meters what a normal eye sees at 12 meters.';
    }
    if (best == 'Worse than 6/60') {
      return 'Significant reduction. Vision is below the standard screening range.';
    }

    return 'Your visual acuity represents the clarity of your vision at a distance compared to a standard eye.';
  }

  Widget _buildEyeResult(String eye, String score, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility, color: color, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  eye,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              score,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              status,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorVisionCard(TestSessionProvider provider) {
    final result = widget.historicalResult?.colorVision ?? provider.colorVision;
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.grey.withValues(alpha: 0.1)),
        ),
        child: const Center(
          child: Text(
            'No color vision data available',
            style: TextStyle(
              color: AppColors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final isNormal = result.isNormal;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Eyes comparison
          Row(
            children: [
              Expanded(
                child: _buildColorEyeResult(
                  'Right Eye',
                  result.rightEye,
                  const Color(0xFF8B5CF6), // Violet
                ),
              ),
              Container(
                width: 1.5,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.grey.withValues(alpha: 0.1),
                      AppColors.grey.withValues(alpha: 0.3),
                      AppColors.grey.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildColorEyeResult(
                  'Left Eye',
                  result.leftEye,
                  const Color(0xFFEC4899), // Pink
                ),
              ),
            ],
          ),
          const Divider(height: 48, thickness: 1),
          // Clinical Interpretation
          _buildClinicalInfoSection(
            'Clinical Finding',
            _getColorVisionExplanation(result.deficiencyType, result.severity),
          ),
          const SizedBox(height: 16),
          // Recommendation if not normal
          if (!isNormal)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.recommendation,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorEyeResult(
    String eyeLabel,
    ColorVisionEyeResult eyeResult,
    Color color,
  ) {
    final isNormal = eyeResult.status == ColorVisionStatus.normal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.palette, color: color, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  eyeLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${eyeResult.correctAnswers}/${eyeResult.totalDiagnosticPlates}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              eyeResult.status.displayName,
              style: TextStyle(
                fontSize: 12,
                color: isNormal ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getColorVisionExplanation(
    DeficiencyType? type,
    DeficiencySeverity? severity,
  ) {
    if (type == null || type == DeficiencyType.none) {
      return 'Normal color vision.';
    }

    String typeStr = type.toString().split('.').last.toUpperCase();
    String sevStr =
        severity?.toString().split('.').last.toLowerCase() ?? 'unknown';

    if (type == DeficiencyType.protan) {
      return 'Protanopia/Protanomaly ($sevStr) detected. This is a red-color deficiency where the long-wavelength sensitive cones are missing or abnormal.';
    }
    if (type == DeficiencyType.deutan) {
      return 'Deuteranopia/Deuteranomaly ($sevStr) detected. This is a green-color deficiency, the most common type of red-green color blindness.';
    }

    return '$typeStr deficiency ($sevStr) detected. Ishihara plates screening indicates reduced sensitivity to specific color spectrums.';
  }

  Widget _buildAmslerGridCard(TestSessionProvider provider) {
    final rightResult =
        widget.historicalResult?.amslerGridRight ?? provider.amslerGridRight;
    final leftResult =
        widget.historicalResult?.amslerGridLeft ?? provider.amslerGridLeft;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAmslerEyeResult(
                  'Right Eye',
                  rightResult,
                  const Color(0xFF3B82F6),
                ),
              ),
              Container(
                width: 1.5,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.grey.withValues(alpha: 0.1),
                      AppColors.grey.withValues(alpha: 0.3),
                      AppColors.grey.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildAmslerEyeResult(
                  'Left Eye',
                  leftResult,
                  const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const Divider(height: 48, thickness: 1),
          _buildAmslerLegend(),
          if ((rightResult?.hasDistortions ?? false) ||
              (leftResult?.hasDistortions ?? false)) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_off_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Clinical Findings',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The markings indicate potential metamorphosis (wavy lines) or scotoma (missing spots). This often signals physical changes in the macula. Please consult an eye care professional.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmslerLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marking Legend:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem('Wavy', AppColors.error),
            _buildLegendItem('Missing', AppColors.warning),
            _buildLegendItem('Blurry', AppColors.info),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ========== PELLI-ROBSON CONTRAST SENSITIVITY ==========

  bool _hasPelliRobsonResults(TestSessionProvider provider) {
    return widget.historicalResult?.pelliRobson != null ||
        provider.pelliRobson != null;
  }

  Widget _buildPelliRobsonCard(TestSessionProvider provider) {
    final result = widget.historicalResult?.pelliRobson ?? provider.pelliRobson;

    if (result == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textTertiary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall category header
          _buildPelliRobsonOverallHeader(result),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),

          // Per-eye results
          if (result.rightEye != null)
            () {
              final re = result.rightEye!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEyeSectionTitle('Right Eye'),
                  const SizedBox(height: 8),
                  _buildPelliRobsonEyeResults(re),
                  const SizedBox(height: 24),
                ],
              );
            }(),
          if (result.leftEye != null)
            () {
              final le = result.leftEye!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEyeSectionTitle('Left Eye'),
                  const SizedBox(height: 8),
                  _buildPelliRobsonEyeResults(le),
                  const SizedBox(height: 24),
                ],
              );
            }(),

          // Explanation
          _buildPelliRobsonExplanation(result.userSummary),
        ],
      ),
    );
  }

  Widget _buildPelliRobsonExplanation(String summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'What This Means',
                style: TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildPelliRobsonEyeResults(PelliRobsonEyeResult eyeResult) {
    final near = eyeResult.shortDistance;
    final dist = eyeResult.longDistance;
    return Column(
      children: [
        if (near != null)
          _buildPelliRobsonDistanceResult(
            'Near Vision (40cm)',
            near,
            Icons.smartphone,
          ),
        if (near != null && dist != null) const SizedBox(height: 12),
        if (dist != null)
          _buildPelliRobsonDistanceResult(
            'Distance Vision (1m)',
            dist,
            Icons.visibility,
          ),
      ],
    );
  }

  Widget _buildPelliRobsonOverallHeader(PelliRobsonResult result) {
    Color categoryColor;
    IconData categoryIcon;

    switch (result.overallCategory) {
      case 'Excellent':
        categoryColor = AppColors.success;
        categoryIcon = Icons.star;
        break;
      case 'Normal':
        categoryColor = AppColors.info;
        categoryIcon = Icons.check_circle;
        break;
      case 'Borderline':
        categoryColor = AppColors.warning;
        categoryIcon = Icons.warning_amber;
        break;
      case 'Reduced':
      default:
        categoryColor = AppColors.error;
        categoryIcon = Icons.error;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(categoryIcon, color: categoryColor, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contrast Sensitivity',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                result.overallCategory,
                style: TextStyle(
                  color: categoryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Average score badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${result.averageScore.toStringAsFixed(2)} log CS',
            style: TextStyle(
              color: categoryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPelliRobsonDistanceResult(
    String label,
    PelliRobsonSingleResult result,
    IconData icon,
  ) {
    Color categoryColor;

    switch (result.category) {
      case 'Excellent':
        categoryColor = AppColors.success;
        break;
      case 'Normal':
        categoryColor = AppColors.info;
        break;
      case 'Borderline':
        categoryColor = AppColors.warning;
        break;
      case 'Reduced':
      default:
        categoryColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last correct triplet: ${result.lastFullTriplet.isNotEmpty ? result.lastFullTriplet : 'N/A'}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.category,
                  style: TextStyle(
                    color: categoryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${result.adjustedScore.toStringAsFixed(2)} log CS',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Very light slate
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.gavel_rounded,
              color: AppColors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEDICAL DISCLAIMER',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'This vision screening tool does not provide medical diagnosis. It is intended for early detection support. Always visit a licensed ophthalmologist for a comprehensive eye exam and medical advice.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    height: 1.5,
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

  Widget _buildAmslerEyeResult(String eye, dynamic result, Color color) {
    final isNormal = result?.isNormal ?? true;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_on, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              eye,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isNormal
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isNormal ? 'Normal' : 'Review',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isNormal ? AppColors.success : AppColors.warning,
            ),
          ),
        ),
        if (result != null && !isNormal) ...[
          const SizedBox(height: 8),
          Text(
            '${result.distortionPoints.length} area(s) marked',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
        if (result != null)
          () {
            final String? path = result.annotatedImagePath;
            final String? url = result.firebaseImageUrl;

            if (path == null && url == null) return const SizedBox.shrink();

            return Column(
              children: [
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: path != null && !path.startsWith('http')
                        ? Image.file(
                            File(path),
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              if (url != null) {
                                return Image.network(
                                  url,
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) =>
                                      const SizedBox.shrink(),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          )
                        : Image.network(
                            path ?? url!,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                  ),
                ),
              ],
            );
          }(),
      ],
    );
  }

  Widget _buildRecommendationCard(TestSessionProvider provider) {
    final status =
        widget.historicalResult?.overallStatus ?? provider.getOverallStatus();

    Color baseColor = const Color(0xFF10B981);
    IconData icon = Icons.health_and_safety_rounded;
    String title = 'Medical Consultation Advice';

    switch (status) {
      case TestStatus.normal:
        baseColor = const Color(0xFF10B981);
        icon = Icons.health_and_safety_rounded;
        break;
      case TestStatus.review:
        baseColor = const Color(0xFFF59E0B);
        icon = Icons.healing_rounded;
        break;
      case TestStatus.urgent:
        baseColor = const Color(0xFFEF4444);
        icon = Icons.emergency_rounded;
        title = 'Urgent Consultation Required';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: baseColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: baseColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: baseColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Based on your screening results',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.historicalResult?.recommendation ??
                  provider.getRecommendation(),
              style: TextStyle(
                color: AppColors.textPrimary,
                height: 1.6,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(TestSessionProvider provider) {
    return Column(
      children: [
        // Primary action - Download PDF
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)], // Premium blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : _generatePdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.transparent,
              foregroundColor: AppColors.white,
              shadowColor: AppColors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _isGeneratingPdf
                ? const EyeLoader(size: 20)
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(
              _isGeneratingPdf ? 'Generating Report...' : 'Download PDF Report',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Start Full Eye Exam (Continue action)
        ElevatedButton.icon(
          onPressed: () {
            provider.reset();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/comprehensive-test',
              (route) => false,
            );
          },
          icon: const Icon(Icons.assessment_rounded),
          label: const Text('Start Full Eye Exam'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Restart Current Test
        OutlinedButton.icon(
          onPressed: () {
            provider.reset();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/quick-test',
              (route) => false,
            );
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Restart Test'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.warning,
            minimumSize: const Size(double.infinity, 54),
            side: const BorderSide(color: AppColors.warning, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Sharing Row
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                onPressed: _isGeneratingPdf
                    ? null
                    : () {
                        final user = FirebaseAuth.instance.currentUser;
                        final result =
                            widget.historicalResult ??
                            _savedResult ??
                            provider.buildTestResult(user?.uid ?? '');
                        _sharePdfReport(result);
                      },
                icon: Icons.ios_share_rounded,
                label: 'Share',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/my-results');
                },
                icon: Icons.history_rounded,
                label: 'History',
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Back to Home
        ElevatedButton.icon(
          onPressed: () {
            _navigateHome().then((_) => provider.reset());
          },
          icon: const Icon(Icons.home_rounded),
          label: const Text('Back to Home'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.grey.withValues(alpha: 0.1),
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _shareGridTracing was unused and has been removed as PDF sharing is prioritized.

  Future<void> _generatePdf() async {
    final provider = context.read<TestSessionProvider>();
    final user = FirebaseAuth.instance.currentUser;

    setState(() => _isGeneratingPdf = true);

    try {
      final result =
          widget.historicalResult ??
          _savedResult ??
          provider.buildTestResult(user?.uid ?? '');

      // Check if file already exists
      final String filePath = await _pdfExportService.getExpectedFilePath(
        result,
      );
      final File file = File(filePath);

      if (await file.exists()) {
        if (mounted) {
          setState(() => _isGeneratingPdf = false);
          await showDownloadSuccessDialog(context: context, filePath: filePath);
        }
        return;
      }

      if (!mounted) return;
      UIUtils.showProgressDialog(
        context: context,
        message: 'Generating PDF...',
      );

      final String generatedPath = await _pdfExportService
          .generateAndDownloadPdf(result);

      if (!mounted) return;
      UIUtils.hideProgressDialog(context);

      // Show beautiful success dialog
      await showDownloadSuccessDialog(
        context: context,
        filePath: generatedPath,
      );
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        SnackbarUtils.showError(context, 'Failed to generate PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _sharePdfReport(TestResultModel result) async {
    try {
      UIUtils.showProgressDialog(context: context, message: 'Preparing PDF...');

      final String filePath = await _pdfExportService.generateAndDownloadPdf(
        result,
      );

      if (mounted) {
        UIUtils.hideProgressDialog(context);
      }
      await Share.shareXFiles([XFile(filePath)], text: 'Vision Test Report');
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        SnackbarUtils.showError(context, 'Failed to share PDF report');
      }
    }
  }

  Widget _buildShortDistanceCard(TestSessionProvider provider) {
    final result =
        widget.historicalResult?.shortDistance ?? provider.shortDistance;

    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.grey.withValues(alpha: 0.1)),
        ),
        child: const Center(
          child: Text(
            'No reading test data available',
            style: TextStyle(
              color: AppColors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final isGood = result.averageSimilarity >= 70.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Status icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isGood ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGood ? Icons.auto_stories_rounded : Icons.menu_book_rounded,
                  color: isGood ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.status,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: isGood ? AppColors.success : AppColors.warning,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Best Acuity: ${result.bestAcuity}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Score display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${result.averageSimilarity.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Match',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress bar
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double width =
                      constraints.maxWidth *
                      (result.correctSentences / result.totalSentences);
                  return Container(
                    height: 10,
                    width: width,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success.withValues(alpha: 0.7),
                          AppColors.success,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildNewStatItem(
                  'Sentences',
                  '${result.correctSentences}/${result.totalSentences}',
                  Icons.text_format_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.border.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _buildNewStatItem(
                  'Accuracy',
                  '${(result.accuracy * 100).toStringAsFixed(0)}%',
                  Icons.track_changes_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ========== MOBILE REFRACTOMETRY ==========

  bool _hasRefractometryResults(TestSessionProvider provider) {
    return widget.historicalResult?.mobileRefractometry != null ||
        provider.mobileRefractometry != null;
  }

  Widget _buildRefractometryCard(TestSessionProvider provider) {
    final result =
        widget.historicalResult?.mobileRefractometry ??
        provider.mobileRefractometry;
    if (result == null) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical Stacking of Eyes
              if (result.rightEye != null)
                _buildRefractometryEyeBlock(
                  'Right Eye',
                  result.rightEye!,
                  AppColors.primary,
                  provider,
                ),
              if (result.rightEye != null && result.leftEye != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Divider(height: 1),
                ),
              if (result.leftEye != null)
                _buildRefractometryEyeBlock(
                  'Left Eye',
                  result.leftEye!,
                  AppColors.secondary,
                  provider,
                ),
            ],
          ),
        ),

        if (result.healthWarnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Clinical Observations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  result.healthWarnings.join('. '),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRefractometryEyeBlock(
    String label,
    MobileRefractometryEyeResult res,
    Color color,
    TestSessionProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEnhancedRefractionEye(label, res, color, provider),
        const SizedBox(height: 20),
        _buildLaymanEyeInterpretation(label, res, color),
      ],
    );
  }

  Widget _buildEnhancedRefractionEye(
    String label,
    MobileRefractometryEyeResult? res,
    Color color,
    TestSessionProvider provider,
  ) {
    if (res == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${double.parse(res.accuracy).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Accuracy',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Table(
          children: [
            TableRow(
              children: [
                _buildValueCell('SPH', res.sphere, 'Sphere'),
                _buildValueCell('CYL', res.cylinder, 'Cylinder'),
                _buildValueCell('AXIS', '${res.axis}°', 'Axis'),
                if (provider.profileAge != null &&
                    provider.profileAge! >= 40 &&
                    double.tryParse(res.addPower) != null &&
                    double.parse(res.addPower) > 0)
                  _buildValueCell(
                    'ADD',
                    '+${res.addPower.replaceFirst(RegExp(r'^\++'), '')}',
                    'Reading',
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueCell(String label, String value, String fullName) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Text(
          fullName,
          style: TextStyle(
            fontSize: 8,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLaymanEyeInterpretation(
    String eyeLabel,
    MobileRefractometryEyeResult res,
    Color color,
  ) {
    final sph = double.tryParse(res.sphere) ?? 0.0;
    final cyl = double.tryParse(res.cylinder) ?? 0.0;
    final add = double.tryParse(res.addPower) ?? 0.0;

    String condition = 'Healthy Vision';
    String reduction = '';
    String description = 'This eye shows no significant refractive issues.';
    List<String> symptoms = [];

    final sphAbs = sph.abs();
    final cylAbs = cyl.abs();

    if (sph < -0.25) {
      String level = sphAbs > 6.0
          ? 'High'
          : (sphAbs > 3.0 ? 'Moderate' : 'Low');
      condition = '$level Myopia';
      description = 'Distance objects may appear blurry or out of focus.';
      symptoms.add('Difficulty seeing distant street signs or screens.');
    } else if (sph > 0.25) {
      String level = sphAbs > 6.0
          ? 'High'
          : (sphAbs > 3.0 ? 'Moderate' : 'Low');
      condition = '$level Hyperopia';
      description =
          'May experience blurriness or strain during close-up tasks.';
      symptoms.add('Eye strain during reading or phone use.');
    }

    if (cylAbs > 0.25) {
      String level = cylAbs > 1.0 ? 'Significant' : 'Mild';
      if (condition == 'Healthy Vision') {
        condition = '$level Astigmatism';
        description =
            'Vision may be distorted at all distances due to eye shape.';
      } else {
        condition += ' with Astigmatism';
      }
      symptoms.add('Vision appearing stretched or light "smearing".');
    }

    // Vision Reduction Logic
    final maxError = math.max(sphAbs, cylAbs);
    if (maxError > 6.0) {
      reduction = 'Heavy reduction';
    } else if (maxError > 3.0) {
      reduction = 'Moderate reduction';
    } else if (maxError > 0.25) {
      reduction = 'Slight reduction';
    }

    if (add > 0.25) {
      symptoms.add('Need to hold reading material further away (Presbyopia).');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:
                (condition == 'Healthy Vision'
                        ? AppColors.success
                        : AppColors.primary)
                    .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  (condition == 'Healthy Vision'
                          ? AppColors.success
                          : AppColors.primary)
                      .withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                condition == 'Healthy Vision'
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: condition == 'Healthy Vision'
                    ? AppColors.success
                    : AppColors.primary,
                size: 14,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    condition,
                    style: TextStyle(
                      color: condition == 'Healthy Vision'
                          ? AppColors.successDark
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (reduction.isNotEmpty)
                    Text(
                      reduction,
                      style: TextStyle(
                        color: condition == 'Healthy Vision'
                            ? AppColors.success
                            : AppColors.primary.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
        if (symptoms.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...symptoms.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.arrow_right_alt_rounded,
                      size: 16,
                      color: color.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _hasPrescription(TestSessionProvider provider) {
    final rx =
        widget.historicalResult?.refractionPrescription ??
        provider.refractionPrescription;
    return rx != null && rx.includeInResults;
  }

  Widget _buildPrescriptionCard(TestSessionProvider provider) {
    final rx =
        widget.historicalResult?.refractionPrescription ??
        provider.refractionPrescription;
    if (rx == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Practitioner Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLINICAL PRESCRIPTION',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      'Verified by ${rx.practitionerName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Final Prescription Table
          const Text(
            'Final Prescription',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildPrescriptionDataTable(rx.finalPrescription),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Subjective Refraction Sections
          const Text(
            'Subjective Refraction',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSimpleRefractionBlock(
                  'RIGHT EYE',
                  rx.rightEyeSubjective,
                  AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _buildSimpleRefractionBlock(
                  'LEFT EYE',
                  rx.leftEyeSubjective,
                  AppColors.secondary,
                ),
              ),
            ],
          ),

          if (rx.notes != null && rx.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Clinical Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rx.notes!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrescriptionDataTable(FinalPrescriptionData data) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            // Header
            _buildRxTableHeader(),
            // Right Eye
            _buildRxTableRow('OD (Right)', data.right),
            // Left Eye
            _buildRxTableRow('OS (Left)', data.left),
          ],
        ),
      ),
    );
  }

  TableRow _buildRxTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: AppColors.divider),
      children: [
        _buildRxHeaderCell('EYE'),
        _buildRxHeaderCell('SPH'),
        _buildRxHeaderCell('CYL'),
        _buildRxHeaderCell('AXIS'),
      ],
    );
  }

  Widget _buildRxHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  TableRow _buildRxTableRow(String eye, SubjectiveRefractionData eyeData) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            eye,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        _buildRxValueCell(eyeData.sph),
        _buildRxValueCell(eyeData.cyl),
        _buildRxValueCell(eyeData.axis),
      ],
    );
  }

  Widget _buildRxValueCell(String value) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSimpleRefractionBlock(
    String label,
    SubjectiveRefractionData data,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        _buildRxDetailRow('SPH', data.sph),
        _buildRxDetailRow('CYL', data.cyl),
        _buildRxDetailRow('AXIS', '${data.axis}°'),
        _buildRxDetailRow('VN', data.vn),
      ],
    );
  }

  Widget _buildRxDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasVAData(TestSessionProvider provider) {
    return widget.historicalResult?.visualAcuityRight != null ||
        widget.historicalResult?.visualAcuityLeft != null ||
        provider.visualAcuityRight != null ||
        provider.visualAcuityLeft != null;
  }

  bool _hasShortDistanceData(TestSessionProvider provider) {
    return widget.historicalResult?.shortDistance != null ||
        provider.shortDistance != null;
  }

  bool _hasColorVisionData(TestSessionProvider provider) {
    return widget.historicalResult?.colorVision != null ||
        provider.colorVision != null;
  }

  bool _hasAmslerData(TestSessionProvider provider) {
    return widget.historicalResult?.amslerGridRight != null ||
        widget.historicalResult?.amslerGridLeft != null ||
        provider.amslerGridRight != null ||
        provider.amslerGridLeft != null;
  }
}
