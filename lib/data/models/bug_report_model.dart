import 'package:cloud_firestore/cloud_firestore.dart';

class BugReportModel {
  final String id;
  final String userId;
  final String userName;
  final int userAge;
  final String description;
  final DateTime timestamp;
  final bool emailSent;

  BugReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAge,
    required this.description,
    required this.timestamp,
    this.emailSent = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAge': userAge,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'emailSent': emailSent,
    };
  }

  factory BugReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BugReportModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAge: data['userAge'] ?? 0,
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      emailSent: data['emailSent'] ?? false,
    );
  }
}
