// File: lib/core/services/distance_detection_service.dart

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Distance status for visual feedback
enum DistanceStatus {
  tooClose,
  tooFar,
  optimal,
  noFaceDetected,
  faceDetectedNoDistance,
}

/// Distance detection service using Google ML Kit Face Detection
/// Optimized to prevent system-wide deadlocks and resource contention.
class DistanceDetectionService {
  final FaceDetector _faceDetector;
  CameraController? _cameraController;
  bool _isProcessing = false;
  Timer? _processingTimer;
  StreamController<Map<String, dynamic>>? _streamController;

  // Callbacks
  Function(double distance, DistanceStatus status)? onDistanceUpdate;
  Function(String message)? onError;

  static const double _averageIPDCm = 6.3;
  static const double _defaultTargetDistanceCm = 100.0;
  static const double _defaultToleranceCm = 8.0;

  final double targetDistanceCm;
  final double toleranceCm;
  final double? minDistanceCm;
  final double? maxDistanceCm;

  double _smoothedDistance = 0.0;
  static const double _smoothingFactor = 0.3;
  double _lastKnownGoodDistance = 0.0;

  // ✅ CRITICAL FIX: Increased from 250ms to 1500ms to avoid crashing native bridge
  static const int _processingIntervalMs = 1500;

  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 10;

  double _calibratedFaceWidthRatio = 1.0;
  bool _isFaceWidthCalibrated = false;
  static const double _averageFaceWidthCm = 14.3;

  DistanceDetectionService({
    this.targetDistanceCm = _defaultTargetDistanceCm,
    this.toleranceCm = _defaultToleranceCm,
    this.minDistanceCm,
    this.maxDistanceCm,
  }) : _faceDetector = FaceDetector(
         options: FaceDetectorOptions(
           enableContours: false,
           enableClassification: false,
           enableLandmarks: true,
           enableTracking: true,
           performanceMode: FaceDetectorMode.fast,
           minFaceSize: 0.15,
         ),
       );

  Future<CameraController?> initializeCamera() async {
    try {
      // ✅ STABILITY FIX: Re-use existing controller if already initialized
      // This prevents the camera hardware from being thrashing (opening/closing)
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        debugPrint(
          '[DistanceService] Camera already active, reusing controller',
        );
        return _cameraController;
      }

      if (_cameraController != null) {
        debugPrint('[DistanceService] Disposing stale camera controller');
        await _cameraController!.dispose().catchError(
          (e) => debugPrint('Error disposing: $e'),
        );
        _cameraController = null;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        onError?.call('No cameras available');
        return null;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      debugPrint('[DistanceService] Camera initialized');
      return _cameraController;
    } catch (e) {
      onError?.call('Failed to initialize camera: $e');
      return null;
    }
  }

