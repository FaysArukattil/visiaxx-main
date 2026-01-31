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

  Future<void> saveResults(
    List<TestResultModel> results, {
    String? customKey,
  }) async {
    try {
      final key = customKey ?? _keyResults;
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = results
          .map((r) => r.toJson())
          .toList();
      await prefs.setString(key, json.encode(jsonList));
      await prefs.setInt(
        '${key}_last_sync',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint(
        '[DashboardPersistence] ✅ Saved ${results.length} results to disk (key: $key)',
      );
    } catch (e) {
      debugPrint('[DashboardPersistence] ❌ Error saving results: $e');
    }
  }

  Future<List<TestResultModel>> getStoredResults({String? customKey}) async {
    try {
      final key = customKey ?? _keyResults;
      final prefs = await SharedPreferences.getInstance();
      final String? resultsJson = prefs.getString(key);

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

  Future<DateTime?> getLastSyncTime({String? customKey}) async {
    final key = customKey ?? _keyResults;
    final prefs = await SharedPreferences.getInstance();
    final int? lastSync = prefs.getInt('${key}_last_sync');
    if (lastSync == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(lastSync);
  }

  Future<void> saveHiddenIds(List<String> ids, {String? customKey}) async {
    try {
      final key = '${customKey ?? _keyResults}_hidden';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, ids);
      debugPrint('[DashboardPersistence] ✅ Saved ${ids.length} hidden IDs');
    } catch (e) {
      debugPrint('[DashboardPersistence] ❌ Error saving hidden IDs: $e');
    }
  }

  Future<List<String>> getStoredHiddenIds({String? customKey}) async {
    try {
      final key = '${customKey ?? _keyResults}_hidden';
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key) ?? [];
    } catch (e) {
      debugPrint('[DashboardPersistence] ❌ Error loading hidden IDs: $e');
      return [];
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyResults);
    await prefs.remove(_keyLastSync);
    await prefs.remove('${_keyResults}_hidden');
    debugPrint('[DashboardPersistence] 🗑️ Cleared all local data');
  }
}
