import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/models/color_vision_result.dart';
import '../../home/widgets/app_bar_widget.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../core/utils/snackbar_utils.dart';

class PatientResultsViewScreen extends StatefulWidget {
  final List<String> resultIds;
  final String patientName;

  const PatientResultsViewScreen({
    super.key,
    required this.resultIds,
    required this.patientName,
  });

  @override
  State<PatientResultsViewScreen> createState() =>
      _PatientResultsViewScreenState();
}

class _PatientResultsViewScreenState extends State<PatientResultsViewScreen> {
  final _testResultService = TestResultService();
  final _pdfExportService = PdfExportService();
  List<TestResultModel> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final results = await _testResultService.getTestResultsByIds(
      widget.resultIds,
    );
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  Future<void> _downloadPdf(TestResultModel result) async {
    try {
      UIUtils.showProgressDialog(
        context: context,
        message: 'Generating PDF...',
      );
      final path = await _pdfExportService.generateAndDownloadPdf(result);
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        SnackbarUtils.showSuccess(context, 'PDF saved to: $path');
      }
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        SnackbarUtils.showError(context, 'Failed to generate PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(title: '${widget.patientName}\'s Results'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? _buildEmptyState()
          : _buildResultsList(),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: context.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: _getStatusIcon(result.overallStatus),
            title: Text(
              result.testType.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              DateFormat('MMM d, yyyy • h:mm a').format(result.timestamp),
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickSummary(result),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadPdf(result),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Download Full Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickSummary(TestResultModel result) {
    // Specific summary based on test type
    String summary =
        'Overall Status: ${result.overallStatus.name.toUpperCase()}';

    if (result.visualAcuityRight != null || result.visualAcuityLeft != null) {
      summary += '\nVA (R): ${result.visualAcuityRight?.snellenScore ?? "N/A"}';
      summary += '\nVA (L): ${result.visualAcuityLeft?.snellenScore ?? "N/A"}';
    }

    if (result.colorVision != null) {
      summary +=
          '\nColor Vision: ${result.colorVision!.overallStatus.displayName}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(summary, style: const TextStyle(fontSize: 13, height: 1.5)),
    );
  }

  Widget _getStatusIcon(TestStatus status) {
    Color color;
    IconData icon;
    switch (status) {
      case TestStatus.normal:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case TestStatus.review:
        color = Colors.orange;
        icon = Icons.info_outline;
        break;
      case TestStatus.urgent:
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No details found for these results.'));
  }
}
