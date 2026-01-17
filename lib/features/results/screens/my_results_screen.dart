import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/network_connectivity_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:visiaxx/core/widgets/download_success_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/test_result_model.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';
import '../../../core/utils/snackbar_utils.dart';

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
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _results = [];
        _isLoading = false;
        _error = 'Please log in to view results';
      });
      return;
    }

    // 1. Try to load from CACHE ONLY for immediate display
    try {
      debugPrint('[MyResults] ⚡ Fetching from CACHE first...');
      final cachedResults = await _testResultService.getTestResults(
        user.uid,
        source: Source.cache,
      );
      if (mounted && cachedResults.isNotEmpty) {
        setState(() {
          _results = cachedResults;
          _results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _isLoading = false; // Show cached data right away
        });
        debugPrint(
          '[MyResults] ⚡ Showing ${cachedResults.length} cached results',
        );
      }
    } catch (e) {
      debugPrint('[MyResults] ⚡ Initial cache fetch failed: $e');
    }

    // 2. Refresh from server (or cache+server)
    try {
      debugPrint('[MyResults] 🔄 Refreshing from server...');

      // If we still don't have results, show loading
      if (_results.isEmpty) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      // Check connectivity and show snackbar safely using addPostFrameCallback
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final connectivity = Provider.of<NetworkConnectivityProvider>(
            context,
            listen: false,
          );
          if (!connectivity.isOnline) {
            SnackbarUtils.showInfo(
              context,
              'No internet connection. Showing cached results. Please turn on internet and refresh to sync newest data.',
              duration: const Duration(seconds: 5),
            );
          }
        });
      }

      // Load results from service (which handles local/remote)
      final results = await _testResultService.getTestResults(user.uid);
      debugPrint(
        '[MyResults] ✅ Server refresh complete: ${results.length} results',
      );

      // Sort by date descending
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
          // Only show error if we have NO results at all
          if (_results.isEmpty) {
            _error = 'Failed to load results: $e';
          }
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
      // Check if file already exists
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

        // Show beautiful success dialog
        await showDownloadSuccessDialog(
          context: context,
          filePath: generatedPath,
        );
      }
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);

        final errorMessage = e.toString().contains('Permission denied')
            ? 'Storage permission denied. PDF saved to app folder instead.'
            : 'Failed to generate PDF: $e';

        SnackbarUtils.showError(context, errorMessage);
      }
    }
  }

  Future<void> _sharePdf(TestResultModel result) async {
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
        SnackbarUtils.showError(context, 'Failed to share PDF: $e');
      }
    }
  }

  /// Show confirmation dialog before hiding from view
  Future<void> _confirmDeleteResult(TestResultModel result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Result?'),
        content: Text(
          'Are you sure you want to remove the test result for ${result.profileName.isEmpty ? 'Self' : result.profileName} from your view',
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

  /// Delete a test result from Firebase
  Future<void> _deleteResult(TestResultModel result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _testResultService.deleteTestResult(user.uid, result.id);

      final index = _results.indexWhere((r) => r.id == result.id);
      if (index != -1) {
        final removedItem = _results.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(
              opacity: animation,
              child: _buildResultCard(removedItem),
            ),
          ),
          duration: const Duration(milliseconds: 300),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to delete: $e');
      }
    }
  }

  Future<void> _shareGridTracing(String? localPath, String? remoteUrl) async {
    try {
      if (localPath != null && await File(localPath).exists()) {
        await Share.shareXFiles([
          XFile(localPath),
        ], text: 'Amsler Grid Tracing');
      } else if (remoteUrl != null) {
        // Download to share
        final response = await http.get(Uri.parse(remoteUrl));
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/amsler_share.png');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Amsler Grid Tracing');
      } else {
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to load results');
        }
      }
    } catch (e) {
      debugPrint('[MyResults] Share error: $e');
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to share image: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Results'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadResults),
        ],
      ),
      body: _error != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: EyeLoader.fullScreen())
                      : _filteredResults.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadResults,
                          child: AnimatedList(
                            key: _listKey,
                            padding: const EdgeInsets.all(16),
                            initialItemCount: _filteredResults.length,
                            itemBuilder: (context, index, animation) {
                              if (index >= _filteredResults.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    child: _buildResultCard(
                                      _filteredResults[index],
                                    ),
                                  ),
                                ),
                              );
                            },
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
      color: AppColors.surface,
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
          color: isSelected
              ? (color ?? AppColors.primary)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? (color ?? AppColors.primary) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.textOnPrimary
                : AppColors.textSecondary,
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
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
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
              'No local results found.\nPlease turn on internet and\nclick refresh to fetch your data.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
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
                : AppColors.cardShadow,
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
                        'MMM dd, yyyy • h:mm a',
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
          // Results grid - Now triggers quick summary on tap
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

  void _showResultDetails(TestResultModel result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) =>
          _ResultDetailSheet(result: result, onShareImage: _shareGridTracing),
    );
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
              DateFormat('MMMM dd, yyyy â€¢ h:mm a').format(result.timestamp),
              style: const TextStyle(color: AppColors.textSecondary),
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

            // ðŸ†• Short Distance (Reading Test)
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
                if (result.amslerGridRight != null) ...[
                  _buildDetailRow(
                    'Right Eye',
                    result.amslerGridRight!.hasDistortions
                        ? 'Distortions detected'
                        : 'Normal',
                  ),
                  if (result.amslerGridRight != null)
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
                  if (result.amslerGridLeft != null)
                    _buildGridImage(
                      result.amslerGridLeft!.annotatedImagePath,
                      result.amslerGridLeft!.firebaseImageUrl,
                    ),
                ],
              ]),

            // Pelli-Robson
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

                // Fallback for legacy data
                if (prRows.isEmpty) {
                  if (pr.shortDistance != null) {
                    prRows.add(
                      _buildDetailRow(
                        'Near (Legacy)',
                        '${pr.shortDistance!.adjustedScore.toStringAsFixed(2)} log CS',
                      ),
                    );
                  }
                  if (pr.longDistance != null) {
                    prRows.add(
                      _buildDetailRow(
                        'Distance (Legacy)',
                        '${pr.longDistance!.adjustedScore.toStringAsFixed(2)} log CS',
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

            // Mobile Refractometry
            if (result.mobileRefractometry != null)
              () {
                final ref = result.mobileRefractometry!;
                return _buildSection('Mobile Refractometry', [
                  if (ref.rightEye != null)
                    _buildDetailRow(
                      'Right Eye',
                      'SPH: ${ref.rightEye!.sphere}, CYL: ${ref.rightEye!.cylinder}, AX: ${ref.rightEye!.axis}Â°',
                    ),
                  if (ref.leftEye != null)
                    _buildDetailRow(
                      'Left Eye',
                      'SPH: ${ref.leftEye!.sphere}, CYL: ${ref.leftEye!.cylinder}, AX: ${ref.leftEye!.axis}Â°',
                    ),
                  _buildDetailRow(
                    'Status',
                    ref.criticalAlert ? 'Urgent' : 'Normal',
                  ),
                ]);
              }(),

            // Questionnaire Summary
            if (result.questionnaire != null)
              _buildQuestionnaireSection(result.questionnaire!),

            // Recommendation
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
