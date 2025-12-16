import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/distance_detection_service.dart';

/// Centralized distance validation and messaging
class DistanceHelper {
  /// Check if distance is acceptable based on target
  static bool isDistanceAcceptable(
    double currentDistance,
    double targetDistance,
  ) {
    if (currentDistance <= 0) return false;
    return currentDistance >= targetDistance;
  }

  /// Get color based on distance status
  static Color getDistanceColor(double currentDistance, double targetDistance) {
    if (currentDistance <= 0) return AppColors.error;

    // Within 10cm below target = warning
    if (currentDistance >= targetDistance) {
      return AppColors.success;
    } else if (currentDistance >= (targetDistance - 10)) {
      return AppColors.warning;
    } else {
      return AppColors.error;
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
      case DistanceStatus.optimal:
        return 'Perfect! Distance is correct';
      case DistanceStatus.noFaceDetected:
        return 'Position your face in the camera';
      case DistanceStatus.tooFar:
        // This shouldn't happen with new logic, but just in case
        return 'Distance is good!';
    }
  }

  /// Get acceptable range string
  static String getAcceptableRangeText(double targetDistance) {
    return 'Minimum ${targetDistance.toInt()} cm';
  }

  /// Get detailed instruction text
  static String getDetailedInstruction(double targetDistance) {
    if (targetDistance >= 100) {
      return 'Maintain at least 1 meter distance';
    } else {
      return 'Maintain at least ${targetDistance.toInt()}cm distance';
    }
  }

  /// Check if test should pause (no face or too close)
  static bool shouldPauseTest(DistanceStatus status) {
    return status == DistanceStatus.noFaceDetected ||
        status == DistanceStatus.tooClose;
  }

  /// Get pause reason message
  static String getPauseReason(DistanceStatus status, double targetDistance) {
    if (status == DistanceStatus.noFaceDetected) {
      return 'Test paused - Face not detected';
    } else if (status == DistanceStatus.tooClose) {
      return 'Test paused - Too close to screen';
    } else {
      return 'Test paused - Adjust your position';
    }
  }
}
