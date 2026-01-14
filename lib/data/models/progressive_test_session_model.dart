import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking progressive comprehensive test sessions
class ProgressiveTestSession {
  final String sessionId;
  final String userId;
  final String profileId;
  final String profileName;
  final DateTime startedAt;
  final DateTime? lastUpdated;
  final List<String> completedTests;
  final Map<String, dynamic> testResults;
  final Map<String, dynamic>? questionnaire;
  final bool isComplete;
  final String? finalPdfUrl;

  ProgressiveTestSession({
    required this.sessionId,
    required this.userId,
    required this.profileId,
    required this.profileName,
    required this.startedAt,
    this.lastUpdated,
    required this.completedTests,
    required this.testResults,
    this.questionnaire,
    this.isComplete = false,
    this.finalPdfUrl,
  });

  factory ProgressiveTestSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProgressiveTestSession.fromJson({...data, 'sessionId': doc.id});
  }

  factory ProgressiveTestSession.fromJson(Map<String, dynamic> data) {
    return ProgressiveTestSession(
      sessionId: data['sessionId'] ?? '',
      userId: data['userId'] ?? '',
      profileId: data['profileId'] ?? '',
      profileName: data['profileName'] ?? '',
      startedAt: data['startedAt'] is Timestamp
          ? (data['startedAt'] as Timestamp).toDate()
          : DateTime.parse(data['startedAt'].toString()),
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : (data['lastUpdated'] != null
                ? DateTime.parse(data['lastUpdated'].toString())
                : null),
      completedTests: List<String>.from(data['completedTests'] ?? []),
      testResults: Map<String, dynamic>.from(data['testResults'] ?? {}),
      questionnaire: data['questionnaire'] != null
          ? Map<String, dynamic>.from(data['questionnaire'])
          : null,
      isComplete: data['isComplete'] ?? false,
      finalPdfUrl: data['finalPdfUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'profileId': profileId,
      'profileName': profileName,
      'startedAt': Timestamp.fromDate(startedAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated ?? DateTime.now()),
      'completedTests': completedTests,
      'testResults': testResults,
      'questionnaire': questionnaire,
      'isComplete': isComplete,
      'finalPdfUrl': finalPdfUrl,
    };
  }

  bool get isExpired {
    final expiryDate = startedAt.add(const Duration(days: 7));
    return DateTime.now().isAfter(expiryDate);
  }

  double get progressPercentage {
    const totalTests = 7; // VA, Color, Amsler, Short, Pelli, MR, Questionnaire
    return (completedTests.length / totalTests) * 100;
  }

  ProgressiveTestSession copyWith({
    String? sessionId,
    String? userId,
    String? profileId,
    String? profileName,
    DateTime? startedAt,
    DateTime? lastUpdated,
    List<String>? completedTests,
    Map<String, dynamic>? testResults,
    Map<String, dynamic>? questionnaire,
    bool? isComplete,
    String? finalPdfUrl,
  }) {
    return ProgressiveTestSession(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      startedAt: startedAt ?? this.startedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      completedTests: completedTests ?? this.completedTests,
      testResults: testResults ?? this.testResults,
      questionnaire: questionnaire ?? this.questionnaire,
      isComplete: isComplete ?? this.isComplete,
      finalPdfUrl: finalPdfUrl ?? this.finalPdfUrl,
    );
  }
}
