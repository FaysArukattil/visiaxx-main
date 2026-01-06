import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/test_result_service.dart';
import '../../../data/models/test_result_model.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';

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

    try {
      final results = await _resultService.getTestResults(user.uid);
      if (mounted) {
        setState(() {
          _allResults = results;
          _groupResults();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PractitionerResults] Error loading results: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load results';
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
      return const Center(child: CircularProgressIndicator());
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No results yet'
                  : 'No results matching "$_searchQuery"',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Complete a test to see results here',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ],
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
    final timeFormat = DateFormat('h:mm a');
    final statusColor = _getStatusColor(result.overallStatus);
    final statusText = _getStatusText(result.overallStatus);

    return GestureDetector(
      onTap: () => _viewResult(result),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile avatar
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              radius: 24,
              child: Text(
                result.profileName.isNotEmpty
                    ? result.profileName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Patient info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.profileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        timeFormat.format(result.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: result.testType == 'comprehensive'
                              ? AppColors.secondary.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result.testType == 'comprehensive' ? 'Full' : 'Quick',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: result.testType == 'comprehensive'
                                ? AppColors.secondary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TestStatus status) {
    switch (status) {
      case TestStatus.normal:
        return AppColors.success;
      case TestStatus.review:
        return AppColors.warning;
      case TestStatus.urgent:
        return AppColors.error;
    }
  }

  String _getStatusText(TestStatus status) {
    switch (status) {
      case TestStatus.normal:
        return 'Normal';
      case TestStatus.review:
        return 'Review';
      case TestStatus.urgent:
        return 'Urgent';
    }
  }

  void _viewResult(TestResultModel result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuickTestResultScreen(historicalResult: result),
      ),
    );
  }
}
