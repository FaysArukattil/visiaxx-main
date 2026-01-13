/// Single eye result for Mobile Refractometry
class MobileRefractometryEyeResult {
  final String eye; // 'right' or 'left'
  final String sphere;
  final String cylinder;
  final int axis;
  final String accuracy;
  final String avgBlur;
  final String addPower; // For presbyopia

  MobileRefractometryEyeResult({
    required this.eye,
    required this.sphere,
    required this.cylinder,
    required this.axis,
    required this.accuracy,
    required this.avgBlur,
    required this.addPower,
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
  final bool criticalAlert;
  final String overallInterpretation;
  final bool isAccommodating;
  final DateTime timestamp;

  MobileRefractometryResult({
    this.rightEye,
    this.leftEye,
    required this.patientAge,
    this.healthWarnings = const [],
    this.identifiedRisks = const [],
    this.criticalAlert = false,
    this.overallInterpretation = '',
    this.isAccommodating = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'rightEye': rightEye?.toJson(),
      'leftEye': leftEye?.toJson(),
      'patientAge': patientAge,
      'healthWarnings': healthWarnings,
      'identifiedRisks': identifiedRisks,
      'criticalAlert': criticalAlert,
      'overallInterpretation': overallInterpretation,
      'isAccommodating': isAccommodating,
      'timestamp': timestamp.toIso8601String(),
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
      criticalAlert: json['criticalAlert'] ?? false,
      overallInterpretation: json['overallInterpretation'] ?? '',
      isAccommodating: json['isAccommodating'] ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => toJson();

  factory MobileRefractometryResult.fromMap(Map<String, dynamic> map) {
    return MobileRefractometryResult.fromJson(map);
  }
}
