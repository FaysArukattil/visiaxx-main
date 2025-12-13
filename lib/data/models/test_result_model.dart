import 'package:cloud_firestore/cloud_firestore.dart';
import 'questionnaire_model.dart';
import 'visiual_acuity_result.dart';
import 'color_vision_result.dart';
import 'amsler_grid_result.dart';

/// Test result status
enum TestStatus {
  normal('Normal', '✅'),
  review('Review Recommended', '⚠️'),
  urgent('Urgent Consultation', '🚨');

  final String label;
  final String emoji;

  const TestStatus(this.label, this.emoji);
}

/// Comprehensive test result model containing all vision test data
class TestResultModel {
  final String id;
  final String userId;
  final String profileId;
  final String profileName;
  final String profileType; // 'self' or 'family'
  final DateTime timestamp;
  final String testType; // 'quick' or 'comprehensive'
  final QuestionnaireModel? questionnaire;
  final VisualAcuityResult? visualAcuityRight;
  final VisualAcuityResult? visualAcuityLeft;
  final ColorVisionResult? colorVision;
  final AmslerGridResult? amslerGridRight;
  final AmslerGridResult? amslerGridLeft;
  final TestStatus overallStatus;
  final String recommendation;
  final String? pdfUrl;
  final bool isFlagged;
  final PractitionerNotes? practitionerNotes;

  TestResultModel({
    required this.id,
    required this.userId,
    required this.profileId,
    required this.profileName,
    required this.profileType,
    required this.timestamp,
    required this.testType,
    this.questionnaire,
    this.visualAcuityRight,
    this.visualAcuityLeft,
    this.colorVision,
    this.amslerGridRight,
    this.amslerGridLeft,
    required this.overallStatus,
    required this.recommendation,
    this.pdfUrl,
    this.isFlagged = false,
    this.practitionerNotes,
  });

  factory TestResultModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TestResultModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      profileId: data['profileId'] ?? '',
      profileName: data['profileName'] ?? '',
      profileType: data['profileType'] ?? 'self',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      testType: data['testType'] ?? 'quick',
      visualAcuityRight: data['visualAcuityRight'] != null
          ? VisualAcuityResult.fromMap(data['visualAcuityRight'])
          : null,
      visualAcuityLeft: data['visualAcuityLeft'] != null
          ? VisualAcuityResult.fromMap(data['visualAcuityLeft'])
          : null,
      colorVision: data['colorVision'] != null
          ? ColorVisionResult.fromMap(data['colorVision'])
          : null,
      amslerGridRight: data['amslerGridRight'] != null
          ? AmslerGridResult.fromMap(data['amslerGridRight'])
          : null,
      amslerGridLeft: data['amslerGridLeft'] != null
          ? AmslerGridResult.fromMap(data['amslerGridLeft'])
          : null,
      overallStatus: TestStatus.values.firstWhere(
        (s) => s.name == data['overallStatus'],
        orElse: () => TestStatus.normal,
      ),
      recommendation: data['recommendation'] ?? '',
      pdfUrl: data['pdfUrl'],
      isFlagged: data['isFlagged'] ?? false,
      practitionerNotes: data['practitionerNotes'] != null
          ? PractitionerNotes.fromMap(data['practitionerNotes'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'profileId': profileId,
      'profileName': profileName,
      'profileType': profileType,
      'timestamp': Timestamp.fromDate(timestamp),
      'testType': testType,
      'questionnaire': questionnaire?.toFirestore(),
      'visualAcuityRight': visualAcuityRight?.toMap(),
      'visualAcuityLeft': visualAcuityLeft?.toMap(),
      'colorVision': colorVision?.toMap(),
      'amslerGridRight': amslerGridRight?.toMap(),
      'amslerGridLeft': amslerGridLeft?.toMap(),
      'overallStatus': overallStatus.name,
      'recommendation': recommendation,
      'pdfUrl': pdfUrl,
      'isFlagged': isFlagged,
      'practitionerNotes': practitionerNotes?.toMap(),
    };
  }

