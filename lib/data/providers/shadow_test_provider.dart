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
  bool _isDisposed = false;

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
    try {
      AppLogger.log('$_tag: Initializing camera', tag: _tag);

      _isCameraStarting = true;
      _errorMessage = null;
      _currentEye = 'right';
      _rightEyeGrading = null;
      _leftEyeGrading = null;
      _finalResult = null;
      _isFlashOn = false;
      _isCapturing = false;
      _state = ShadowTestState.initial;

      if (!_isDisposed) notifyListeners();

      // Register lifecycle observer
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);

      // Dispose existing camera
      await _cameraService.dispose();
      await Future.delayed(const Duration(milliseconds: 100));

      // Initialize camera
      await _cameraService.initialize();

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception('Camera initialization failed');
      }

      AppLogger.log('$_tag: Camera initialized', tag: _tag);

      // Turn on flash
      _isFlashOn = true;
      await _cameraService.setFlashMode(FlashMode.torch);

      AppLogger.log('$_tag: Flash enabled', tag: _tag);

      // Give camera time to stabilize after flash activation
      await Future.delayed(const Duration(milliseconds: 500));

      // Start eye detection
      _startEyeDetection();
      await Future.delayed(const Duration(milliseconds: 200));

      // Camera is ready - clear any previous errors
      _isCameraStarting = false;
      _errorMessage = null;
      if (!_isDisposed) notifyListeners();

      AppLogger.log('$_tag: Camera ready', tag: _tag);
    } catch (e) {
      AppLogger.log('$_tag: Init error: $e', tag: _tag, isError: true);
      _isCameraStarting = false;
      _errorMessage = 'Camera initialization failed. Please restart test.';
      if (!_isDisposed) notifyListeners();
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
    if (_isCapturing || !_isReadyForCapture || _isDisposed) return;

    // Check if controller is still valid
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      _errorMessage = 'Camera not available';
      notifyListeners();
      return;
    }

    _isCapturing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppLogger.log('$_tag: Capturing image for $_currentEye eye', tag: _tag);

      // Stop searching before capture
      _cameraService.stopSearchingForEyes();

      // Wait for camera to stabilize
      await Future.delayed(const Duration(milliseconds: 300));

      // Double-check controller is still valid
      if (_isDisposed || _cameraService.controller == null) {
        throw Exception('Camera not available');
      }

      // Capture image
      final imagePath = await _cameraService.captureImage();
      if (imagePath == null) {
        throw Exception('Capture failed. Retry.');
      }

      AppLogger.log('$_tag: Image captured successfully', tag: _tag);

      // Check image quality
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
    try {
      AppLogger.log('$_tag: Stopping camera', tag: _tag);

      // Stop eye detection first
      _cameraService.stopSearchingForEyes();

      // Turn off flash
      _isFlashOn = false;
      await _cameraService.setFlashMode(FlashMode.off);
      await _cameraService.turnOffFlashlight();

      // Wait for flash to actually turn off
      await Future.delayed(const Duration(milliseconds: 200));

      // Dispose camera
      await _cameraService.dispose();

      _isCameraStarting = false;
      notifyListeners();
    } catch (e) {
      AppLogger.log(
        '$_tag: Error stopping camera: $e',
        tag: _tag,
        isError: true,
      );
      // Force cleanup even if there's an error
      _isCameraStarting = false;
      _isFlashOn = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.log('$_tag: Lifecycle state changed to: $state', tag: _tag);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - release camera immediately
      stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground - reinitialize if needed
      if (_state != ShadowTestState.result &&
          _cameraService.controller == null) {
        // Give a small delay before reinitializing
        Future.delayed(const Duration(milliseconds: 300), () {
          initializeCamera(); // Remove the mounted check here
        });
      }
    }
  }

  @override
  void dispose() {
    AppLogger.log('$_tag: Provider disposing', tag: _tag);

    _isDisposed = true;

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Stop camera synchronously
    _cameraService.stopSearchingForEyes();
    _isFlashOn = false;

    // Fire and forget camera disposal
    _cameraService.dispose().catchError((e) {
      AppLogger.log('$_tag: Error in dispose: $e', tag: _tag);
    });

    super.dispose();
  }
}
