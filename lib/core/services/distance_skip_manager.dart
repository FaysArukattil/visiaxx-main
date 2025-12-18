import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Singleton service to manage distance calibration skip cooldowns
/// Prevents distance warnings from showing too frequently after user skips
class DistanceSkipManager {
  static final DistanceSkipManager _instance = DistanceSkipManager._internal();
  factory DistanceSkipManager() => _instance;
  DistanceSkipManager._internal();

  static const String _keyPrefix = 'distance_skip_';
  static const int _cooldownSeconds = 60; // 60 seconds cooldown

  final Map<String, DateTime> _skipTimestamps = {};

  /// Check if distance warning can be shown for given test type
  /// Returns false if user skipped within cooldown period
  Future<bool> canShowDistanceWarning(String testType) async {
    // Check in-memory cache first
    final cachedTimestamp = _skipTimestamps[testType];
    if (cachedTimestamp != null) {
      final elapsed = DateTime.now().difference(cachedTimestamp);
      if (elapsed.inSeconds < _cooldownSeconds) {
        return false;
      }
    }

    // Check persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampMs = prefs.getInt('$_keyPrefix$testType');

      if (timestampMs != null) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        final elapsed = DateTime.now().difference(timestamp);

        if (elapsed.inSeconds < _cooldownSeconds) {
          // Update cache
          _skipTimestamps[testType] = timestamp;
          return false;
        }
      }
    } catch (e) {
      // If preferences fail, allow showing warning
      debugPrint('[DistanceSkipManager] Error checking skip: $e');
    }

    return true;
  }

  /// Record that user skipped distance warning for given test type
  Future<void> recordSkip(String testType) async {
    final now = DateTime.now();

    // Update in-memory cache
    _skipTimestamps[testType] = now;

    // Persist to storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_keyPrefix$testType', now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[DistanceSkipManager] Error recording skip: $e');
    }
  }

  /// Clear skip record for given test type
  Future<void> clearSkip(String testType) async {
    // Clear from cache
    _skipTimestamps.remove(testType);

    // Clear from storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$testType');
    } catch (e) {
      debugPrint('[DistanceSkipManager] Error clearing skip: $e');
    }
  }

  /// Clear all skip records
  Future<void> clearAll() async {
    // Clear cache
    _skipTimestamps.clear();

    // Clear storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_keyPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('[DistanceSkipManager] Error clearing all skips: $e');
    }
  }

  /// Get remaining cooldown time in seconds for given test type
  /// Returns 0 if no cooldown active
  Future<int> getRemainingCooldown(String testType) async {
    final cachedTimestamp = _skipTimestamps[testType];
    DateTime? timestamp = cachedTimestamp;

    // Check persistent storage if not in cache
    if (timestamp == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final timestampMs = prefs.getInt('$_keyPrefix$testType');
        if (timestampMs != null) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        }
      } catch (e) {
        debugPrint('[DistanceSkipManager] Error getting cooldown: $e');
      }
    }

    if (timestamp == null) return 0;

    final elapsed = DateTime.now().difference(timestamp);
    final remaining = _cooldownSeconds - elapsed.inSeconds;

    return remaining > 0 ? remaining : 0;
  }
}

// Test type constants for consistency
class DistanceTestType {
  static const String visualAcuity = 'visual_acuity';
  static const String shortDistance = 'short_distance';
  static const String colorVision = 'color_vision';
  static const String amslerGrid = 'amsler_grid';
}
