import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/torchlight_test_result.dart';

enum ExtraocularPhase {
  alignment,
  hPattern,
  starPattern,
  convergence,
  finished,
}

class ExtraocularMuscleProvider extends ChangeNotifier {
  ExtraocularPhase _currentPhase = ExtraocularPhase.alignment;
  bool _isAligned = false;
  double _horizontalAngle = 0.0;
  double _verticalAngle = 0.0;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Results building state
  final Map<String, MovementQuality> _movements = {};
  bool _nystagmusDetected = false;
  final List<CranialNerve> _affectedNerves = [];
  bool _ptosisDetected = false;
  EyeSide? _ptosisEye;
  final Map<String, double> _restrictionMap = {};

  // Getters
  ExtraocularPhase get currentPhase => _currentPhase;
  bool get isAligned => _isAligned;
  double get horizontalAngle => _horizontalAngle;
  double get verticalAngle => _verticalAngle;

  bool get nystagmusDetected => _nystagmusDetected;
  bool get ptosisDetected => _ptosisDetected;
  EyeSide? get ptosisEye => _ptosisEye;
  List<CranialNerve> get affectedNerves => List.unmodifiable(_affectedNerves);

  MovementQuality? getMovement(String direction) => _movements[direction];
  double? getRestriction(String direction) => _restrictionMap[direction];

  void startAlignment() {
    _currentPhase = ExtraocularPhase.alignment;
    _accelerometerSubscription = accelerometerEvents.listen((
      AccelerometerEvent event,
    ) {
      // Simple alignment logic: device should be relatively upright (portrait)
      // and facing the user
      _horizontalAngle = event.x; // Tilt left/right
      _verticalAngle =
          event.z; // Tilt forward/back (should be near 0 for vertical)

      // Thresholds for "aligned"
      _isAligned = event.x.abs() < 1.0 && event.z.abs() < 2.0;
      notifyListeners();
    });
  }

  void stopSensing() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  void setPhase(ExtraocularPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void recordMovement(
    String direction,
    MovementQuality quality,
    double restriction,
  ) {
    _movements[direction] = quality;
    _restrictionMap[direction] = restriction;
    notifyListeners();
  }

  void setNystagmus(bool detected) {
    _nystagmusDetected = detected;
    notifyListeners();
  }

  void setPtosis(bool detected, [EyeSide? eye]) {
    _ptosisDetected = detected;
    _ptosisEye = eye;
    notifyListeners();
  }

  void addAffectedNerve(CranialNerve nerve) {
    if (!_affectedNerves.contains(nerve)) {
      _affectedNerves.add(nerve);
      notifyListeners();
    }
  }

  ExtraocularResult buildResult(String patternUsed) {
    return ExtraocularResult(
      movements: Map.from(_movements),
      nystagmusDetected: _nystagmusDetected,
      affectedNerves: List.from(_affectedNerves),
      ptosisDetected: _ptosisDetected,
      ptosisEye: _ptosisEye,
      restrictionMap: Map.from(_restrictionMap),
      patternUsed: patternUsed,
    );
  }

  void reset() {
    stopSensing();
    _currentPhase = ExtraocularPhase.alignment;
    _isAligned = false;
    _movements.clear();
    _nystagmusDetected = false;
    _affectedNerves.clear();
    _ptosisDetected = false;
    _ptosisEye = null;
    _restrictionMap.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopSensing();
    super.dispose();
  }
}
