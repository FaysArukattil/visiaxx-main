// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:visiaxx/core/services/file_manager_service.dart';
import '../../../core/services/dashboard_persistence_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/models/patient_model.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../data/models/mobile_refractometry_result.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/auth_service.dart'; // RE-ADDED
import '../../../data/models/user_model.dart';

class PractitionerDashboardScreen extends StatefulWidget {
  const PractitionerDashboardScreen({super.key});

  @override
  State<PractitionerDashboardScreen> createState() =>
      _PractitionerDashboardScreenState();
}

class _PractitionerDashboardScreenState
    extends State<PractitionerDashboardScreen> {
  final PatientService _patientService = PatientService();
  final PdfExportService _pdfService = PdfExportService();
  final TestResultService _resultService = TestResultService();
  final AuthService _authService = AuthService(); // RE-ADDED
  StreamSubscription<List<TestResultModel>>? _resultsSubscription;
  StreamSubscription<UserModel?>? _profileSubscription; // NEW

  bool _isInitialLoading = true;
  bool _isSyncing = false; // NEW: Track background sync
  bool _isFilterLoading = false;
  double _loadingProgress = 0.0; // NEW: Track load %
  int _totalToLoad = 0; // NEW: Total count
  String _selectedPeriod = 'all';
  List<String> _selectedConditions = [];
  Map<String, dynamic> _statistics = {};
  List<TestResultModel> _allResults = []; // NEW: Persistent list of all results
  List<TestResultModel> _filteredResults = [];
  List<PatientModel> _patients = [];
  List<String> _hiddenResultIds = []; // NEW: Real-time hidden IDs

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
    _resultsSubscription?.cancel();
    _profileSubscription?.cancel(); // NEW
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_allResults.isEmpty) {
      setState(() => _isInitialLoading = true);
    }

    // Cancel existing subscription if any
    await _resultsSubscription?.cancel();

    try {
      // 1. FAST LOAD FROM DISK
      debugPrint('[Dashboard] 💾 Loading from disk...');
      final persistence = DashboardPersistenceService();
      final storedResults = await persistence.getStoredResults();
      final lastSync = await persistence.getLastSyncTime();

      if (mounted && storedResults.isNotEmpty) {
        setState(() {
          _allResults = storedResults;
          _applyFilters(storedResults);
          _isInitialLoading = false;
        });
        debugPrint(
          '[Dashboard] ✅ Loaded ${storedResults.length} items from disk',
        );
      }

      // 2. Load Patients & Hidden IDs in parallel
      final results = await Future.wait([
        _authService.getUserData(user.uid),
        _patientService.getPatients(user.uid),
      ]);

      final userProfile = results[0] as UserModel?;
      _patients = results[1] as List<PatientModel>;

      if (mounted && userProfile != null) {
        setState(() {
          _hiddenResultIds = userProfile.hiddenResultIds;
          if (_allResults.isNotEmpty) _applyFilters(_allResults);
        });
      }

      // 3. INCREMENTAL FETCH FROM FIRESTORE
      debugPrint('[Dashboard] 🔄 Starting incremental fetch...');
      List<TestResultModel> fetchedResults;

      if (lastSync != null && storedResults.isNotEmpty) {
        // Step 3a: Show background sync indicator
        setState(() => _isSyncing = true);

        // Fetch only new results since last sync
        fetchedResults = await _resultService.getPractitionerResultsIncremental(
          practitionerId: user.uid,
          since: lastSync,
        );

        if (fetchedResults.isNotEmpty) {
          // Merge and update
          final Map<String, TestResultModel> resultsMap = {
            for (var r in _allResults) r.id: r,
          };
          for (var r in fetchedResults) {
            resultsMap[r.id] = r;
          }
          final mergedResults = resultsMap.values.toList();
          mergedResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (mounted) {
            setState(() {
              _allResults = mergedResults;
              _applyFilters(mergedResults);
            });
          }
          await persistence.saveResults(mergedResults);
        }
        setState(() => _isSyncing = false);
      } else {
        // Step 3b: Full fetch with PROGRESS tracking
        setState(() {
          _isSyncing = true;
          _loadingProgress = 0.05; // Starting
        });

        debugPrint('[Dashboard] ℹ️ First run. Fetching with progress...');
        final totalCount = await _resultService.getPractitionerResultsCount(
          user.uid,
        );

        if (mounted) {
          setState(() => _totalToLoad = totalCount);
        }

        if (totalCount > 0) {
          final List<TestResultModel> pagedResults = [];
          const int pageSize = 50;
          DocumentSnapshot? lastDoc;

          while (pagedResults.length < totalCount) {
            final batch = await _resultService.getPractitionerResultsPaged(
              practitionerId: user.uid,
              limit: pageSize,
              startAfter: lastDoc,
            );

            if (batch.isEmpty) break;

            pagedResults.addAll(batch);
            lastDoc = _resultService.lastProcessedDoc;

            if (mounted) {
              setState(() {
                _loadingProgress = (pagedResults.length / totalCount).clamp(
                  0.0,
                  1.0,
                );
                _allResults = List.from(pagedResults);
                _applyFilters(_allResults);
              });
            }
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }

        if (_allResults.isEmpty) {
          debugPrint(
            '[Dashboard] ⚠️ CollectionGroup returned 0. Trying patient-by-patient fallback...',
          );
          // FALLBACK: Original logic fetching by patient
          final allPatientsResults = <TestResultModel>[];
          final identity = userProfile?.identityString ?? user.uid;

          final patientsCount = _patients.length;
          if (patientsCount > 0) {
            for (int i = 0; i < patientsCount; i++) {
              final p = _patients[i];
              final snapshot = await FirebaseFirestore.instance
                  .collection('Practitioners')
                  .doc(identity)
                  .collection('patients')
                  .doc(p.id)
                  .collection('tests')
                  .orderBy('timestamp', descending: true)
                  .get();

              for (var doc in snapshot.docs) {
                final data = doc.data();
                data['id'] = doc.id;
                allPatientsResults.add(TestResultModel.fromJson(data));
              }

              if (mounted) {
                setState(() {
                  _loadingProgress = (i + 1) / patientsCount;
                  _allResults = List.from(allPatientsResults);
                  _applyFilters(_allResults);
                });
              }
            }
          }

          if (mounted) {
            setState(() {
              _isInitialLoading = false;
              _isSyncing = false;
              _loadingProgress = 1.0;
            });
          }
          await persistence.saveResults(_allResults);
          return;
        }

        if (mounted) {
          setState(() {
            _isInitialLoading = false;
            _isSyncing = false;
          });
        }
        await persistence.saveResults(_allResults);
      }

      // 4. Start Real-time Listeners for updates while on screen
      _profileSubscription = _authService.getUserStream(user.uid).listen((
        userProfile,
      ) {
        if (mounted && userProfile != null) {
          setState(() {
            _hiddenResultIds = userProfile.hiddenResultIds;
            _applyFilters(_allResults);
          });
        }
      });

      _resultsSubscription = _resultService
          .getPractitionerResultsStream(user.uid)
          .listen(
            (streamResults) {
              if (mounted) {
                // DEFENSIVE: Merge stream results with existing results to avoid wiping out fallback data
                // if collectionGroup query has issues but patient-by-patient sync worked.
                final Map<String, TestResultModel> resultsMap = {
                  for (var r in _allResults) r.id: r,
                };

                bool hasAnyChange = false;
                for (var r in streamResults) {
                  if (!resultsMap.containsKey(r.id)) {
                    resultsMap[r.id] = r;
                    hasAnyChange = true;
                  }
                }

                // If stream has fewer items AND we already have data, we might be seeing an inconsistent
                // collectionGroup vs fallback state. We prioritize keeping the fallback data for now.
                // However, if stream results are NEWER or DIFFERENT, we should reflect that.

                if (hasAnyChange ||
                    (streamResults.isNotEmpty &&
                        streamResults.length != _allResults.length)) {
                  final mergedResults = resultsMap.values.toList();
                  mergedResults.sort(
                    (a, b) => b.timestamp.compareTo(a.timestamp),
                  );

                  setState(() {
                    _allResults = mergedResults;
                    _applyFilters(mergedResults);
                  });
                  persistence.saveResults(mergedResults);
                }
              }
            },
            onError: (error) {
              debugPrint('[Dashboard] ❌ Stream Error: $error');
              // Don't show error to user if we already have some data
            },
          );
    } catch (e) {
      debugPrint('[Dashboard] ❌ Error loading data: $e');
      if (mounted) {
        setState(() => _isInitialLoading = false);
        SnackbarUtils.showError(context, 'Refresh failed. Check connectivity.');
      }
    }
  }

  void _applyFilters(List<TestResultModel> allResults) {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    // First apply period filter if no custom date range is set
    if (_startDate == null && _endDate == null) {
      switch (_selectedPeriod) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          endDate = now;
          break;
        case 'month':
          startDate = now.subtract(const Duration(days: 30));
          endDate = now;
          break;
        case 'all':
          startDate = null;
          endDate = null;
          break;
      }
    }

    // NEW: Always filter out hidden results first
    var filtered = allResults
        .where((r) => !_hiddenResultIds.contains(r.id))
        .toList();

    // Apply custom date range if set (this overrides period filter)
    if (_startDate != null && _endDate != null) {
      // Check if it's a single date (start and end are the same day)
      final isSingleDate =
          _startDate!.year == _endDate!.year &&
          _startDate!.month == _endDate!.month &&
          _startDate!.day == _endDate!.day;

      if (isSingleDate) {
        // Filter for exact date
        filtered = filtered.where((r) {
          return r.timestamp.year == _startDate!.year &&
              r.timestamp.month == _startDate!.month &&
              r.timestamp.day == _startDate!.day;
        }).toList();
      } else {
        // Filter for date range
        final rangeStart = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        final rangeEnd = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );

        filtered = filtered.where((r) {
          return r.timestamp.isAfter(
                rangeStart.subtract(const Duration(seconds: 1)),
              ) &&
              r.timestamp.isBefore(rangeEnd.add(const Duration(seconds: 1)));
        }).toList();
      }
    } else if (startDate != null) {
      // Apply period filter
      filtered = filtered.where((r) {
        if (endDate != null) {
          return r.timestamp.isAfter(
                startDate!.subtract(const Duration(seconds: 1)),
              ) &&
              r.timestamp.isBefore(endDate.add(const Duration(seconds: 1)));
        } else {
          return r.timestamp.isAfter(startDate!);
        }
      }).toList();
    }

    // Apply condition filters
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
    final statusCounts = <String, int>{'normal': 0, 'review': 0, 'urgent': 0};

    // Track unique patients per condition
    final conditionPatients = <String, Set<String>>{
      'Normal': <String>{},
      'Myopia': <String>{},
      'Hyperopia': <String>{},
      'Astigmatism': <String>{},
      'Presbyopia': <String>{},
      'Color Vision Deficiency': <String>{},
      'Cataract': <String>{},
      'Macular Issue': <String>{},
      'Vision Impairment': <String>{},
      'Low Contrast Sensitivity': <String>{},
    };
    final uniquePatients = <String>{};

    for (final result in _filteredResults) {
      final statusKey = result.overallStatus.name;
      statusCounts[statusKey] = (statusCounts[statusKey] ?? 0) + 1;

      // Track unique patients for each condition
      final conditions = _getAllResultConditions(result);
      for (final condition in conditions) {
        if (conditionPatients.containsKey(condition)) {
          conditionPatients[condition]!.add(result.profileId);
        }
      }

      uniquePatients.add(result.profileId);
    }

    // Convert unique patient sets to counts
    final conditionCounts = <String, int>{};
    conditionPatients.forEach((condition, patients) {
      conditionCounts[condition] = patients.length;
    });

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
        conditions.add('Cataract');
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
    if (conditions.contains('Cataract')) return 'Cataract';
    if (conditions.contains('Macular Issue')) return 'Macular Issue';
    if (conditions.contains('Myopia')) return 'Myopia';
    if (conditions.contains('Hyperopia')) return 'Hyperopia';
    if (conditions.contains('Astigmatism')) return 'Astigmatism';
    if (conditions.contains('Presbyopia')) return 'Presbyopia';
    if (conditions.contains('Color Vision Deficiency')) {
      return 'Color Vision Deficiency';
    }
    if (conditions.contains('Vision Impairment')) return 'Vision Impairment';
    if (conditions.contains('Low Contrast Sensitivity')) {
      return 'Low Contrast Sensitivity';
    }
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

    // Use persistent results list
    if (_allResults.isNotEmpty) {
      _applyFilters(_allResults);
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              minHeight:
                  MediaQuery.of(context).orientation == Orientation.landscape
                  ? MediaQuery.of(context).size.height * 0.8
                  : MediaQuery.of(context).size.height * 0.65,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        if (_allResults.isNotEmpty) {
                          _applyFilters(_allResults);
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

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
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
                                      color: AppColors.primary.withValues(
                                        alpha: 0.5,
                                      ),
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
                                    color: AppColors.success.withValues(
                                      alpha: 0.1,
                                    ),
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
                        SizedBox(
                          height: 200,
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
                                          if (tempEndDate == null ||
                                              tempEndDate!.isBefore(date)) {
                                            tempEndDate = date;
                                          }
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
                                          if (tempStartDate != null &&
                                              date.isBefore(tempStartDate!)) {
                                            return;
                                          } else {
                                            tempEndDate = date;
                                          }
                                        }
                                      } else {
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
    // Calculate active results only (exclude hidden/deleted ones)
    final allResults = _allResults;
    final activeResults = allResults
        .where((r) => !_hiddenResultIds.contains(r.id))
        .toList();
    final totalResults = activeResults.length;

    final filteredCount = _filteredResults.length;
    final hasFilters =
        _selectedPeriod != 'all' ||
        _selectedConditions.isNotEmpty ||
        _startDate != null ||
        _endDate != null;

    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Download Reports',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select the report collection you wish to export to your device.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: All Reports
                _buildDownloadCard(
                  icon: Icons.auto_awesome_motion_rounded,
                  title: 'All Recommendations',
                  subtitle: 'Export entire database ($totalResults reports)',
                  value: 'all',
                  isRecommended: !hasFilters,
                ),

                const SizedBox(height: 12),

                // Option 2: Filtered Reports
                _buildDownloadCard(
                  icon: Icons.filter_list_rounded,
                  title: 'Current Filters',
                  subtitle: _getFilterDescription(filteredCount),
                  value: 'filtered',
                  isRecommended: hasFilters,
                  isEnabled: filteredCount > 0,
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadCard({
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEnabled
                ? (isRecommended
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : AppColors.surface)
                : AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecommended && isEnabled
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: isEnabled ? 1 : 0.5),
              width: isRecommended && isEnabled ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.textTertiary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? AppColors.primary : AppColors.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isEnabled
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended && isEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'BEST CHOICE',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
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
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFilterDescription(int count) {
    final filters = <String>[];

    // Date-based description
    if (_startDate != null && _endDate != null) {
      if (_startDate!.year == _endDate!.year &&
          _startDate!.month == _endDate!.month &&
          _startDate!.day == _endDate!.day) {
        filters.add('📅 ${DateFormat('MMM d, yyyy').format(_startDate!)}');
      } else {
        filters.add(
          '📅 ${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
        );
      }
    } else if (_selectedPeriod != 'all') {
      switch (_selectedPeriod) {
        case 'today':
          filters.add('📅 Today');
          break;
        case 'week':
          filters.add('📅 Last 7 days');
          break;
        case 'month':
          filters.add('📅 Last 30 days');
          break;
      }
    }

    // Condition-based description
    if (_selectedConditions.isNotEmpty) {
      if (_selectedConditions.length == 1) {
        filters.add('🏥 ${_selectedConditions.first}');
      } else if (_selectedConditions.length <= 3) {
        filters.add('🏥 ${_selectedConditions.join(', ')}');
      } else {
        filters.add('🏥 ${_selectedConditions.length} conditions');
      }
    }

    final filterText = filters.isNotEmpty ? filters.join(' • ') : 'All reports';
    return '$count reports\n$filterText';
  }

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      debugPrint(
        '[Dashboard] Checking storage permission for Android SDK: $sdkInt',
      );

      if (sdkInt >= 33) {
        debugPrint('[Dashboard] Android 13+: Using scoped storage');
        return true;
      }

      if (sdkInt >= 30) {
        PermissionStatus status = await Permission.manageExternalStorage.status;

        if (status.isDenied) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.folder_open, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Storage Access')),
                ],
              ),
              content: const Text(
                'Visiaxx needs access to save PDF reports to your Downloads folder.\n\n'
                'This permission allows the app to:\n'
                '• Save reports to Downloads/Visiaxx_Reports\n'
                '• Organize files for easy access\n'
                'Your files remain private and secure.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Grant Access'),
                ),
              ],
            ),
          );

          if (shouldRequest != true) return false;
          status = await Permission.manageExternalStorage.request();
        }

        if (status.isPermanentlyDenied) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.settings, color: AppColors.warning),
                  SizedBox(width: 12),
                  Expanded(child: Text('Permission Required')),
                ],
              ),
              content: const Text(
                'Storage permission is required to save PDFs to Downloads.\n\n'
                'Please enable it in Settings:\n'
                '1. Open App Settings\n'
                '2. Go to Permissions\n'
                '3. Enable "Files and media" or "All files access"',
                style: TextStyle(fontSize: 14),
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

          if (shouldOpen == true) {
            await openAppSettings();
          }
          return false;
        }

        return status.isGranted;
      } else {
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
                'Storage permission is needed to download PDFs. '
                'Please enable it in app settings.',
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

          if (shouldOpen == true) {
            await openAppSettings();
          }
          return false;
        }

        return status.isGranted;
      }
    } catch (e) {
      debugPrint('[Dashboard] Error checking permission: $e');
      return false;
    }
  }

  Future<void> _downloadAllPDFs() async {
    // Show download options dialog
    final choice = await _showDownloadOptionsDialog();

    if (choice == null) return; // User cancelled

    // Determine which results to download
    List<TestResultModel> resultsToDownload;
    String folderName;

    if (choice == 'all') {
      // Download only active results (what's shown on dashboard)
      debugPrint(
        '[Dashboard] 📥 Download All clicked. _allResults count: ${_allResults.length}',
      );

      // Filter to only active (non-hidden) results
      final activeResults = _allResults
          .where((r) => !_hiddenResultIds.contains(r.id))
          .toList();

      debugPrint(
        '[Dashboard] ✅ Active results to download: ${activeResults.length}',
      );

      if (activeResults.isEmpty) {
        debugPrint('[Dashboard] ❌ No active results available!');
        SnackbarUtils.showError(context, 'No active results available');
        return;
      }

      resultsToDownload = activeResults;
      folderName = 'All_Reports';
      debugPrint(
        '[Dashboard] ✅ Will download ${resultsToDownload.length} results to $folderName',
      );
    } else {
      // Download filtered results
      if (_filteredResults.isEmpty) {
        SnackbarUtils.showInfo(context, 'No filtered results to download');
        return;
      }
      resultsToDownload = _filteredResults;
      folderName = _getSmartFolderName();
    }

    if (resultsToDownload.isEmpty) {
      SnackbarUtils.showInfo(context, 'No results to download');
      return;
    }

    // Check and request permissions
    if (!await _ensureStoragePermission()) return;

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
      int failCount = 0;
      debugPrint(
        '[Dashboard] 🔄 Starting download of ${resultsToDownload.length} PDFs...',
      );
      debugPrint('[Dashboard] 📂 Target: ${targetDir.path}');

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

          final filePath = '${targetDir.path}/$filename';
          final file = File(filePath);

          // CRITICAL: Use writeAsBytes with mode that overwrites
          // This prevents "File exists" errors
          try {
            await file.writeAsBytes(
              pdfBytes,
              mode: FileMode.writeOnly,
              flush: true,
            );
            successCount++;
            debugPrint(
              '[Dashboard] ✅ [$successCount/${resultsToDownload.length}] Saved: $filename',
            );
          } catch (writeError) {
            // If writeOnly fails, try deleting first
            if (await file.exists()) {
              await file.delete();
            }
            await file.create(recursive: true);
            await file.writeAsBytes(pdfBytes, flush: true);
            successCount++;
            debugPrint(
              '[Dashboard] ✅ [$successCount/${resultsToDownload.length}] Saved (retry): $filename',
            );
          }
        } catch (e, stack) {
          failCount++;
          debugPrint('[Dashboard] ❌ Failed ${result.profileName}: $e');
          if (failCount <= 3) {
            debugPrint(
              '[Dashboard] Stack: ${stack.toString().substring(0, 200)}...',
            );
          }
        }
      }

      debugPrint(
        '[Dashboard] 🎉 Complete! Success: $successCount, Failed: $failCount',
      );

      debugPrint(
        '[Dashboard] 🎉 Download complete! Successfully saved $successCount PDFs',
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog

        // If only one result, pass its path for the "Print" feature
        String? singlePath;
        if (successCount == 1 && resultsToDownload.length == 1) {
          final result = resultsToDownload.first;
          final name = result.profileName.replaceAll(
            RegExp(r'[^a-zA-Z0-9]'),
            '_',
          );
          final age = result.profileAge?.toString() ?? 'NA';
          final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
          final timeStr = DateFormat('HH-mm').format(result.timestamp);
          final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';
          singlePath = '${targetDir.path}/$filename';
        }

        debugPrint(
          '[Dashboard] 📊 Showing success dialog: count=$successCount, singlePath=$singlePath',
        );
        await _showDownloadSuccessDialog(
          successCount,
          targetDir.path,
          singleFilePath: singlePath,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        SnackbarUtils.showError(context, 'Failed to download PDFs: $e');
      }
    }
  }

  Future<void> _showDownloadSuccessDialog(
    int count,
    String path, {
    String? singleFilePath,
  }) async {
    debugPrint(
      '[Dashboard] 🖼️ Rendering success dialog. Single file: ${singleFilePath != null}',
    );

    // Get the folder name safely
    final folderName = path.split(RegExp(r'[/\\]')).last;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        children: [
                          // Success Icon with glow
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Reports Ready',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'Successfully prepared $count clinical report${count > 1 ? 's' : ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.8,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Location Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.folder_open_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'SAVE LOCATION',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textTertiary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  folderName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  path,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Action Buttons
                          if (singleFilePath != null) ...[
                            // Primary Action: Open and Print for single file
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      try {
                                        final file = File(singleFilePath);
                                        if (await file.exists()) {
                                          final bytes = await file
                                              .readAsBytes();
                                          await Printing.layoutPdf(
                                            onLayout: (format) async => bytes,
                                            name: singleFilePath
                                                .split(RegExp(r'[/\\]'))
                                                .last,
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          SnackbarUtils.showError(
                                            context,
                                            'Print failed: $e',
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.print_rounded,
                                      size: 20,
                                    ),
                                    label: const Text('Print'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                      foregroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final res = await OpenFilex.open(
                                        singleFilePath,
                                      );
                                      if (res.type != ResultType.done &&
                                          mounted) {
                                        SnackbarUtils.showError(
                                          context,
                                          'Could not open report',
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    child: const Text('Open'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Secondary: Folder opening
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _openFolder(path);
                                },
                                icon: const Icon(
                                  Icons.file_download_outlined,
                                  size: 18,
                                ),
                                label: const Text('View in Downloads'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Batch download - only folder opening
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _openFolder(path);
                                },
                                icon: const Icon(
                                  Icons.folder_special_rounded,
                                  size: 20,
                                ),
                                label: const Text('Open Downloads Folder'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Close Button (Top-Right)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFolder(String folderPath) async {
    try {
      final success = await FileManagerService.openFolder(folderPath);

      if (!success && mounted) {
        // Instead of showing a simple snackbar, show helpful instructions
        SnackbarUtils.showWarning(
          context,
          Platform.isAndroid
              ? 'Files saved! Open Files app → Downloads → Visiaxx_Reports'
              : 'Files saved! Open Files app to view reports',
          duration: const Duration(seconds: 5),
        );
      } else if (success && mounted) {
        SnackbarUtils.showSuccess(context, 'Opening file manager...');
      }
    } catch (e) {
      debugPrint('[Dashboard] Error opening folder: $e');
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Could not open file manager. Files are saved in Downloads/Visiaxx_Reports',
        );
      }
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    return await FileManagerService.getDownloadDirectory();
  }

  String _getPeriodFolderName() {
    return _getSmartFolderName(); // Use the smart folder name
  }

  String _getSmartFolderName() {
    final now = DateTime.now();
    final parts = <String>[];

    // 1. Date-based filtering
    if (_startDate != null && _endDate != null) {
      // Check if it's a single date
      if (_startDate!.year == _endDate!.year &&
          _startDate!.month == _endDate!.month &&
          _startDate!.day == _endDate!.day) {
        // Single date
        parts.add('Date_${DateFormat('yyyy-MM-dd').format(_startDate!)}');
      } else {
        // Date range
        final start = DateFormat('yyyy-MM-dd').format(_startDate!);
        final end = DateFormat('yyyy-MM-dd').format(_endDate!);
        parts.add('Range_${start}_to_$end');
      }
    } else {
      // Period-based
      switch (_selectedPeriod) {
        case 'today':
          parts.add('Today_${DateFormat('yyyy-MM-dd').format(now)}');
          break;
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          parts.add('Week_${DateFormat('yyyy-MM-dd').format(weekStart)}');
          break;
        case 'month':
          parts.add('Month_${DateFormat('yyyy-MM').format(now)}');
          break;
        case 'all':
          parts.add('All_Time');
          break;
      }
    }

    // 2. Condition-based filtering
    if (_selectedConditions.isNotEmpty) {
      if (_selectedConditions.length == 1) {
        // Single condition
        final condition = _selectedConditions.first.replaceAll(' ', '_');
        parts.add('Condition_$condition');
      } else if (_selectedConditions.length <= 3) {
        // Multiple conditions (up to 3)
        final conditions = _selectedConditions
            .map((c) => c.replaceAll(' ', '_'))
            .join('_and_');
        parts.add('Conditions_$conditions');
      } else {
        // Many conditions
        parts.add('Multiple_Conditions_${_selectedConditions.length}');
      }
    }

    // 3. If no filters applied (shouldn't happen, but just in case)
    if (parts.isEmpty) {
      parts.add('All_Reports');
    }

    // Join parts with forward slash for folder hierarchy
    final folderName = parts.join('/');

    debugPrint('[Dashboard] Smart folder name: $folderName');
    return folderName;
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
      // 1. Check permissions
      if (!await _ensureStoragePermission()) return;

      if (!mounted) return;
      UIUtils.showProgressDialog(
        context: context,
        message: 'Generating PDF...',
      );

      final String name = result.profileName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final age = result.profileAge?.toString() ?? 'NA';
      final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
      final timeStr = DateFormat('HH-mm').format(result.timestamp);
      final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';

      final baseDir = await _getDownloadDirectory();
      final targetDir = Directory(
        '${baseDir.path}/Visiaxx_Reports/Single_Reports',
      );

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final file = File('${targetDir.path}/$filename');

      // Generate bytes
      final pdfBytes = await _pdfService.generatePdfBytes(result);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        UIUtils.hideProgressDialog(context);
        await _showDownloadSuccessDialog(
          1,
          targetDir.path,
          singleFilePath: file.path,
        );
      }
    } catch (e) {
      if (mounted) {
        UIUtils.hideProgressDialog(context);
        final errorMessage = 'Failed to generate PDF: $e';
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

  Future<void> _deleteResult(TestResultModel result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _resultService.deleteTestResult(user.uid, result.id);
      // The stream listener will automatically update the UI
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Result deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to delete: $e');
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
        title: const Text('Practitioner Dashboard'),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: _isSyncing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _loadingProgress),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutSine,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value > 0 ? value : null,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 4,
                    );
                  },
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await DashboardPersistenceService().clearAll();
          setState(() {
            _selectedPeriod = 'all';
            _selectedConditions = [];
            _startDate = null;
            _endDate = null;
            _searchQuery = '';
            _searchController.clear();
          });
          await _loadDashboardData();
        },
        child: Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_isSyncing && _totalToLoad > 0)
                  SliverToBoxAdapter(child: _buildSyncStatusBanner()),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
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
                        _buildRecentResultsHeader(),
                      ],
                    ),
                  ),
                ),
                _buildRecentResultsList(),
                if (_allResults.isEmpty && _isSyncing)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const EyeLoader(size: 60),
                          const SizedBox(height: 24),
                          Text(
                            'Loading Patient Records...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We are retrieving clinical data from the cloud',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_allResults.isEmpty && !_isSyncing && !_isInitialLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_late_outlined,
                            size: 60,
                            color: AppColors.textTertiary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Patient Records Found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try performing a test or checking connection',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            if (_isFilterLoading)
              Positioned.fill(
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.7),
                  child: const Center(child: EyeLoader(size: 60)),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _buildDownloadButton(),
    );
  }

  Widget _buildSyncStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.1),
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
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: value > 0 ? value : null,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synchronizing Patient Database...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fetching clinical records from clinical cloud storage',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
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
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16), // Premium squircle radius
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _downloadAllPDFs,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: const Icon(
              Icons.file_download_outlined,
              color: AppColors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final hasDateFilter = _startDate != null || _endDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _showDatePicker,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasDateFilter
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasDateFilter
                        ? AppColors.white.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  hasDateFilter
                      ? Icons.date_range
                      : Icons.calendar_today_outlined,
                  color: hasDateFilter ? AppColors.white : AppColors.primary,
                  size: 20,
                ),
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
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 1.2,
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
                    if (_allResults.isNotEmpty) {
                      _applyFilters(_allResults);
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
    final isSelected = _selectedPeriod == value && _startDate == null;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _startDate = null;
            _endDate = null;
          });
          _changeFilter(value, _selectedConditions);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.primary,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final totalTests = _statistics['totalTests'] ?? 0;
    final uniquePatients = _statistics['uniquePatients'] ?? 0;
    final statusCounts =
        _statistics['statusCounts'] as Map<String, dynamic>? ?? {};

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
                AppColors.primary,
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
                '${statusCounts['review'] ?? statusCounts['Review'] ?? 0}',
                Icons.visibility_outlined,
                AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Urgent',
                '${statusCounts['urgent'] ?? statusCounts['Urgent'] ?? 0}',
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
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTestGraph() {
    final conditionCounts =
        _statistics['conditionCounts'] as Map<String, int>? ?? {};
    final totalPatients = _statistics['uniquePatients'] ?? 0;

    if (conditionCounts.isEmpty) return const SizedBox.shrink();

    // Prepare data
    final displayData = conditionCounts.entries.toList();
    displayData.sort((a, b) => b.value.compareTo(a.value)); // Sort by count

    final maxCount = displayData.fold<int>(
      0,
      (prev, e) => e.value > prev ? e.value : prev,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categorical Distribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Patients grouped by detectable conditions',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalPatients',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Horizontal Bars
          ...displayData.map((entry) {
            final percentage = maxCount > 0 ? entry.value / maxCount : 0.0;
            final color = _getConditionColor(entry.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage.clamp(0.01, 1.0),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.7), color],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildConditionBreakdown() {
    final conditionCounts =
        _statistics['conditionCounts'] as Map<String, int>? ?? {};

    // Always include all core conditions even if count is 0
    final entries = conditionCounts.entries.toList();

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
        return const Color(0xFF2196F3); // Blue
      case 'Hyperopia':
        return const Color(0xFFFF9800); // Orange
      case 'Presbyopia':
        return const Color(0xFF00BCD4); // Cyan
      case 'Astigmatism':
        return const Color(0xFF673AB7); // Deep Purple
      case 'Color Vision Deficiency':
        return const Color(0xFFE91E63); // Pink
      case 'Macular Issue':
        return const Color(0xFFF44336); // Red
      case 'Possible Cataract':
      case 'Cataract':
        return const Color(0xFF795548); // Brown
      case 'Vision Impairment':
        return const Color(0xFF607D8B); // Blue Grey
      case 'Low Contrast Sensitivity':
        return const Color(0xFF3F51B5); // Indigo
      default:
        return AppColors.primary;
    }
  }

  Widget _buildRecentResultsHeader() {
    final searchFilteredResults = _getCurrentFilteredAndSearchedResults();

    return Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  List<TestResultModel> _getCurrentFilteredAndSearchedResults() {
    if (_searchQuery.isEmpty) return _filteredResults;

    final query = _searchQuery.toLowerCase();
    return _filteredResults.where((r) {
      if (r.profileName.toLowerCase().contains(query)) return true;

      // Try to find matching patient phone
      final patient = _patients.firstWhere(
        (p) => p.id == r.profileId || p.fullName == r.profileName,
        orElse: () => PatientModel(
          id: 'temp',
          firstName: '',
          lastName: '',
          age: 0,
          sex: '',
          createdAt: DateTime.now(),
        ),
      );

      return patient.phone?.toLowerCase().contains(query) ?? false;
    }).toList();
  }

  Widget _buildRecentResultsList() {
    final results = _getCurrentFilteredAndSearchedResults();
    if (results.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final result = results[index];
          final patient = _patients.firstWhere(
            (p) => p.id == result.profileId || p.fullName == result.profileName,
            orElse: () => PatientModel(
              id: result.profileId,
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
          return _buildEnhancedResultCard(result, patient);
        }, childCount: results.length),
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
      margin: const EdgeInsets.only(bottom: 16),
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
          onTap: () => _showResultDetails(result),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Avatar, Name and Phone Button
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
                    if (hasPhone)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _makePhoneCall(patient.phone!),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          color: AppColors.primary,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
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

                const SizedBox(height: 16),

                // Test Results Grid
                _buildProfessionalDiagnosticGrid(result),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'View',
                        icon: Icons.visibility_rounded,
                        isPrimary: false,
                        onTap: () => _showResultDetails(result),
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
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: () => _confirmDeleteResult(result),
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

  Widget _buildProfessionalDiagnosticGrid(TestResultModel result) {
    // Check if any data exists
    final hasVA =
        result.visualAcuityRight != null || result.visualAcuityLeft != null;
    final hasRefraction = result.mobileRefractometry != null;
    final hasOthers =
        result.colorVision != null ||
        result.pelliRobson != null ||
        result.amslerGridRight != null ||
        result.amslerGridLeft != null;

    if (!hasVA && !hasRefraction && !hasOthers) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primaryLight.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
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
                      color: AppColors.primary.withValues(alpha: 0.15),
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
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
          ],
          // Row 2: Refraction Table
          if (hasRefraction) ...[
            _buildRefractionTable(result.mobileRefractometry!),
            if (hasOthers)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.primary.withValues(alpha: 0.05),
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
                          color: AppColors.primary.withValues(alpha: 0.15),
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
                            color: AppColors.primary.withValues(alpha: 0.15),
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
                            color: AppColors.primary.withValues(alpha: 0.15),
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
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
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
                Icon(icon, size: 10, color: AppColors.primary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
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
      color: AppColors.primary.withValues(alpha: 0.02),
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
}

class _TableHeader extends StatelessWidget {
  final String label;
  const _TableHeader(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
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
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
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

class _TableCell extends StatelessWidget {
  final String value;
  const _TableCell(this.value);
  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}
