import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/game_progress_model.dart';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'GameProgress';

  /// Get progress for a specific game and user
  Future<GameProgressModel?> getGameProgress(
    String userId,
    String gameId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc('${userId}_$gameId')
          .get();

      if (doc.exists) {
        return GameProgressModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('[GameService] Error fetching game progress: $e');
      return null;
    }
  }

  /// Update user progress for a game
  Future<void> updateGameProgress(GameProgressModel progress) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc('${progress.userId}_${progress.gameId}')
          .set(progress.toFirestore(), SetOptions(merge: true));
      debugPrint('[GameService] Game progress updated: ${progress.gameId}');
    } catch (e) {
      debugPrint('[GameService] Error updating game progress: $e');
      rethrow;
    }
  }

  /// Reset progress for a specific game
  Future<void> resetGameProgress(String userId, String gameId) async {
    try {
      final freshProgress = GameProgressModel(
        gameId: gameId,
        userId: userId,
        currentLevel: 1,
        clearedLevels: [],
        totalScore: 0,
        lastPlayed: DateTime.now(),
      );
      await updateGameProgress(freshProgress);
      debugPrint('[GameService] Game progress reset: $gameId');
    } catch (e) {
      debugPrint('[GameService] Error resetting game progress: $e');
      rethrow;
    }
  }

  /// Get all game progress for a user
  Future<List<GameProgressModel>> getAllGameProgress(String userId) async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => GameProgressModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[GameService] Error fetching all game progress: $e');
      return [];
    }
  }

  /// Get global leaderboard for a specific game
  Future<List<GameProgressModel>> getGlobalLeaderboard(String gameId) async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('gameId', isEqualTo: gameId)
          .orderBy('totalScore', descending: true)
          .limit(20)
          .get();

      return query.docs
          .map((doc) => GameProgressModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[GameService] Error fetching leaderboard: $e');
      return [];
    }
  }
}
