import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for individual test results (standalone tests)
class IndividualTestResult {
  final String id;
  final String userId;
  final String profileId;
  final String profileName;
  final int? profileAge;
  final String? profileSex;
  final DateTime timestamp;
  final String testType; // 'visual_acuity', 'color_vision', etc.
  final Map<String, dynamic> testData; // Flexible storage for any test result
  final String? pdfUrl;
  final String? awsUrl;
  final bool isHidden;

  IndividualTestResult({
    required this.id,
    required this.userId,
    required this.profileId,
    required this.profileName,
    this.profileAge,
    this.profileSex,
    required this.timestamp,
    required this.testType,
    required this.testData,
    this.pdfUrl,
    this.awsUrl,
    this.isHidden = false,
  });

  factory IndividualTestResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IndividualTestResult.fromJson({...data, 'id': doc.id});
  }

  factory IndividualTestResult.fromJson(Map<String, dynamic> data) {
    return IndividualTestResult(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      profileId: data['profileId'] ?? '',
      profileName: data['profileName'] ?? '',
      profileAge: data['profileAge'],
      profileSex: data['profileSex'],
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : (data['timestamp'] != null
                ? DateTime.parse(data['timestamp'].toString())
                : DateTime.now()),
      testType: data['testType'] ?? '',
      testData: Map<String, dynamic>.from(data['testData'] ?? {}),
      pdfUrl: data['pdfUrl'],
      awsUrl: data['awsUrl'],
      isHidden: data['isHidden'] ?? false,
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
      'timestamp': timestamp.toIso8601String(),
      'testType': testType,
      'testData': testData,
      'pdfUrl': pdfUrl,
      'awsUrl': awsUrl,
      'isHidden': isHidden,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'profileId': profileId,
      'profileName': profileName,
      'profileAge': profileAge,
      'profileSex': profileSex,
      'timestamp': Timestamp.fromDate(timestamp),
      'testType': testType,
      'testData': testData,
      'pdfUrl': pdfUrl,
      'awsUrl': awsUrl,
      'isHidden': isHidden,
    };
  }

  String get testDisplayName {
    switch (testType) {
      case 'visual_acuity':
        return 'Visual Acuity Test';
      case 'color_vision':
        return 'Color Vision Test';
      case 'amsler_grid':
        return 'Amsler Grid Test';
      case 'short_distance':
        return 'Reading Test';
      case 'pelli_robson':
        return 'Contrast Sensitivity Test';
      case 'mobile_refractometry':
        return 'Mobile Refractometry Test';
      default:
        return 'Vision Test';
    }
  }
}
