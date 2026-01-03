import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../data/models/pelli_robson_result.dart';

/// Comprehensive results screen displaying all test data
class QuickTestResultScreen extends StatefulWidget {
  final TestResultModel? historicalResult;
  const QuickTestResultScreen({super.key, this.historicalResult});

  @override
  State<QuickTestResultScreen> createState() => _QuickTestResultScreenState();
}

class _QuickTestResultScreenState extends State<QuickTestResultScreen> {
  bool _isGeneratingPdf = false;
  bool _hasSaved = false;
  TestResultModel? _savedResult;

  final TestResultService _testResultService = TestResultService();
  final PdfExportService _pdfExportService = PdfExportService();

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

    setState(() {});

    try {
      final provider = context.read<TestSessionProvider>();
      final result = provider.buildTestResult(user.uid);

      debugPrint('[QuickTestResult] Saving test result for user: ${user.uid}');
      debugPrint('[QuickTestResult] Result data: ${result.toJson()}');

      final resultId = await _testResultService.saveTestResult(
        userId: user.uid,
        result: result,
      );

      debugPrint(
        '[QuickTestResult] ✅ Result saved successfully with ID: $resultId',
      );

      if (mounted) {
        setState(() {
          _hasSaved = true;
          _savedResult = result.copyWith(id: resultId);
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Results saved successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[QuickTestResult] ❌ ERROR saving results: $e');

      if (mounted) {
        setState(() {});

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
          provider.reset();
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
                  provider.reset();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Overall status header
              _buildStatusHeader(overallStatus, timestamp),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Patient info card
                    _buildPatientInfoCard(provider),
                    const SizedBox(height: 20),

                    // Visual Acuity Results
                    _buildSectionTitle('Visual Acuity', Icons.visibility),
                    _buildVisualAcuityCard(provider),
                    const SizedBox(height: 20),

                    // Short Distance Results
                    _buildSectionTitle(
                      'Reading Test (Near Vision)',
                      Icons.text_fields,
                    ),
                    _buildShortDistanceCard(provider),
                    const SizedBox(height: 20),

                    // Color Vision Results
                    _buildSectionTitle('Color Vision', Icons.palette),
                    _buildColorVisionCard(provider),
                    const SizedBox(height: 20),

                    // Amsler Grid Results
                    _buildSectionTitle('Amsler Grid', Icons.grid_on),
                    _buildAmslerGridCard(provider),
                    const SizedBox(height: 20),

                    // Pelli-Robson Contrast Sensitivity Results (if available)
                    if (_hasPelliRobsonResults(provider)) ...[
                      _buildSectionTitle(
                        'Contrast Sensitivity',
                        Icons.contrast,
                      ),
                      _buildPelliRobsonCard(provider),
                      const SizedBox(height: 20),
                    ],

                    // Recommendation
                    _buildRecommendationCard(provider),
                    const SizedBox(height: 24),

                    // Action buttons
                    _buildDisclaimer(),
                    const SizedBox(height: 24),
                    _buildActionButtons(provider),
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
    Color backgroundColor;
    Color textColor;
    IconData statusIcon;

    switch (status) {
      case TestStatus.normal:
        backgroundColor = AppColors.success;
        textColor = Colors.white;
        statusIcon = Icons.check_circle;
        break;
      case TestStatus.review:
        backgroundColor = AppColors.warning;
        textColor = Colors.white;
        statusIcon = Icons.warning;
        break;
      case TestStatus.urgent:
        backgroundColor = AppColors.error;
        textColor = Colors.white;
        statusIcon = Icons.error;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor, backgroundColor.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 64, color: textColor),
          const SizedBox(height: 16),
          Text(
            '${status.emoji} ${status.label}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMMM dd, yyyy • h:mm a').format(timestamp),
            style: TextStyle(color: textColor.withValues(alpha: 0.9)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
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
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isFamily
                      ? AppColors.info.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFamily ? 'Family' : 'Self',
                  style: TextStyle(
                    color: isFamily ? AppColors.info : AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  testDate,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  AppColors.rightEye,
                ),
              ),
              Container(width: 1, height: 80, color: AppColors.border),
              Expanded(
                child: _buildEyeResult(
                  'Left Eye',
                  leftResult?.snellenScore ?? 'N/A',
                  leftResult?.status ?? 'N/A',
                  AppColors.leftEye,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
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
    if (best == '6/6')
      return 'Excellent. You see at 6 meters what a normal eye sees at 6 meters (20/20 equivalent).';
    if (best == '6/9')
      return 'Good. You see at 6 meters what a normal eye sees at 9 meters.';
    if (best == '6/12')
      return 'Mild reduction. You see at 6 meters what a normal eye sees at 12 meters.';
    if (best == 'Worse than 6/60')
      return 'Significant reduction. Vision is below the standard screening range.';

    return 'Your visual acuity represents the clarity of your vision at a distance compared to a standard eye.';
  }

  Widget _buildEyeResult(String eye, String score, String status, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              eye,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            score,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildColorVisionCard(TestSessionProvider provider) {
    final result = widget.historicalResult?.colorVision ?? provider.colorVision;
    final isNormal = result?.isNormal ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: isNormal
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNormal ? Icons.check : Icons.warning,
                  color: isNormal ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result?.status ?? 'Normal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isNormal ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result?.status ?? 'Color vision appears normal',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Score bar
          Row(
            children: [
              Expanded(
                flex: result?.correctAnswers ?? 0,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if ((result?.correctAnswers ?? 0) < (result?.totalPlates ?? 0))
                Expanded(
                  flex:
                      (result?.totalPlates ?? 0) -
                      (result?.correctAnswers ?? 0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${result?.correctAnswers ?? 0}/${result?.totalPlates ?? 0} plates correct',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (!isNormal) ...[
            const Divider(height: 24),
            _buildClinicalInfoSection(
              'Detailed Finding',
              _getColorVisionExplanation(
                result?.deficiencyType,
                result?.severity,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getColorVisionExplanation(
    DeficiencyType? type,
    DeficiencySeverity? severity,
  ) {
    if (type == null || type == DeficiencyType.none)
      return 'Normal color vision.';

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  AppColors.rightEye,
                ),
              ),
              Container(width: 1, height: 80, color: AppColors.border),
              Expanded(
                child: _buildAmslerEyeResult(
                  'Left Eye',
                  leftResult,
                  AppColors.leftEye,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildAmslerLegend(),
          if ((rightResult?.hasDistortions ?? false) ||
              (leftResult?.hasDistortions ?? false)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Clinical Findings',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The markings indicate potential metamorphosis (wavy lines) or scotoma (missing spots). This often signals physical changes in the macula. Please consult an eye care professional.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall category header
          _buildPelliRobsonOverallHeader(result),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Per-eye results
          if (result.rightEye != null) () {
            final re = result.rightEye!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEyeSectionTitle('Right Eye'),
                _buildPelliRobsonEyeResults(re),
                const SizedBox(height: 16),
              ],
            );
          }(),
          if (result.leftEye != null) () {
            final le = result.leftEye!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEyeSectionTitle('Left Eye'),
                _buildPelliRobsonEyeResults(le),
                const SizedBox(height: 16),
              ],
            );
          }(),
          if (result.bothEyes != null || result.shortDistance != null) ...[
            // LEGACY: If we have old "Both Eyes" results, we can show them, 
            // but the user said they are replaced by R/L.
            // For now, I'll remove this to hide "Both Eyes" as requested.
          ],

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.success,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISCLAIMER:',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This vision test is a screening tool and is not a substitute for a professional eye examination by a qualified optometrist or ophthalmologist. If you have concerns about your vision, please seek professional medical advice.',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    height: 1.4,
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
        if (result != null) () {
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

    Color bgColor;
    Color borderColor;
    IconData icon;

    switch (status) {
      case TestStatus.normal:
        bgColor = AppColors.success.withValues(alpha: 0.1);
        borderColor = AppColors.success.withValues(alpha: 0.3);
        icon = Icons.check_circle_outline;
        break;
      case TestStatus.review:
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        borderColor = AppColors.warning.withValues(alpha: 0.3);
        icon = Icons.schedule;
        break;
      case TestStatus.urgent:
        bgColor = AppColors.error.withValues(alpha: 0.1);
        borderColor = AppColors.error.withValues(alpha: 0.3);
        icon = Icons.priority_high;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              const Text(
                'Recommendation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.historicalResult?.recommendation ??
                provider.getRecommendation(),
            style: TextStyle(color: AppColors.textPrimary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(TestSessionProvider provider) {
    final isHistorical = widget.historicalResult != null;

    return Column(
      children: [
        // Primary action - Download PDF
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : _generatePdf,
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            label: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _isGeneratingPdf ? 'Generating...' : 'Download PDF Report',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary actions - Fixed with Flexible and proper constraints
        Row(
          children: [
            // Share button
            Flexible(
              flex: 1,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(height: 4),
                        Text('Share', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // History button - Only show if not already coming from history
            if (!isHistorical) ...[
              Flexible(
                flex: 1,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/my-results');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(height: 4),
                          Text('History', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Logs button
            Flexible(
              flex: 1,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/speech-logs');
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.article_outlined, size: 20),
                        SizedBox(height: 4),
                        Text('Logs', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Retake test
        TextButton.icon(
          onPressed: () {
            provider.reset();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/quick-test',
              (route) => false,
            );
          },
          icon: const Icon(Icons.replay),
          label: Text(isHistorical ? 'Start New Test' : 'Retake Test'),
        ),
      ],
    );
  }

  Future<void> _shareGridTracing(String? localPath, String? remoteUrl) async {
    try {
      if (localPath != null && await File(localPath).exists()) {
        await Share.shareXFiles([XFile(localPath)], text: 'Amsler Grid Tracing');
      } else if (remoteUrl != null) {
        // Download to share
        final response = await http.get(Uri.parse(remoteUrl));
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/amsler_share.png');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Amsler Grid Tracing');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image not available for sharing')),
        );
      }
    } catch (e) {
      debugPrint('[QuickTestResult] Share error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share image: $e')),
      );
    }
  }

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
      final String filePath = await _pdfExportService.getExpectedFilePath(result);
      final File file = File(filePath);

      if (await file.exists()) {
        if (mounted) setState(() => _isGeneratingPdf = false);
        await OpenFilex.open(filePath);
        return;
      }

      UIUtils.showProgressDialog(
        context: context,
        message: 'Generating PDF...',
      );

      final String generatedPath = await _pdfExportService.generateAndDownloadPdf(result);

      if (mounted) {
        UIUtils.hideProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF Report saved to Downloads'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                OpenFilex.open(generatedPath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _sharePdfReport(TestResultModel result) async {
    try {
      UIUtils.showProgressDialog(
        context: context,
        message: 'Preparing PDF...',
      );

      final String filePath = await _pdfExportService.generateAndDownloadPdf(result);
      
      if (mounted) {
        UIUtils.hideProgressDialog(context);
      }

      await Share.shareXFiles([XFile(filePath)], text: 'Vision Test Report');
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildShortDistanceCard(TestSessionProvider provider) {
    final result =
        widget.historicalResult?.shortDistance ?? provider.shortDistance;

    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No reading test data available',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final isGood = result.averageSimilarity >= 70.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: isGood
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGood ? Icons.check : Icons.warning,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isGood ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Best Acuity: ${result.bestAcuity}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Score display
              Column(
                children: [
                  Text(
                    '${result.averageSimilarity.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Match',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Row(
            children: [
              Expanded(
                flex: result.correctSentences,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (result.correctSentences < result.totalSentences)
                Expanded(
                  flex: result.totalSentences - result.correctSentences,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Sentences',
                '${result.correctSentences}/${result.totalSentences}',
              ),
              Container(width: 1, height: 30, color: AppColors.border),
              _buildStatItem(
                'Accuracy',
                '${(result.accuracy * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