  /// Calculate overall status based on individual test results
  static TestStatus calculateOverallStatus({
    VisualAcuityResult? vaRight,
    VisualAcuityResult? vaLeft,
    ColorVisionResult? colorVision,
    AmslerGridResult? amslerRight,
    AmslerGridResult? amslerLeft,
  }) {
    // Check for urgent conditions
    if ((amslerRight?.hasDistortions ?? false) ||
        (amslerLeft?.hasDistortions ?? false)) {
      return TestStatus.urgent;
    }

    // Check visual acuity thresholds
    if (vaRight != null && vaRight.logMAR >= 0.5) {
      return TestStatus.urgent;
    }
    if (vaLeft != null && vaLeft.logMAR >= 0.5) {
      return TestStatus.urgent;
    }

    // Check for review conditions
    if (colorVision != null && !colorVision.isNormal) {
      return TestStatus.review;
    }
    if (vaRight != null && vaRight.logMAR >= 0.3) {
      return TestStatus.review;
    }
    if (vaLeft != null && vaLeft.logMAR >= 0.3) {
      return TestStatus.review;
    }

    return TestStatus.normal;
  }

  /// Generate recommendation text based on results
  static String generateRecommendation(TestStatus status) {
    switch (status) {
      case TestStatus.normal:
        return 'Your vision appears to be healthy. Continue with regular annual eye check-ups.';
      case TestStatus.review:
        return 'Some aspects of your vision test suggest a follow-up examination would be beneficial. Please schedule an appointment with an eye care professional.';
      case TestStatus.urgent:
        return 'Your test results indicate that you should see an eye care professional as soon as possible. Please schedule an appointment within the next few days.';
    }
  }

  TestResultModel copyWith({
    String? id,
    String? userId,
    String? profileId,
    String? profileName,
    String? profileType,
    DateTime? timestamp,
    String? testType,
    QuestionnaireModel? questionnaire,
    VisualAcuityResult? visualAcuityRight,
    VisualAcuityResult? visualAcuityLeft,
    ColorVisionResult? colorVision,
    AmslerGridResult? amslerGridRight,
    AmslerGridResult? amslerGridLeft,
    TestStatus? overallStatus,
    String? recommendation,
    String? pdfUrl,
    bool? isFlagged,
    PractitionerNotes? practitionerNotes,
  }) {
    return TestResultModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      profileType: profileType ?? this.profileType,
      timestamp: timestamp ?? this.timestamp,
      testType: testType ?? this.testType,
      questionnaire: questionnaire ?? this.questionnaire,
      visualAcuityRight: visualAcuityRight ?? this.visualAcuityRight,
      visualAcuityLeft: visualAcuityLeft ?? this.visualAcuityLeft,
      colorVision: colorVision ?? this.colorVision,
      amslerGridRight: amslerGridRight ?? this.amslerGridRight,
      amslerGridLeft: amslerGridLeft ?? this.amslerGridLeft,
      overallStatus: overallStatus ?? this.overallStatus,
      recommendation: recommendation ?? this.recommendation,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      isFlagged: isFlagged ?? this.isFlagged,
      practitionerNotes: practitionerNotes ?? this.practitionerNotes,
    );
  }
}

/// Practitioner notes model
class PractitionerNotes {
  final String examinerId;
  final String examinerName;
  final String notes;
  final String status;
  final DateTime timestamp;

  PractitionerNotes({
    required this.examinerId,
    required this.examinerName,
    required this.notes,
    required this.status,
    required this.timestamp,
  });

  factory PractitionerNotes.fromMap(Map<String, dynamic> data) {
    return PractitionerNotes(
      examinerId: data['examinerId'] ?? '',
      examinerName: data['examinerName'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'examinerId': examinerId,
      'examinerName': examinerName,
      'notes': notes,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
