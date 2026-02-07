import 'package:flutter/material.dart';
import '../models/stereopsis_result.dart';

/// Provider for managing Stereopsis Test state
class StereopsisProvider extends ChangeNotifier {
  int _currentRound = 0;
  int _score = 0;
  final int _totalRounds = 5;
  bool _isTestComplete = false;
  int _correctIndex = 0;

  // Getters
  int get currentRound => _currentRound;
  int get score => _score;
  int get totalRounds => _totalRounds;
  bool get isTestComplete => _isTestComplete;
  int get correctIndex => _correctIndex;
  double get progress => (_currentRound / _totalRounds).clamp(0.0, 1.0);

  /// Generate a new round with a random correct position
  void generateNewRound() {
    _correctIndex = DateTime.now().millisecondsSinceEpoch % 4;
    notifyListeners();
  }

  /// Submit an answer for the current round
  void submitAnswer(int selectedIndex) {
    if (_isTestComplete) return;

    if (selectedIndex == _correctIndex) {
      _score++;
    }

    if (_currentRound < _totalRounds - 1) {
      _currentRound++;
      generateNewRound();
    } else {
      _isTestComplete = true;
      notifyListeners();
    }
  }

  /// Get the result grade based on current score
  StereopsisGrade getResultGrade() {
    return StereopsisGrade.fromScore(_score, _totalRounds);
  }

  /// Create a result object from the current state
  StereopsisResult createResult() {
    return StereopsisResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      grade: getResultGrade(),
      score: _score,
      totalRounds: _totalRounds,
    );
  }

  /// Reset the test for a new attempt
  void reset() {
    _currentRound = 0;
    _score = 0;
    _isTestComplete = false;
    generateNewRound();
    notifyListeners();
  }
}
