import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../../core/services/shadow_test_camera_service.dart';
import '../../core/services/shadow_detection_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/shadow_test_result.dart';
import './test_session_provider.dart';

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
  bool _isFlashOn = false;

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
  bool get isFlashOn => _isFlashOn;
  CameraController? get cameraController => _cameraService.controller;

  Future<void> initializeCamera() async {
    try {
      _errorMessage = null;
      // Reset test state to ensure fresh session
      _currentEye = 'right';
      _rightEyeGrading = null;
      _leftEyeGrading = null;
      _finalResult = null;
      _isFlashOn = false;
      _isCapturing = false;
      _state = ShadowTestState.initial;

      await _cameraService.initialize();

      // Add listener to camera controller to trigger UI updates when camera state changes
      // This is critical for release mode where timing is different than debug mode
      final controller = _cameraService.controller;
      if (controller != null) {
        controller.addListener(() {
          // Trigger UI rebuild when camera value changes (e.g., preview becomes available)
          notifyListeners();
        });
      }

      // Small delay to ensure camera preview is fully ready before updating UI
      // This is important for release mode where initialization timing differs
      await Future.delayed(const Duration(milliseconds: 200));

      // Automatically turn on flash for the test
      _isFlashOn = true;
      await _cameraService.setFlashMode(FlashMode.torch);

      _isReadyForCapture = true; // Enable manual capture
      _readinessFeedback = 'Ready to capture ${_currentEye.toUpperCase()} eye';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  // Auto-detection loop removed as per user request to use manual capture only.

  Future<void> toggleFlashlight() async {
    _isFlashOn = !_isFlashOn;
    await _cameraService.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
    notifyListeners();
  }

  // _processEyeDetection method removed as it's no longer used due to manual capture only.

  Future<void> captureAndAnalyze(TestSessionProvider sessionProvider) async {
    if (_isCapturing || !_isReadyForCapture) return;

    _isCapturing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppLogger.log('$_tag: Capturing image for $_currentEye eye', tag: _tag);

      // Image capture (Flashlight managed by state)
      final imagePath = await _cameraService.captureImage();
      if (imagePath == null) throw Exception('Failed to capture image');

      // Validate that the image contains an eye
      final validationResult = await _detectionService.validateEyeImage(
        imagePath,
      );

      if (!validationResult.isValid) {
        _errorMessage = validationResult.message;
        _readinessFeedback = 'Please retake the image';
        _isCapturing = false;
        notifyListeners();
        return;
      }

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
        _readinessFeedback = 'Ready to capture LEFT eye';
      } else {
        _leftEyeGrading = grading;
        await _generateFinalResult();

        // Push result to global test session
        if (_finalResult != null) {
          sessionProvider.setShadowTestResult(_finalResult!);
        }

        // Turn off flash once test is complete
        _isFlashOn = false;
        await _cameraService.setFlashMode(FlashMode.off);

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

  Future<void> reset() async {
    await initializeCamera();
  }

  void setState(ShadowTestState newState) {
    _state = newState;
    if (newState == ShadowTestState.initial) {
      _currentEye = 'right';
      _rightEyeGrading = null;
      _leftEyeGrading = null;
      _finalResult = null;
      _isFlashOn = false;
      _cameraService.setFlashMode(FlashMode.off);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}
