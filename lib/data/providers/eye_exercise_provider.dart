import 'package:flutter/material.dart';
import '../../features/eye_exercises/models/exercise_video_model.dart';
import '../../core/constants/exercise_videos.dart';

class EyeExerciseProvider with ChangeNotifier {
  List<ExerciseVideo> _videos = [];
  int _currentIndex = 0;
  bool _isInitialized = false;

  List<ExerciseVideo> get videos => _videos;
  int get currentIndex => _currentIndex;
  bool get isInitialized => _isInitialized;

  void initialize() {
    if (_isInitialized) return;
    _videos = ExerciseVideos.getShuffledVideos();
    _isInitialized = true;
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _videos.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void reset() {
    _currentIndex = 0;
    _videos = ExerciseVideos.getShuffledVideos();
    notifyListeners();
  }
}
