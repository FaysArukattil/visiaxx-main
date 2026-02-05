import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/models/visiual_acuity_result.dart';
import '../../../data/models/amsler_grid_result.dart';
import '../../../data/models/mobile_refractometry_result.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../data/models/pelli_robson_result.dart';
import '../../../data/models/short_distance_result.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../data/models/refraction_prescription_model.dart';

/// Comprehensive test result screen
class ComprehensiveResultScreen extends StatefulWidget {
  const ComprehensiveResultScreen({super.key});

  @override
  State<ComprehensiveResultScreen> createState() =>
      _ComprehensiveResultScreenState();
}

class _ComprehensiveResultScreenState extends State<ComprehensiveResultScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    final vaRight = provider.visualAcuityRight;
    final vaLeft = provider.visualAcuityLeft;
    final ColorVisionResult? colorVision = provider.colorVision;
    final PelliRobsonResult? pelliRobson = provider.pelliRobson;
    final MobileRefractometryResult? refractometry =
        provider.mobileRefractometry;
    final AmslerGridResult? amslerRight = provider.amslerGridRight;
    final AmslerGridResult? amslerLeft = provider.amslerGridLeft;
    final ShortDistanceResult? shortDistance = provider.shortDistance;

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
                // For comprehensive results, "Restart" could mean restarting the whole process
                // or just the last test. Usually, going back to comprehensive-test is safer.
                provider.reset();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/comprehensive-test',
                  (route) => false,
                );
              },
              onExit: () async {
                await _navigateHome();
                if (mounted) {
                  provider.reset();
                }
              },
              hasCompletedTests: provider.hasAnyCompletedTest,
              onSaveAndExit: provider.hasAnyCompletedTest
                  ? () {
                      Navigator.of(dialogContext).pop();
                    }
                  : null,
            );
          },
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Comprehensive Results'),
          backgroundColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: AppColors.transparent,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => _navigateHome(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Status Header
              _buildOverallStatusHeader(provider.getOverallStatus()),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (vaRight != null || vaLeft != null)
                      _buildResultSection(
                        context,
                        title: 'Visual Acuity',
                        results: [
                          if (vaRight != null)
                            'Right Eye: ${vaRight.snellenScore}',
                          if (vaLeft != null)
                            'Left Eye: ${vaLeft.snellenScore}',
                        ],
                        status: _getVAStatus(vaRight, vaLeft),
                        color: _getVAColor(vaRight, vaLeft),
                        icon: Icons.visibility_rounded,
                      ),
                    if (shortDistance != null) ...[
                      const SizedBox(height: 16),
                      _buildResultSection(
                        context,
                        title: 'Near Vision',
                        results: [
                          'Acuity: ${shortDistance.bestAcuity}',
                          'Accuracy: ${(shortDistance.accuracy * 100).toStringAsFixed(0)}%',
                        ],
                        status: shortDistance.averageSimilarity >= 0.8
                            ? 'Good'
                            : 'Review',
                        color: shortDistance.averageSimilarity >= 0.8
                            ? AppColors.success
                            : AppColors.warning,
                        icon: Icons.menu_book_rounded,
                      ),
                    ],
                    if (pelliRobson != null) ...[
                      const SizedBox(height: 16),
                      _buildResultSection(
                        context,
                        title: 'Contrast Sensitivity',
                        results: [
                          'Score: ${pelliRobson.averageScore.toStringAsFixed(2)} log CS',
                        ],
                        status: pelliRobson.overallCategory,
                        color: _getContrastColor(pelliRobson.overallCategory),
                        icon: Icons.contrast_rounded,
                      ),
                    ],
                    if (colorVision != null) ...[
                      const SizedBox(height: 16),
                      _buildResultSection(
                        context,
                        title: 'Color Vision',
                        results: [
                          'Score: ${colorVision.correctAnswers}/${colorVision.totalPlates}',
                        ],
                        status: colorVision.isNormal ? 'Normal' : 'Reduced',
                        color: colorVision.isNormal
                            ? AppColors.success
                            : AppColors.error,
                        icon: Icons.palette_rounded,
                      ),
                    ],
                    if (amslerRight != null || amslerLeft != null) ...[
                      const SizedBox(height: 16),
                      _buildResultSection(
                        context,
                        title: 'Amsler Grid',
                        results: [
                          if (amslerRight != null)
                            'Right Eye: ${amslerRight.hasDistortions ? "Distortions" : "Normal"}',
                          if (amslerLeft != null)
                            'Left Eye: ${amslerLeft.hasDistortions ? "Distortions" : "Normal"}',
                        ],
                        status: _getAmslerStatus(amslerRight, amslerLeft),
                        color: _getAmslerColor(amslerRight, amslerLeft),
                        icon: Icons.grid_view_rounded,
                      ),
                    ],
                    if (refractometry != null) ...[
                      const SizedBox(height: 16),
                      _buildRefractometrySection(provider, refractometry),
                    ],
                    if (_hasPrescription(provider)) ...[
                      const SizedBox(height: 16),
                      _buildPrescriptionCard(provider),
                    ],
                    const SizedBox(height: 24),
                    // Recommendations Card
                    _buildRecommendationsCard(
                      provider.getOverallStatus(),
                      provider.getRecommendation(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _generatePDF(provider),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'PDF Report',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateHome(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallStatusHeader(TestStatus status) {
    Color color;
    switch (status) {
      case TestStatus.normal:
        color = AppColors.success;
        break;
      case TestStatus.review:
        color = AppColors.warning;
        break;
      case TestStatus.urgent:
        color = AppColors.error;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(status.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefractometrySection(
    TestSessionProvider provider,
    MobileRefractometryResult result,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Mobile Refractometry',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (result.criticalAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Critical',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (result.rightEye != null)
                  Expanded(
                    child: _buildEyeRefraction(
                      'RIGHT',
                      result.rightEye!,
                      provider.profileAge,
                    ),
                  ),
                if (result.rightEye != null && result.leftEye != null)
                  Container(
                    width: 1,
                    height: 60,
                    color: AppColors.border.withValues(alpha: 0.5),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                if (result.leftEye != null)
                  Expanded(
                    child: _buildEyeRefraction(
                      'LEFT',
                      result.leftEye!,
                      provider.profileAge,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeRefraction(
    String eye,
    MobileRefractometryEyeResult res,
    int? age,
  ) {
    final showAdd =
        (age ?? 0) >= 40 &&
        double.tryParse(res.addPower) != null &&
        double.parse(res.addPower) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eye,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        _buildRefractionValue('SPH', res.sphere),
        _buildRefractionValue('CYL', res.cylinder),
        _buildRefractionValue('AXIS', '${res.axis}°'),
        if (showAdd)
          _buildRefractionValue(
            'ADD',
            '+${res.addPower.replaceFirst(RegExp(r'^\++'), '')}',
          ),
      ],
    );
  }

  Widget _buildRefractionValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 35,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(TestStatus status, String recommendation) {
    Color color = status == TestStatus.normal
        ? AppColors.primary
        : (status == TestStatus.review ? AppColors.warning : AppColors.error);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                'Clinical Recommendation',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recommendation,
            style: const TextStyle(
              height: 1.5,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _getVAStatus(VisualAcuityResult? r, VisualAcuityResult? l) {
    if (r == null && l == null) return 'N/A';
    final worstLogMAR = math.max(r?.logMAR ?? 0, l?.logMAR ?? 0);
    if (worstLogMAR <= 0.1) return 'Excellent';
    if (worstLogMAR <= 0.3) return 'Good';
    if (worstLogMAR <= 0.5) return 'Borderline';
    return 'Reduced';
  }

  Color _getVAColor(VisualAcuityResult? r, VisualAcuityResult? l) {
    final status = _getVAStatus(r, l);
    if (status == 'Excellent' || status == 'Good') return AppColors.success;
    if (status == 'Borderline') return AppColors.warning;
    return AppColors.error;
  }

  Color _getContrastColor(String category) {
    if (category == 'Excellent' || category == 'Normal') {
      return AppColors.success;
    }
    if (category == 'Borderline') return AppColors.warning;
    return AppColors.error;
  }

  String _getAmslerStatus(AmslerGridResult? r, AmslerGridResult? l) {
    if (r == null && l == null) return 'N/A';
    if ((r?.hasDistortions ?? false) || (l?.hasDistortions ?? false)) {
      return 'Abnormal';
    }
    return 'Normal';
  }

  Color _getAmslerColor(AmslerGridResult? r, AmslerGridResult? l) {
    return _getAmslerStatus(r, l) == 'Normal'
        ? AppColors.success
        : AppColors.error;
  }

  Future<void> _generatePDF(TestSessionProvider provider) async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Generating clinical report...')),
      );

      final result = provider.buildTestResult(provider.profileId);
      final pdfService = PdfExportService();
      await pdfService.generateAndDownloadPdf(result);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('PDF report downloaded to your Downloads folder'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _navigateHome() async {
    await NavigationUtils.navigateHome(context);
  }

  Widget _buildResultSection(
    BuildContext context, {
    required String title,
    required List<String> results,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (results.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...results.map(
                (result) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasPrescription(TestSessionProvider provider) {
    return provider.refractionPrescription != null &&
        provider.refractionPrescription!.includeInResults;
  }

  Widget _buildPrescriptionCard(TestSessionProvider provider) {
    final rx = provider.refractionPrescription;
    if (rx == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: AppColors.success.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Verified Prescription',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Text(
                  'By ${rx.practitionerName}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Final Prescription Table
            _buildRxDataTable(rx.finalPrescription),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Subjective Details
            Row(
              children: [
                Expanded(
                  child: _buildSmallRxDetail(
                    'RIGHT EYE',
                    rx.rightEyeSubjective,
                    AppColors.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _buildSmallRxDetail(
                    'LEFT EYE',
                    rx.leftEyeSubjective,
                    AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRxDataTable(FinalPrescriptionData data) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(0.8),
            2: FlexColumnWidth(0.8),
            3: FlexColumnWidth(0.8),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
              children: [
                _buildRxTableCell('EYE', isHeader: true),
                _buildRxTableCell('SPH', isHeader: true),
                _buildRxTableCell('CYL', isHeader: true),
                _buildRxTableCell('AXIS', isHeader: true),
              ],
            ),
            _buildRxTableRow('Right', data.right),
            _buildRxTableRow('Left', data.left),
          ],
        ),
      ),
    );
  }

  TableRow _buildRxTableRow(String eye, SubjectiveRefractionData data) {
    return TableRow(
      children: [
        _buildRxTableCell(eye, isBold: true),
        _buildRxTableCell(data.sph),
        _buildRxTableCell(data.cyl),
        _buildRxTableCell(data.axis),
      ],
    );
  }

  Widget _buildRxTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? 9 : 11,
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.w500,
          color: isHeader ? AppColors.textSecondary : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSmallRxDetail(
    String eye,
    SubjectiveRefractionData data,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eye,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        _buildRxValueLabel('SPH', data.sph),
        _buildRxValueLabel('CYL', data.cyl),
        _buildRxValueLabel('AXIS', '${data.axis}°'),
        _buildRxValueLabel('VN', data.vn),
      ],
    );
  }

  Widget _buildRxValueLabel(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
