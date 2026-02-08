import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/eye_hydration_result.dart';

class EyeHydrationProvider extends ChangeNotifier {
  // Constants for blink detection
  static const double PROB_THRESHOLD =
      0.45; // Ultra-sensitive (catch shallow blinks)
  static const double PROB_RECOVER =
      0.6; // Low recovery point for shallow blink cycles
  static const int MIN_BLINK_DURATION_MS = 50; // More inclusive
  static const int MAX_BLINK_DURATION_MS =
      600; // Slightly tighter for real blinks
  static const int MIN_BETWEEN_BLINKS_MS =
      300; // Prevent double counting on sensitive threshold

  // Broadcast stream for blink events to trigger animations
  final _blinkStreamController = StreamController<void>.broadcast();
  Stream<void> get blinkStream => _blinkStreamController.stream;

  bool _isTestRunning = false;
  int _blinkCount = 0;
  DateTime? _testStartTime;
  EyeHydrationResult? _finalResult;
  double _screenBrightness = 0.5;

  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isProcessing = false;
  bool _inBlinkState = false;
  DateTime? _lastBlinkTime;

  double _currentLeftProb = 1.0;
  double _currentRightProb = 1.0;
  double _smoothProb = 1.0;
  static const double _smoothingFactor = 0.2;
  bool _faceDetected = false;

  // Getters
  bool get isTestRunning => _isTestRunning;
  int get blinkCount => _blinkCount;
  bool get faceDetected => _faceDetected;
  double get leftEyeOpenProbability => _currentLeftProb;
  double get rightEyeOpenProbability => _currentRightProb;
  double get currentBlinkProbability => _smoothProb;
  EyeHydrationResult? get finalResult => _finalResult;

  set screenBrightness(double value) {
    _screenBrightness = value;
    notifyListeners();
  }

  final List<String> readingContent = [
    "The World of Ancient Discoveries",
    "Archaeology is the study of human activity through the recovery and analysis of material culture. The archaeological record consists of artifacts, architecture, biofacts or ecofacts and cultural landscapes.",
    "Ancient civilizations often left behind complex structures that tell stories of their daily lives, beliefs, and social hierarchies. From the pyramids of Giza to the Terracotta Army in China, these discoveries provide a window into the past.",
    "Modern technology, such as LiDAR and ground-penetrating radar, has revolutionized how archaeologists find and map historical sites without disturbing the earth. This helps preserve the sites for future generations.",
    "Understanding our history helps us appreciate the journey of humanity and the different cultures that have shaped our world today. It reminds us that while technology changes, human nature remains remarkably consistent across millennia.",
  ];

  Future<void> startTest(CameraController controller) async {
    _cameraController = controller;
    _isTestRunning = true;
    _blinkCount = 0;
    _testStartTime = DateTime.now();
    _finalResult = null;
    _inBlinkState = false;
    _lastBlinkTime = null;

    _startImageStream();
    notifyListeners();
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final faces = await _processImage(image);
        if (faces.isNotEmpty) {
          if (!_faceDetected) {
            debugPrint('🙂 Face detected');
          }
          _analyzeFace(faces.first);
        } else {
          if (_faceDetected) {
            debugPrint('❓ Face lost');
          }
          _faceDetected = false;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error processing image: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<List<Face>> _processImage(CameraImage image) async {
    final format = _getInputImageFormat(image.format.group);

    // Improved byte extraction for YUV420
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _getImageRotation(),
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
    return await _faceDetector.processImage(inputImage);
  }

  InputImageRotation _getImageRotation() {
    final orientation = _cameraController!.description.sensorOrientation;
    switch (orientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat _getInputImageFormat(ImageFormatGroup format) {
    if (Platform.isAndroid) {
      // Android cameras typically use YUV_420_888 which is often compatible with NV21 for ML Kit
      return InputImageFormat.nv21;
    } else if (Platform.isIOS) {
      return InputImageFormat.bgra8888;
    }
    return InputImageFormat.nv21;
  }

  void _analyzeFace(Face face) {
    _faceDetected = true;
    _currentLeftProb = face.leftEyeOpenProbability ?? 1.0;
    _currentRightProb = face.rightEyeOpenProbability ?? 1.0;

    double avgProb = (_currentLeftProb + _currentRightProb) / 2.0;

    // Apply exponential moving average for smoother UI
    _smoothProb =
        (_smoothingFactor * avgProb) + ((1 - _smoothingFactor) * _smoothProb);

    DateTime now = DateTime.now();

    bool isClosed = avgProb < PROB_THRESHOLD;
    bool isOpened = avgProb > PROB_RECOVER;

    if (isClosed) {
      if (!_inBlinkState) {
        // COUNT ON CLOSURE - More responsive feel
        bool isDuplicate = false;
        if (_lastBlinkTime != null) {
          if (now.difference(_lastBlinkTime!).inMilliseconds <
              MIN_BETWEEN_BLINKS_MS) {
            isDuplicate = true;
          }
        }

        if (!isDuplicate) {
          _blinkCount++;
          _lastBlinkTime = now;
          _inBlinkState = true;

          // Notify stream to trigger animations
          _blinkStreamController.add(null);

          debugPrint('👁️ Blink detected on closure! Count: $_blinkCount');
        } else {
          // Still mark as in blink state to avoid re-triggering immediately
          _inBlinkState = true;
        }
      }
    } else if (isOpened) {
      if (_inBlinkState) {
        // Reset blink state once eyes are sufficiently open again
        _inBlinkState = false;
      }
    }
    notifyListeners();
  }

  Future<void> stopTest() async {
    if (!_isTestRunning) return;

    _isTestRunning = false;
    await _cameraController?.stopImageStream();

    final testDuration = DateTime.now().difference(_testStartTime!);
    _finalResult = EyeHydrationResult.analyze(
      blinkCount: _blinkCount,
      duration: testDuration,
      screenBrightness: _screenBrightness,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }
}
