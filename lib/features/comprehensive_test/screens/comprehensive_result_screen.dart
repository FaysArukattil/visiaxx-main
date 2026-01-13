import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/models/visiual_acuity_result.dart';
import '../../../data/models/amsler_grid_result.dart';
import '../../../data/models/mobile_refractometry_result.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../data/models/pelli_robson_result.dart';
import '../../../data/models/short_distance_result.dart';
import '../../../core/services/pdf_export_service.dart';

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

    return Scaffold(
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
                        if (vaLeft != null) 'Left Eye: ${vaLeft.snellenScore}',
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
                    _buildRefractometrySection(refractometry),
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

  Widget _buildRefractometrySection(MobileRefractometryResult result) {
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
                    child: _buildEyeRefraction('RIGHT', result.rightEye!),
                  ),
                if (result.rightEye != null && result.leftEye != null)
                  Container(
                    width: 1,
                    height: 60,
                    color: AppColors.border.withValues(alpha: 0.5),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                if (result.leftEye != null)
                  Expanded(child: _buildEyeRefraction('LEFT', result.leftEye!)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeRefraction(String eye, MobileRefractometryEyeResult res) {
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
        if (double.tryParse(res.addPower) != null &&
            double.parse(res.addPower) > 0)
          _buildRefractionValue('ADD', '+${res.addPower}'),
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
}
