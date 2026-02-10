import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/visual_field_result.dart';

class VisualFieldProvider extends ChangeNotifier {
  bool _isTestActive = false;
  int _currentStimulusIndex = 0;
  final List<Stimulus> _stimuli = [];
  final List<Stimulus> _results = [];
  Stimulus? _activeStimulus;

  bool get isTestActive => _isTestActive;
  Stimulus? get activeStimulus => _activeStimulus;
  double get progress =>
      _stimuli.isEmpty ? 0 : (_currentStimulusIndex / _stimuli.length);
  bool get isComplete =>
      _currentStimulusIndex >= _stimuli.length && _stimuli.isNotEmpty;
  List<Stimulus> get results => List.unmodifiable(_results);

  double get overallSensitivity =>
      totalCount > 0 ? (detectedCount / totalCount) : 0.0;

  void startTest() {
    _stimuli.clear();
    _results.clear();
    _currentStimulusIndex = 0;
    _isTestActive = true;

    final random = math.Random();

    // Generate 20 stimuli (5 per quadrant)
    for (int i = 0; i < 20; i++) {
      final quadrantIndex = i % 4;
      final quadrant = VisualFieldQuadrant.values[quadrantIndex];

      double dx, dy;
      switch (quadrantIndex) {
        case 0: // topRight (x: 0.5-0.95, y: 0.05-0.5)
          dx = 0.5 + random.nextDouble() * 0.4;
          dy = 0.1 + random.nextDouble() * 0.4;
          break;
        case 1: // topLeft (x: 0.05-0.5, y: 0.05-0.5)
          dx = 0.1 + random.nextDouble() * 0.4;
          dy = 0.1 + random.nextDouble() * 0.4;
          break;
        case 2: // bottomRight (x: 0.5-0.95, y: 0.5-0.95)
          dx = 0.5 + random.nextDouble() * 0.4;
          dy = 0.5 + random.nextDouble() * 0.4;
          break;
        case 3: // bottomLeft (x: 0.05-0.5, y: 0.5-0.95)
          dx = 0.1 + random.nextDouble() * 0.4;
          dy = 0.5 + random.nextDouble() * 0.4;
          break;
        default:
          dx = 0.5;
          dy = 0.5;
      }

      _stimuli.add(
        Stimulus(
          position: Offset(dx, dy),
          quadrant: quadrant,
          intensity: 0.2 + random.nextDouble() * 0.8,
        ),
      );
    }

    _stimuli.shuffle();
    _showNextStimulus();
  }

  void _showNextStimulus() {
    if (_currentStimulusIndex < _stimuli.length) {
      _activeStimulus = null;
      notifyListeners();

      // Wait 1-2 seconds between stimuli
      Future.delayed(
        Duration(milliseconds: 1000 + math.Random().nextInt(1000)),
        () {
          if (!_isTestActive) return;

          _activeStimulus = _stimuli[_currentStimulusIndex];
          final capturedIndex = _currentStimulusIndex;
          notifyListeners();

          // Wait 1.5 seconds for response
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (_isTestActive &&
                _activeStimulus != null &&
                _currentStimulusIndex == capturedIndex) {
              _recordResponse(false);
            }
          });
        },
      );
    } else {
      _isTestActive = false;
      notifyListeners();
    }
  }

  void recordDetection() {
    if (_isTestActive && _activeStimulus != null) {
      _recordResponse(true);
    }
  }

  void _recordResponse(bool detected) {
    if (_activeStimulus == null) return;

    final result = _activeStimulus!;
    result.isDetected = detected;
    _results.add(result);

    _activeStimulus = null;
    _currentStimulusIndex++;
    notifyListeners();

    _showNextStimulus();
  }

  Map<VisualFieldQuadrant, double> getQuadrantResults() {
    final Map<VisualFieldQuadrant, int> totalPerQuadrant = {};
    final Map<VisualFieldQuadrant, int> detectedPerQuadrant = {};

    for (var r in _results) {
      totalPerQuadrant[r.quadrant] = (totalPerQuadrant[r.quadrant] ?? 0) + 1;
      if (r.isDetected) {
        detectedPerQuadrant[r.quadrant] =
            (detectedPerQuadrant[r.quadrant] ?? 0) + 1;
      }
    }

    final Map<VisualFieldQuadrant, double> sensitivity = {};
    for (var q in VisualFieldQuadrant.values) {
      if (q == VisualFieldQuadrant.center) continue;
      final total = totalPerQuadrant[q] ?? 0;
      final detected = detectedPerQuadrant[q] ?? 0;
      sensitivity[q] = total == 0 ? 0 : (detected / total);
    }

    return sensitivity;
  }

  int get detectedCount => _results.where((r) => r.isDetected).length;
  int get totalCount => _results.length;

  String getInterpretation() {
    final sensitivity = getQuadrantResults();
    final List<String> findings = [];

    sensitivity.forEach((quadrant, score) {
      if (score < 0.7) {
        String level = score < 0.4 ? "Significant" : "Mild";
        findings.add("$level sensitivity reduction in the ${quadrant.label}");
      }
    });

    if (findings.isEmpty) {
      return "No significant peripheral vision defects detected. All quadrants show normal sensitivity.";
    } else {
      return "Potential visual field defects identified:\n• ${findings.join("\n• ")}";
    }
  }

  VisualFieldResult createResult() {
    return VisualFieldResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      quadrantSensitivity: getQuadrantResults(),
      totalStimuli: totalCount,
      detectedStimuli: detectedCount,
      stimuliResults: _results,
    );
  }

  void reset() {
    _isTestActive = false;
    _activeStimulus = null;
    _currentStimulusIndex = 0;
    _stimuli.clear();
    _results.clear();
    notifyListeners();
  }
}
