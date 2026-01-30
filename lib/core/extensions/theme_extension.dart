import 'package:flutter/material.dart';

/// Theme helper extension to easily access theme colors
/// Usage: context.primary, context.onSurface, context.secondaryText
extension ThemeExtension on BuildContext {
  // Primary colors
  Color get primary => Theme.of(this).primaryColor;
  Color get onPrimary => Theme.of(this).colorScheme.onPrimary;

  // Surface colors
  Color get surface => Theme.of(this).colorScheme.surface;
  Color get onSurface => Theme.of(this).colorScheme.onSurface;
  Color get scaffoldBackground => Theme.of(this).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(this).cardColor;

  // Text colors
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.6);
  Color get textTertiary =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.4);

  // Error color
  Color get error => Theme.of(this).colorScheme.error;

  // Divider colors
  Color get dividerColor => Theme.of(this).dividerColor;

  // Check if dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
