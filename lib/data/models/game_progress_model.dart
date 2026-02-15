import 'package:cloud_firestore/cloud_firestore.dart';

class GameProgressModel {
  final String gameId;
  final String userId;
  final int currentLevel;
  final List<int> clearedLevels;
  final int totalScore;
  final DateTime lastPlayed;

  GameProgressModel({
    required this.gameId,
    required this.userId,
    this.currentLevel = 1,
    this.clearedLevels = const [],
    this.totalScore = 0,
    required this.lastPlayed,
  });

  factory GameProgressModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameProgressModel.fromJson(data);
  }

  factory GameProgressModel.fromJson(Map<String, dynamic> json) {
    return GameProgressModel(
      gameId: json['gameId'] ?? '',
      userId: json['userId'] ?? '',
      currentLevel: json['currentLevel'] ?? 1,
      clearedLevels: List<int>.from(json['clearedLevels'] ?? []),
      totalScore: json['totalScore'] ?? 0,
      lastPlayed: json['lastPlayed'] is Timestamp
          ? (json['lastPlayed'] as Timestamp).toDate()
          : (json['lastPlayed'] != null
              ? DateTime.parse(json['lastPlayed'])
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'userId': userId,
      'currentLevel': currentLevel,
      'clearedLevels': clearedLevels,
      'totalScore': totalScore,
      'lastPlayed': lastPlayed.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gameId': gameId,
      'userId': userId,
      'currentLevel': currentLevel,
      'clearedLevels': clearedLevels,
      'totalScore': totalScore,
      'lastPlayed': Timestamp.fromDate(lastPlayed),
    };
  }

  GameProgressModel copyWith({
    String? gameId,
    String? userId,
    int? currentLevel,
    List<int>? clearedLevels,
    int? totalScore,
    DateTime? lastPlayed,
  }) {
    return GameProgressModel(
      gameId: gameId ?? this.gameId,
      userId: userId ?? this.userId,
      currentLevel: currentLevel ?? this.currentLevel,
      clearedLevels: clearedLevels ?? this.clearedLevels,
      totalScore: totalScore ?? this.totalScore,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }
}
