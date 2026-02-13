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

class ShadowTestProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _tag = 'ShadowTestProvider';

  final ShadowTestCameraService _cameraService = ShadowTestCameraService();
  final ShadowDetectionService _detectionService = ShadowDetectionService();

  ShadowTestState _state = ShadowTestState.initial;
  String _currentEye = 'right';

  // Detection feedback
  final bool _isEyeDetected = false;
  String _readinessFeedback = 'Positioning...';
  bool _isReadyForCapture = false;

  // Results
  EyeGrading? _rightEyeGrading;
  EyeGrading? _leftEyeGrading;
  ShadowTestResult? _finalResult;

  bool _isCapturing = false;
  bool _isCameraStarting = false;
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
  bool get isCameraStarting => _isCameraStarting;
  String? get errorMessage => _errorMessage;
  bool get isFlashOn => _isFlashOn;
  CameraController? get cameraController => _cameraService.controller;

  Future<void> initializeCamera() async {
    _isCameraStarting = true;
    notifyListeners();
    try {
      _errorMessage = null;
      _currentEye = 'right';
      _rightEyeGrading = null;
      _leftEyeGrading = null;
      _finalResult = null;
      _isFlashOn = false;
      _isCapturing = false;
      _state = ShadowTestState.initial;

      await _cameraService.dispose();

      // Register lifecycle observer if not already
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);

      await _cameraService.initialize();

      final controller = _cameraService.controller;
      if (controller != null) {
        controller.addListener(() {
          notifyListeners();
        });

        // Start eye detection stream to fulfill "Only Works for Eyes" requirement
        _startEyeDetection();
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Automatically turn on flash for the test
      _isFlashOn = true;
      await _cameraService.setFlashMode(FlashMode.torch);

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  void _startEyeDetection() {
    _readinessFeedback = 'Positioning eye...';
    _isReadyForCapture = false;

    _cameraService.startSearchingForEyes((faces, size, isIrisManual) {
      // Check if eye is centered and valid
      final eyeDetected = _cameraService.isEyeInCenter(
        faces,
        size,
        isIrisManual: isIrisManual,
      );

      if (faces.isNotEmpty || isIrisManual) {
        AppLogger.log(
          '$_tag: Detected ${faces.length} faces. Manual Iris: $isIrisManual. Toggle: $eyeDetected',
          tag: _tag,
        );
      }

      if (eyeDetected != _isReadyForCapture) {
        _isReadyForCapture = eyeDetected;
        _readinessFeedback = eyeDetected
            ? 'Eye detected. Ready to capture ${_currentEye.toUpperCase()} eye'
            : 'Align eye in the circle';
        notifyListeners();
      }
    });
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

      // Stop searching before capture to avoid resource contention
      _cameraService.stopSearchingForEyes();

      // Capture image
      final imagePath = await _cameraService.captureImage();
      if (imagePath == null) throw Exception('Failed to capture image');

      // Check image quality (ShadowDetectionService refactored)
      final quality = await _detectionService.checkImageQuality(imagePath);
      if (!quality.isGood) {
        _errorMessage = quality.message;
        _readinessFeedback = 'Please retake. ${quality.message}';
        _isCapturing = false;
        _startEyeDetection(); // Restart detection loop
        notifyListeners();
        return;
      }

      // Transition to analyzing state in UI
      _state = ShadowTestState.analyzing;
      notifyListeners();

      // Analyze image clinically
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
        _startEyeDetection(); // Restart for next eye
      } else {
        _leftEyeGrading = grading;
        await _generateFinalResult();

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
      _startEyeDetection(); // Recover by restarting detection
    } finally {
      _isCapturing = false;
      _isCameraStarting = false;
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
      _isFlashOn = false;
      _cameraService.setFlashMode(FlashMode.off);
      _cameraService.turnOffFlashlight();
    }
    notifyListeners();
  }

  Future<void> stopCamera() async {
    _isFlashOn = false;
    _isCameraStarting = false;
    await _cameraService.setFlashMode(FlashMode.off);
    await _cameraService.turnOffFlashlight();
    await _cameraService.dispose();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.log('$_tag: Lifecycle state changed to: $state', tag: _tag);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Release camera immediately when app goes to background
      stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize camera when app returns from background
      if (_state != ShadowTestState.initial &&
          _cameraService.controller == null) {
        initializeCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopCamera();
    super.dispose();
  }
}
