import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_monitor_service.dart';
import '../../data/providers/test_session_provider.dart';
import '../../data/providers/eye_exercise_provider.dart';

/// Service for comprehensive data cleanup on logout.
/// Ensures no data leaks between user sessions by clearing all providers,
/// local storage, and navigation state.
class DataCleanupService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Keys that should NOT be cleared during logout (app-level settings)
  static const List<String> _preservedPreferenceKeys = [
    'selected_language',
    'theme_mode',
    'app_version_shown',
    'onboarding_complete',
  ];

  /// Perform comprehensive cleanup of all app data
  /// Call this on logout or session conflict
  static Future<void> cleanupAllData(BuildContext context) async {
    debugPrint('[DataCleanup] 🧹 Starting comprehensive data cleanup...');

    try {
      // 0. Remove session from Firebase RTDB (DO THIS FIRST while IDs still exist)
      try {
        final sessionMonitor = SessionMonitorService();
        await sessionMonitor.removeSession();
        sessionMonitor.stopMonitoring();
        debugPrint('[DataCleanup] ✅ Session removed from Firebase');
      } catch (e) {
        debugPrint('[DataCleanup] ⚠️ Failed to remove session: $e');
      }

      // 1. Reset all providers
      await _resetProviders(context);

      // 2. Clear local storage (except preserved settings)
      await _clearLocalStorage();

      // 3. Clear secure storage (session tokens, etc.)
      await _clearSecureStorage();

      // 4. Sign out from Firebase (if not already signed out)
      await _signOutFirebase();

      debugPrint('[DataCleanup] ✅ Cleanup completed successfully');
    } catch (e) {
      debugPrint('[DataCleanup] ❌ Error during cleanup: $e');
      // Still try to sign out even if other cleanup fails
      await _signOutFirebase();
    }
  }

  /// Reset all provider states to initial values
  static Future<void> _resetProviders(BuildContext context) async {
    debugPrint('[DataCleanup] Resetting providers...');

    try {
      if (!context.mounted) return;

      // Reset TestSessionProvider
      try {
        final testSessionProvider = Provider.of<TestSessionProvider>(
          context,
          listen: false,
        );
        testSessionProvider.reset();
        debugPrint('[DataCleanup] ✅ TestSessionProvider reset');
      } catch (e) {
        debugPrint('[DataCleanup] ❌ Failed to reset TestSessionProvider: $e');
      }

      // Reset EyeExerciseProvider
      try {
        final eyeExerciseProvider = Provider.of<EyeExerciseProvider>(
          context,
          listen: false,
        );
        eyeExerciseProvider.resetState();
        debugPrint('[DataCleanup] ✅ EyeExerciseProvider reset');
      } catch (e) {
        debugPrint('[DataCleanup] ❌ Failed to reset EyeExerciseProvider: $e');
      }
    } catch (e) {
      debugPrint('[DataCleanup] ❌ Error resetting providers: $e');
    }
  }

  /// Clear SharedPreferences except preserved keys
  static Future<void> _clearLocalStorage() async {
    debugPrint('[DataCleanup] Clearing local storage...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();

      int clearedCount = 0;
      for (final key in allKeys) {
        if (!_preservedPreferenceKeys.contains(key)) {
          await prefs.remove(key);
          clearedCount++;
        }
      }

      debugPrint('[DataCleanup] ✅ Cleared $clearedCount preference keys');
    } catch (e) {
      debugPrint('[DataCleanup] ❌ Failed to clear local storage: $e');
    }
  }

  /// Clear all secure storage (session tokens, etc.)
  static Future<void> _clearSecureStorage() async {
    debugPrint('[DataCleanup] Clearing secure storage...');

    try {
      await _secureStorage.deleteAll();
      debugPrint('[DataCleanup] ✅ Secure storage cleared');
    } catch (e) {
      debugPrint('[DataCleanup] ❌ Failed to clear secure storage: $e');
    }
  }

  /// Sign out from Firebase Auth
  static Future<void> _signOutFirebase() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
        debugPrint('[DataCleanup] ✅ Firebase sign out complete');
      }
    } catch (e) {
      debugPrint('[DataCleanup] ❌ Failed to sign out from Firebase: $e');
    }
  }

  /// Clear navigation stack and navigate to a route
  /// Use this after cleanup to ensure clean navigation state
  static void navigateToLogin(BuildContext context) {
    if (!context.mounted) return;

    debugPrint('[DataCleanup] Navigating to login screen...');
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  /// Perform cleanup for test exit (partial cleanup)
  /// Only clears test-related data, not full logout
  static Future<void> cleanupTestData(BuildContext context) async {
    debugPrint('[DataCleanup] Cleaning up test data...');

    try {
      if (!context.mounted) return;

      // Only reset test session provider
      final testSessionProvider = Provider.of<TestSessionProvider>(
        context,
        listen: false,
      );
      testSessionProvider.reset();

      debugPrint('[DataCleanup] ✅ Test data cleanup complete');
    } catch (e) {
      debugPrint('[DataCleanup] ❌ Failed to cleanup test data: $e');
    }
  }

  /// Clear specific test results without full reset
  /// Useful for restarting individual tests
  static void clearCurrentTestOnly(BuildContext context, String testType) {
    debugPrint('[DataCleanup] Clearing $testType test data...');

    try {
      if (!context.mounted) return;

      final testSessionProvider = Provider.of<TestSessionProvider>(
        context,
        listen: false,
      );

      switch (testType) {
        case 'visual_acuity':
          testSessionProvider.resetVisualAcuity();
          break;
        case 'color_vision':
          testSessionProvider.resetColorVision();
          break;
        case 'amsler_grid':
          testSessionProvider.resetAmslerGrid();
          break;
        case 'short_distance':
          testSessionProvider.resetShortDistance();
          break;
        case 'pelli_robson':
          testSessionProvider.resetPelliRobson();
          break;
        default:
          debugPrint('[DataCleanup] ⚠️ Unknown test type: $testType');
      }

      debugPrint('[DataCleanup] ✅ $testType test data cleared');
    } catch (e) {
      debugPrint('[DataCleanup] ❌ Failed to clear $testType test data: $e');
    }
  }
}
