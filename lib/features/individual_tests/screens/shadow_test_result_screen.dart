import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/shadow_test_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/shadow_test_result.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShadowTestResultScreen extends StatefulWidget {
  const ShadowTestResultScreen({super.key});

  @override
  State<ShadowTestResultScreen> createState() => _ShadowTestResultScreenState();
}

class _ShadowTestResultScreenState extends State<ShadowTestResultScreen> {
  final TestResultService _testResultService = TestResultService();
  bool _isGeneratingPdf = false;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveResultsToFirebase();
    });
  }

  Future<void> _saveResultsToFirebase() async {
    if (_hasSaved) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final sessionProvider = context.read<TestSessionProvider>();
      final resultModel = sessionProvider.buildTestResult(user.uid);

      await _testResultService.saveTestResult(
        userId: user.uid,
        result: resultModel,
      );

      if (mounted) {
        setState(() => _hasSaved = true);
        SnackbarUtils.showSuccess(context, 'Results saved successfully!');
      }
    } catch (e) {
      debugPrint('[ShadowTestResult] Save error: $e');
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to save results: $e');
      }
    }
  }

  Future<void> _downloadPDF(ShadowTestResult result) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final sessionProvider = context.read<TestSessionProvider>();
      final resultModel = sessionProvider.buildTestResult(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      );

      final pdfService = PdfExportService();
      await pdfService.generateAndDownloadPdf(resultModel);

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
            onPressed: () async {
              provider.setState(ShadowTestState.initial);
              context.read<TestSessionProvider>().reset();
              await NavigationUtils.navigateHome(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStandardHeader(context, result),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPatientInfoCard(context.read<TestSessionProvider>()),
                  const SizedBox(height: 24),
                  _buildResultsGrid(context, result),
                  const SizedBox(height: 24),
                  _buildClinicalSummary(context, result),
                  const SizedBox(height: 32),
                  _buildDisclaimer(),
                  const SizedBox(height: 32),
                  _buildStandardActionButtons(context, result),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardHeader(BuildContext context, ShadowTestResult result) {
    Color riskColor;
    IconData riskIcon;

    switch (result.overallRisk) {
      case 'CRITICAL':
      case 'VERY HIGH':
        riskColor = context.error;
        riskIcon = Icons.error_rounded;
        break;
      case 'HIGH':
        riskColor = context.warning;
        riskIcon = Icons.warning_amber_rounded;
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [riskColor, riskColor.withValues(alpha: 0.8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Icon(riskIcon, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            '${result.overallRisk} RISK',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy • h:mm a').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
    final name = provider.profileName.isEmpty ? 'User' : provider.profileName;
    final isPatient = provider.profileType == 'patient';
    final badgeText = isPatient
        ? 'Patient'
        : (provider.profileType == 'family'
              ? 'Family Member'
              : 'Primary Account');
    final badgeColor = isPatient
        ? context.warning
        : (provider.profileType == 'family' ? context.info : context.primary);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: context.primary.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                if (provider.profileAge != null)
                  Text(
                    '${provider.profileAge} years • ${provider.profileSex ?? ""}',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
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

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.border.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This test is a screening tool. It does not replace a clinical examination. Consult an ophthalmologist for a definitive diagnosis.',
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardActionButtons(
    BuildContext context,
    ShadowTestResult result,
  ) {
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Download PDF Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final provider = context.read<ShadowTestProvider>();
                  provider.setState(ShadowTestState.initial);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retake'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: context.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => NavigationUtils.navigateHome(context),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Home'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: context.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
