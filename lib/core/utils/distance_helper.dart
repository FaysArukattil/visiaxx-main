import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/distance_detection_service.dart';

/// Centralized distance validation and messaging
class DistanceHelper {
  /// Check if distance is acceptable based on target
  static bool isDistanceAcceptable(
    double currentDistance,
    double targetDistance, {
    double tolerance = 5.0,
  }) {
    if (currentDistance <= 0) return false;

    // Calculate acceptable range
    final minDistance = targetDistance - tolerance;
    final maxDistance = targetDistance + tolerance;

    return currentDistance >= minDistance && currentDistance <= maxDistance;
  }

  /// Get color based on distance status
  static Color getDistanceColor(
    double currentDistance,
    double targetDistance, {
    double tolerance = 5.0,
  }) {
    if (currentDistance <= 0) return AppColors.error;

    final minDistance = targetDistance - tolerance;
    final maxDistance = targetDistance + tolerance;

    // Within optimal range
    if (currentDistance >= minDistance && currentDistance <= maxDistance) {
      return AppColors.success;
    }
    // Too close
    else if (currentDistance < minDistance) {
      return AppColors.error;
    }
    // Too far
    else {
      return AppColors.warning;
    }
  }

  /// Get user-friendly message for distance status
  static String getDistanceMessage(
    DistanceStatus status,
    double targetDistance,
  ) {
    switch (status) {
      case DistanceStatus.tooClose:
        return 'Move back - You are too close';
      case DistanceStatus.tooFar:
        return 'Move closer - You are too far';
      case DistanceStatus.optimal:
        return 'Perfect! Distance is correct';
      case DistanceStatus.noFaceDetected:
        return 'Position your face in the camera';
    }
  }

  /// Get acceptable range string
  static String getAcceptableRangeText(
    double targetDistance, {
    double tolerance = 5.0,
  }) {
    final min = (targetDistance - tolerance).toInt();
    final max = (targetDistance + tolerance).toInt();
    return '$min - $max cm';
  }

  /// Get detailed instruction text
  static String getDetailedInstruction(double targetDistance) {
    if (targetDistance >= 100) {
      return 'Maintain 1 meter (100cm) distance from screen';
    } else {
      return 'Maintain ${targetDistance.toInt()}cm distance from screen';
    }
  }

  /// Check if test should pause (no face or wrong distance)
  static bool shouldPauseTest(DistanceStatus status) {
    return status == DistanceStatus.noFaceDetected ||
        status == DistanceStatus.tooClose ||
        status == DistanceStatus.tooFar;
  }

  /// Get pause reason message
  static String getPauseReason(DistanceStatus status, double targetDistance) {
    if (status == DistanceStatus.noFaceDetected) {
      return 'Face not detected';
    } else if (status == DistanceStatus.tooClose) {
      return 'Too close to screen';
    } else if (status == DistanceStatus.tooFar) {
      return 'Too far from screen';
    } else {
      return 'Adjust your position';
    }
  }

  /// Check if distance is acceptable for specific test type
  /// Uses more lenient thresholds during active testing
  static bool isDistanceAcceptableForTest(
    double currentDistance,
    String testType,
  ) {
    if (currentDistance <= 0) return false;

    switch (testType) {
      case 'visual_acuity':
        // Visual acuity: accept if >100cm during test
        return currentDistance > 100;
      case 'short_distance':
      case 'amsler_grid':
      case 'color_vision':
        // Reading distance tests: accept if >40cm
        return currentDistance > 40;
      default:
        // Fallback to standard validation
        return currentDistance > 40;
    }
  }

  /// Get minimum acceptable distance for test type
  static double getMinimumDistanceForTest(String testType) {
    switch (testType) {
      case 'visual_acuity':
        return 100.0;
      case 'short_distance':
      case 'amsler_grid':
      case 'color_vision':
        return 40.0;
      default:
        return 40.0;
    }
  }

  /// Check if distance should trigger pause based on test type
  /// More lenient than calibration requirements
  static bool shouldPauseTestForDistance(
    double currentDistance,
    DistanceStatus status,
    String testType,
  ) {
    // Always pause if no face detected
    if (status == DistanceStatus.noFaceDetected) {
      return true;
    }

    // Check test-specific minimum distance
    final minDistance = getMinimumDistanceForTest(testType);

    // Pause if below minimum
    if (currentDistance > 0 && currentDistance < minDistance) {
      return true;
    }

    // Pause if too close (safety threshold)
    if (status == DistanceStatus.tooClose) {
      return true;
    }

    return false;
  }
}
