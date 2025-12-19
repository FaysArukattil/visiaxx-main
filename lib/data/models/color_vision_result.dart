enum ColorVisionStatus {
  normal, // 12-14 correct out of 14
  mild, // 9-11 correct
  moderate, // 6-8 correct
  severe, // 0-5 correct
}

enum DeficiencyType {
  none,
  redGreenDeficiency, // Generic (can't distinguish specific type)
  protanopia, // No red cones (severe)
  protanomaly, // Weak red (mild)
  deuteranopia, // No green cones (severe)
  deuteranomaly, // Weak green (mild)
  protan,
  deutan,
}

enum DeficiencySeverity { none, mild, moderate, severe }

/// Complete color vision test result for BOTH eyes
class ColorVisionResult {
  final ColorVisionEyeResult rightEye;
  final ColorVisionEyeResult leftEye;
  final ColorVisionStatus overallStatus;
  final DeficiencyType deficiencyType;
  final DeficiencySeverity severity;
  final String recommendation;
  final DateTime timestamp;
  final int totalDurationSeconds;

  ColorVisionResult({
    required this.rightEye,
    required this.leftEye,
    required this.overallStatus,
    required this.deficiencyType,
    required this.severity,
    required this.recommendation,
    required this.timestamp,
    required this.totalDurationSeconds,
  });

  // Helper getters
  bool get isNormal => overallStatus == ColorVisionStatus.normal;
  bool get hasDeficiency => deficiencyType != DeficiencyType.none;

  String get summaryText {
    if (isNormal) {
      return 'Normal color vision in both eyes';
    } else {
      return '${deficiencyType.displayName} detected (${severity.displayName})';
    }
  }

  // Serialization
  Map<String, dynamic> toMap() {
    return {
      'rightEye': rightEye.toMap(),
      'leftEye': leftEye.toMap(),
      'overallStatus': overallStatus.name,
      'deficiencyType': deficiencyType.name,
      'severity': severity.name,
      'recommendation': recommendation,
      'timestamp': timestamp.toIso8601String(),
      'totalDurationSeconds': totalDurationSeconds,
    };
  }

  factory ColorVisionResult.fromMap(Map<String, dynamic> map) {
    return ColorVisionResult(
      rightEye: ColorVisionEyeResult.fromMap(map['rightEye']),
      leftEye: ColorVisionEyeResult.fromMap(map['leftEye']),
      overallStatus: ColorVisionStatus.values.firstWhere(
        (e) => e.name == map['overallStatus'],
        orElse: () => ColorVisionStatus.normal,
      ),
      deficiencyType: DeficiencyType.values.firstWhere(
        (e) => e.name == map['deficiencyType'],
        orElse: () => DeficiencyType.none,
      ),
      severity: DeficiencySeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => DeficiencySeverity.none,
      ),
      recommendation: map['recommendation'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      totalDurationSeconds: map['totalDurationSeconds'] ?? 0,
    );
  }

  // BACKWARD COMPATIBILITY: Old model accessors
  int get correctAnswers =>
      ((rightEye.correctAnswers + leftEye.correctAnswers) / 2).round();
  int get totalPlates => 14; // Total plates per eye (including demo)
  String? get deficiency => hasDeficiency ? deficiencyType.displayName : null;
  String get status => overallStatus.displayName;
  List<PlateResponse> get plateResponses => [
    ...rightEye.responses,
    ...leftEye.responses,
  ];
  List<int> get incorrectPlates {
    final incorrect = <int>[];
    for (final r in rightEye.responses) {
      if (!r.isCorrect && !r.wasDemo) incorrect.add(r.plateNumber);
    }
    for (final r in leftEye.responses) {
      if (!r.isCorrect && !r.wasDemo) incorrect.add(r.plateNumber);
    }
    return incorrect.toSet().toList()..sort();
  }
}

/// Result for a single eye
class ColorVisionEyeResult {
  final String eye; // 'right' or 'left'
  final int correctAnswers; // Out of 14 (including demo)
  final int totalDiagnosticPlates; // Always 14
  final List<PlateResponse> responses; // All 14 responses
  final ColorVisionStatus status;
  final DeficiencyType? detectedType;

  ColorVisionEyeResult({
    required this.eye,
    required this.correctAnswers,
    required this.totalDiagnosticPlates,
    required this.responses,
    required this.status,
    this.detectedType,
  });

  double get accuracy => correctAnswers / totalDiagnosticPlates;

