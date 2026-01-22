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

/// Optimized My Results screen with better performance and modern UI
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
  final ScrollController _scrollController = ScrollController();

  // Pagination
  static const int _itemsPerPage = 10;
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoading && _hasMore) {
        _loadMoreResults();
      }
    }
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

    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      debugPrint('[MyResults] 📊 Loading results for user: ${user.uid}');

      // Strategy: Try server first with short timeout, then fallback to cache
      List<TestResultModel> results = [];

      try {
        // Try server with 3-second timeout
        debugPrint('[MyResults] 🌐 Attempting server fetch...');
        results = await _testResultService
            .getTestResults(user.uid, source: Source.server)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint(
                  '[MyResults] ⏱️ Server timeout, falling back to cache',
                );
                return [];
              },
            );

        if (results.isNotEmpty) {
          debugPrint(
            '[MyResults] ✅ Loaded ${results.length} results from server',
          );
        }
      } catch (serverError) {
        debugPrint('[MyResults] ⚠️ Server fetch failed: $serverError');
      }

      // If server failed or timed out, try cache
      if (results.isEmpty) {
        debugPrint('[MyResults] 💾 Loading from cache...');
        try {
          results = await _testResultService.getTestResults(
            user.uid,
            source: Source.cache,
          );
          debugPrint(
            '[MyResults] ✅ Loaded ${results.length} results from cache',
          );
        } catch (cacheError) {
          debugPrint('[MyResults] ❌ Cache fetch also failed: $cacheError');
        }
      }

      // Sort results
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _hasMore = results.length > _itemsPerPage;

          if (results.isEmpty) {
            _error = null; // Don't show error if just no results yet
          }
        });
      }

      // Background refresh from server if we used cache
      if (results.isNotEmpty) {
        _backgroundRefresh(user.uid);
      }
    } catch (e) {
      debugPrint('[MyResults] ❌ ERROR loading results: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load results';
          _isLoading = false;
        });
      }
    }
  }

  /// Background refresh from server (doesn't block UI)
  Future<void> _backgroundRefresh(String userId) async {
    try {
      debugPrint('[MyResults] 🔄 Background refresh from server...');
      final freshResults = await _testResultService
          .getTestResults(userId, source: Source.server)
          .timeout(const Duration(seconds: 5));

      if (mounted && freshResults.isNotEmpty) {
        freshResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Only update if data actually changed
        if (freshResults.length != _results.length) {
          setState(() {
            _results = freshResults;
            _hasMore = freshResults.length > _itemsPerPage;
          });
          debugPrint(
            '[MyResults] ✅ Background refresh complete - ${freshResults.length} results',
          );
        }
      }
    } catch (e) {
      debugPrint('[MyResults] ⚠️ Background refresh failed (non-critical): $e');
      // Don't show error - this is background operation
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _currentPage++;
    });
  }

  List<TestResultModel> get _filteredResults {
    var filtered = _selectedFilter == 'all'
        ? _results
        : _results.where((r) {
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

    // Apply pagination
    final endIndex = (_currentPage + 1) * _itemsPerPage;
    return filtered.take(endIndex.clamp(0, filtered.length)).toList();
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

  Future<bool?> _confirmDeleteResult(TestResultModel result) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Remove Result?', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the test result for ${result.profileName.isEmpty ? 'Self' : result.profileName}?\n\nThis action cannot be undone.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground({required bool isLeft}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [AppColors.error, AppColors.error.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Align(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: AppColors.white,
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteResult(TestResultModel result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _testResultService.deleteTestResult(user.uid, result.id);
      setState(() {
        _results.removeWhere((r) => r.id == result.id);
      });

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Result removed successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Results'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _error != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: _isLoading && _results.isEmpty
                      ? const Center(child: EyeLoader.fullScreen())
                      : _filteredResults.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadResults,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount:
                                _filteredResults.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _filteredResults.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final result = _filteredResults[index];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Dismissible(
                                  key: Key(result.id),
                                  direction: DismissDirection.horizontal,
                                  confirmDismiss: (direction) async {
                                    return await _confirmDeleteResult(result);
                                  },
                                  onDismissed: (direction) {
                                    _deleteResult(result);
                                  },
                                  background: _buildSwipeBackground(
                                    isLeft: true,
                                  ),
                                  secondaryBackground: _buildSwipeBackground(
                                    isLeft: false,
                                  ),
                                  child: _buildModernResultCard(result),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildFilterChip('All', 'all')),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              'Normal',
              'normal',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              'Review',
              'review',
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip('Urgent', 'urgent', color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = value == _selectedFilter;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    color ?? AppColors.primary,
                    (color ?? AppColors.primary).withValues(alpha: 0.8),
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? AppColors.primary)
                : AppColors.border.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (color ?? AppColors.primary).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildModernResultCard(TestResultModel result) {
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isComprehensive
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            isComprehensive
                ? AppColors.primary.withValues(alpha: 0.03)
                : AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isComprehensive
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.3),
          width: isComprehensive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isComprehensive
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  QuickTestResultScreen(historicalResult: result),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Avatar and Name
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          result.profileName.isNotEmpty
                              ? result.profileName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                            fontSize: 20,
                          ),
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
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  DateFormat(
                                    'MMM dd, yyyy • h:mm a',
                                  ).format(result.timestamp),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Row 2: Status Badge (Full Width)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    result.overallStatus.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Row 3: Full Examination Badge
                if (isComprehensive) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'COMPREHENSIVE EXAMINATION',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Test Results Grid
                _buildTestResultsGrid(result),

                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'View',
                        icon: Icons.visibility_rounded,
                        isPrimary: false,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                QuickTestResultScreen(historicalResult: result),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        label: 'PDF',
                        icon: Icons.download_rounded,
                        isPrimary: true,
                        onTap: () => _downloadPdf(result),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.share_rounded,
                      onTap: () => _sharePdf(result),
                    ),
                    const SizedBox(width: 6),
                    _buildIconButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: () async {
                        final confirmed = await _confirmDeleteResult(result);
                        if (confirmed == true && mounted) {
                          await _deleteResult(result);
                        }
                      },
                      isDelete: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestResultsGrid(TestResultModel result) {
    final List<Widget> testRows = [];

    // Visual Acuity Row (only if data exists)
    if (result.visualAcuityRight != null || result.visualAcuityLeft != null) {
      testRows.add(
        Row(
          children: [
            if (result.visualAcuityRight != null)
              _buildResultItem(
                'RIGHT VA',
                result.visualAcuityRight!.snellenScore,
                Icons.remove_red_eye_outlined,
              ),
            if (result.visualAcuityRight != null &&
                result.visualAcuityLeft != null)
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.border,
              ),
            if (result.visualAcuityLeft != null)
              _buildResultItem(
                'LEFT VA',
                result.visualAcuityLeft!.snellenScore,
                Icons.remove_red_eye_outlined,
              ),
          ],
        ),
      );
    }

    // Color Vision Row (with detailed status per eye)
    if (result.colorVision != null) {
      if (testRows.isNotEmpty) testRows.add(const SizedBox(height: 12));

      final rightStatus = _getColorVisionStatus(result.colorVision!.rightEye);
      final leftStatus = _getColorVisionStatus(result.colorVision!.leftEye);

      testRows.add(
        Row(
          children: [
            _buildResultItem('COLOR (R)', rightStatus, Icons.palette_rounded),
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.border,
            ),
            _buildResultItem('COLOR (L)', leftStatus, Icons.palette_rounded),
          ],
        ),
      );
    }

    // Contrast Sensitivity or Amsler Grid Row
    if (result.testType == 'comprehensive' && result.pelliRobson != null) {
      if (testRows.isNotEmpty) testRows.add(const SizedBox(height: 12));

      final rightContrast =
          result.pelliRobson!.rightEye?.longDistance?.adjustedScore;
      final leftContrast =
          result.pelliRobson!.leftEye?.longDistance?.adjustedScore;

      if (rightContrast != null || leftContrast != null) {
        testRows.add(
          Row(
            children: [
              if (rightContrast != null)
                _buildResultItem(
                  'CONTRAST (R)',
                  '${rightContrast.toStringAsFixed(1)} CS',
                  Icons.contrast_rounded,
                ),
              if (rightContrast != null && leftContrast != null)
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: AppColors.border,
                ),
              if (leftContrast != null)
                _buildResultItem(
                  'CONTRAST (L)',
                  '${leftContrast.toStringAsFixed(1)} CS',
                  Icons.contrast_rounded,
                ),
            ],
          ),
        );
      }
    } else if (result.amslerGridRight != null ||
        result.amslerGridLeft != null) {
      if (testRows.isNotEmpty) testRows.add(const SizedBox(height: 12));

      testRows.add(
        Row(
          children: [
            if (result.amslerGridRight != null)
              _buildResultItem(
                'AMSLER (R)',
                result.amslerGridRight!.hasDistortions ? 'Distorted' : 'Normal',
                Icons.grid_on_rounded,
              ),
            if (result.amslerGridRight != null && result.amslerGridLeft != null)
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.border,
              ),
            if (result.amslerGridLeft != null)
              _buildResultItem(
                'AMSLER (L)',
                result.amslerGridLeft!.hasDistortions ? 'Distorted' : 'Normal',
                Icons.grid_on_rounded,
              ),
          ],
        ),
      );
    }

    // If no test data available, show a message
    if (testRows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No test data available',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(children: testRows),
    );
  }

  String _getColorVisionStatus(dynamic eyeResult) {
    if (eyeResult == null) return 'N/A';

    // Try to get detected type first
    if (eyeResult.detectedType != null &&
        eyeResult.detectedType.toString() != 'DeficiencyType.none') {
      final type = eyeResult.detectedType.toString().split('.').last;
      switch (type) {
        case 'protan':
          return 'Protan';
        case 'deutan':
          return 'Deutan';
        case 'tritan':
          return 'Tritan';
        default:
          break;
      }
    }

    // Fall back to status
    final status = eyeResult.status?.toString().split('.').last ?? 'unknown';
    switch (status) {
      case 'normal':
        return 'Normal';
      case 'mild':
        return 'Mild';
      case 'moderate':
        return 'Moderate';
      case 'severe':
        return 'Severe';
      default:
        return 'Check';
    }
  }

  Widget _buildResultItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF6366F1)],
                  )
                : null,
            color: isPrimary ? null : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPrimary ? Colors.transparent : AppColors.border,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isPrimary ? AppColors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPrimary
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isDelete = false,
  }) {
    final color = isDelete ? AppColors.error : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: color),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error loading results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.visibility_outlined,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Results Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No test results found.\nPull down to refresh or start a new test.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/quick-test'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Quick Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
