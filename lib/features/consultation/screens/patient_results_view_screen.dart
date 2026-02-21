import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../data/models/test_result_model.dart';
import '../../../core/widgets/eye_loader.dart';
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
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Decorations
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.primary.withValues(alpha: 0.05),
                    context.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  '${widget.patientName}\'s Results',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: EyeLoader(size: 40)),
                )
              else if (_results.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final result = _results[index];
                      return _buildResultCard(result, index);
                    }, childCount: _results.length),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(TestResultModel result, int index) {
    return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: context.dividerColor.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: _getStatusIcon(result.overallStatus),
              title: Text(
                result.testType.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              subtitle: Text(
                DateFormat('MMM d, yyyy • h:mm a').format(result.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQuickSummary(result),
                      const SizedBox(height: 24),
                      _buildActionButton(
                        'DOWNLOAD PDF REPORT',
                        context.primary,
                        () => _downloadPdf(result),
                        icon: Icons.picture_as_pdf_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 50).ms)
        .slideY(begin: 0.05);
  }

  Widget _buildQuickSummary(TestResultModel result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.primary.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, size: 16, color: context.primary),
              const SizedBox(width: 8),
              Text(
                'DIAGNOSTIC SUMMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: context.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRow(
            'Overall Status',
            result.overallStatus.name.toUpperCase(),
          ),
          if (result.visualAcuityRight != null ||
              result.visualAcuityLeft != null) ...[
            const SizedBox(height: 8),
            _summaryRow(
              'Right Eye (OD)',
              result.visualAcuityRight?.snellenScore ?? "N/A",
            ),
            const SizedBox(height: 8),
            _summaryRow(
              'Left Eye (OS)',
              result.visualAcuityLeft?.snellenScore ?? "N/A",
            ),
          ],
          if (result.colorVision != null) ...[
            const SizedBox(height: 8),
            _summaryRow('Color Vision', result.colorVision!.status),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 12),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getStatusIcon(TestStatus status) {
    Color color;
    IconData icon;
    switch (status) {
      case TestStatus.normal:
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case TestStatus.review:
        color = Colors.orange;
        icon = Icons.info_rounded;
        break;
      case TestStatus.urgent:
        color = Colors.red;
        icon = Icons.warning_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_late_rounded,
              size: 80,
              color: context.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Results Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: context.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No diagnostic data found for this patient.',
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
    );
  }
}
