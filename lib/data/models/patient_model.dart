import 'package:cloud_firestore/cloud_firestore.dart';

/// Patient model for storing patient profiles under practitioners
/// Similar to FamilyMemberModel but without relationship field
class PatientModel {
  final String id;
  final String firstName;
  final String? lastName;
  final int age;
  final String sex;
  final String? phone;
  final String? notes;
  final DateTime createdAt;

  // Pre-test questionnaire tracking
  final bool hasPreTestQuestions;
  final String? latestQuestionnaireId;
  final DateTime? questionnaireUpdatedAt;

  PatientModel({
    required this.id,
    required this.firstName,
    this.lastName,
    required this.age,
    required this.sex,
    this.phone,
    this.notes,
    required this.createdAt,
    this.hasPreTestQuestions = false,
    this.latestQuestionnaireId,
    this.questionnaireUpdatedAt,
  });

  /// Full name combining first and last name
  String get fullName => lastName != null && lastName!.isNotEmpty
      ? '$firstName $lastName'
      : firstName;

  /// Returns a descriptive string for document naming: First_Last_Age_Sex_ID
  String get identityString {
    final sanitizedFirst = firstName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final sanitizedLast = (lastName ?? '').replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );
    return '${sanitizedFirst}_${sanitizedLast}_${age}_${sex}_$id';
  }

  /// Create PatientModel from Firestore document
  factory PatientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'],
      age: data['age'] ?? 0,
      sex: data['sex'] ?? '',
      phone: data['phone'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasPreTestQuestions: data['hasPreTestQuestions'] ?? false,
      latestQuestionnaireId: data['latestQuestionnaireId'],
      questionnaireUpdatedAt: (data['questionnaireUpdatedAt'] as Timestamp?)
          ?.toDate(),
    );
  }

  /// Create PatientModel from Map
  factory PatientModel.fromMap(Map<String, dynamic> data, String id) {
    return PatientModel(
      id: id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'],
      age: data['age'] ?? 0,
      sex: data['sex'] ?? '',
      phone: data['phone'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasPreTestQuestions: data['hasPreTestQuestions'] ?? false,
      latestQuestionnaireId: data['latestQuestionnaireId'],
      questionnaireUpdatedAt: (data['questionnaireUpdatedAt'] as Timestamp?)
          ?.toDate(),
    );
  }

  /// Convert PatientModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'sex': sex,
      'phone': phone,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'hasPreTestQuestions': hasPreTestQuestions,
      'latestQuestionnaireId': latestQuestionnaireId,
      if (questionnaireUpdatedAt != null)
        'questionnaireUpdatedAt': Timestamp.fromDate(questionnaireUpdatedAt!),
    };
  }

  /// Create a copy with updated fields
  PatientModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    int? age,
    String? sex,
    String? phone,
    String? notes,
    DateTime? createdAt,
    bool? hasPreTestQuestions,
    String? latestQuestionnaireId,
    DateTime? questionnaireUpdatedAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      hasPreTestQuestions: hasPreTestQuestions ?? this.hasPreTestQuestions,
      latestQuestionnaireId:
          latestQuestionnaireId ?? this.latestQuestionnaireId,
      questionnaireUpdatedAt:
          questionnaireUpdatedAt ?? this.questionnaireUpdatedAt,
    );
  }

  @override
  String toString() => fullName;
}
