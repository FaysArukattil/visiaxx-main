import 'package:flutter/material.dart';

/// Model for individual eye care tips
class EyeCareTip {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String category;

  const EyeCareTip({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
  });
}

/// Category model for eye care sections
class EyeCareTipCategory {
  final String id;
  final String title;
  final String emoji;
  final Color color;
  final List<EyeCareTip> tips;

  const EyeCareTipCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.tips,
  });
}
