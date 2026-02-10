import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visiaxx/data/models/mobile_refractometry_result.dart';
import 'questionnaire_model.dart';
import 'visiual_acuity_result.dart';
import 'color_vision_result.dart';
import 'amsler_grid_result.dart';
import 'short_distance_result.dart';
import 'pelli_robson_result.dart';
import 'refraction_prescription_model.dart';
import 'shadow_test_result.dart';
import 'stereopsis_result.dart';
import 'eye_hydration_result.dart';

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
  final int? profileAge; // Age for PDF naming
  final String? profileSex; // Gender for PDF
  final String profileType; // 'self' or 'family'
  final DateTime timestamp;
  final String testType; // 'quick' or 'comprehensive'
  final QuestionnaireModel? questionnaire;
  final VisualAcuityResult? visualAcuityRight;
  final VisualAcuityResult? visualAcuityLeft;
  final ShortDistanceResult? shortDistance;
  final ColorVisionResult? colorVision;
  final AmslerGridResult? amslerGridRight;
  final AmslerGridResult? amslerGridLeft;
  final PelliRobsonResult? pelliRobson;
  final MobileRefractometryResult? mobileRefractometry;
  final ShadowTestResult? shadowTest;
  final StereopsisResult? stereopsis;
  final EyeHydrationResult? eyeHydration;
  final RefractionPrescriptionModel? refractionPrescription;
  final TestStatus overallStatus;
  final String recommendation;
  final String? pdfUrl;
  final bool isFlagged;
  final bool isDeleted; // Soft-delete support
  final PractitionerNotes? practitionerNotes;

  TestResultModel({
    required this.id,
    required this.userId,
    required this.profileId,
    required this.profileName,
    this.profileAge,
    this.profileSex,
    required this.profileType,
    required this.timestamp,
    required this.testType,
    this.questionnaire,
    this.visualAcuityRight,
    this.visualAcuityLeft,
    this.shortDistance,
    this.colorVision,
    this.amslerGridRight,
    this.amslerGridLeft,
    this.pelliRobson,
    this.mobileRefractometry,
    this.shadowTest,
    this.stereopsis,
    this.eyeHydration,
    this.refractionPrescription,
    required this.overallStatus,
    required this.recommendation,
    this.pdfUrl,
    this.isFlagged = false,
    this.isDeleted = false,
    this.practitionerNotes,
  });

  factory TestResultModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TestResultModel.fromJson({...data, 'id': doc.id});
  }

  factory TestResultModel.fromJson(Map<String, dynamic> data) {
    return TestResultModel(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      profileId: data['profileId'] ?? '',
      profileName: data['profileName'] ?? '',
      profileAge: data['profileAge'],
      profileSex: data['profileSex'],
      profileType: data['profileType'] ?? 'self',
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : (data['timestamp'] != null
                ? DateTime.parse(data['timestamp'].toString())
                : DateTime.now()),
      testType: data['testType'] ?? 'quick',
      questionnaire: data['questionnaire'] != null
          ? QuestionnaireModel.fromMap(
              data['questionnaire'] as Map<String, dynamic>,
            )
          : null,
      visualAcuityRight: data['visualAcuityRight'] != null
          ? VisualAcuityResult.fromMap(data['visualAcuityRight'])
          : null,
      visualAcuityLeft: data['visualAcuityLeft'] != null
          ? VisualAcuityResult.fromMap(data['visualAcuityLeft'])
          : null,
      shortDistance: data['shortDistance'] != null
          ? ShortDistanceResult.fromMap(data['shortDistance'])
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
      pelliRobson: data['pelliRobson'] != null
          ? PelliRobsonResult.fromMap(data['pelliRobson'])
          : null,

      mobileRefractometry: data['mobileRefractometry'] != null
          ? MobileRefractometryResult.fromJson(data['mobileRefractometry'])
          : null,
      shadowTest: data['shadowTest'] != null
          ? ShadowTestResult.fromJson(data['shadowTest'])
          : null,
      stereopsis: data['stereopsis'] != null
          ? StereopsisResult.fromJson(data['stereopsis'])
          : null,
      eyeHydration: data['eyeHydration'] != null
          ? EyeHydrationResult.fromJson(data['eyeHydration'])
          : null,
      refractionPrescription: data['refractionPrescription'] != null
          ? RefractionPrescriptionModel.fromMap(data['refractionPrescription'])
          : null,
      overallStatus: TestStatus.values.firstWhere(
        (s) => s.name == data['overallStatus'],
        orElse: () => TestStatus.normal,
      ),
      recommendation: data['recommendation'] ?? '',
      pdfUrl: data['pdfUrl'],
      isFlagged: data['isFlagged'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      practitionerNotes: data['practitionerNotes'] != null
          ? PractitionerNotes.fromMap(data['practitionerNotes'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'profileId': profileId,
      'profileName': profileName,
      'profileAge': profileAge,
      'profileSex': profileSex,
      'profileType': profileType,
      'timestamp': timestamp.toIso8601String(),
      'testType': testType,
      'questionnaire': questionnaire?.toJson(),
      'visualAcuityRight': visualAcuityRight?.toMap(),
      'visualAcuityLeft': visualAcuityLeft?.toMap(),
      'shortDistance': shortDistance?.toMap(),
      'colorVision': colorVision?.toMap(),
      'amslerGridRight': amslerGridRight?.toMap(),
      'amslerGridLeft': amslerGridLeft?.toMap(),
      'pelliRobson': pelliRobson?.toMap(),
      'mobileRefractometry': mobileRefractometry?.toJson(),
      'shadowTest': shadowTest?.toJson(),
      'stereopsis': stereopsis?.toJson(),
      'eyeHydration': eyeHydration?.toJson(),
      'refractionPrescription': refractionPrescription?.toJson(),
      'overallStatus': overallStatus.name,
      'recommendation': recommendation,
      'pdfUrl': pdfUrl,
      'isFlagged': isFlagged,
      'isDeleted': isDeleted,
      'practitionerNotes': practitionerNotes?.toJson(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'profileId': profileId,
      'profileName': profileName,
      'profileAge': profileAge,
      'profileType': profileType,
      'timestamp': Timestamp.fromDate(timestamp),
      'testType': testType,
      'questionnaire': questionnaire?.toFirestore(),
      'visualAcuityRight': visualAcuityRight?.toMap(),
      'visualAcuityLeft': visualAcuityLeft?.toMap(),
      'shortDistance': shortDistance?.toMap(),
      'colorVision': colorVision?.toMap(),
      'amslerGridRight': amslerGridRight?.toMap(),
      'amslerGridLeft': amslerGridLeft?.toMap(),
      'pelliRobson': pelliRobson?.toMap(),
      if (mobileRefractometry != null)
        'mobileRefractometry': mobileRefractometry!.toJson(),
      if (shadowTest != null) 'shadowTest': shadowTest!.toJson(),
      if (stereopsis != null) 'stereopsis': stereopsis!.toJson(),
      if (eyeHydration != null) 'eyeHydration': eyeHydration!.toJson(),
      if (refractionPrescription != null)
        'refractionPrescription': refractionPrescription!.toMap(),
      'overallStatus': overallStatus.name,
      'recommendation': recommendation,
      'pdfUrl': pdfUrl,
      'isFlagged': isFlagged,
      'isDeleted': isDeleted,
      'practitionerNotes': practitionerNotes?.toMap(),
    };
  }

  /// Helper getter to get primary visual acuity result for condition checking
  VisualAcuityResult? get visualAcuityResult {
    // Return the worse eye for overall condition assessment
    if (visualAcuityRight == null && visualAcuityLeft == null) return null;
    if (visualAcuityRight == null) return visualAcuityLeft;
    if (visualAcuityLeft == null) return visualAcuityRight;

    // Return the eye with worse condition
    return visualAcuityRight!.logMAR >= visualAcuityLeft!.logMAR
        ? visualAcuityRight
        : visualAcuityLeft;
  }

  /// Calculate overall status based on individual test results
  static TestStatus calculateOverallStatus({
    VisualAcuityResult? vaRight,
    VisualAcuityResult? vaLeft,
    ColorVisionResult? colorVision,
    AmslerGridResult? amslerRight,
    AmslerGridResult? amslerLeft,
    PelliRobsonResult? pelliRobson,
    MobileRefractometryResult? mobileRefractometry,
    ShadowTestResult? shadowTest,
    StereopsisResult? stereopsis,
    EyeHydrationResult? eyeHydration,
  }) {
    // Check for URGENT conditions (severe/bilateral issues)
    if (shadowTest != null &&
        (shadowTest.overallRisk == 'CRITICAL' ||
            shadowTest.overallRisk == 'VERY HIGH')) {
      return TestStatus.urgent;
    }

    if (amslerRight != null &&
        amslerRight.needsAttention &&
        amslerRight.distortionPoints.length > 10) {
      return TestStatus.urgent;
    }
    // Urgent if: Both eyes have Amsler distortions OR either eye has extensive distortions
    final rightDistortions = amslerRight?.distortionPoints.length ?? 0;
    final leftDistortions = amslerLeft?.distortionPoints.length ?? 0;

    if ((amslerRight?.hasDistortions ?? false) &&
        (amslerLeft?.hasDistortions ?? false)) {
      // Both eyes have distortions - urgent
      return TestStatus.urgent;
    }

    if (rightDistortions >= 5 || leftDistortions >= 5) {
      // Extensive distortions in one eye (5+ marked areas) - urgent
      return TestStatus.urgent;
    }

    // Check visual acuity thresholds for urgent
    // logMAR >= 0.7 is 20/100 or worse (legally impaired)
    if (vaRight != null &&
        vaLeft != null &&
        vaRight.logMAR >= 0.7 &&
        vaLeft.logMAR >= 0.7) {
      // Both eyes significantly impaired - urgent
      return TestStatus.urgent;
    }

    if ((vaRight?.logMAR ?? 0) >= 0.9 || (vaLeft?.logMAR ?? 0) >= 0.9) {
      // One eye severely impaired (20/160 or worse) - urgent
      return TestStatus.urgent;
    }

    // Check for Mobile Refractometry critical alerts
    if (mobileRefractometry != null && mobileRefractometry.criticalAlert) {
      return TestStatus.urgent;
    }

    // Urgent if: Eye hydration is very low (dryness risk)
    if (eyeHydration != null &&
        eyeHydration.status == EyeHydrationStatus.dryness) {
      return TestStatus.urgent;
    }

    // Check for REVIEW conditions (moderate concerns)
    // Review if: Any Amsler distortions (but not urgent level)
    if ((amslerRight?.hasDistortions ?? false) ||
        (amslerLeft?.hasDistortions ?? false)) {
      return TestStatus.review;
    }

    // Review if: Color vision issues
    if (colorVision != null && !colorVision.isNormal) {
      return TestStatus.review;
    }

    // Review if: Moderate VA impairment (20/40 to 20/100)
    if ((vaRight?.logMAR ?? 0) >= 0.3 || (vaLeft?.logMAR ?? 0) >= 0.3) {
      return TestStatus.review;
    }

    // Review if: Pelli-Robson shows reduced contrast sensitivity
    if (pelliRobson != null && pelliRobson.needsReferral) {
      return TestStatus.review;
    }
    if (shadowTest != null &&
        (shadowTest.overallRisk == 'HIGH' ||
            shadowTest.overallRisk == 'MODERATE')) {
      return TestStatus.review;
    }

    // Review if: Stereopsis is absent
    if (stereopsis != null && !stereopsis.stereopsisPresent) {
      return TestStatus.review;
    }

    // Review if Mobile Refractometry has health warnings
    if (mobileRefractometry != null &&
        mobileRefractometry.healthWarnings.isNotEmpty) {
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
    int? profileAge,
    String? profileSex,
    String? profileType,
    DateTime? timestamp,
    String? testType,
    QuestionnaireModel? questionnaire,
    VisualAcuityResult? visualAcuityRight,
    VisualAcuityResult? visualAcuityLeft,
    ShortDistanceResult? shortDistance,
    ColorVisionResult? colorVision,
    AmslerGridResult? amslerGridRight,
    AmslerGridResult? amslerGridLeft,
    PelliRobsonResult? pelliRobson,
    MobileRefractometryResult? mobileRefractometry,
    ShadowTestResult? shadowTest,
    StereopsisResult? stereopsis,
    RefractionPrescriptionModel? refractionPrescription,
    TestStatus? overallStatus,
    String? recommendation,
    String? pdfUrl,
    bool? isFlagged,
    bool? isDeleted,
    PractitionerNotes? practitionerNotes,
  }) {
    return TestResultModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      profileAge: profileAge ?? this.profileAge,
      profileSex: profileSex ?? this.profileSex,
      profileType: profileType ?? this.profileType,
      timestamp: timestamp ?? this.timestamp,
      testType: testType ?? this.testType,
      questionnaire: questionnaire ?? this.questionnaire,
      visualAcuityRight: visualAcuityRight ?? this.visualAcuityRight,
      visualAcuityLeft: visualAcuityLeft ?? this.visualAcuityLeft,
      shortDistance: shortDistance ?? this.shortDistance,
      colorVision: colorVision ?? this.colorVision,
      amslerGridRight: amslerGridRight ?? this.amslerGridRight,
      amslerGridLeft: amslerGridLeft ?? this.amslerGridLeft,
      pelliRobson: pelliRobson ?? this.pelliRobson,
      mobileRefractometry: mobileRefractometry ?? this.mobileRefractometry,
      shadowTest: shadowTest ?? this.shadowTest,
      stereopsis: stereopsis ?? this.stereopsis,
      eyeHydration: eyeHydration ?? this.eyeHydration,
      refractionPrescription:
          refractionPrescription ?? this.refractionPrescription,
      overallStatus: overallStatus ?? this.overallStatus,
      recommendation: recommendation ?? this.recommendation,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      isFlagged: isFlagged ?? this.isFlagged,
      isDeleted: isDeleted ?? this.isDeleted,
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

  Map<String, dynamic> toJson() {
    return {
      'examinerId': examinerId,
      'examinerName': examinerName,
      'notes': notes,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => {
    'examinerId': examinerId,
    'examinerName': examinerName,
    'notes': notes,
    'status': status,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}