  Map<String, dynamic> toMap() {
    return {
      'eye': eye,
      'correctAnswers': correctAnswers,
      'totalDiagnosticPlates': totalDiagnosticPlates,
      'responses': responses.map((r) => r.toMap()).toList(),
      'status': status.name,
      'detectedType': detectedType?.name,
    };
  }

  factory ColorVisionEyeResult.fromMap(Map<String, dynamic> map) {
    return ColorVisionEyeResult(
      eye: map['eye'] ?? 'right',
      correctAnswers: map['correctAnswers'] ?? 0,
      totalDiagnosticPlates: map['totalDiagnosticPlates'] ?? 14,
      responses:
          (map['responses'] as List<dynamic>?)
              ?.map((e) => PlateResponse.fromMap(e))
              .toList() ??
          [],
      status: ColorVisionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ColorVisionStatus.normal,
      ),
      detectedType: map['detectedType'] != null
          ? DeficiencyType.values.firstWhere(
              (e) => e.name == map['detectedType'],
              orElse: () => DeficiencyType.none,
            )
          : null,
    );
  }
}

/// Individual plate response
class PlateResponse {
  final int plateNumber; // 1-25
  final String category; // 'demo', 'transformation', etc.
  final String normalExpectedAnswer;
  final String userAnswer; // What user said/typed
  final bool isCorrect;
  final int responseTimeMs;
  final bool wasDemo;
  final String?
  selectionMethod; // NEW: 'normal', 'colorBlind', 'other', 'cantSee', null for legacy

  const PlateResponse({
    required this.plateNumber,
    required this.category,
    required this.normalExpectedAnswer,
    required this.userAnswer,
    required this.isCorrect,
    required this.responseTimeMs,
    this.wasDemo = false,
    this.selectionMethod, // Optional for backward compatibility
  });

  Map<String, dynamic> toMap() {
    return {
      'plateNumber': plateNumber,
      'category': category,
      'normalExpectedAnswer': normalExpectedAnswer,
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'responseTimeMs': responseTimeMs,
      'wasDemo': wasDemo,
      'selectionMethod': selectionMethod,
    };
  }

  factory PlateResponse.fromMap(Map<String, dynamic> map) {
    return PlateResponse(
      plateNumber: map['plateNumber'] ?? 0,
      category: map['category'] ?? '',
      normalExpectedAnswer:
          map['normalExpectedAnswer'] ?? map['expectedAnswer'] ?? '',
      userAnswer: map['userAnswer'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
      responseTimeMs: map['responseTimeMs'] ?? 0,
      wasDemo: map['wasDemo'] ?? false,
      selectionMethod: map['selectionMethod'], // Null for legacy data
    );
  }

  // Backward compatibility
  String get expectedAnswer => normalExpectedAnswer;
}

// Extension methods for display
extension ColorVisionStatusExtension on ColorVisionStatus {
  String get displayName {
    switch (this) {
      case ColorVisionStatus.normal:
        return 'Normal';
      case ColorVisionStatus.mild:
        return 'Mild Deficiency';
      case ColorVisionStatus.moderate:
        return 'Moderate Deficiency';
      case ColorVisionStatus.severe:
        return 'Severe Deficiency';
    }
  }
}

extension DeficiencyTypeExtension on DeficiencyType {
  String get displayName {
    switch (this) {
      case DeficiencyType.none:
        return 'None';
      case DeficiencyType.redGreenDeficiency:
        return 'Red-Green Color Vision Deficiency';
      case DeficiencyType.protanopia:
        return 'Protanopia (Red Deficiency - Severe)';
      case DeficiencyType.protanomaly:
        return 'Protanomaly (Red Deficiency - Mild)';
      case DeficiencyType.deuteranopia:
        return 'Deuteranopia (Green Deficiency - Severe)';
      case DeficiencyType.deuteranomaly:
        return 'Deuteranomaly (Green Deficiency - Mild)';
      case DeficiencyType.protan:
        return 'Protan (Red Deficiency)';
      case DeficiencyType.deutan:
        return 'Deutan (Green Deficiency)';
    }
  }
}

extension DeficiencySeverityExtension on DeficiencySeverity {
  String get displayName {
    switch (this) {
      case DeficiencySeverity.none:
        return 'None';
      case DeficiencySeverity.mild:
        return 'Mild';
      case DeficiencySeverity.moderate:
        return 'Moderate';
      case DeficiencySeverity.severe:
        return 'Severe';
    }
  }
}
