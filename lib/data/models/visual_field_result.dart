import 'package:flutter/material.dart';

/// Quadrants for visual field testing
enum VisualFieldQuadrant {
  topRight('Upper Temporal'),
  topLeft('Upper Nasal'),
  bottomRight('Lower Temporal'),
  bottomLeft('Lower Nasal'),
  center('Central');

  final String label;
  const VisualFieldQuadrant(this.label);
}

/// A single stimulus point in the visual field test
class Stimulus {
  final Offset position;
  final VisualFieldQuadrant quadrant;
  final double intensity; // 0.1 to 1.0 (faint to bright)
  bool isDetected;

  Stimulus({
    required this.position,
    required this.quadrant,
    this.intensity = 1.0,
    this.isDetected = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'dx': position.dx,
      'dy': position.dy,
      'quadrant': quadrant.name,
      'intensity': intensity,
      'isDetected': isDetected,
    };
  }

  factory Stimulus.fromJson(Map<String, dynamic> json) {
    return Stimulus(
      position: Offset(
        (json['dx'] as num).toDouble(),
        (json['dy'] as num).toDouble(),
      ),
      quadrant: VisualFieldQuadrant.values.firstWhere(
        (e) => e.name == json['quadrant'],
        orElse: () => VisualFieldQuadrant.center,
      ),
      intensity: (json['intensity'] as num).toDouble(),
      isDetected: json['isDetected'] ?? false,
    );
  }
}

/// Result model for the Visual Field Test
class VisualFieldResult {
  final String id;
  final Map<VisualFieldQuadrant, double> quadrantSensitivity;
  final int totalStimuli;
  final int detectedStimuli;
  final DateTime date;
  final List<Stimulus> stimuliResults;

  VisualFieldResult({
    required this.id,
    required this.quadrantSensitivity,
    required this.totalStimuli,
    required this.detectedStimuli,
    required this.stimuliResults,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quadrantSensitivity': quadrantSensitivity.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'totalStimuli': totalStimuli,
      'detectedStimuli': detectedStimuli,
      'date': date.toIso8601String(),
      'stimuliResults': stimuliResults.map((s) => s.toJson()).toList(),
    };
  }

  factory VisualFieldResult.fromJson(Map<String, dynamic> json) {
    final sensitivityMap = (json['quadrantSensitivity'] as Map<String, dynamic>)
        .map(
          (key, value) => MapEntry(
            VisualFieldQuadrant.values.firstWhere(
              (e) => e.name == key,
              orElse: () => VisualFieldQuadrant.center,
            ),
            (value as num).toDouble(),
          ),
        );

    return VisualFieldResult(
      id: json['id'] ?? '',
      quadrantSensitivity: sensitivityMap,
      totalStimuli: json['totalStimuli'] ?? 0,
      detectedStimuli: json['detectedStimuli'] ?? 0,
      stimuliResults: (json['stimuliResults'] as List? ?? [])
          .map((s) => Stimulus.fromJson(s as Map<String, dynamic>))
          .toList(),
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
    );
  }

  double get overallSensitivity =>
      totalStimuli > 0 ? (detectedStimuli / totalStimuli) : 0.0;

  String get interpretation {
    final sensitivity = overallSensitivity;
    if (sensitivity >= 0.9) {
      return 'Excellent visual field sensitivity. No significant peripheral vision loss detected.';
    } else if (sensitivity >= 0.75) {
      return 'Good peripheral awareness. Some minor blind spots may be present.';
    } else if (sensitivity >= 0.5) {
      return 'Moderate peripheral vision loss detected. Consider more frequent monitoring.';
    } else {
      return 'Significant peripheral vision loss detected. Clinical evaluation is recommended to investigate potential causes like glaucoma.';
    }
  }
}
