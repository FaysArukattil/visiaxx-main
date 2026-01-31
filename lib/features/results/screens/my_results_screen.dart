import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visiaxx/core/widgets/download_success_dialog.dart';
import 'package:visiaxx/core/services/pdf_export_service.dart';
import 'package:visiaxx/core/services/test_result_service.dart';
import 'package:visiaxx/core/services/family_member_service.dart';
import 'package:visiaxx/core/utils/ui_utils.dart';
import 'package:visiaxx/data/models/test_result_model.dart';
import 'package:visiaxx/data/models/color_vision_result.dart';
import 'package:visiaxx/data/models/mobile_refractometry_result.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';
import 'package:visiaxx/core/extensions/theme_extension.dart';
import 'package:visiaxx/core/services/dashboard_persistence_service.dart';
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
  final DashboardPersistenceService _persistenceService =
      DashboardPersistenceService();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<TestResultModel>>? _resultsSubscription;
  bool _isInitialLoading = true; // Track first-time load
  bool _isSyncing = false; // Track background sync
  double _loadingProgress = 0.0;
  int _loadedCount = 0; // Track items loaded
  String _loadingStage =
      ''; // Track current stage (e.g., "Loading cache...", "Syncing...")

  // Pagination
  static const int _itemsPerPage = 10;
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
    _scrollController.addListener(_onScroll);

    // Run recovery check AFTER stream is established and has emitted at least once
    // // This prevents the recovery from interfering with initial data load
    // Future.delayed(const Duration(seconds: 3), () {
    //   if (mounted && _results.isNotEmpty) {
    //     _runRecoveryIfNeeded();
    //   }
    // });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _resultsSubscription?.cancel();
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
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
          _isInitialLoading = false;
          _error = 'Please log in to view results';
        });
      }
      return;
    }

    setState(() {
      _isLoading = _results.isEmpty;
      _isInitialLoading = _results.isEmpty;
      _isSyncing = _results.isNotEmpty;
      _error = null;
      _currentPage = 0;
      _hasMore = true;
      _loadingProgress = 0.0;
      _loadedCount = 0;
      _loadingStage = 'Initializing...';
    });

    // Cancel existing subscription
    await _resultsSubscription?.cancel();

    // STAGE 1: DISK LOAD (0% → 30%)
    try {
      setState(() {
        _loadingProgress = 0.05;
        _loadingStage = 'Loading cached data...';
      });

      final storedResults = await _persistenceService.getStoredResults(
        customKey: 'user_results',
      );

      setState(() => _loadingProgress = 0.15);

      final storedHidden = await _persistenceService.getStoredHiddenIds(
        customKey: 'user_results',
      );

      final filteredResults = storedResults
          .where((r) => !storedHidden.contains(r.id))
          .toList();

      if (mounted && filteredResults.isNotEmpty) {
        setState(() {
          _results = filteredResults;
          _loadedCount = filteredResults.length;
          _loadingProgress = 0.3;
          _loadingStage = 'Loaded ${filteredResults.length} from cache';
          _isLoading = false;
          _hasMore = filteredResults.length > _itemsPerPage;
        });
        debugPrint('[MyResults] ✅ Loaded ${filteredResults.length} from disk');
      }
    } catch (e) {
      debugPrint('[MyResults] ❌ Disk load error: $e');
      setState(() => _loadingProgress = 0.0);
    }

    // STAGE 2: FIRESTORE STREAM (30% → 100%)
    debugPrint('[MyResults] 🔄 Starting Firestore stream...');
    setState(() {
      _loadingProgress = 0.4;
      _loadingStage = 'Connecting to cloud...';
    });

    _resultsSubscription = _testResultService
        .getTestResultsStream(user.uid)
        .listen(
          (results) {
            _safeSetState(() {
              _results = results;
              _loadedCount = results.length;
              _loadingProgress = 1.0;
              _loadingStage = 'Synced ${results.length} results';
              _isLoading = false;
              _isInitialLoading = false;
              _isSyncing = false;
              _hasMore = results.length > _itemsPerPage;
              _error = null;
            });
            debugPrint(
              '[MyResults] ✅ Stream update: ${results.length} results',
            );

            // Save to disk
            _persistenceService.saveResults(results, customKey: 'user_results');

            // Hide progress after delay
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                setState(() {
                  _loadingProgress = 0.0;
                  _isInitialLoading = false;
                  _isSyncing = false;
                });
              }
            });
          },
          onError: (e) {
            debugPrint('[MyResults] ❌ Stream error: $e');
            _safeSetState(() {
              if (_results.isEmpty) {
                _error = 'Failed to load results';
              }
              _isLoading = false;
              _isInitialLoading = false;
              _isSyncing = false;
              _loadingProgress = 0.0;
            });
          },
        );
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

  Future<void> _runRecoveryIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      debugPrint('[MyResults] 🔧 Running orphaned results recovery check...');

      // DON'T show loading indicator - let stream handle UI updates
      final familyMemberService = FamilyMemberService();

      // Run recovery in background without blocking UI
      await familyMemberService.recoverOrphanedResults(user.uid);

      debugPrint('[MyResults] ✅ Recovery check complete');

      // DON'T reload - the stream will automatically pick up any changes
    } catch (e) {
      debugPrint('[MyResults] ⚠️ Recovery check failed: $e');
    }
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
                color: context.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: context.error,
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteResult(TestResultModel result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _testResultService.deleteTestResult(user.uid, result.id);

      // Immediate local hidden list update
      final currentHidden = await _persistenceService.getStoredHiddenIds(
        customKey: 'user_results',
      );
      if (!currentHidden.contains(result.id)) {
        await _persistenceService.saveHiddenIds([
          ...currentHidden,
          result.id,
        ], customKey: 'user_results');
      }

      setState(() {
        _results.removeWhere((r) => r.id == result.id);
      });

      // Update local cache for instant feedback
      await _persistenceService.saveResults(
        _results,
        customKey: 'user_results',
      );

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
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('My Results'),
        backgroundColor: context.scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: context.textPrimary,
        bottom: _isSyncing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  backgroundColor: context.primary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(context.primary),
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: _error != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildFilters(),

                // Loading progress bar - RIGHT AFTER FILTERS
                if (_isInitialLoading || _isSyncing)
                  _buildLoadingProgressOverlay(),

                Expanded(
                  child: _filteredResults.isEmpty && !_isInitialLoading
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
                                  child: Center(child: EyeLoader(size: 32)),
                                );
                              }

                              final result = _filteredResults[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildModernResultCard(result),
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
        color: context.scaffoldBackground,
        border: Border(
          bottom: BorderSide(
            color: context.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildFilterChip('All', 'all')),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip('Normal', 'normal', color: context.success),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip('Review', 'review', color: context.warning),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip('Urgent', 'urgent', color: context.error),
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
                    color ?? context.primary,
                    (color ?? context.primary).withValues(alpha: 0.8),
                  ],
                )
              : null,
          color: isSelected ? null : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? context.primary)
                : context.dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (color ?? context.primary).withValues(alpha: 0.25),
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
              color: isSelected ? Colors.white : context.textSecondary,
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
        statusColor = context.success;
        break;
      case TestStatus.review:
        statusColor = context.warning;
        break;
      case TestStatus.urgent:
        statusColor = context.error;
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
                ? context.primary.withValues(alpha: 0.08)
                : context.cardColor,
            isComprehensive
                ? context.primary.withValues(alpha: 0.03)
                : context.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isComprehensive
              ? context.primary.withValues(alpha: 0.3)
              : context.dividerColor.withValues(alpha: 0.3),
          width: isComprehensive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isComprehensive
                ? context.primary.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
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
                            context.primary,
                            context.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.primary.withValues(alpha: 0.3),
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
                            color: Colors.white,
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
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: context.textPrimary,
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
                                color: context.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  DateFormat(
                                    'MMM dd, yyyy • h:mm a',
                                  ).format(result.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.primary,
                                    fontWeight: FontWeight.bold,
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
                      color: Colors.white,
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
                      gradient: LinearGradient(
                        colors: [context.primary, const Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: context.primary.withValues(alpha: 0.3),
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
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'COMPREHENSIVE EXAMINATION',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    // Check if any data exists
    final hasVA =
        result.visualAcuityRight != null || result.visualAcuityLeft != null;
    final hasRefraction = result.mobileRefractometry != null;
    final hasOthers =
        result.colorVision != null ||
        result.pelliRobson != null ||
        result.amslerGridRight != null ||
        result.amslerGridLeft != null;

    if (!hasVA && !hasRefraction && !hasOthers) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No test data available',
            style: TextStyle(
              fontSize: 12,
              color: context.textPrimary.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.primary.withValues(alpha: 0.08),
            context.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.primary.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Visual Acuity
          if (hasVA) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (result.visualAcuityRight != null)
                    _buildDiagnosticItem(
                      'RIGHT EYE VA',
                      result.visualAcuityRight?.snellenScore,
                      icon: Icons.remove_red_eye_outlined,
                    ),
                  if (result.visualAcuityRight != null &&
                      result.visualAcuityLeft != null)
                    Container(
                      width: 1,
                      height: 30,
                      color: context.primary.withValues(alpha: 0.15),
                    ),
                  if (result.visualAcuityLeft != null)
                    _buildDiagnosticItem(
                      'LEFT EYE VA',
                      result.visualAcuityLeft?.snellenScore,
                      icon: Icons.remove_red_eye_outlined,
                    ),
                ],
              ),
            ),
            if (hasRefraction || hasOthers)
              Divider(
                height: 1,
                thickness: 1,
                color: context.primary.withValues(alpha: 0.05),
              ),
          ],
          // Row 2: Refraction Table
          if (hasRefraction) ...[
            _buildRefractionTable(result.mobileRefractometry!),
            if (hasOthers)
              Divider(
                height: 1,
                thickness: 1,
                color: context.primary.withValues(alpha: 0.05),
              ),
          ],
          // Row 3: Others (Per-Eye Display)
          if (hasOthers)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color Vision - Per Eye with Specific Deficiency Type
                  if (result.colorVision != null) ...[
                    Row(
                      children: [
                        // Right Eye Color Vision
                        _buildDiagnosticItem(
                          'COLOR VISION (RIGHT)',
                          result.colorVision!.rightEye.detectedType != null &&
                                  result.colorVision!.rightEye.detectedType !=
                                      DeficiencyType.none
                              ? result
                                    .colorVision!
                                    .rightEye
                                    .detectedType!
                                    .displayName
                              : (result.colorVision!.rightEye.status ==
                                        ColorVisionStatus.normal
                                    ? 'NORMAL'
                                    : result
                                          .colorVision!
                                          .rightEye
                                          .status
                                          .displayName
                                          .toUpperCase()),
                          icon: Icons.palette,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: context.primary.withValues(alpha: 0.15),
                        ),
                        // Left Eye Color Vision
                        _buildDiagnosticItem(
                          'COLOR VISION (LEFT)',
                          result.colorVision!.leftEye.detectedType != null &&
                                  result.colorVision!.leftEye.detectedType !=
                                      DeficiencyType.none
                              ? result
                                    .colorVision!
                                    .leftEye
                                    .detectedType!
                                    .displayName
                              : (result.colorVision!.leftEye.status ==
                                        ColorVisionStatus.normal
                                    ? 'NORMAL'
                                    : result
                                          .colorVision!
                                          .leftEye
                                          .status
                                          .displayName
                                          .toUpperCase()),
                          icon: Icons.palette,
                        ),
                      ],
                    ),
                    if (result.pelliRobson != null ||
                        result.amslerGridRight != null ||
                        result.amslerGridLeft != null)
                      const SizedBox(height: 8),
                  ],
                  // Contrast Sensitivity - Per Eye
                  if (result.pelliRobson != null) ...[
                    Row(
                      children: [
                        // Right Eye Contrast
                        if (result.pelliRobson!.rightEye != null)
                          _buildDiagnosticItem(
                            'CONTRAST (RIGHT)',
                            '${result.pelliRobson!.rightEye!.longDistance?.adjustedScore.toStringAsFixed(1) ?? '0.0'} CS',
                            icon: Icons.contrast,
                          ),
                        if (result.pelliRobson!.rightEye != null &&
                            result.pelliRobson!.leftEye != null)
                          Container(
                            width: 1,
                            height: 30,
                            color: context.primary.withValues(alpha: 0.15),
                          ),
                        // Left Eye Contrast
                        if (result.pelliRobson!.leftEye != null)
                          _buildDiagnosticItem(
                            'CONTRAST (LEFT)',
                            '${result.pelliRobson!.leftEye!.longDistance?.adjustedScore.toStringAsFixed(1) ?? '0.0'} CS',
                            icon: Icons.contrast,
                          ),
                      ],
                    ),
                    if (result.amslerGridRight != null ||
                        result.amslerGridLeft != null)
                      const SizedBox(height: 8),
                  ],
                  // Amsler Grid - Per Eye
                  if (result.amslerGridRight != null ||
                      result.amslerGridLeft != null) ...[
                    Row(
                      children: [
                        // Right Eye Amsler
                        if (result.amslerGridRight != null)
                          _buildDiagnosticItem(
                            'AMSLER (RIGHT)',
                            result.amslerGridRight!.hasDistortions
                                ? 'DISTORTED'
                                : 'NORMAL',
                            icon: Icons.grid_on,
                          ),
                        if (result.amslerGridRight != null &&
                            result.amslerGridLeft != null)
                          Container(
                            width: 1,
                            height: 30,
                            color: context.primary.withValues(alpha: 0.15),
                          ),
                        // Left Eye Amsler
                        if (result.amslerGridLeft != null)
                          _buildDiagnosticItem(
                            'AMSLER (LEFT)',
                            result.amslerGridLeft!.hasDistortions
                                ? 'DISTORTED'
                                : 'NORMAL',
                            icon: Icons.grid_on,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(String label, String? value, {IconData? icon}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: context.textPrimary.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 10, color: context.primary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value ?? 'N/A',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefractionTable(MobileRefractometryResult result) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: context.primary.withValues(alpha: 0.02),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 30),
                Expanded(child: _TableHeader('SPH')),
                Expanded(child: _TableHeader('CYL')),
                Expanded(child: _TableHeader('AXIS')),
              ],
            ),
          ),
          if (result.rightEye != null)
            _RefractionRow('Right', result.rightEye!),
          if (result.leftEye != null) _RefractionRow('Left', result.leftEye!),
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
                ? LinearGradient(
                    colors: [context.primary, const Color(0xFF6366F1)],
                  )
                : null,
            color: isPrimary ? null : context.scaffoldBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPrimary ? Colors.transparent : context.dividerColor,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: context.primary.withValues(alpha: 0.3),
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
                color: isPrimary
                    ? Colors.white
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? Colors.white : context.textPrimary,
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
    final color = isDelete ? context.error : context.primary;

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
                color: context.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 64, color: context.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimary.withValues(alpha: 0.6),
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
                    context.primary.withValues(alpha: 0.15),
                    context.primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.visibility_outlined,
                size: 80,
                color: context.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Results Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No test results found.\nPull down to refresh or start a new test.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildSyncStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: context.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _loadingProgress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutSine,
        builder: (context, value, child) {
          return Row(
            children: [
              const EyeLoader(size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Synchronizing results...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Updating latest tests for all members',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value > 0 ? value : null,
                        backgroundColor: context.primary.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.primary,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
              if (value > 0 && value < 1.0)
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: context.primary,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingProgressOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.primary.withValues(alpha: 0.08),
            context.primary.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: context.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const EyeLoader(size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loadingStage.isEmpty
                          ? (_loadingProgress < 0.3
                                ? 'Loading cached data...'
                                : 'Syncing with cloud...')
                          : _loadingStage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loadedCount > 0
                          ? '$_loadedCount ${_loadedCount == 1 ? 'result' : 'results'} loaded'
                          : 'Please wait...',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(_loadingProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: context.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _loadingProgress > 0 ? _loadingProgress : null,
              backgroundColor: context.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(context.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _lastUpdate;
  void _safeSetState(VoidCallback fn) {
    final now = DateTime.now();
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!).inMilliseconds < 100) {
      // Skip update if too soon after last one
      return;
    }
    _lastUpdate = now;
    if (mounted) {
      setState(fn);
    }
  }
}

class _TableCell extends StatelessWidget {
  final String value;
  const _TableCell(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.textPrimary,
      ),
    );
  }
}

class _RefractionRow extends StatelessWidget {
  final String eye;
  final MobileRefractometryEyeResult data;
  const _RefractionRow(this.eye, this.data);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              eye,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: context.primary,
              ),
            ),
          ),
          Expanded(child: _TableCell(data.sphere)),
          Expanded(child: _TableCell(data.cylinder)),
          Expanded(child: _TableCell('${data.axis}')),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  const _TableHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w800,
        color: context.textSecondary,
      ),
    );
  }
}
