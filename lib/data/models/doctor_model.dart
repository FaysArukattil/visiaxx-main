import 'package:cloud_firestore/cloud_firestore.dart';

/// Doctor specialty types
enum DoctorSpecialty {
  ophthalmologist,
  optometrist,
  retinaSpecialist,
  pediatricOphthalmologist,
  glaucomaSpecialist,
  general,
}

class DoctorModel {
  final String id; // Matches UserModel.id
  final String firstName;
  final String lastName;
  final String specialty;
  final String degree;
  final String registrationNumber;
  final String bio;
  final String photoUrl;
  final String location; // e.g., "Mumbai"
  final double rating;
  final int reviewCount;
  final int experienceYears;
  final List<String> availableServices; // e.g., ["Online", "In-Person"]
  final Map<String, dynamic>? metadata;

  DoctorModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialty,
    required this.degree,
    this.registrationNumber = '',
    this.bio = '',
    this.photoUrl = '',
    this.location = '',
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.experienceYears,
    this.availableServices = const ["Online", "In-Person"],
    this.metadata,
  });

  String get fullName => '$firstName $lastName';

  factory DoctorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DoctorModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      specialty: data['specialty'] ?? '',
      degree: data['degree'] ?? '',
      registrationNumber: data['registrationNumber'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      location: data['location'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      experienceYears: data['experienceYears'] ?? 0,
      availableServices: List<String>.from(
        data['availableServices'] ?? ["Online", "In-Person"],
      ),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'specialty': specialty,
      'degree': degree,
      'registrationNumber': registrationNumber,
      'bio': bio,
      'photoUrl': photoUrl,
      'location': location,
      'rating': rating,
      'reviewCount': reviewCount,
      'experienceYears': experienceYears,
      'availableServices': availableServices,
      'metadata': metadata,
    };
  }

  DoctorModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? specialty,
    String? degree,
    String? registrationNumber,
    String? bio,
    String? photoUrl,
    String? location,
    double? rating,
    int? reviewCount,
    int? experienceYears,
    List<String>? availableServices,
    Map<String, dynamic>? metadata,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      specialty: specialty ?? this.specialty,
      degree: degree ?? this.degree,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      experienceYears: experienceYears ?? this.experienceYears,
      availableServices: availableServices ?? this.availableServices,
      metadata: metadata ?? this.metadata,
    );
  }
}
