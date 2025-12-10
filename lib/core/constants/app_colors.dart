import 'package:flutter/material.dart';

/// Centralized color management for the Vision Testing App
/// All UI components must reference these constants (NO hardcoded colors)
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryLight = Color(0xFF5AC8FA);
  static const Color primaryDark = Color(0xFF0056B3);

  // Secondary Colors
  static const Color secondary = Color(0xFF5856D6);
  static const Color secondaryLight = Color(0xFF8E8AE6);
  static const Color secondaryDark = Color(0xFF3D3B9E);

  // Accent Colors
  static const Color accent = Color(0xFFFF3B30);
  static const Color accentLight = Color(0xFFFF6961);
  static const Color accentDark = Color(0xFFCC2F26);

  // Status Colors
  static const Color success = Color(0xFF34C759);
  static const Color successLight = Color(0xFF6DD58B);
  static const Color successDark = Color(0xFF248A3D);

  static const Color warning = Color(0xFFFF9500);
  static const Color warningLight = Color(0xFFFFB84D);
  static const Color warningDark = Color(0xFFCC7700);

  static const Color error = Color(0xFFFF3B30);
  static const Color errorLight = Color(0xFFFF6961);
  static const Color errorDark = Color(0xFFCC2F26);

  static const Color info = Color(0xFF5AC8FA);
  static const Color infoLight = Color(0xFF8DD8FB);
  static const Color infoDark = Color(0xFF2DA0CC);

  // Background Colors
  static const Color background = Color(0xFFF2F2F7);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF1C1C1E);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF9F9F9);
  static const Color surfaceDark = Color(0xFF2C2C2E);

  // Text Colors
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF6C6C70);
  static const Color textTertiary = Color(0xFFAEAEB2);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Border & Divider Colors
  static const Color border = Color(0xFFE5E5EA);
  static const Color divider = Color(0xFFC6C6C8);

  // Card Colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x1A000000);

  // Test-specific Colors
  static const Color testBackground = Color(0xFFFFFFFF);
  static const Color distanceOk = Color(0xFF34C759);
  static const Color distanceWarning = Color(0xFFFF9500);
  static const Color distanceError = Color(0xFFFF3B30);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF007AFF),
    Color(0xFF5856D6),
  ];

  static const List<Color> successGradient = [
    Color(0xFF34C759),
    Color(0xFF30D158),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
  ];

  static const List<Color> errorGradient = [
    Color(0xFFFF3B30),
    Color(0xFFFF6961),
  ];

  // Eye Test Colors
  static const Color rightEye = Color(0xFF007AFF);
  static const Color leftEye = Color(0xFF34C759);

  // Amsler Grid Colors
  static const Color amslerGridLine = Color(0xFF000000);
  static const Color amslerCenterDot = Color(0xFFFF3B30);
  static const Color amslerDistortion = Color(0xFFFF3B30);

  // Overlay Colors
  static const Color overlayLight = Color(0x80FFFFFF);
  static const Color overlayDark = Color(0x80000000);
  static const Color relaxationOverlay = Color(0xE6000000);

  // Role-based Colors
  static const Color userRole = Color(0xFF007AFF);
  static const Color examinerRole = Color(0xFF5856D6);
  static const Color adminRole = Color(0xFFFF3B30);
}
