import 'package:flutter/material.dart';
import '../../core/services/game_service.dart';
import '../models/game_progress_model.dart';

class GameProvider with ChangeNotifier {
  final GameService _gameService = GameService();

  Map<String, GameProgressModel> _gameProgress = {};
  final Map<String, List<GameProgressModel>> _leaderboards = {};
  bool _isLoading = false;

  Map<String, GameProgressModel> get gameProgress => _gameProgress;
  Map<String, List<GameProgressModel>> get leaderboards => _leaderboards;
  bool get isLoading => _isLoading;

  /// Fetch all game progress for a user
  Future<void> loadAllProgress(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final progressList = await _gameService.getAllGameProgress(userId);
      _gameProgress = {for (var p in progressList) p.gameId: p};
    } catch (e) {
      debugPrint('[GameProvider] Error loading progress: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch leaderboard for a specific game
  Future<void> fetchLeaderboard(String gameId) async {
    try {
      final leaderboard = await _gameService.getGlobalLeaderboard(gameId);
      _leaderboards[gameId] = leaderboard;
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Error fetching leaderboard: $e');
    }
  }

  /// Get progress for a specific game
  GameProgressModel? getProgress(String gameId) => _gameProgress[gameId];

  /// Update progress for a game
  Future<void> updateProgress(GameProgressModel progress) async {
    try {
      await _gameService.updateGameProgress(progress);
      _gameProgress[progress.gameId] = progress;
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Error updating progress: $e');
      rethrow;
    }
  }

  /// Reset progress for a game
  Future<void> resetProgress(String userId, String gameId) async {
    try {
      await _gameService.resetGameProgress(userId, gameId);
      final freshProgress = GameProgressModel(
        gameId: gameId,
        userId: userId,
        userName: _gameProgress[gameId]?.userName ?? 'Player',
        userRole: _gameProgress[gameId]?.userRole ?? 'user',
        currentLevel: 1,
        clearedLevels: [],
        totalScore: 0,
        lastPlayed: DateTime.now(),
      );
      _gameProgress[gameId] = freshProgress;
      notifyListeners();
    } catch (e) {
      debugPrint('[GameProvider] Error resetting progress: $e');
      rethrow;
    }
  }

  /// Mark a level as cleared
  Future<void> clearLevel(
    String userId,
    String gameId,
    int level,
    int addedScore, {
    String userName = 'Player',
    String userRole = 'user',
  }) async {
    final current =
        _gameProgress[gameId] ??
        GameProgressModel(
          gameId: gameId,
          userId: userId,
          userName: userName,
          userRole: userRole,
          lastPlayed: DateTime.now(),
        );

    final updatedCleared = Set<int>.from(current.clearedLevels)..add(level);
    final updatedLevel = level + 1; // Move to next level

    final updated = current.copyWith(
      userName: userName != 'Player'
          ? userName
          : (current.userName != 'Player' ? current.userName : 'Player'),
      userRole: userRole,
      currentLevel: updatedLevel,
      clearedLevels: updatedCleared.toList(),
      totalScore: current.totalScore + addedScore,
      lastPlayed: DateTime.now(),
    );

    await updateProgress(updated);
    // Refresh leaderboard after update
    fetchLeaderboard(gameId);
  }
}
