import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/dashboard_cache_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/download_success_dialog.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/models/patient_model.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PractitionerDashboardScreen extends StatefulWidget {
  const PractitionerDashboardScreen({super.key});

  @override
  State<PractitionerDashboardScreen> createState() =>
      _PractitionerDashboardScreenState();
}

class _PractitionerDashboardScreenState
    extends State<PractitionerDashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  final PatientService _patientService = PatientService();
  final PdfExportService _pdfService = PdfExportService();
  final DashboardCacheService _cache = DashboardCacheService();

  bool _isInitialLoading = true;
  bool _isFilterLoading = false;
  String _selectedPeriod = 'all';
  List<String> _selectedConditions = [];
  Map<String, dynamic> _statistics = {};
  List<TestResultModel> _filteredResults = [];
  List<PatientModel> _patients = [];
  Map<DateTime, int> _dailyCounts = {};

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Date filter state
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isInitialLoading = true);

    try {
      final cachedData = _cache.getCachedData();

      if (cachedData != null) {
        debugPrint('[Dashboard] ⚡ Loading from cache');
        _applyCachedData(cachedData);
        setState(() => _isInitialLoading = false);
        return;
      }

      final results = await Future.wait([
        _dbService.getTestStatistics(practitionerId: user.uid),
        _dbService.getPractitionerTestResults(practitionerId: user.uid),
        _patientService.getPatients(user.uid),
        _dbService.getDailyTestCounts(practitionerId: user.uid, days: 30),
      ]);

      final allStats = results[0] as Map<String, dynamic>;
      final allResults = results[1] as List<TestResultModel>;
      final patients = results[2] as List<PatientModel>;
      final dailyCounts = results[3] as Map<DateTime, int>;

      _cache.cacheData(
        statistics: allStats,
        allResults: allResults,
        patients: patients,
        dailyCounts: dailyCounts,
      );

      if (mounted) {
        _applyCachedData({
          'statistics': allStats,
          'allResults': allResults,
          'patients': patients,
          'dailyCounts': dailyCounts,
        });
        setState(() => _isInitialLoading = false);
      }
    } catch (e) {
      debugPrint('[Dashboard] ❌ Error loading data: $e');
      if (mounted) {
        setState(() => _isInitialLoading = false);
        SnackbarUtils.showError(context, 'Failed to load dashboard data');
      }
    }
  }

  void _applyCachedData(Map<String, dynamic> data) {
    _statistics = data['statistics'] as Map<String, dynamic>;
    final allResults = data['allResults'] as List<TestResultModel>;
    _patients = data['patients'] as List<PatientModel>;
    _dailyCounts = data['dailyCounts'] as Map<DateTime, int>;

    _applyFilters(allResults);
  }

  void _applyFilters(List<TestResultModel> allResults) {
    final now = DateTime.now();
    DateTime? startDate;

    switch (_selectedPeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'all':
        startDate = null;
        break;
    }

    var filtered = startDate == null
        ? allResults
        : allResults.where((r) => r.timestamp.isAfter(startDate!)).toList();

    // Apply custom date range if set
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((r) {
        if (_startDate != null && r.timestamp.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null &&
            r.timestamp.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      }).toList();
    }

    if (_selectedConditions.isNotEmpty) {
      filtered = filtered.where((r) {
        final conditions = _getAllResultConditions(r);
        return _selectedConditions.any(
          (selected) => conditions.contains(selected),
        );
      }).toList();
    }

    setState(() {
      _filteredResults = filtered;
      _calculateFilteredStats();
    });
  }

  void _calculateFilteredStats() {
    final statusCounts = <String, int>{};
    final conditionCounts = <String, int>{};
    final uniquePatients = <String>{};

    for (final result in _filteredResults) {
      statusCounts[result.overallStatus.label] =
          (statusCounts[result.overallStatus.label] ?? 0) + 1;

      final conditions = _getAllResultConditions(result);
      for (final condition in conditions) {
        conditionCounts[condition] = (conditionCounts[condition] ?? 0) + 1;
      }

      uniquePatients.add(result.profileId);
    }

    _statistics = {
      'totalTests': _filteredResults.length,
      'uniquePatients': uniquePatients.length,
      'statusCounts': statusCounts,
      'conditionCounts': conditionCounts,
    };
  }

  List<String> _getAllResultConditions(TestResultModel result) {
    final conditions = <String>[];

    if (result.mobileRefractometry != null) {
      final rightSphere =
          double.tryParse(
            result.mobileRefractometry!.rightEye?.sphere ?? '0',
          ) ??
          0;
      final leftSphere =
          double.tryParse(result.mobileRefractometry!.leftEye?.sphere ?? '0') ??
          0;
      final rightCyl =
          double.tryParse(
            result.mobileRefractometry!.rightEye?.cylinder ?? '0',
          ) ??
          0;
      final leftCyl =
          double.tryParse(
            result.mobileRefractometry!.leftEye?.cylinder ?? '0',
          ) ??
          0;

      final worseSphere = rightSphere.abs() > leftSphere.abs()
          ? rightSphere
          : leftSphere;
      final worseCyl = rightCyl.abs() > leftCyl.abs() ? rightCyl : leftCyl;

      if (worseCyl.abs() >= 0.75) conditions.add('Astigmatism');
      if (worseSphere < -0.50) conditions.add('Myopia');
      if (worseSphere > 0.50) conditions.add('Hyperopia');

      final rightAdd =
          double.tryParse(
            result.mobileRefractometry!.rightEye?.addPower ?? '0',
          ) ??
          0;
      final leftAdd =
          double.tryParse(
            result.mobileRefractometry!.leftEye?.addPower ?? '0',
          ) ??
          0;
      if (rightAdd > 0.75 || leftAdd > 0.75) conditions.add('Presbyopia');
    }

    final rightLogMAR = result.visualAcuityRight?.logMAR ?? 0;
    final leftLogMAR = result.visualAcuityLeft?.logMAR ?? 0;
    final worseLogMAR = rightLogMAR > leftLogMAR ? rightLogMAR : leftLogMAR;

    if (worseLogMAR > 0.3) conditions.add('Vision Impairment');

    if (result.colorVision != null && !result.colorVision!.isNormal) {
      conditions.add('Color Vision Deficiency');
    }

    if ((result.amslerGridRight?.hasDistortions ?? false) ||
        (result.amslerGridLeft?.hasDistortions ?? false)) {
      conditions.add('Macular Issue');

      final rightDistortions =
          result.amslerGridRight?.distortionPoints.length ?? 0;
      final leftDistortions =
          result.amslerGridLeft?.distortionPoints.length ?? 0;
      if (rightDistortions >= 5 || leftDistortions >= 5) {
        conditions.add('Possible Cataract');
      }
    }

    if (result.pelliRobson != null && result.pelliRobson!.needsReferral) {
      conditions.add('Low Contrast Sensitivity');
    }

    if (conditions.isEmpty) conditions.add('Normal');

    return conditions;
  }

  String _getPrimaryCondition(TestResultModel result) {
    final conditions = _getAllResultConditions(result);
    if (conditions.contains('Possible Cataract')) return 'Possible Cataract';
    if (conditions.contains('Macular Issue')) return 'Macular Issue';
    if (conditions.contains('Myopia')) return 'Myopia';
    if (conditions.contains('Hyperopia')) return 'Hyperopia';
    if (conditions.contains('Astigmatism')) return 'Astigmatism';
    if (conditions.contains('Presbyopia')) return 'Presbyopia';
    if (conditions.contains('Color Vision Deficiency'))
      return 'Color Vision Deficiency';
    if (conditions.contains('Vision Impairment')) return 'Vision Impairment';
    if (conditions.contains('Low Contrast Sensitivity'))
      return 'Low Contrast Sensitivity';
    return 'Normal';
  }

  Future<void> _changeFilter(String period, List<String> conditions) async {
    if (period == _selectedPeriod &&
        conditions.toSet().difference(_selectedConditions.toSet()).isEmpty &&
        _selectedConditions.toSet().difference(conditions.toSet()).isEmpty) {
      return;
    }

    setState(() {
      _selectedPeriod = period;
      _selectedConditions = conditions;
      _isFilterLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    final cachedData = _cache.getCachedData();
    if (cachedData != null) {
      final allResults = cachedData['allResults'] as List<TestResultModel>;
      _applyFilters(allResults);
    }

    setState(() => _isFilterLoading = false);
  }

  Future<void> _showDatePicker() async {
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    bool isSelectingStartDate = true;
    bool isRangeMode = true; // New: Track if user wants range or single date

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                // Header with clear and done buttons
                Row(
                  children: [
                    // Clear button
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          tempStartDate = null;
                          tempEndDate = null;
                          isSelectingStartDate = true;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),

                    // Title (centered and flexible)
                    Expanded(
                      child: Text(
                        'Select Date',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Done button
                    TextButton.icon(
                      onPressed: () {
                        // Validate dates before applying
                        if (isRangeMode) {
                          if (tempStartDate != null && tempEndDate != null) {
                            if (tempStartDate!.isAfter(tempEndDate!)) {
                              SnackbarUtils.showError(
                                context,
                                'Start date must be before end date',
                              );
                              return;
                            }
                          }
                        }

                        setState(() {
                          _startDate = tempStartDate;
                          _endDate = isRangeMode ? tempEndDate : tempStartDate;
                        });
                        Navigator.pop(context);
                        final cachedData = _cache.getCachedData();
                        if (cachedData != null) {
                          _applyFilters(cachedData['allResults']);
                        }
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Done'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Mode selector: Range or Single Date
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isRangeMode = true;
                              isSelectingStartDate = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isRangeMode
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Range',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isRangeMode
                                    ? AppColors.white
                                    : AppColors.textSecondary,
                                fontWeight: isRangeMode
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isRangeMode = false;
                              isSelectingStartDate = true;
                              tempEndDate = tempStartDate;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isRangeMode
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Single Date',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !isRangeMode
                                    ? AppColors.white
                                    : AppColors.textSecondary,
                                fontWeight: !isRangeMode
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Date selection indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (isRangeMode)
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateDisplay(
                                label: 'From Date',
                                date: tempStartDate,
                                isActive: isSelectingStartDate,
                                onTap: () {
                                  setModalState(() {
                                    isSelectingStartDate = true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.arrow_forward,
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateDisplay(
                                label: 'To Date',
                                date: tempEndDate,
                                isActive: !isSelectingStartDate,
                                onTap: () {
                                  setModalState(() {
                                    isSelectingStartDate = false;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        _buildDateDisplay(
                          label: 'Selected Date',
                          date: tempStartDate,
                          isActive: true,
                          onTap: () {},
                        ),
                      if (isRangeMode &&
                          tempStartDate != null &&
                          tempEndDate != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${_calculateDaysBetween(tempStartDate!, tempEndDate!)} days selected',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Instruction text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isRangeMode
                              ? (isSelectingStartDate
                                    ? 'Select the start date of your range'
                                    : 'Select the end date of your range')
                              : 'Select a single date to view tests',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Calendar picker
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: AppColors.white,
                          surface: AppColors.surface,
                          onSurface: AppColors.textPrimary,
                        ),
                      ),
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          primaryColor: AppColors.primary,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: isRangeMode
                              ? (isSelectingStartDate
                                    ? (tempStartDate ?? DateTime.now())
                                    : (tempEndDate ?? DateTime.now()))
                              : (tempStartDate ?? DateTime.now()),
                          minimumDate: DateTime(2020, 1, 1),
                          maximumDate: DateTime.now(),
                          onDateTimeChanged: (date) {
                            setModalState(() {
                              if (isRangeMode) {
                                if (isSelectingStartDate) {
                                  tempStartDate = date;
                                  // Auto-set end date if it's before the new start date
                                  if (tempEndDate == null ||
                                      tempEndDate!.isBefore(date)) {
                                    tempEndDate = date;
                                  }
                                  // Auto advance to end date selection
                                  Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () {
                                      if (mounted) {
                                        setModalState(() {
                                          isSelectingStartDate = false;
                                        });
                                      }
                                    },
                                  );
                                } else {
                                  // Only validate and prevent invalid selection
                                  if (tempStartDate != null &&
                                      date.isBefore(tempStartDate!)) {
                                    // Don't update - prevent invalid selection
                                    return;
                                  } else {
                                    tempEndDate = date;
                                  }
                                }
                              } else {
                                // Single date mode
                                tempStartDate = date;
                                tempEndDate = date;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateDisplay({
    required String label,
    required DateTime? date,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive
                    ? AppColors.white.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? DateFormat('MMM dd, yyyy').format(date)
                  : 'Not selected',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? AppColors.white
                    : (date != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateDaysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }

  Future<String?> _showDownloadOptionsDialog() async {
    final totalResults = _cache.getCachedData()?['allResults']?.length ?? 0;
    final filteredCount = _filteredResults.length;
    final hasFilters =
        _selectedPeriod != 'all' ||
        _selectedConditions.isNotEmpty ||
        _startDate != null ||
        _endDate != null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.download, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Download PDFs'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose which reports to download:',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Download All Option
            _buildDownloadOption(
              icon: Icons.select_all,
              title: 'Download All Reports',
              subtitle: '$totalResults total reports',
              value: 'all',
              isRecommended: !hasFilters,
            ),

            const SizedBox(height: 12),

            // Download Filtered Option
            _buildDownloadOption(
              icon: Icons.filter_alt,
              title: 'Download Filtered Reports',
              subtitle: _getFilterDescription(filteredCount),
              value: 'filtered',
              isRecommended: hasFilters,
              isEnabled: filteredCount > 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    bool isRecommended = false,
    bool isEnabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? () => Navigator.pop(context, value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEnabled
                ? (isRecommended
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.background)
                : AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecommended && isEnabled
                  ? AppColors.primary
                  : AppColors.border,
              width: isRecommended ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? AppColors.primary : AppColors.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isEnabled
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 6),
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
                              'RECOMMENDED',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isEnabled
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFilterDescription(int count) {
    final filters = <String>[];

    if (_selectedPeriod != 'all') {
      filters.add(_selectedPeriod.toUpperCase());
    }

    if (_startDate != null || _endDate != null) {
      if (_startDate != null && _endDate != null) {
        filters.add(
          '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}',
        );
      } else if (_startDate != null) {
        filters.add('From ${DateFormat('MMM d').format(_startDate!)}');
      } else if (_endDate != null) {
        filters.add('Until ${DateFormat('MMM d').format(_endDate!)}');
      }
    }

    if (_selectedConditions.isNotEmpty) {
      if (_selectedConditions.length == 1) {
        filters.add(_selectedConditions.first);
      } else {
        filters.add('${_selectedConditions.length} conditions');
      }
    }

    final filterText = filters.isNotEmpty
        ? filters.join(' • ')
        : 'Current view';
    return '$count reports • $filterText';
  }

  Future<void> _downloadAllPDFs() async {
    // Show download options dialog
    final choice = await _showDownloadOptionsDialog();

    if (choice == null) return; // User cancelled

    // Determine which results to download
    List<TestResultModel> resultsToDownload;
    String folderName;

    if (choice == 'all') {
      final cachedData = _cache.getCachedData();
      if (cachedData == null) {
        SnackbarUtils.showError(context, 'No data available');
        return;
      }
      resultsToDownload = cachedData['allResults'] as List<TestResultModel>;
      folderName = 'All_Reports';
    } else {
      // Download filtered results
      if (_filteredResults.isEmpty) {
        SnackbarUtils.showInfo(context, 'No filtered results to download');
        return;
      }
      resultsToDownload = _filteredResults;
      folderName = _getPeriodFolderName();
    }

    if (resultsToDownload.isEmpty) {
      SnackbarUtils.showInfo(context, 'No results to download');
      return;
    }

    // Check permissions for Android
    if (Platform.isAndroid) {
      PermissionStatus status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
      if (status.isPermanentlyDenied) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Permission Required'),
            content: const Text(
              'Storage permission is needed to download PDFs. Please enable it in settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (shouldOpen == true) await openAppSettings();
        return;
      }
    }

    if (!mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Downloading ${resultsToDownload.length} PDFs...'),
              const SizedBox(height: 8),
              Text(
                choice == 'all' ? 'All reports' : 'Filtered reports',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final baseDir = await _getDownloadDirectory();
      final targetDir = Directory(
        '${baseDir.path}/Visiaxx_Reports/$folderName',
      );

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      int successCount = 0;
      for (final result in resultsToDownload) {
        try {
          final pdfBytes = await _pdfService.generatePdfBytes(result);
          final name = result.profileName.replaceAll(
            RegExp(r'[^a-zA-Z0-9]'),
            '_',
          );
          final age = result.profileAge?.toString() ?? 'NA';
          final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
          final timeStr = DateFormat('HH-mm').format(result.timestamp);
          final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';

          final file = File('${targetDir.path}/$filename');
          await file.writeAsBytes(pdfBytes);
          successCount++;
        } catch (e) {
          debugPrint('[Dashboard] Failed to save PDF: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        _showDownloadSuccessDialog(successCount, targetDir.path);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarUtils.showError(context, 'Failed to download PDFs: $e');
      }
    }
  }

  void _showDownloadSuccessDialog(int count, String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Download Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully downloaded $count PDFs'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
      final altDir = Directory('/storage/emulated/0/Downloads');
      if (await altDir.exists()) return altDir;
      final externalDir = await getExternalStorageDirectory();
      return externalDir ?? await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  String _getPeriodFolderName() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        return DateFormat('yyyy-MM-dd').format(now);
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return 'Week_${DateFormat('yyyy-MM-dd').format(weekStart)}';
      case 'month':
        return DateFormat('yyyy-MM').format(now);
      default:
        return 'All_Reports';
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      SnackbarUtils.showError(context, 'Cannot make call');
    }
  }

  Future<void> _downloadPdf(TestResultModel result) async {
    try {
      final String filePath = await _pdfService.getExpectedFilePath(result);
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

      final String generatedPath = await _pdfService.generateAndDownloadPdf(
        result,
      );

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

      final String filePath = await _pdfService.generateAndDownloadPdf(result);

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

  void _showResultDetails(TestResultModel result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuickTestResultScreen(historicalResult: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _cache.clearCache();
              _loadDashboardData();
            },
          ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(child: EyeLoader.fullScreen())
          : RefreshIndicator(
              onRefresh: () async {
                _cache.clearCache();
                await _loadDashboardData();
              },
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPeriodSelector(),
                        const SizedBox(height: 16),
                        _buildStatisticsCards(),
                        const SizedBox(height: 20),
                        _buildTestGraph(),
                        const SizedBox(height: 20),
                        _buildConditionBreakdown(),
                        const SizedBox(height: 20),
                        _buildRecentResults(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                  if (_isFilterLoading)
                    Positioned.fill(
                      child: Container(
                        color: AppColors.black.withValues(alpha: 0.3),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: _buildDownloadButton(),
    );
  }

  Widget _buildDownloadButton() {
    final cachedData = _cache.getCachedData();
    final totalResults = cachedData?['allResults']?.length ?? 0;
    final hasFilters =
        _selectedPeriod != 'all' ||
        _selectedConditions.isNotEmpty ||
        _startDate != null ||
        _endDate != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _downloadAllPDFs,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download, color: AppColors.white, size: 20),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFilters ? 'Download PDFs' : 'Download All',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_filteredResults.length} / $totalResults',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                    ] else
                      Text(
                        '$totalResults reports',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
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

  Widget _buildPeriodSelector() {
    final hasDateFilter = _startDate != null || _endDate != null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _buildPeriodButton('Today', 'today'),
                    _buildPeriodButton('Week', 'week'),
                    _buildPeriodButton('Month', 'month'),
                    _buildPeriodButton('All', 'all'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: hasDateFilter
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasDateFilter ? AppColors.primary : AppColors.border,
                  width: hasDateFilter ? 2 : 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  hasDateFilter ? Icons.date_range : Icons.calendar_today,
                  color: hasDateFilter
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                onPressed: _showDatePicker,
                tooltip: 'Custom Date Range',
              ),
            ),
          ],
        ),

        // Show selected date range
        if (hasDateFilter) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    size: 16,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom Date Range',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateRange(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.error,
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    final cachedData = _cache.getCachedData();
                    if (cachedData != null) {
                      _applyFilters(cachedData['allResults']);
                    }
                  },
                  tooltip: 'Clear date filter',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateRange() {
    if (_startDate != null && _endDate != null) {
      // Check if it's a single date
      if (_startDate!.year == _endDate!.year &&
          _startDate!.month == _endDate!.month &&
          _startDate!.day == _endDate!.day) {
        return DateFormat('MMM d, yyyy').format(_startDate!);
      }

      // It's a range
      final isSameMonth =
          _startDate!.month == _endDate!.month &&
          _startDate!.year == _endDate!.year;
      if (isSameMonth) {
        return '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('d, yyyy').format(_endDate!)}';
      }
      return '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}';
    } else if (_startDate != null) {
      return 'From ${DateFormat('MMM d, yyyy').format(_startDate!)}';
    } else if (_endDate != null) {
      return 'Until ${DateFormat('MMM d, yyyy').format(_endDate!)}';
    }
    return 'Select dates';
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeFilter(value, _selectedConditions),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final totalTests = _statistics['totalTests'] ?? 0;
    final uniquePatients = _statistics['uniquePatients'] ?? 0;
    final statusCounts = _statistics['statusCounts'] as Map<String, int>? ?? {};

    return Column(
      children: [
        // First Row: Total Tests & Patients
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Tests',
                '$totalTests',
                Icons.assessment_outlined,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Patients',
                '$uniquePatients',
                Icons.people_outline,
                AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second Row: Review & Urgent
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Review',
                '${statusCounts['Review'] ?? 0}',
                Icons.visibility_outlined,
                AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Urgent',
                '${statusCounts['Urgent'] ?? 0}',
                Icons.warning_amber_rounded,
                AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTestGraph() {
    if (_dailyCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Tests Over Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No test data for selected period',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sortedDates = _dailyCounts.keys.toList()..sort();
    final maxCount = _dailyCounts.values.reduce((a, b) => a > b ? a : b);
    final yAxisMax = maxCount < 5 ? 5.0 : (maxCount + 2).toDouble();

    final spots = sortedDates.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _dailyCounts[entry.value]!.toDouble(),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tests Over Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredResults.length} total',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: yAxisMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yAxisMax < 10 ? 1 : null,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: AppColors.border, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: yAxisMax < 10 ? 1 : null,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: sortedDates.length > 14 ? 2 : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedDates.length)
                          return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('d/M').format(sortedDates[index]),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                    left: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = sortedDates[spot.x.toInt()];
                        return LineTooltipItem(
                          '${DateFormat('MMM d').format(date)}\n${spot.y.toInt()} tests',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: spots.length > 2,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: AppColors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.3),
                          AppColors.primary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionBreakdown() {
    final conditionCounts =
        _statistics['conditionCounts'] as Map<String, int>? ?? {};
    final entries = conditionCounts.entries.where((e) => e.value > 0).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    entries.sort((a, b) {
      if (a.key == 'Normal') return -1;
      if (b.key == 'Normal') return 1;
      return a.key.compareTo(b.key);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter by Conditions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_selectedConditions.isNotEmpty)
                GestureDetector(
                  onTap: () => _changeFilter(_selectedPeriod, []),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.clear_all,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clear (${_selectedConditions.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to select multiple conditions',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries
                .map((e) => _buildConditionChip(e.key, e.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionChip(String condition, int count) {
    final isSelected = _selectedConditions.contains(condition);
    Color color = _getConditionColor(condition);

    return GestureDetector(
      onTap: () {
        final newConditions = List<String>.from(_selectedConditions);
        if (isSelected) {
          newConditions.remove(condition);
        } else {
          newConditions.add(condition);
        }
        _changeFilter(_selectedPeriod, newConditions);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)])
              : null,
          color: isSelected ? null : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            Text(
              condition,
              style: TextStyle(
                color: isSelected ? AppColors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? AppColors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Normal':
        return AppColors.success;
      case 'Myopia':
      case 'Hyperopia':
      case 'Presbyopia':
        return AppColors.warning;
      case 'Astigmatism':
        return AppColors.info;
      case 'Color Vision Deficiency':
        return const Color(0xFF9C27B0);
      case 'Macular Issue':
      case 'Possible Cataract':
        return AppColors.error;
      case 'Vision Impairment':
      case 'Low Contrast Sensitivity':
        return const Color(0xFFFF6F00);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildRecentResults() {
    if (_filteredResults.isEmpty) return const SizedBox.shrink();

    final patientsWithResults = <String, PatientModel>{};
    for (final result in _filteredResults) {
      final patientId = result.profileId ?? result.profileName;
      if (!patientsWithResults.containsKey(patientId)) {
        final patient = _patients.firstWhere(
          (p) => p.id == result.profileId || p.fullName == result.profileName,
          orElse: () => PatientModel(
            id: result.profileId ?? '',
            firstName: result.profileName.split(' ').first,
            lastName: result.profileName.split(' ').length > 1
                ? result.profileName.split(' ').last
                : '',
            age: result.profileAge ?? 0,
            sex: result.profileSex ?? 'Unknown',
            phone: null,
            createdAt: result.timestamp,
          ),
        );
        patientsWithResults[patientId] = patient;
      }
    }

    final searchFilteredResults = _searchQuery.isEmpty
        ? _filteredResults
        : _filteredResults.where((r) {
            final query = _searchQuery.toLowerCase();
            return r.profileName.toLowerCase().contains(query) ||
                (patientsWithResults[r.profileId ?? r.profileName]?.phone
                        ?.toLowerCase()
                        .contains(query) ??
                    false);
          }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Test Results',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${searchFilteredResults.length} results',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by patient name or phone...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...searchFilteredResults.map((result) {
            final patient =
                patientsWithResults[result.profileId ?? result.profileName];
            return _buildEnhancedResultCard(result, patient);
          }),
        ],
      ),
    );
  }

  Widget _buildEnhancedResultCard(
    TestResultModel result,
    PatientModel? patient,
  ) {
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

    final isComprehensive = result.testType == 'comprehensive';
    final hasPhone = patient?.phone != null && patient!.phone!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Changed from default
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
                      maxLines: 2, // Added: Allow 2 lines for long names
                      overflow: TextOverflow
                          .ellipsis, // Added: Show ... if still too long
                    ),
                    const SizedBox(height: 2), // Added small spacing
                    Text(
                      DateFormat(
                        'MMM dd, yyyy • h:mm a',
                      ).format(result.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1, // Added: Ensure single line
                      overflow: TextOverflow.ellipsis, // Added: Handle overflow
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
              if (hasPhone)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.phone, size: 18),
                    color: AppColors.success,
                    padding: const EdgeInsets.all(8), // Added: Reduce padding
                    constraints: const BoxConstraints(
                      minWidth: 36, // Added: Set minimum size
                      minHeight: 36,
                    ),
                    onPressed: () => _makePhoneCall(patient!.phone!),
                    tooltip: patient!.phone,
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                // Changed from no wrapper to Flexible
                child: Container(
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
                    maxLines: 1, // Added: Ensure single line
                    overflow: TextOverflow.ellipsis, // Added: Handle overflow
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showResultDetails(result),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ), // Added horizontal padding
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: IntrinsicHeight(
                // Added: Makes all columns same height
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
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _showResultDetails(result),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text(
                    'View',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPdf(result),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text(
                    'PDF',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 1,
                child: IconButton(
                  onPressed: () => _sharePdf(result),
                  icon: const Icon(Icons.share, size: 20),
                  color: AppColors.primary,
                  tooltip: 'Share report',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
        ), // Added padding between items
        child: Column(
          mainAxisSize: MainAxisSize.min, // Added: Minimize vertical space
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
