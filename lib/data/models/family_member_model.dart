import 'package:cloud_firestore/cloud_firestore.dart';

/// Family member model for storing family member profiles
class FamilyMemberModel {
  final String id;
  final String firstName;
  final int age;
  final String sex;
  final String relationship;
  final String? phone;
  final DateTime createdAt;

  FamilyMemberModel({
    required this.id,
    required this.firstName,
    required this.age,
    required this.sex,
    required this.relationship,
    this.phone,
    required this.createdAt,
  });

  /// Returns a descriptive string for document naming: Name_Age_Sex_ID
  String get identityString {
    final sanitizedFirst = firstName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return '${sanitizedFirst}_${age}_${sex}_$id';
  }

  /// Create FamilyMemberModel from Firestore document
  factory FamilyMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyMemberModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      age: data['age'] ?? 0,
      sex: data['sex'] ?? '',
      relationship: data['relationship'] ?? '',
      phone: data['phone'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create FamilyMemberModel from Map
  factory FamilyMemberModel.fromMap(Map<String, dynamic> data, String id) {
    return FamilyMemberModel(
      id: id,
      firstName: data['firstName'] ?? '',
      age: data['age'] ?? 0,
      sex: data['sex'] ?? '',
      relationship: data['relationship'] ?? '',
      phone: data['phone'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert FamilyMemberModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'age': age,
      'sex': sex,
      'relationship': relationship,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a copy with updated fields
  FamilyMemberModel copyWith({
    String? id,
    String? firstName,
    int? age,
    String? sex,
    String? relationship,
    String? phone,
    DateTime? createdAt,
  }) {
    return FamilyMemberModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => firstName;
}
