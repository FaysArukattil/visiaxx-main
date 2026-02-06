import 'package:cloud_firestore/cloud_firestore.dart';

enum ShadowTestGrade {
  grade0(0, 'Closed angle', 'Immediate risk', 'No space visible'),
  grade1(1, 'Very narrow angle', 'Very high risk', '<1:0.25'),
  grade2(2, 'Narrow angle', 'High risk of angle closure', '1:0.25'),
  grade3(3, 'Open angle', 'Low to moderate risk', '1:1 to 1:0.5'),
  grade4(4, 'Wide open angle', 'Low risk', '>1:1');

  final int grade;
  final String angleStatus;
  final String glaucomaRisk;
  final String ratio;

  const ShadowTestGrade(
    this.grade,
    this.angleStatus,
    this.glaucomaRisk,
    this.ratio,
  );

  static ShadowTestGrade fromGrade(int grade) {
    return ShadowTestGrade.values.firstWhere(
      (e) => e.grade == grade,
      orElse: () => ShadowTestGrade.grade3,
    );
  }
}

class EyeGrading {
  final ShadowTestGrade grade;
  final String? imagePath;
  final String? awsImageUrl; // To store AWS URL
  final double? shadowRatio;
  final DateTime timestamp;

  EyeGrading({
    required this.grade,
    this.imagePath,
    this.awsImageUrl,
    this.shadowRatio,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'grade': grade.grade,
      'angleStatus': grade.angleStatus,
      'glaucomaRisk': grade.glaucomaRisk,
      'ratio': grade.ratio,
      'imagePath': imagePath,
      'awsImageUrl': awsImageUrl,
      'shadowRatio': shadowRatio,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory EyeGrading.fromJson(Map<String, dynamic> json) {
    return EyeGrading(
      grade: ShadowTestGrade.fromGrade(json['grade'] ?? 3),
      imagePath: json['imagePath'],
      awsImageUrl: json['awsImageUrl'],
      shadowRatio: json['shadowRatio']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  EyeGrading copyWith({
    ShadowTestGrade? grade,
    String? imagePath,
    String? awsImageUrl,
    double? shadowRatio,
    DateTime? timestamp,
  }) {
    return EyeGrading(
      grade: grade ?? this.grade,
      imagePath: imagePath ?? this.imagePath,
      awsImageUrl: awsImageUrl ?? this.awsImageUrl,
      shadowRatio: shadowRatio ?? this.shadowRatio,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() => toJson();
}

class ShadowTestResult {
  final String id;
  final String patientId;
  final String? patientName;
  final EyeGrading rightEye;
  final EyeGrading leftEye;
  final DateTime testDate;
  final String interpretation;
  final String conclusion;
  final String overallRisk;
  final bool requiresReferral;

  ShadowTestResult({
    required this.id,
    required this.patientId,
    this.patientName,
    required this.rightEye,
    required this.leftEye,
    DateTime? testDate,
    String? interpretation,
    String? conclusion,
    String? overallRisk,
    bool? requiresReferral,
  }) : testDate = testDate ?? DateTime.now(),
       interpretation =
           interpretation ?? _generateInterpretation(rightEye, leftEye),
       conclusion = conclusion ?? _generateConclusion(rightEye, leftEye),
       overallRisk = overallRisk ?? _calculateOverallRisk(rightEye, leftEye),
       requiresReferral = requiresReferral ?? _shouldRefer(rightEye, leftEye);

  static String _generateInterpretation(
    EyeGrading rightEye,
    EyeGrading leftEye,
  ) {
    String interpretation = '';

    if (rightEye.grade.grade <= 2) {
      interpretation +=
          'Right Eye shows a significantly shallow anterior chamber, '
          'indicating ${rightEye.grade.glaucomaRisk.toLowerCase()} for angle-closure glaucoma.\n';
    } else {
      interpretation +=
          'Right Eye shows ${rightEye.grade.angleStatus.toLowerCase()}, '
          'indicating ${rightEye.grade.glaucomaRisk.toLowerCase()}.\n';
    }

    if (leftEye.grade.grade <= 2) {
      interpretation +=
          'Left Eye shows a significantly shallow anterior chamber, '
          'indicating ${leftEye.grade.glaucomaRisk.toLowerCase()} for angle-closure glaucoma.';
    } else {
      interpretation +=
          'Left Eye shows ${leftEye.grade.angleStatus.toLowerCase()}, '
          'indicating ${leftEye.grade.glaucomaRisk.toLowerCase()}.';
    }

    return interpretation;
  }

  static String _generateConclusion(EyeGrading rightEye, EyeGrading leftEye) {
    int minGrade = rightEye.grade.grade < leftEye.grade.grade
        ? rightEye.grade.grade
        : leftEye.grade.grade;

    if (minGrade == 0) {
      return 'Immediate medical attention required. Closed angle detected.';
    } else if (minGrade <= 1) {
      return 'Urgent referral to glaucoma specialist recommended. Very high risk detected.';
    } else if (minGrade == 2) {
      return 'Referral to glaucoma specialist recommended for further evaluation.';
    } else if (minGrade == 3) {
      return 'Routine eye examination recommended. Monitor for changes.';
    } else {
      return 'Normal anterior chamber depth. Continue routine eye care.';
    }
  }

  static String _calculateOverallRisk(EyeGrading rightEye, EyeGrading leftEye) {
    int minGrade = rightEye.grade.grade < leftEye.grade.grade
        ? rightEye.grade.grade
        : leftEye.grade.grade;

    if (minGrade == 0) return 'CRITICAL';
    if (minGrade == 1) return 'VERY HIGH';
    if (minGrade == 2) return 'HIGH';
    if (minGrade == 3) return 'MODERATE';
    return 'LOW';
  }

  static bool _shouldRefer(EyeGrading rightEye, EyeGrading leftEye) {
    return rightEye.grade.grade <= 2 || leftEye.grade.grade <= 2;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'rightEye': rightEye.toJson(),
      'leftEye': leftEye.toJson(),
      'testDate': Timestamp.fromDate(testDate),
      'interpretation': interpretation,
      'conclusion': conclusion,
      'overallRisk': overallRisk,
      'requiresReferral': requiresReferral,
    };
  }

  factory ShadowTestResult.fromJson(Map<String, dynamic> json) {
    return ShadowTestResult(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'],
      rightEye: EyeGrading.fromJson(json['rightEye']),
      leftEye: EyeGrading.fromJson(json['leftEye']),
      testDate: (json['testDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      interpretation: json['interpretation'],
      conclusion: json['conclusion'],
      overallRisk: json['overallRisk'],
      requiresReferral: json['requiresReferral'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => toJson();

  ShadowTestResult copyWith({
    String? id,
    String? patientId,
    String? patientName,
    EyeGrading? rightEye,
    EyeGrading? leftEye,
    DateTime? testDate,
    String? interpretation,
    String? conclusion,
    String? overallRisk,
    bool? requiresReferral,
  }) {
    return ShadowTestResult(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      rightEye: rightEye ?? this.rightEye,
      leftEye: leftEye ?? this.leftEye,
      testDate: testDate ?? this.testDate,
      interpretation: interpretation ?? this.interpretation,
      conclusion: conclusion ?? this.conclusion,
      overallRisk: overallRisk ?? this.overallRisk,
      requiresReferral: requiresReferral ?? this.requiresReferral,
    );
  }
}
