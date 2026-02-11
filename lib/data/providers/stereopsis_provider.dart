import 'package:flutter/material.dart';
import '../models/stereopsis_result.dart';

/// Provider for managing Stereopsis Test state
class StereopsisProvider extends ChangeNotifier {
  int _currentRound = 0;
  int _score = 0;
  final int _totalRounds = 4;
  bool _isTestComplete = false;

  // Seconds of arc for each round
  final List<int> _arcValues = [400, 200, 100, 40];

  // Whether the current round's ball should be rendered with 3D depth
  bool _is3DInCurrentRound = true;

  // Getters
  int get currentRound => _currentRound;
  int get score => _score;
  int get totalRounds => _totalRounds;
  bool get isTestComplete => _isTestComplete;
  int get currentArc => _arcValues[_currentRound];
  bool get is3DInCurrentRound => _is3DInCurrentRound;
  double get progress => (_currentRound / _totalRounds).clamp(0.0, 1.0);

  /// Generate a new round with random 3D/Flat state
  void generateNewRound() {
    // 75% chance of being 3D to keep the test moving, but 25% chance of being flat to detect false positives
    _is3DInCurrentRound = (DateTime.now().millisecondsSinceEpoch % 4) != 0;
    notifyListeners();
  }

  /// Submit whether the user perceived the ball in 3D
  void submitAnswer(bool perceived3D) {
    if (_isTestComplete) return;

    // Correct if user response matches the actual physical state of the ball
    if (perceived3D == _is3DInCurrentRound) {
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
