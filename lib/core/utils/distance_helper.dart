// ignore_for_file: unused_local_variable

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
  /// Get color based on distance status
  /// Get color based on distance status
  static Color getDistanceColor(
    double currentDistance,
    double targetDistance, {
    double tolerance = 5.0,
    String? testType,
  }) {
    // … FIX: No face detected
    if (currentDistance <= 0) return AppColors.error;

    // Use test-specific floor if type is provided
    final minDistance = testType != null
        ? getMinimumDistanceForTest(testType)
        : (targetDistance - tolerance);

    // FIX: Only show error if TOO CLOSE (below minimum)
    // For refraction distance (60-100+), anything above 60 is green.
    // For refraction near (35+), anything above 35 is green.
    if (currentDistance < minDistance) {
      return AppColors.error; // Too close
    } else {
      return AppColors.success; // At minimum or further - both safe
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
      case DistanceStatus.optimal:
        return 'Perfect! Distance is correct';
      case DistanceStatus.noFaceDetected:
        return 'Searching for face...';
      case DistanceStatus.faceDetectedNoDistance:
        return 'Distance search active';
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

  /// Check if face is detected (even if distance can't be calculated)
  /// Returns true for optimal, faceDetectedNoDistance, tooClose, tooFar
  /// Returns false only for noFaceDetected
  /// Check if face is detected (even if distance can't be calculated)
  /// Returns true for optimal, faceDetectedNoDistance, tooClose, tooFar
  /// Returns false only for noFaceDetected
  static bool isFaceDetected(DistanceStatus status) {
    // … FIX: Face is detected in all states except noFaceDetected
    return status != DistanceStatus.noFaceDetected;
  }

  /// Check if test should pause (no face or wrong distance)
  static bool shouldPauseTest(DistanceStatus status) {
    // Only pause if COMPLETELY no face detected
    // Don't pause for faceDetectedNoDistance - face IS visible
    return status == DistanceStatus.noFaceDetected;
  }

  /// Get pause reason message
  /// Get pause reason message
  /// Get pause reason message
  static String getPauseReason(DistanceStatus status, double targetDistance) {
    if (status == DistanceStatus.noFaceDetected) {
      return 'No Face Detected';
    }
    if (status == DistanceStatus.tooClose) {
      return 'Too close to screen';
    } else if (status == DistanceStatus.tooFar) {
      return 'Too far from screen';
    } else {
      return 'Maintain distance';
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

  /// Get minimum acceptable distance for test type (LENIENT FLOOR)
  static double getMinimumDistanceForTest(String testType) {
    switch (testType) {
      case 'refraction_distance':
        return 60.0; // User requested 60-100+ range
      case 'refraction_near':
        return 35.0; // User requested 35+ for near
      case 'visual_acuity':
        return 80.0; // User requested floor at 80cm for 1m test
      case 'short_distance':
      case 'amsler_grid':
      case 'color_vision':
        return 35.0; // User requested floor at 35cm for 40cm test
      default:
        return 35.0;
    }
  }

  /// Check if distance should trigger pause based on test type
  /// More lenient than calibration requirements
  /// Check if distance should trigger pause based on test type
  /// More lenient than calibration requirements
  /// Check if distance should trigger pause based on test type
  /// More lenient than calibration requirements
  static bool shouldPauseTestForDistance(
    double currentDistance,
    DistanceStatus status,
    String testType,
  ) {
    // … Pause if no face detected (currentDistance <= 0)
    // OR if too close (below minimum)
    final minDistance = getMinimumDistanceForTest(testType);

    if (currentDistance <= 0 || currentDistance < minDistance) {
      return true;
    }

    return false;
  }

  /// Check if distance is correct for feedback display
  static bool isDistanceCorrect(DistanceStatus status) {
    // Face is detected and not in tooClose state
    return status == DistanceStatus.optimal ||
        status == DistanceStatus.tooFar ||
        status == DistanceStatus.faceDetectedNoDistance;
  }
}
