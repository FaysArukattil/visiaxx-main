import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/test_session_provider.dart';
import '../../data/providers/eye_exercise_provider.dart';

/// Manager for centralized provider operations.
/// Provides a single point to reset all providers in the app.
class ProviderManager {
  /// Reset all providers to their initial state
  /// Should be called on logout or session conflict
  static void resetAllProviders(BuildContext context) {
    debugPrint('[ProviderManager] Resetting all providers...');

    if (!context.mounted) {
      debugPrint('[ProviderManager]  ï¸ Context not mounted, skipping reset');
      return;
    }

    // Reset TestSessionProvider
    _resetTestSessionProvider(context);

    // Reset EyeExerciseProvider
    _resetEyeExerciseProvider(context);

    debugPrint('[ProviderManager] … All providers reset complete');
  }

  /// Reset TestSessionProvider
  static void _resetTestSessionProvider(BuildContext context) {
    try {
      final provider = Provider.of<TestSessionProvider>(context, listen: false);
      provider.reset();
      debugPrint('[ProviderManager] … TestSessionProvider reset');
    } catch (e) {
      debugPrint('[ProviderManager] Œ Failed to reset TestSessionProvider: $e');
    }
  }

  /// Reset EyeExerciseProvider
  static void _resetEyeExerciseProvider(BuildContext context) {
    try {
      final provider = Provider.of<EyeExerciseProvider>(context, listen: false);
      provider.resetState();
      debugPrint('[ProviderManager] … EyeExerciseProvider reset');
    } catch (e) {
      debugPrint('[ProviderManager] Œ Failed to reset EyeExerciseProvider: $e');
    }
  }

  /// Check if all providers are in clean/initial state
  /// Useful for debugging data leak issues
  static bool areProvidersClean(BuildContext context) {
    try {
      final testSession = Provider.of<TestSessionProvider>(
        context,
        listen: false,
      );
      final eyeExercise = Provider.of<EyeExerciseProvider>(
        context,
        listen: false,
      );

      final testSessionClean =
          testSession.profileId.isEmpty &&
          testSession.questionnaire == null &&
          testSession.visualAcuityRight == null &&
          testSession.visualAcuityLeft == null;

      final eyeExerciseClean = !eyeExercise.isInitialized;

      return testSessionClean && eyeExerciseClean;
    } catch (e) {
      debugPrint('[ProviderManager] Œ Error checking provider state: $e');
      return false;
    }
  }

  /// Log current state of all providers (for debugging)
  static void logProviderStates(BuildContext context) {
    try {
      final testSession = Provider.of<TestSessionProvider>(
        context,
        listen: false,
      );
      final eyeExercise = Provider.of<EyeExerciseProvider>(
        context,
        listen: false,
      );

      debugPrint('[ProviderManager] Provider States:');
      debugPrint('  TestSessionProvider:');
      debugPrint('    - profileType: ${testSession.profileType}');
      debugPrint('    - profileId: ${testSession.profileId}');
      debugPrint('    - profileName: ${testSession.profileName}');
      debugPrint(
        '    - hasQuestionnaire: ${testSession.questionnaire != null}',
      );
      debugPrint('    - hasVARight: ${testSession.visualAcuityRight != null}');
      debugPrint('    - hasVALeft: ${testSession.visualAcuityLeft != null}');
      debugPrint('    - hasColorVision: ${testSession.colorVision != null}');
      debugPrint('    - isTestInProgress: ${testSession.isTestInProgress}');
      debugPrint('  EyeExerciseProvider:');
      debugPrint('    - isInitialized: ${eyeExercise.isInitialized}');
      debugPrint('    - currentIndex: ${eyeExercise.currentIndex}');
      debugPrint('    - videosCount: ${eyeExercise.videos.length}');
    } catch (e) {
      debugPrint('[ProviderManager] Œ Error logging provider states: $e');
    }
  }
}