  Future<void> startMonitoring() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await initializeCamera();
    }

    if (_cameraController == null) return;

    _streamController?.close();
    _streamController = StreamController<Map<String, dynamic>>.broadcast();
    _consecutiveErrors = 0;

    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(
      const Duration(milliseconds: _processingIntervalMs),
      (timer) async {
        if (!_isProcessing &&
            _cameraController != null &&
            _cameraController!.value.isInitialized) {
          await _captureAndProcess();
        }
      },
    );
  }

  Future<void> stopMonitoring() async {
    _processingTimer?.cancel();
    _processingTimer = null;
    await _streamController?.close();
    _streamController = null;
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;
    _isProcessing = true;

    XFile? imageFile;
    try {
      // ⚠️ takePicture is expensive, do not call more once per 1.5s
      imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        if (_lastKnownGoodDistance > 0) {
          _updateDistance(
            _lastKnownGoodDistance,
            DistanceStatus.noFaceDetected,
          );
        } else {
          _updateDistance(0, DistanceStatus.noFaceDetected);
        }
        _consecutiveErrors++;
      } else {
        final face = faces.reduce(
          (a, b) => a.boundingBox.width > b.boundingBox.width ? a : b,
        );

        // Get image dimensions for dynamic focal length
        double? imageWidth;
        double? imageHeight;

        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          // In portrait, height is the longer dimension, width is shorter
          // But ML Kit usually handles the rotation.
          // We need the width of the image as processed by ML Kit.
          final previewSize = _cameraController!.value.previewSize!;
          // ML Kit input image dimensions match preview dimensions (adjusted for orientation)
          // For portrait front camera, typical is 720 (width) x 1280 (height) or similar
          imageWidth = previewSize.height;
          imageHeight = previewSize.width;
        }

        final distance = _calculateDistanceFromFace(
          face,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );

        if (distance > 0) {
          _smoothedDistance = (_smoothedDistance <= 0)
              ? distance
              : (_smoothingFactor * distance +
                    (1 - _smoothingFactor) * _smoothedDistance);
          _lastKnownGoodDistance = _smoothedDistance;
          _updateDistance(
            _smoothedDistance,
            _getDistanceStatus(_smoothedDistance),
          );
          _consecutiveErrors = 0;
        } else if (_lastKnownGoodDistance > 0) {
          _updateDistance(
            _lastKnownGoodDistance,
            DistanceStatus.faceDetectedNoDistance,
          );
        }
      }

      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        onError?.call('Face detection failed repeatedly');
        await stopMonitoring();
      }
    } catch (e) {
      debugPrint('[DistanceService] Processing error: $e');
    } finally {
      _isProcessing = false;
      if (imageFile != null) {
        try {
          final file = File(imageFile.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  double _calculateDistanceFromFace(
    Face face, {
    double? imageWidth,
    double? imageHeight,
  }) {
    try {
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final faceWidth = face.boundingBox.width;

      // Dynamic focal length estimation
      // Use provided imageWidth or fallback to 720 (common portrait width for medium resolution)
      final effectiveWidth = imageWidth ?? 720.0;

      // Heuristic: focal length in pixels is typically around 1.0 to 1.1 times the image width
      // for most modern front-facing smartphone cameras (HFOV ~50-60 degrees).
      // We'll use 1.05 as a middle-ground starting point.
      final double focalLengthPixels = effectiveWidth * 1.05;

      if (leftEye != null && rightEye != null) {
        final dx = leftEye.position.x - rightEye.position.x;
        final dy = leftEye.position.y - rightEye.position.y;
        final pixelIPD = math.sqrt(dx * dx + dy * dy);

        if (pixelIPD > 0) {
          final distanceCm = (_averageIPDCm * focalLengthPixels) / pixelIPD;

          // Diagnostic Logging
          if (kDebugMode && _consecutiveErrors == 0) {
            debugPrint(
              '[DistanceAccuracy] Res: ${imageWidth?.toInt()}x${imageHeight?.toInt()} | '
              'PixelIPD: ${pixelIPD.toStringAsFixed(1)} | '
              'Focal: ${focalLengthPixels.toInt()} | '
              'Dist: ${distanceCm.toStringAsFixed(1)}cm',
            );
          }

          if (faceWidth > 0 && distanceCm > 10 && distanceCm < 300) {
            _calibratedFaceWidthRatio =
                distanceCm /
                ((_averageFaceWidthCm * focalLengthPixels) / faceWidth);
            _isFaceWidthCalibrated = true;
          }
          if (distanceCm >= 10 && distanceCm <= 300) return distanceCm;
        }
      }

      if (faceWidth > 0) {
        double rawDist = (_averageFaceWidthCm * focalLengthPixels) / faceWidth;
        double dist = _isFaceWidthCalibrated
            ? rawDist * _calibratedFaceWidthRatio
            : rawDist;
        if (dist >= 10 && dist <= 300) return dist;
      }
      return -1.0;
    } catch (e) {
      return -1.0;
    }
  }

  void _updateDistance(double distance, DistanceStatus status) {
    onDistanceUpdate?.call(distance, status);
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.add({
        'distance': distance,
        'status': status,
        'timestamp': DateTime.now(),
      });
    }
  }

  bool get isReady =>
      _cameraController != null && _cameraController!.value.isInitialized;
  bool get isMonitoring =>
      _processingTimer != null && _processingTimer!.isActive;

  DistanceStatus _getDistanceStatus(double distanceCm) {
    final min = minDistanceCm ?? (targetDistanceCm - toleranceCm);
    final max = maxDistanceCm ?? (targetDistanceCm + toleranceCm);
    if (distanceCm < min) return DistanceStatus.tooClose;
    if (distanceCm > max) return DistanceStatus.tooFar;
    return DistanceStatus.optimal;
  }

  Future<void> dispose() async {
    await stopMonitoring();
    await _cameraController?.dispose();
    _cameraController = null;
    await _faceDetector.close();
  }
}
