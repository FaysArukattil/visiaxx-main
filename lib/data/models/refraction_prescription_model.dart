import 'package:cloud_firestore/cloud_firestore.dart';

/// Subjective refraction data for one eye
class SubjectiveRefractionData {
  final String sph; // Sphere (e.g., "+1.25", "-2.50")
  final String cyl; // Cylinder (e.g., "-0.75")
  final String axis; // Axis (e.g., "90", "180")
  final String vn; // Visual acuity (e.g., "6/6", "20/20")
  final String prism; // Prism (e.g., "0.00", "2.00")
  final String add; // Addition power for reading (e.g., "+2.00")

  SubjectiveRefractionData({
    required this.sph,
    required this.cyl,
    required this.axis,
    required this.vn,
    required this.prism,
    required this.add,
  });

  Map<String, dynamic> toJson() {
    return {
      'sph': sph,
      'cyl': cyl,
      'axis': axis,
      'vn': vn,
      'prism': prism,
      'add': add,
    };
  }

  factory SubjectiveRefractionData.fromJson(Map<String, dynamic> json) {
    return SubjectiveRefractionData(
      sph: json['sph'] ?? '0.00',
      cyl: json['cyl'] ?? '0.00',
      axis: json['axis'] ?? '0',
      vn: json['vn'] ?? '6/6',
      prism: json['prism'] ?? '0.00',
      add: json['add'] ?? '0.00',
    );
  }

  Map<String, dynamic> toMap() => toJson();

  factory SubjectiveRefractionData.fromMap(Map<String, dynamic> map) {
    return SubjectiveRefractionData.fromJson(map);
  }

  /// Create empty/default subjective refraction
  factory SubjectiveRefractionData.empty() {
    return SubjectiveRefractionData(
      sph: '0.00',
      cyl: '0.00',
      axis: '0',
      vn: '6/6',
      prism: '0.00',
      add: '0.00',
    );
  }

  SubjectiveRefractionData copyWith({
    String? sph,
    String? cyl,
    String? axis,
    String? vn,
    String? prism,
    String? add,
  }) {
    return SubjectiveRefractionData(
      sph: sph ?? this.sph,
      cyl: cyl ?? this.cyl,
      axis: axis ?? this.axis,
      vn: vn ?? this.vn,
      prism: prism ?? this.prism,
      add: add ?? this.add,
    );
  }
}

/// Final prescription data combining both eyes
class FinalPrescriptionData {
  final SubjectiveRefractionData right;
  final SubjectiveRefractionData left;

  FinalPrescriptionData({required this.right, required this.left});

  Map<String, dynamic> toJson() {
    return {'right': right.toJson(), 'left': left.toJson()};
  }

  factory FinalPrescriptionData.fromJson(Map<String, dynamic> json) {
    return FinalPrescriptionData(
      right: json['right'] != null
          ? SubjectiveRefractionData.fromJson(json['right'])
          : SubjectiveRefractionData.empty(),
      left: json['left'] != null
          ? SubjectiveRefractionData.fromJson(json['left'])
          : SubjectiveRefractionData.empty(),
    );
  }

  Map<String, dynamic> toMap() => toJson();

  factory FinalPrescriptionData.fromMap(Map<String, dynamic> map) {
    return FinalPrescriptionData.fromJson(map);
  }

  FinalPrescriptionData copyWith({
    SubjectiveRefractionData? right,
    SubjectiveRefractionData? left,
  }) {
    return FinalPrescriptionData(
      right: right ?? this.right,
      left: left ?? this.left,
    );
  }
}

/// Complete refraction prescription model
class RefractionPrescriptionModel {
  final SubjectiveRefractionData rightEyeSubjective;
  final SubjectiveRefractionData leftEyeSubjective;
  final FinalPrescriptionData finalPrescription;
  final SubjectiveRefractionData predictedRight;
  final SubjectiveRefractionData predictedLeft;
  final bool includeInResults; // Controls visibility in PDF and user results
  final bool hasManualEdits; // Tracks if practitioner made changes
  final String practitionerId;
  final String practitionerName;
  final DateTime timestamp;
  final String? notes;
  final Map<String, dynamic>?
  accuracyMetrics; // Difference between predicted and actual

