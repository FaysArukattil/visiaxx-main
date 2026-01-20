import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/dashboard_cache_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/models/patient_model.dart';
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
  List<String> _selectedConditions = []; // Changed from single to multiple
  Map<String, dynamic> _statistics = {};
  List<TestResultModel> _filteredResults = [];
  List<PatientModel> _patients = [];
  Map<DateTime, int> _dailyCounts = {};

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyWithCalls = false; // Filter for patients with phone numbers

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
      // Try cache first
      final cachedData = _cache.getCachedData();

      if (cachedData != null) {
        debugPrint('[Dashboard] ⚡ Loading from cache');
        _applyCachedData(cachedData);
        setState(() => _isInitialLoading = false);
        return;
      }

      // Load fresh data
      final now = DateTime.now();
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

      // Cache the data
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

    // Apply multiple condition filters
    if (_selectedConditions.isNotEmpty) {
      filtered = filtered.where((r) {
        final conditions = _getAllResultConditions(r);
        // Check if ANY selected condition matches ANY result condition
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

      // Count all conditions (not just primary)
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

  /// Get ALL conditions from a result (not just primary)
  List<String> _getAllResultConditions(TestResultModel result) {
    final conditions = <String>[];

    // Check mobile refractometry
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

      // Check for presbyopia (add power for near vision)
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

    // Check visual acuity
    final rightLogMAR = result.visualAcuityRight?.logMAR ?? 0;
    final leftLogMAR = result.visualAcuityLeft?.logMAR ?? 0;
    final worseLogMAR = rightLogMAR > leftLogMAR ? rightLogMAR : leftLogMAR;

    if (worseLogMAR > 0.3) conditions.add('Vision Impairment');

    // Check color vision
    if (result.colorVision != null && !result.colorVision!.isNormal) {
      conditions.add('Color Vision Deficiency');
    }

    // Check Amsler Grid for macular issues
    if ((result.amslerGridRight?.hasDistortions ?? false) ||
        (result.amslerGridLeft?.hasDistortions ?? false)) {
      conditions.add('Macular Issue');

      // Severe distortions might indicate more serious conditions
      final rightDistortions =
          result.amslerGridRight?.distortionPoints.length ?? 0;
      final leftDistortions =
          result.amslerGridLeft?.distortionPoints.length ?? 0;
      if (rightDistortions >= 5 || leftDistortions >= 5) {
        conditions.add('Possible Cataract');
      }
    }

    // Check contrast sensitivity
    if (result.pelliRobson != null && result.pelliRobson!.needsReferral) {
      conditions.add('Low Contrast Sensitivity');
    }

    // If no issues found
    if (conditions.isEmpty) conditions.add('Normal');

    return conditions;
  }

  /// Get primary condition for display
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

  Future<void> _downloadAllPDFs() async {
    if (_filteredResults.isEmpty) {
      SnackbarUtils.showInfo(context, 'No results to download');
      return;
    }

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
              Text('Downloading ${_filteredResults.length} PDFs...'),
            ],
          ),
        ),
      ),
    );

    try {
      final baseDir = await _getDownloadDirectory();
      final periodFolder = _getPeriodFolderName();
      final targetDir = Directory(
        '${baseDir.path}/Visiaxx_Reports/$periodFolder',
      );

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      int successCount = 0;
      for (final result in _filteredResults) {
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
                        const SizedBox(height: 20),
                        _buildPatientsList(),
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
                Text(
                  'Download All (${_filteredResults.length})',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
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
    );
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

    return Row(
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

    // Sort entries: Normal first, then alphabetically
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
        return const Color(0xFF9C27B0); // Purple
      case 'Macular Issue':
      case 'Possible Cataract':
        return AppColors.error;
      case 'Vision Impairment':
      case 'Low Contrast Sensitivity':
        return const Color(0xFFFF6F00); // Deep Orange
      default:
        return AppColors.primary;
    }
  }

  Widget _buildRecentResults() {
    if (_filteredResults.isEmpty) return const SizedBox.shrink();

    // Get unique patients from filtered results
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

          // Search Bar
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

          // Results List
          ...searchFilteredResults.map((result) {
            final patient =
                patientsWithResults[result.profileId ?? result.profileName];
            return _buildEnhancedResultCard(result, patient);
          }),
        ],
      ),
    );
  }

  // Enhanced Result Card matching My Results screen
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
          // Header with call button
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
              // Call Button
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
                    onPressed: () => _makePhoneCall(patient!.phone!),
                    tooltip: patient!.phone,
                  ),
                ),
              const SizedBox(width: 8),
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

          // Results Grid
          Container(
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

  Widget _buildPatientsList() {
    if (_patients.isEmpty) return const SizedBox.shrink();

    final filteredPatients = _searchQuery.isEmpty
        ? _patients
        : _patients.where((p) {
            final query = _searchQuery.toLowerCase();
            return p.fullName.toLowerCase().contains(query) ||
                (p.phone?.toLowerCase().contains(query) ?? false);
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
          const Text(
            'Patients',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search patients...',
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
          ...filteredPatients
              .take(8)
              .map((patient) => _buildPatientCard(patient)),
          if (filteredPatients.length > 8)
            Center(
              child: TextButton(
                onPressed: () {
                  // Show all patients
                },
                child: Text('View all ${filteredPatients.length} patients'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(PatientModel patient) {
    // Find latest result for this patient
    final patientResults = _filteredResults
        .where(
          (r) => r.profileId == patient.id || r.profileName == patient.fullName,
        )
        .toList();

    final latestResult = patientResults.isNotEmpty
        ? patientResults.first
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.03),
            AppColors.background,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              patient.firstName[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${patient.age} yrs • ${patient.sex}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (latestResult != null) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            latestResult.overallStatus,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          latestResult.overallStatus.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: _getStatusColor(latestResult.overallStatus),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (patient.phone != null)
            Container(
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.phone, size: 18),
                color: AppColors.success,
                onPressed: () => _makePhoneCall(patient.phone!),
                tooltip: patient.phone,
              ),
            ),
        ],
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
}
