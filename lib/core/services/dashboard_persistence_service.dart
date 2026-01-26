import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/test_result_model.dart';

class DashboardPersistenceService {
  static const String _keyResults = 'practitioner_results';
  static const String _keyLastSync = 'practitioner_last_sync';

  static final DashboardPersistenceService _instance =
      DashboardPersistenceService._internal();
  factory DashboardPersistenceService() => _instance;
  DashboardPersistenceService._internal();

  Future<void> saveResults(List<TestResultModel> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = results
          .map((r) => r.toJson())
          .toList();
      await prefs.setString(_keyResults, json.encode(jsonList));
      await prefs.setInt(_keyLastSync, DateTime.now().millisecondsSinceEpoch);
      debugPrint(
        '[DashboardPersistence] ✅ Saved ${results.length} results to disk',
      );
    } catch (e) {
      debugPrint('[DashboardPersistence] ❌ Error saving results: $e');
    }
  }

  Future<List<TestResultModel>> getStoredResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? resultsJson = prefs.getString(_keyResults);

      if (resultsJson == null || resultsJson.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(resultsJson);
      return jsonList
          .map((data) => TestResultModel.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DashboardPersistence] ❌ Error loading results: $e');
      return [];
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastSync = prefs.getInt(_keyLastSync);
    if (lastSync == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(lastSync);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyResults);
    await prefs.remove(_keyLastSync);
    debugPrint('[DashboardPersistence] 🗑️ Cleared all local data');
  }
}
