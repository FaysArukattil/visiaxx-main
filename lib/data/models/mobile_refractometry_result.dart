/// Single eye result for Mobile Refractometry
class MobileRefractometryEyeResult {
  final String eye; // 'right' or 'left'
  final String sphere;
  final String cylinder;
  final int axis;
  final String accuracy;
  final String avgBlur;
  final String addPower; // For presbyopia
  final String? interpretation; // Specific diagnosis/classification
  final String visualAcuity; // Best Snellen achieved
  final List<Map<String, dynamic>>
  characterStats; // Breakdown by character type
  final String severityLevel; // 'Normal', 'Slight', 'Moderate', 'High'
  final String
  refractiveErrorType; // 'Normal', 'Myopia', 'Hyperopia', 'Astigmatism', 'Presbyopia'

  MobileRefractometryEyeResult({
    required this.eye,
    required this.sphere,
    required this.cylinder,
    required this.axis,
    required this.accuracy,
    required this.avgBlur,
    required this.addPower,
    this.interpretation,
    this.visualAcuity = '6/60',
    this.characterStats = const [],
    this.severityLevel = 'Normal',
    this.refractiveErrorType = 'Normal',
  });

  Map<String, dynamic> toJson() {
    return {
      'eye': eye,
      'sphere': sphere,
      'cylinder': cylinder,
      'axis': axis,
      'accuracy': accuracy,
      'avgBlur': avgBlur,
      'addPower': addPower,
      'interpretation': interpretation,
      'visualAcuity': visualAcuity,
      'characterStats': characterStats,
      'severityLevel': severityLevel,
      'refractiveErrorType': refractiveErrorType,
    };
  }

  factory MobileRefractometryEyeResult.fromJson(Map<String, dynamic> json) {
    return MobileRefractometryEyeResult(
      eye: json['eye'] ?? '',
      sphere: json['sphere'] ?? '0.00',
      cylinder: json['cylinder'] ?? '0.00',
      axis: json['axis'] ?? 0,
      accuracy: json['accuracy'] ?? '0.0',
      avgBlur: json['avgBlur'] ?? '0.00',
      addPower: json['addPower'] ?? '0.00',
      interpretation: json['interpretation'],
      visualAcuity: json['visualAcuity'] ?? '6/60',
      characterStats: List<Map<String, dynamic>>.from(
        json['characterStats'] ?? [],
      ),
      severityLevel: json['severityLevel'] ?? 'Normal',
      refractiveErrorType: json['refractiveErrorType'] ?? 'Normal',
    );
  }

  Map<String, dynamic> toMap() => toJson();

  factory MobileRefractometryEyeResult.fromMap(Map<String, dynamic> map) {
    return MobileRefractometryEyeResult.fromJson(map);
  }
}

/// Complete Mobile Refractometry test result
class MobileRefractometryResult {
  final MobileRefractometryEyeResult? rightEye;
  final MobileRefractometryEyeResult? leftEye;
  final int patientAge;
  final List<String> healthWarnings; // Disease screening alerts
  final List<Map<String, dynamic>> identifiedRisks; // Structured risk data
  final List<Map<String, dynamic>>
  detectedDiseases; // VA-based disease screening
  final bool criticalAlert;
  final bool requiresUrgentReferral; // Urgent ophthalmologist visit needed
  final String overallInterpretation;
  final bool isAccommodating;
  final DateTime timestamp;
  final List<Map<String, dynamic>> detectedConditions; // Flagged pathologies
  final double reliabilityScore; // Based on response time consistency
  final String recommendedFollowUp; // Specific next steps

  MobileRefractometryResult({
    this.rightEye,
    this.leftEye,
    required this.patientAge,
    this.healthWarnings = const [],
    this.identifiedRisks = const [],
    this.detectedDiseases = const [],
    this.criticalAlert = false,
    this.requiresUrgentReferral = false,
    this.overallInterpretation = '',
    this.isAccommodating = false,
    DateTime? timestamp,
    this.detectedConditions = const [],
    this.reliabilityScore = 0.0,
    this.recommendedFollowUp = '',
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'rightEye': rightEye?.toJson(),
      'leftEye': leftEye?.toJson(),
      'patientAge': patientAge,
      'healthWarnings': healthWarnings,
      'identifiedRisks': identifiedRisks,
      'detectedDiseases': detectedDiseases,
      'criticalAlert': criticalAlert,
      'requiresUrgentReferral': requiresUrgentReferral,
      'overallInterpretation': overallInterpretation,
      'isAccommodating': isAccommodating,
      'timestamp': timestamp.toIso8601String(),
      'detectedConditions': detectedConditions,
      'reliabilityScore': reliabilityScore,
      'recommendedFollowUp': recommendedFollowUp,
    };
  }

  factory MobileRefractometryResult.fromJson(Map<String, dynamic> json) {
    return MobileRefractometryResult(
      rightEye: json['rightEye'] != null
          ? MobileRefractometryEyeResult.fromJson(json['rightEye'])
          : null,
      leftEye: json['leftEye'] != null
          ? MobileRefractometryEyeResult.fromJson(json['leftEye'])
          : null,
      patientAge: json['patientAge'] ?? 30,
      healthWarnings: List<String>.from(json['healthWarnings'] ?? []),
      identifiedRisks: List<Map<String, dynamic>>.from(
        json['identifiedRisks'] ?? [],
      ),
      detectedDiseases: List<Map<String, dynamic>>.from(
        json['detectedDiseases'] ?? [],
      ),
      criticalAlert: json['criticalAlert'] ?? false,
      requiresUrgentReferral: json['requiresUrgentReferral'] ?? false,
      overallInterpretation: json['overallInterpretation'] ?? '',
      isAccommodating: json['isAccommodating'] ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      detectedConditions: List<Map<String, dynamic>>.from(
        json['detectedConditions'] ?? [],
      ),
      reliabilityScore: (json['reliabilityScore'] ?? 0.0).toDouble(),
      recommendedFollowUp: json['recommendedFollowUp'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => toJson();

  factory MobileRefractometryResult.fromMap(Map<String, dynamic> map) {
    return MobileRefractometryResult.fromJson(map);
  }
}
