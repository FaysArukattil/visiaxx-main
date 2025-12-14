import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../data/models/test_result_model.dart';

/// My Results screen showing test history with Firebase integration and PDF export
class MyResultsScreen extends StatefulWidget {
  const MyResultsScreen({super.key});

  @override
  State<MyResultsScreen> createState() => _MyResultsScreenState();
}

class _MyResultsScreenState extends State<MyResultsScreen> {
  String _selectedFilter = 'all';
  bool _isLoading = true;
  String? _error;
  List<TestResultModel> _results = [];

  final TestResultService _testResultService = TestResultService();
  final PdfExportService _pdfExportService = PdfExportService();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('[MyResults] Loading results for user: ${user?.uid}');

      if (user == null) {
        debugPrint('[MyResults] ❌ No user logged in');
        setState(() {
          _results = [];
          _isLoading = false;
          _error = 'Please log in to view results';
        });
        return;
      }

      debugPrint('[MyResults] Fetching from Firebase...');
      final results = await _testResultService.getTestResults(user.uid);
      debugPrint('[MyResults] ✅ Loaded ${results.length} results');

      if (results.isNotEmpty) {
        debugPrint('[MyResults] First result: ${results.first.toJson()}');
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MyResults] ❌ ERROR loading results: $e');

      if (mounted) {
        setState(() {
          _error = 'Failed to load results: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<TestResultModel> get _filteredResults {
    if (_selectedFilter == 'all') return _results;
    return _results.where((r) {
      switch (_selectedFilter) {
        case 'normal':
          return r.overallStatus == TestStatus.normal;
        case 'review':
          return r.overallStatus == TestStatus.review;
        case 'urgent':
          return r.overallStatus == TestStatus.urgent;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _downloadPdf(TestResultModel result) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating PDF...')));

      await _pdfExportService.sharePdf(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF ready for sharing'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Show confirmation dialog before deleting
  Future<void> _confirmDeleteResult(TestResultModel result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Result?'),
        content: Text(
          'Are you sure you want to delete the test result from ${result.profileName.isEmpty ? 'Self' : result.profileName}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteResult(result);
    }
  }

  /// Delete a test result from Firebase
  Future<void> _deleteResult(TestResultModel result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _testResultService.deleteTestResult(user.uid, result.id);

      setState(() {
        _results.removeWhere((r) => r.id == result.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Result deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('My Results'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey[900],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadResults),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: _filteredResults.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadResults,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredResults.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildResultCard(_filteredResults[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Normal', 'normal', color: AppColors.success),
            const SizedBox(width: 8),
            _buildFilterChip('Review', 'review', color: AppColors.warning),
            const SizedBox(width: 8),
            _buildFilterChip('Urgent', 'urgent', color: AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = value == _selectedFilter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? AppColors.primary) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? (color ?? AppColors.primary) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error loading results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Results Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a vision test to see\nyour results here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/quick-test'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Quick Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(TestResultModel result) {
    Color statusColor;
    switch (result.overallStatus) {
      case TestStatus.normal:
        statusColor = AppColors.success;
        break;
      case TestStatus.review:
        statusColor = AppColors.warning;
        break;
      case TestStatus.urgent:
        statusColor = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  result.profileName.isNotEmpty ? result.profileName[0] : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.profileName.isNotEmpty
                          ? result.profileName
                          : 'Self',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'MMM dd, yyyy • h:mm a',
                      ).format(result.timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.overallStatus.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Results grid
          Row(
            children: [
              _buildMiniResult(
                'VA (R)',
                result.visualAcuityRight?.snellenScore ?? 'N/A',
              ),
              _buildMiniResult(
                'VA (L)',
                result.visualAcuityLeft?.snellenScore ?? 'N/A',
              ),
              _buildMiniResult(
                'Color',
                result.colorVision?.isNormal == true ? 'Normal' : 'Check',
              ),
              _buildMiniResult(
                'Amsler',
                (result.amslerGridRight?.hasDistortions != true &&
                        result.amslerGridLeft?.hasDistortions != true)
                    ? 'Normal'
                    : 'Check',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showResultDetails(result),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPdf(result),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              IconButton(
                onPressed: () => _confirmDeleteResult(result),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.error,
                tooltip: 'Delete result',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniResult(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showResultDetails(TestResultModel result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ResultDetailSheet(result: result),
    );
  }
}

class _ResultDetailSheet extends StatelessWidget {
  final TestResultModel result;

  const _ResultDetailSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Test Results',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM dd, yyyy • h:mm a').format(result.timestamp),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Visual Acuity
            _buildSection('Visual Acuity', [
              _buildDetailRow(
                'Right Eye',
                result.visualAcuityRight?.snellenScore ?? 'N/A',
              ),
              _buildDetailRow(
                'Left Eye',
                result.visualAcuityLeft?.snellenScore ?? 'N/A',
              ),
            ]),

            // 🆕 Short Distance (Reading Test)
            if (result.shortDistance != null)
              _buildSection('Reading Test (Near Vision)', [
                _buildDetailRow(
                  'Best Acuity',
                  result.shortDistance!.bestAcuity,
                ),
                _buildDetailRow(
                  'Sentences',
                  '${result.shortDistance!.correctSentences}/${result.shortDistance!.totalSentences}',
                ),
                _buildDetailRow(
                  'Average Match',
                  '${result.shortDistance!.averageSimilarity.toStringAsFixed(1)}%',
                ),
                _buildDetailRow('Status', result.shortDistance!.status),
              ]),

            // Color Vision
            _buildSection('Color Vision', [
              _buildDetailRow(
                'Score',
                '${result.colorVision?.correctAnswers ?? 0}/${result.colorVision?.totalPlates ?? 0}',
              ),
              _buildDetailRow('Status', result.colorVision?.status ?? 'N/A'),
            ]),

            // Amsler Grid
            if (result.amslerGridRight != null || result.amslerGridLeft != null)
              _buildSection('Amsler Grid', [
                if (result.amslerGridRight != null)
                  _buildDetailRow(
                    'Right Eye',
                    result.amslerGridRight!.hasDistortions
                        ? 'Distortions detected'
                        : 'Normal',
                  ),
                if (result.amslerGridLeft != null)
                  _buildDetailRow(
                    'Left Eye',
                    result.amslerGridLeft!.hasDistortions
                        ? 'Distortions detected'
                        : 'Normal',
                  ),
              ]),

            // Questionnaire Summary
            if (result.questionnaire != null)
              _buildQuestionnaireSection(result.questionnaire!),

            // Recommendation
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommendation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.recommendation,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireSection(dynamic questionnaire) {
    final complaints = <String>[];
    if (questionnaire.chiefComplaints.hasRedness) complaints.add('Redness');
    if (questionnaire.chiefComplaints.hasWatering) complaints.add('Watering');
    if (questionnaire.chiefComplaints.hasItching) complaints.add('Itching');
    if (questionnaire.chiefComplaints.hasHeadache) complaints.add('Headache');
    if (questionnaire.chiefComplaints.hasDryness) complaints.add('Dryness');
    if (questionnaire.chiefComplaints.hasStickyDischarge)
      complaints.add('Sticky Discharge');

    return _buildSection('Questionnaire Responses', [
      _buildDetailRow(
        'Complaints',
        complaints.isEmpty ? 'None' : complaints.join(', '),
      ),
      if (questionnaire.currentMedications != null)
        _buildDetailRow('Medications', questionnaire.currentMedications),
      _buildDetailRow(
        'Recent Surgery',
        questionnaire.hasRecentSurgery ? 'Yes' : 'No',
      ),
    ]);
  }
}
