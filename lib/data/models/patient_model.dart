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

  PatientModel({
    required this.id,
    required this.firstName,
    this.lastName,
    required this.age,
    required this.sex,
    this.phone,
    this.notes,
    required this.createdAt,
  });

  /// Full name combining first and last name
  String get fullName => lastName != null && lastName!.isNotEmpty
      ? '$firstName $lastName'
      : firstName;

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
    );
  }

  @override
  String toString() => fullName;
}
