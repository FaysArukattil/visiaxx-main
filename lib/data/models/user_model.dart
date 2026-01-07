import 'package:cloud_firestore/cloud_firestore.dart';

/// User roles in the application
enum UserRole { user, examiner, admin }

/// User model representing a registered user
class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final int age;
  final String sex;
  final String phone;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final List<String> familyMemberIds;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.age,
    required this.sex,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.lastLoginAt,
    this.familyMemberIds = const [],
  });

  String get fullName => '$firstName $lastName';

  /// Returns a descriptive string for folder/document naming: First_Last_Age_Sex_UID
  String get identityString {
    final sanitizedFirst = firstName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final sanitizedLast = lastName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return '${sanitizedFirst}_${sanitizedLast}_${age}_${sex}_$id';
  }

  /// Returns the Firestore collection name based on the user's role
  String get roleCollection {
    switch (role) {
      case UserRole.user:
        return 'NormalUsers';
      case UserRole.examiner:
        return 'Practitioners';
      case UserRole.admin:
        return 'Admins';
    }
  }

  /// Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Use the stored 'id' (UID) if available, fallback to doc.id (which might be identityString)
    // If it is identityString, we extract the UID from the end
    String uid = data['id'] ?? doc.id;
    if (uid.contains('_')) {
      uid = uid.split('_').last;
    }

    return UserModel(
      id: uid,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      age: data['age'] ?? 0,
      sex: data['sex'] ?? '',
      phone: data['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.user,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      familyMemberIds: List<String>.from(data['familyMemberIds'] ?? []),
    );
  }

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id, // Store UID explicitly
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'age': age,
      'sex': sex,
      'phone': phone,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'familyMemberIds': familyMemberIds,
    };
  }

  /// Alias for toFirestore for compatibility
  Map<String, dynamic> toMap() => toFirestore();

  /// Create UserModel from Map (for Firestore data)
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    String uid = data['id'] ?? id;
    if (uid.contains('_')) {
      uid = uid.split('_').last;
    }

    return UserModel(
      id: uid,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      age: data['age'] ?? 0,
      sex: data['sex'] ?? '',
      phone: data['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.user,
      ),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] is Timestamp
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      familyMemberIds: List<String>.from(data['familyMemberIds'] ?? []),
    );
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    int? age,
    String? sex,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? familyMemberIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      familyMemberIds: familyMemberIds ?? this.familyMemberIds,
    );
  }
}
