// lib/core/services/dashboard_cache_service.dart

import 'package:flutter/foundation.dart';
import '../../data/models/test_result_model.dart';
import '../../data/models/patient_model.dart';

class DashboardCacheService {
  static final DashboardCacheService _instance =
      DashboardCacheService._internal();
  factory DashboardCacheService() => _instance;
  DashboardCacheService._internal();

  // Cache storage
  Map<String, dynamic>? _cachedStatistics;
  List<TestResultModel>? _cachedAllResults;
  List<PatientModel>? _cachedPatients;
  Map<DateTime, int>? _cachedDailyCounts;
  DateTime? _lastCacheTime;

  // Cache duration (5 minutes)
  static const _cacheDuration = Duration(minutes: 5);

  bool get isCacheValid {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheDuration;
  }

  void cacheData({
    required Map<String, dynamic> statistics,
    required List<TestResultModel> allResults,
    required List<PatientModel> patients,
    required Map<DateTime, int> dailyCounts,
  }) {
    _cachedStatistics = statistics;
    _cachedAllResults = allResults;
    _cachedPatients = patients;
    _cachedDailyCounts = dailyCounts;
    _lastCacheTime = DateTime.now();

    debugPrint('[DashboardCache] ✅ Data cached at ${_lastCacheTime}');
  }

  Map<String, dynamic>? getCachedData() {
    if (!isCacheValid) {
      debugPrint('[DashboardCache] ❌ Cache expired or invalid');
      return null;
    }

    return {
      'statistics': _cachedStatistics,
      'allResults': _cachedAllResults,
      'patients': _cachedPatients,
      'dailyCounts': _cachedDailyCounts,
    };
  }

  void clearCache() {
    _cachedStatistics = null;
    _cachedAllResults = null;
    _cachedPatients = null;
    _cachedDailyCounts = null;
    _lastCacheTime = null;

    debugPrint('[DashboardCache] 🗑️ Cache cleared');
  }
}
