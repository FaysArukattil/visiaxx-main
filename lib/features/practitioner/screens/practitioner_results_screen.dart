import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/test_result_model.dart';
import '../../../core/widgets/eye_loader.dart';
import 'package:visiaxx/core/utils/snackbar_utils.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';
import '../../../core/widgets/download_success_dialog.dart';

/// Enhanced results screen for practitioners
/// Features:
/// - Results grouped by date (Today, Yesterday, specific dates)
/// - Search bar for filtering by patient name
/// - Expandable date sections
class PractitionerResultsScreen extends StatefulWidget {
  const PractitionerResultsScreen({super.key});

  @override
  State<PractitionerResultsScreen> createState() =>
      _PractitionerResultsScreenState();
}

class _PractitionerResultsScreenState extends State<PractitionerResultsScreen> {
  List<TestResultModel> _allResults = [];
  Map<String, List<TestResultModel>> _groupedResults = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;

  final TestResultService _resultService = TestResultService();
  final PdfExportService _pdfExportService = PdfExportService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in to view results';
      });
      return;
    }

    // 1. Try to load from CACHE ONLY for immediate display
    try {
      debugPrint('[PractitionerResults] âš¡ Fetching from CACHE first...');
      final cachedResults = await _resultService.getTestResults(
        user.uid,
        source: Source.cache,
      );
      if (mounted && cachedResults.isNotEmpty) {
        setState(() {
          _allResults = cachedResults;
          _groupResults();
          _isLoading = false; // Show cached data right away
        });
        debugPrint(
          '[PractitionerResults] âš¡ Showing ${cachedResults.length} cached results',
        );
      }
    } catch (e) {
      debugPrint('[PractitionerResults] âš¡ Initial cache fetch failed: $e');
    }

    // 2. Full refresh from server
    try {
      debugPrint('[PractitionerResults] ðŸ”„ Refreshing from server...');

      // If we still don't have results, show loading
      if (_allResults.isEmpty) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final results = await _resultService.getTestResults(user.uid);
      debugPrint(
        '[PractitionerResults] âœ… Server refresh complete: ${results.length} results',
      );

      if (mounted) {
        setState(() {
          _allResults = results;
          _groupResults();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PractitionerResults] âŒ Error loading results: $e');
      if (mounted) {
        setState(() {
          // Only show error if we have NO results at all
          if (_allResults.isEmpty) {
            _errorMessage = 'Failed to load results';
          }
          _isLoading = false;
        });
      }
    }
  }

  /// Filter results by search query
  List<TestResultModel> get _filteredResults {
    if (_searchQuery.isEmpty) return _allResults;

    final query = _searchQuery.toLowerCase();
    return _allResults.where((result) {
      return result.profileName.toLowerCase().contains(query);
    }).toList();
  }

  /// Group results by date
  void _groupResults() {
    final results = _filteredResults;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <String, List<TestResultModel>>{};

    for (final result in results) {
      final resultDate = DateTime(
        result.timestamp.year,
        result.timestamp.month,
        result.timestamp.day,
      );

      String groupKey;
      if (resultDate == today) {
        groupKey = 'Today';
      } else if (resultDate == yesterday) {
        groupKey = 'Yesterday';
      } else {
        groupKey = DateFormat('MMMM d, yyyy').format(result.timestamp);
      }

      grouped[groupKey] ??= [];
      grouped[groupKey]!.add(result);
    }

    // Sort results within each group by time (newest first)
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    setState(() => _groupedResults = grouped);
  }

  /// Get ordered date keys (Today, Yesterday, then dates descending)
  List<String> get _orderedDateKeys {
    final keys = _groupedResults.keys.toList();

    // Custom sort order: Today first, Yesterday second, then other dates descending
    keys.sort((a, b) {
      if (a == 'Today') return -1;
      if (b == 'Today') return 1;
      if (a == 'Yesterday') return -1;
      if (b == 'Yesterday') return 1;

      // Parse dates for comparison
      try {
        final dateA = DateFormat('MMMM d, yyyy').parse(a);
        final dateB = DateFormat('MMMM d, yyyy').parse(b);
        return dateB.compareTo(dateA); // Descending order
      } catch (e) {
        return a.compareTo(b);
      }
    });

    return keys;
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _groupResults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadResults();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
          ),

          // Results list
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(child: EyeLoader.fullScreen());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadResults();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_groupedResults.isEmpty) {
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
                  color: AppColors.primary.withValues(alpha: 0.1),
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
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? 'Conduct a vision test for a patient\nto see results here'
                    : 'No results matching "$_searchQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResults,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _orderedDateKeys.length,
        itemBuilder: (context, index) {
          final dateKey = _orderedDateKeys[index];
          final resultsForDate = _groupedResults[dateKey]!;
          return _buildDateGroup(dateKey, resultsForDate);
        },
      ),
    );
  }

  Widget _buildDateGroup(String dateLabel, List<TestResultModel> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: dateLabel == 'Today'
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      dateLabel == 'Today' ? Icons.today : Icons.calendar_today,
                      size: 14,
                      color: dateLabel == 'Today'
                          ? AppColors.primary
                          : AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: dateLabel == 'Today'
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${results.length} ${results.length == 1 ? 'result' : 'results'}',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const Spacer(),
            ],
          ),
        ),

        // Results for this date
        ...results.map(
          (result) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildResultCard(result),
          ),
        ),
      ],
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

    final bool isComprehensive = result.testType == 'comprehensive';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComprehensive
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isComprehensive
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isComprehensive
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.black.withValues(alpha: 0.05),
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
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
                        'MMM dd, yyyy â€¢ h:mm a',
                      ).format(result.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (isComprehensive) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FULL EXAMINATION',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
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
          GestureDetector(
            onTap: () => _showResultDetails(result),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
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
                  if (isComprehensive && result.pelliRobson != null)
                    _buildMiniResult(
                      'Contrast',
                      result.pelliRobson!.averageScore.toStringAsFixed(1),
                    )
                  else
                    _buildMiniResult(
                      'Amsler',
                      (result.amslerGridRight?.hasDistortions != true &&
                              result.amslerGridLeft?.hasDistortions != true)
                          ? 'Normal'
                          : 'Check',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to full-page result view
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            QuickTestResultScreen(historicalResult: result),
                      ),
                    );
                  },
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
              // Share button
              IconButton(
                onPressed: () => _sharePdf(result),
                icon: const Icon(Icons.share, size: 20),
                color: AppColors.primary,
                tooltip: 'Share report',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(TestResultModel result) async {
    try {
      final String filePath = await _pdfExportService.getExpectedFilePath(
        result,
      );
      final File file = File(filePath);

      if (await file.exists()) {
        if (mounted) {
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

      if (mounted) {
        UIUtils.hideProgressDialog(context);
        await showDownloadSuccessDialog(
          context: context,
          filePath: generatedPath,
        );
      }
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        SnackbarUtils.showError(context, 'Failed to generate PDF: $e');
      }
    }
  }

  Future<void> _sharePdf(TestResultModel result) async {
    try {
      UIUtils.showProgressDialog(context: context, message: 'Preparing PDF...');
      final String filePath = await _pdfExportService.generateAndDownloadPdf(
        result,
      );
      if (mounted) UIUtils.hideProgressDialog(context);
      await Share.shareXFiles([XFile(filePath)], text: 'Vision Test Report');
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        SnackbarUtils.showError(context, 'Failed to share PDF: $e');
      }
    }
  }

  Future<void> _confirmDeleteResult(TestResultModel result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Result?'),
        content: Text(
          'Are you sure you want to remove the test result for ${result.profileName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteResult(result);
    }
  }

  Future<void> _deleteResult(TestResultModel result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _resultService.deleteTestResult(user.uid, result.id);
      _loadResults(); // Refresh list
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to delete: $e');
      }
    }
  }

  void _showResultDetails(TestResultModel result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) =>
          _ResultDetailSheet(result: result, onShareImage: _shareGridTracing),
    );
  }

  Future<void> _shareGridTracing(String? localPath, String? remoteUrl) async {
    try {
      if (localPath != null && await File(localPath).exists()) {
        await Share.shareXFiles([
          XFile(localPath),
        ], text: 'Amsler Grid Tracing');
      } else if (remoteUrl != null) {
        final response = await http.get(Uri.parse(remoteUrl));
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/amsler_share.png');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Amsler Grid Tracing');
      }
    } catch (e) {
      debugPrint('[PractitionerResults] Share error: $e');
    }
  }
}

