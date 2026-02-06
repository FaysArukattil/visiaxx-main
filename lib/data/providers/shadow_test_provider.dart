import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/services/shadow_test_camera_service.dart';
import '../../core/services/shadow_detection_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/shadow_test_result.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum ShadowTestState {
  initial,
  instructions,
  rightEyeCapture,
  leftEyeCapture,
  analyzing,
  result,
}

class ShadowTestProvider extends ChangeNotifier {
  static const String _tag = 'ShadowTestProvider';

  final ShadowTestCameraService _cameraService = ShadowTestCameraService();
  final ShadowDetectionService _detectionService = ShadowDetectionService();

  ShadowTestState _state = ShadowTestState.initial;
  String _currentEye = 'right';

  // Detection feedback
  bool _isEyeDetected = false;
  String _readinessFeedback = 'Positioning...';
  bool _isReadyForCapture = false;

  // Results
  EyeGrading? _rightEyeGrading;
  EyeGrading? _leftEyeGrading;
  ShadowTestResult? _finalResult;

  bool _isCapturing = false;
  String? _errorMessage;

  // Getters
  ShadowTestState get state => _state;
  String get currentEye => _currentEye;
  bool get isEyeDetected => _isEyeDetected;
  String get readinessFeedback => _readinessFeedback;
  bool get isReadyForCapture => _isReadyForCapture;
  EyeGrading? get rightEyeGrading => _rightEyeGrading;
  EyeGrading? get leftEyeGrading => _leftEyeGrading;
  ShadowTestResult? get finalResult => _finalResult;
  bool get isCapturing => _isCapturing;
  String? get errorMessage => _errorMessage;
  CameraController? get cameraController => _cameraService.controller;

  Future<void> initializeCamera() async {
    try {
      _errorMessage = null;
      await _cameraService.initialize();

      _cameraService.startImageStream((faces, imageSize) {
        _processEyeDetection(faces, imageSize);
      });

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  void _processEyeDetection(List<Face> faces, Size imageSize) {
    if (faces.isEmpty) {
      _isEyeDetected = false;
      _readinessFeedback = 'No eyes detected';
      _isReadyForCapture = false;
    } else {
      _isEyeDetected = true;
      _readinessFeedback = 'Eyes detected. Hold steady.';
      _isReadyForCapture = true;
    }
    notifyListeners();
  }

  Future<void> captureAndAnalyze() async {
    if (_isCapturing || !_isReadyForCapture) return;

    _isCapturing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppLogger.log('$_tag: Capturing image for $_currentEye eye', tag: _tag);

      // Image capture (Flashlight managed by state)
      final imagePath = await _cameraService.captureImage();
      if (imagePath == null) throw Exception('Failed to capture image');

      // Analyze image
      final analysis = await _detectionService.analyzeEyeImage(imagePath);

      final grading = EyeGrading(
        grade: ShadowTestGrade.fromGrade(analysis.grade),
        imagePath: imagePath,
        shadowRatio: analysis.shadowRatio,
      );

      if (_currentEye == 'right') {
        _rightEyeGrading = grading;
        _currentEye = 'left';
        _state = ShadowTestState.leftEyeCapture;
      } else {
        _leftEyeGrading = grading;
        await _generateFinalResult();
        _state = ShadowTestState.result;
      }
    } catch (e) {
      _errorMessage = 'Test failed: $e';
      AppLogger.log(
        '$_tag: Error in capture flow: $e',
        tag: _tag,
        isError: true,
      );
    } finally {
      _isCapturing = false;
      notifyListeners();
    }
  }

  Future<void> _generateFinalResult() async {
    if (_rightEyeGrading == null || _leftEyeGrading == null) return;

    _finalResult = ShadowTestResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: 'current_user', // This should be updated by the caller
      rightEye: _rightEyeGrading!,
      leftEye: _leftEyeGrading!,
    );
  }

  void setState(ShadowTestState newState) {
    _state = newState;
    if (newState == ShadowTestState.initial) {
      _currentEye = 'right';
      _rightEyeGrading = null;
      _leftEyeGrading = null;
      _finalResult = null;
      _cameraService.turnOffFlashlight();
    } else if (newState == ShadowTestState.rightEyeCapture ||
        newState == ShadowTestState.leftEyeCapture) {
      _cameraService.turnOnFlashlight();
    } else {
      _cameraService.turnOffFlashlight();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}
