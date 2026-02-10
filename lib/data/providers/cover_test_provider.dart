import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/cover_test_result.dart';

enum CoverTestStep {
  instructions,
  coverRight, // Observe Left Eye
  uncoverRight, // Observe Right Eye
  coverLeft, // Observe Right Eye
  uncoverLeft, // Observe Left Eye
  result,
}

class CoverTestProvider extends ChangeNotifier {
  CoverTestStep _currentStep = CoverTestStep.instructions;
  final List<CoverTestObservation> _observations = [];
  bool _isPerformingAction = false;

  CoverTestStep get currentStep => _currentStep;
  List<CoverTestObservation> get observations => _observations;
  bool get isPerformingAction => _isPerformingAction;

  void startTest() {
    _currentStep = CoverTestStep.coverRight;
    _observations.clear();
    _isPerformingAction = false;
    notifyListeners();
  }

  void setPerformingAction(bool value) {
    _isPerformingAction = value;
    notifyListeners();
  }

  void recordObservation(EyeMovement movement) {
    String eye = '';
    String phase = '';

    switch (_currentStep) {
      case CoverTestStep.coverRight:
        eye = 'Left';
        phase = 'Covering Right';
        break;
      case CoverTestStep.uncoverRight:
        eye = 'Right';
        phase = 'Uncovering Right';
        break;
      case CoverTestStep.coverLeft:
        eye = 'Right';
        phase = 'Covering Left';
        break;
      case CoverTestStep.uncoverLeft:
        eye = 'Left';
        phase = 'Uncovering Left';
        break;
      default:
        return;
    }

    _observations.add(
      CoverTestObservation(eye: eye, phase: phase, movement: movement),
    );

    _nextStep();
  }

  void _nextStep() {
    switch (_currentStep) {
      case CoverTestStep.coverRight:
        _currentStep = CoverTestStep.uncoverRight;
        break;
      case CoverTestStep.uncoverRight:
        _currentStep = CoverTestStep.coverLeft;
        break;
      case CoverTestStep.coverLeft:
        _currentStep = CoverTestStep.uncoverLeft;
        break;
      case CoverTestStep.uncoverLeft:
        _currentStep = CoverTestStep.result;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  CoverTestResult calculateResult(String patientId, String? patientName) {
    AlignmentStatus rightStatus = AlignmentStatus.normal;
    AlignmentStatus leftStatus = AlignmentStatus.normal;

    for (var obs in _observations) {
      if (obs.movement == EyeMovement.none) continue;

      // Tropia Detection (Cover phase, observing other eye)
      if (obs.phase.contains('Covering')) {
        if (obs.eye == 'Right') {
          rightStatus = _movementToTropia(obs.movement);
        } else {
          leftStatus = _movementToTropia(obs.movement);
        }
      }
      // Phoria Detection (Uncover phase, observing same eye)
      else if (obs.phase.contains('Uncovering')) {
        final phoria = _movementToPhoria(obs.movement);
        if (obs.eye == 'Right' && rightStatus == AlignmentStatus.normal) {
          rightStatus = phoria;
        } else if (obs.eye == 'Left' && leftStatus == AlignmentStatus.normal) {
          leftStatus = phoria;
        }
      }
    }

    return CoverTestResult(
      id: const Uuid().v4(),
      patientId: patientId,
      patientName: patientName,
      date: DateTime.now(),
      rightEyeStatus: rightStatus,
      leftEyeStatus: leftStatus,
      observations: List.from(_observations),
    );
  }

  AlignmentStatus _movementToTropia(EyeMovement movement) {
    switch (movement) {
      case EyeMovement.inward:
        return AlignmentStatus.exotropia; // Eye was out, moved in
      case EyeMovement.outward:
        return AlignmentStatus.esotropia; // Eye was in, moved out
      case EyeMovement.upward:
        return AlignmentStatus.hypotropia; // Eye was down, moved up
      case EyeMovement.downward:
        return AlignmentStatus.hypertropia; // Eye was up, moved down
      default:
        return AlignmentStatus.normal;
    }
  }

  AlignmentStatus _movementToPhoria(EyeMovement movement) {
    switch (movement) {
      case EyeMovement.inward:
        return AlignmentStatus.exophoria;
      case EyeMovement.outward:
        return AlignmentStatus.esophoria;
      default:
        return AlignmentStatus.normal;
    }
  }

  void reset() {
    _currentStep = CoverTestStep.instructions;
    _observations.clear();
    _isPerformingAction = false;
    notifyListeners();
  }
}