class _ResultDetailSheet extends StatelessWidget {
  final TestResultModel result;
  final Function(String?, String?) onShareImage;

  const _ResultDetailSheet({required this.result, required this.onShareImage});

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
            const Text(
              'Test Results',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM dd, yyyy â€¢ h:mm a').format(result.timestamp),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
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
            _buildSection('Color Vision', [
              _buildDetailRow(
                'Score',
                '${result.colorVision?.correctAnswers ?? 0}/${result.colorVision?.totalPlates ?? 0}',
              ),
              _buildDetailRow('Status', result.colorVision?.status ?? 'N/A'),
            ]),
            if (result.amslerGridRight != null || result.amslerGridLeft != null)
              _buildSection('Amsler Grid', [
                if (result.amslerGridRight != null) ...[
                  _buildDetailRow(
                    'Right Eye',
                    result.amslerGridRight!.hasDistortions
                        ? 'Distortions detected'
                        : 'Normal',
                  ),
                  _buildGridImage(
                    result.amslerGridRight!.annotatedImagePath,
                    result.amslerGridRight!.firebaseImageUrl,
                  ),
                ],
                if (result.amslerGridLeft != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Left Eye',
                    result.amslerGridLeft!.hasDistortions
                        ? 'Distortions detected'
                        : 'Normal',
                  ),
                  _buildGridImage(
                    result.amslerGridLeft!.annotatedImagePath,
                    result.amslerGridLeft!.firebaseImageUrl,
                  ),
                ],
              ]),
            if (result.pelliRobson != null)
              () {
                final pr = result.pelliRobson!;
                final List<Widget> prRows = [];
                if (pr.rightEye != null) {
                  if (pr.rightEye!.shortDistance != null) {
                    prRows.add(
                      _buildDetailRow(
                        'Right Eye (Near)',
                        '${pr.rightEye!.shortDistance!.adjustedScore.toStringAsFixed(2)} log CS',
                      ),
                    );
                  }
                  if (pr.rightEye!.longDistance != null) {
                    prRows.add(
                      _buildDetailRow(
                        'Right Eye (Dist)',
                        '${pr.rightEye!.longDistance!.adjustedScore.toStringAsFixed(2)} log CS',
                      ),
                    );
                  }
                }
                if (pr.leftEye != null) {
                  if (pr.leftEye!.shortDistance != null) {
                    prRows.add(
                      _buildDetailRow(
                        'Left Eye (Near)',
                        '${pr.leftEye!.shortDistance!.adjustedScore.toStringAsFixed(2)} log CS',
                      ),
                    );
                  }
                  if (pr.leftEye!.longDistance != null) {
                    prRows.add(
                      _buildDetailRow(
                        'Left Eye (Dist)',
                        '${pr.leftEye!.longDistance!.adjustedScore.toStringAsFixed(2)} log CS',
                      ),
                    );
                  }
                }
                return Column(
                  children: [
                    _buildSection('Contrast Sensitivity', [
                      ...prRows,
                      _buildDetailRow('Status', pr.overallCategory),
                    ]),
                  ],
                );
              }(),
            if (result.questionnaire != null)
              _buildQuestionnaireSection(result.questionnaire!),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGridImage(String? path, String? url) {
    if (path == null && url == null) return const SizedBox.shrink();
    final bool isNetwork = path != null && path.startsWith('http');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isNetwork
              ? Image.network(
                  path,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                )
              : (path != null)
              ? Image.file(
                  File(path),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    if (url != null) {
                      return Image.network(
                        url,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const SizedBox.shrink(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                )
              : Image.network(
                  url!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
        ),
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
    if (questionnaire.chiefComplaints.hasStickyDischarge) {
      complaints.add('Sticky Discharge');
    }
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

