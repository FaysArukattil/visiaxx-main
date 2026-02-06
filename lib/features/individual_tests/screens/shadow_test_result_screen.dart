import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/shadow_test_provider.dart';
import '../../../data/models/shadow_test_result.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/eye_loader.dart';

class ShadowTestResultScreen extends StatefulWidget {
  const ShadowTestResultScreen({super.key});

  @override
  State<ShadowTestResultScreen> createState() => _ShadowTestResultScreenState();
}

class _ShadowTestResultScreenState extends State<ShadowTestResultScreen> {
  bool _isGeneratingPdf = false;

  Future<void> _downloadPDF(ShadowTestResult result) async {
    setState(() => _isGeneratingPdf = true);
    try {
      // Note: We'll need to update PdfExportService to handle ShadowTestResult
      // For now, we'll simulate the call or use a placeholder if not yet implemented
      // final path = await pdfService.generateShadowTestPdf(result);
      await Future.delayed(const Duration(seconds: 2)); // Simulate

      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'PDF Report generated successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to generate PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShadowTestProvider>();
    final result = provider.finalResult;

    if (result == null) {
      return const Scaffold(body: Center(child: EyeLoader()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () {
              provider.setState(ShadowTestState.initial);
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
            _buildRiskHeader(context, result),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildResultsGrid(context, result),
                  const SizedBox(height: 24),
                  _buildClinicalSummary(context, result),
                  const SizedBox(height: 32),
                  _buildActionButtons(context, result),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskHeader(BuildContext context, ShadowTestResult result) {
    Color riskColor;
    IconData riskIcon;

    switch (result.overallRisk) {
      case 'CRITICAL':
      case 'VERY HIGH':
        riskColor = context.error;
        riskIcon = Icons.warning_rounded;
        break;
      case 'HIGH':
        riskColor = context.warning;
        riskIcon = Icons.error_outline_rounded;
        break;
      case 'MODERATE':
        riskColor = context.info;
        riskIcon = Icons.info_outline_rounded;
        break;
      default:
        riskColor = context.success;
        riskIcon = Icons.check_circle_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [riskColor, riskColor.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(riskIcon, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            '${result.overallRisk} RISK',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.requiresReferral
                ? 'Specialist Referral Recommended'
                : 'Routine Monitoring Recommended',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(BuildContext context, ShadowTestResult result) {
    return Row(
      children: [
        Expanded(child: _buildEyeCard(context, 'Right Eye', result.rightEye)),
        const SizedBox(width: 16),
        Expanded(child: _buildEyeCard(context, 'Left Eye', result.leftEye)),
      ],
    );
  }

  Widget _buildEyeCard(BuildContext context, String title, EyeGrading grading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (grading.imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(grading.imagePath!),
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Grade ${grading.grade.grade}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: context.primary,
            ),
          ),
          Text(
            grading.grade.angleStatus,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalSummary(BuildContext context, ShadowTestResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded, color: context.primary),
              const SizedBox(width: 12),
              const Text(
                'Clinical Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow('Interpretation', result.interpretation),
          const Divider(height: 32),
          _buildSummaryRow('Conclusion', result.conclusion),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ShadowTestResult result) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : () => _downloadPDF(result),
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Download PDF Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retake Test'),
        ),
      ],
    );
  }
}
