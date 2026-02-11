import 'package:flutter/material.dart';
import '../models/stereopsis_result.dart';

/// Data class for each stereopsis test image
class StereoImage {
  final String assetPath;
  final int arcSeconds;

  const StereoImage({required this.assetPath, required this.arcSeconds});
}

/// Provider for managing Stereopsis Test state
///
/// The test shows 5 anaglyph 3D images in order of depth intensity
/// (strongest → subtlest). ALL images are 3D — the user must identify
/// whether they perceive the 3D depth through their red-cyan glasses.
class StereopsisProvider extends ChangeNotifier {
  int _currentRound = 0;
  int _score = 0;
  final int _totalRounds = 5;
  bool _isTestComplete = false;

  /// The list of images for the current test session, randomized on reset
  List<StereoImage> _testImages = [];

  /// All available test images with their corresponding seconds of arc
  final List<StereoImage> _availableImages = const [
    StereoImage(
      assetPath: 'assets/images/stereopsis/stereo_4.jpg',
      arcSeconds: 800,
    ),
    StereoImage(
      assetPath: 'assets/images/stereopsis/stereo_2.jpg',
      arcSeconds: 400,
    ),
    StereoImage(
      assetPath: 'assets/images/stereopsis/stereo_3.jpg',
      arcSeconds: 200,
    ),
    StereoImage(
      assetPath: 'assets/images/stereopsis/stereo_1.jpg',
      arcSeconds: 100,
    ),
    StereoImage(
      assetPath: 'assets/images/stereopsis/stereo_5.jpg',
      arcSeconds: 40,
    ),
  ];

  // ALL images in the test are 3D — this is always true
  bool get is3DInCurrentRound => true;

  // Getters
  int get currentRound => _currentRound;
  int get score => _score;
  int get totalRounds => _totalRounds;
  bool get isTestComplete => _isTestComplete;
  List<StereoImage> get testImages => _testImages;

  StereoImage get currentImage =>
      _testImages[_currentRound.clamp(0, _totalRounds - 1)];

  int get currentArc => currentImage.arcSeconds;

  double get progress => (_currentRound / _totalRounds).clamp(0.0, 1.0);

  /// The smallest ARC value that the user correctly identified as 3D.
  /// Lower = better stereopsis. null = none detected.
  int? _bestArc;
  int? get bestArc => _bestArc;

  /// Submit whether the user perceived the image in 3D
  void submitAnswer(bool perceived3D) {
    if (_isTestComplete) return;

    if (perceived3D) {
      // User correctly sees the 3D effect at this ARC level
      _score++;
      // Track the best (smallest) ARC they can perceive
      final currentArcValue = currentArc;
      if (_bestArc == null || currentArcValue < _bestArc!) {
        _bestArc = currentArcValue;
      }
    }

    if (_currentRound < _totalRounds - 1) {
      _currentRound++;
      notifyListeners();
    } else {
      _isTestComplete = true;
      notifyListeners();
    }
  }

  /// Get the result grade based on the best ARC detected
  StereopsisGrade getResultGrade() {
    if (_bestArc == null) return StereopsisGrade.none;

    if (_bestArc! <= 40) return StereopsisGrade.excellent;
    if (_bestArc! <= 100) return StereopsisGrade.good;
    if (_bestArc! <= 200) return StereopsisGrade.fair;
    if (_bestArc! <= 400) return StereopsisGrade.poor;
    return StereopsisGrade.poor;
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
    _bestArc = null;
    _isTestComplete = false;

    // Shuffle images for randomization
    _testImages = List.from(_availableImages)..shuffle();

    notifyListeners();
  }
}
