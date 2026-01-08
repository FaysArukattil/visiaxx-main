import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final int userAge;
  final int rating; // 1-5 stars
  final String reviewText;
  final DateTime timestamp;
  final bool emailSent;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAge,
    required this.rating,
    required this.reviewText,
    required this.timestamp,
    this.emailSent = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAge': userAge,
      'rating': rating,
      'reviewText': reviewText,
      'timestamp': Timestamp.fromDate(timestamp),
      'emailSent': emailSent,
    };
  }

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAge: data['userAge'] ?? 0,
      rating: data['rating'] ?? 0,
      reviewText: data['reviewText'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      emailSent: data['emailSent'] ?? false,
    );
  }
}