  RefractionPrescriptionModel({
    required this.rightEyeSubjective,
    required this.leftEyeSubjective,
    required this.finalPrescription,
    required this.predictedRight,
    required this.predictedLeft,
    this.includeInResults = true,
    this.hasManualEdits = false,
    required this.practitionerId,
    required this.practitionerName,
    DateTime? timestamp,
    this.notes,
    this.accuracyMetrics,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'rightEyeSubjective': rightEyeSubjective.toJson(),
      'leftEyeSubjective': leftEyeSubjective.toJson(),
      'finalPrescription': finalPrescription.toJson(),
      'predictedRight': predictedRight.toJson(),
      'predictedLeft': predictedLeft.toJson(),
      'includeInResults': includeInResults,
      'hasManualEdits': hasManualEdits,
      'practitionerId': practitionerId,
      'practitionerName': practitionerName,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'accuracyMetrics': accuracyMetrics,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'rightEyeSubjective': rightEyeSubjective.toMap(),
      'leftEyeSubjective': leftEyeSubjective.toMap(),
      'finalPrescription': finalPrescription.toMap(),
      'predictedRight': predictedRight.toMap(),
      'predictedLeft': predictedLeft.toMap(),
      'includeInResults': includeInResults,
      'hasManualEdits': hasManualEdits,
      'practitionerId': practitionerId,
      'practitionerName': practitionerName,
      'timestamp': Timestamp.fromDate(timestamp),
      'notes': notes,
      'accuracyMetrics': accuracyMetrics,
    };
  }

  factory RefractionPrescriptionModel.fromJson(Map<String, dynamic> json) {
    return RefractionPrescriptionModel(
      rightEyeSubjective: json['rightEyeSubjective'] != null
          ? SubjectiveRefractionData.fromJson(json['rightEyeSubjective'])
          : SubjectiveRefractionData.empty(),
      leftEyeSubjective: json['leftEyeSubjective'] != null
          ? SubjectiveRefractionData.fromJson(json['leftEyeSubjective'])
          : SubjectiveRefractionData.empty(),
      finalPrescription: json['finalPrescription'] != null
          ? FinalPrescriptionData.fromJson(json['finalPrescription'])
          : FinalPrescriptionData(
              right: SubjectiveRefractionData.empty(),
              left: SubjectiveRefractionData.empty(),
            ),
      predictedRight: json['predictedRight'] != null
          ? SubjectiveRefractionData.fromJson(json['predictedRight'])
          : SubjectiveRefractionData.empty(),
      predictedLeft: json['predictedLeft'] != null
          ? SubjectiveRefractionData.fromJson(json['predictedLeft'])
          : SubjectiveRefractionData.empty(),
      includeInResults: json['includeInResults'] ?? true,
      hasManualEdits: json['hasManualEdits'] ?? false,
      practitionerId: json['practitionerId'] ?? '',
      practitionerName: json['practitionerName'] ?? '',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is Timestamp
                ? (json['timestamp'] as Timestamp).toDate()
                : DateTime.parse(json['timestamp']))
          : DateTime.now(),
      notes: json['notes'],
      accuracyMetrics: json['accuracyMetrics'],
    );
  }

  factory RefractionPrescriptionModel.fromMap(Map<String, dynamic> map) {
    return RefractionPrescriptionModel.fromJson(map);
  }

  Map<String, dynamic> toMap() => toFirestore();

  RefractionPrescriptionModel copyWith({
    SubjectiveRefractionData? rightEyeSubjective,
    SubjectiveRefractionData? leftEyeSubjective,
    FinalPrescriptionData? finalPrescription,
    SubjectiveRefractionData? predictedRight,
    SubjectiveRefractionData? predictedLeft,
    bool? includeInResults,
    bool? hasManualEdits,
    String? practitionerId,
    String? practitionerName,
    DateTime? timestamp,
    String? notes,
    Map<String, dynamic>? accuracyMetrics,
  }) {
    return RefractionPrescriptionModel(
      rightEyeSubjective: rightEyeSubjective ?? this.rightEyeSubjective,
      leftEyeSubjective: leftEyeSubjective ?? this.leftEyeSubjective,
      finalPrescription: finalPrescription ?? this.finalPrescription,
      predictedRight: predictedRight ?? this.predictedRight,
      predictedLeft: predictedLeft ?? this.predictedLeft,
      includeInResults: includeInResults ?? this.includeInResults,
      hasManualEdits: hasManualEdits ?? this.hasManualEdits,
      practitionerId: practitionerId ?? this.practitionerId,
      practitionerName: practitionerName ?? this.practitionerName,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      accuracyMetrics: accuracyMetrics ?? this.accuracyMetrics,
    );
  }
}
