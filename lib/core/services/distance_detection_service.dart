// File: lib/core/services/distance_detection_service.dart

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Distance status for visual feedback
enum DistanceStatus { tooClose, tooFar, optimal, noFaceDetected }

/// Distance detection service using Google ML Kit Face Detection
/// Uses interpupillary distance (IPD) for accurate distance calculation
class DistanceDetectionService {
  final FaceDetector _faceDetector;
  CameraController? _cameraController;
  bool _isProcessing = false;
  Timer? _processingTimer;
  StreamController<Map<String, dynamic>>? _streamController;

  // Callbacks
  Function(double distance, DistanceStatus status)? onDistanceUpdate;
  Function(String message)? onError;

  // Distance calculation using IPD (more accurate than face width)
  static const double _averageIPDCm = 6.3;

  // Default target distance and tolerance
  static const double _defaultTargetDistanceCm = 100.0;
  static const double _defaultToleranceCm = 8.0;

  // Instance-specific distance parameters (can be customized per test)
  final double targetDistanceCm;
  final double toleranceCm;

  // Smoothing for stable readings
  double _smoothedDistance = 0.0;
  static const double _smoothingFactor = 0.3;

  // Processing interval
  static const int _processingIntervalMs = 250;

  // Error tracking
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 10;

  DistanceDetectionService({
    this.targetDistanceCm = _defaultTargetDistanceCm,
    this.toleranceCm = _defaultToleranceCm,
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

  /// Initialize camera for face detection
  Future<CameraController?> initializeCamera() async {
    try {
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

      // ✅ DEBUG: Comprehensive camera diagnostics
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🎥 CAMERA DIAGNOSTICS');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✓ Initialized: ${_cameraController!.value.isInitialized}');
      debugPrint('✓ Preview Size: ${_cameraController!.value.previewSize}');
      debugPrint('✓ Aspect Ratio: ${_cameraController!.value.aspectRatio}');
      debugPrint('✓ Streaming: ${_cameraController!.value.isStreamingImages}');
      debugPrint('✓ Recording: ${_cameraController!.value.isRecordingVideo}');
      if (_cameraController!.value.errorDescription != null) {
        debugPrint('❌ Error: ${_cameraController!.value.errorDescription}');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return _cameraController;
    } catch (e) {
      onError?.call('Failed to initialize camera: $e');
      debugPrint('[DistanceService] Error: $e');
      return null;
    }
  }

  /// Start continuous distance monitoring
  Future<void> startMonitoring() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      onError?.call('Camera not initialized');
      return;
    }

    _streamController = StreamController<Map<String, dynamic>>.broadcast();
    _consecutiveErrors = 0;

    _processingTimer = Timer.periodic(
      Duration(milliseconds: _processingIntervalMs),
      (timer) async {
        if (!_isProcessing &&
            _cameraController != null &&
            _cameraController!.value.isInitialized) {
          await _captureAndProcess();
        }
      },
    );
  }

  /// Stop distance monitoring
  Future<void> stopMonitoring() async {
    _processingTimer?.cancel();
    _processingTimer = null;
    await _streamController?.close();
    _streamController = null;
  }

  /// Capture image and process for face detection
  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;
    _isProcessing = true;

    XFile? imageFile;

    try {
      imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _updateDistance(0, DistanceStatus.noFaceDetected);
        _consecutiveErrors++;
      } else {
        final face = faces.reduce(
          (a, b) => a.boundingBox.width > b.boundingBox.width ? a : b,
        );

        final distance = _calculateDistanceFromFace(face);

        if (distance > 0) {
          if (_smoothedDistance == 0.0) {
            _smoothedDistance = distance;
          } else {
            // Apply smoothing: smooth = alpha * new + (1-alpha) * old
            _smoothedDistance =
                _smoothingFactor * distance +
                (1 - _smoothingFactor) * _smoothedDistance;
          }

          final status = _getDistanceStatus(_smoothedDistance);
          _updateDistance(_smoothedDistance, status);
          _consecutiveErrors = 0;
        } else {
          _updateDistance(0, DistanceStatus.noFaceDetected);
          _consecutiveErrors++;
        }
      }

      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        onError?.call('Face detection failed repeatedly');
        await stopMonitoring();
      }
    } catch (e) {
      debugPrint('[DistanceService] Processing error: $e');
      _consecutiveErrors++;
      onError?.call('Detection error: $e');
    } finally {
      _isProcessing = false;

      if (imageFile != null) {
        try {
          final file = File(imageFile.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('[DistanceService] Error deleting temp file: $e');
        }
      }
    }
  }

  /// Calculate distance using interpupillary distance (IPD)
  double _calculateDistanceFromFace(Face face) {
    try {
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      if (leftEye == null || rightEye == null) {
        return _calculateDistanceFromFaceWidth(face.boundingBox.width);
      }

      final dx = leftEye.position.x - rightEye.position.x;
      final dy = leftEye.position.y - rightEye.position.y;
      final pixelIPD = math.sqrt(dx * dx + dy * dy);

      if (pixelIPD <= 0) return -1.0;

      const double focalLengthPixels = 600.0;
      final distanceCm = (_averageIPDCm * focalLengthPixels) / pixelIPD;

      if (distanceCm < 10 || distanceCm > 300) return -1.0;

      return distanceCm;
    } catch (e) {
      debugPrint('[DistanceService] IPD calculation error: $e');
      return -1.0;
    }
  }

  /// Fallback: Calculate distance using face width
  double _calculateDistanceFromFaceWidth(double faceWidthPixels) {
    if (faceWidthPixels <= 0) return -1.0;

    const double averageFaceWidthCm = 14.0;
    const double focalLengthPixels = 600.0;

    final distanceCm =
        (averageFaceWidthCm * focalLengthPixels) / faceWidthPixels;

    if (distanceCm < 10 || distanceCm > 300) return -1.0;

    return distanceCm;
  }

  /// Update distance and notify listeners
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

  /// Get distance status based on calculated distance
  /// ✅ THIS WAS THE MISSING METHOD!
  DistanceStatus _getDistanceStatus(double distanceCm) {
    if (distanceCm <= 0) return DistanceStatus.noFaceDetected;

    // ✅ NEW LOGIC: Only check minimum distance (no maximum limit)
    if (distanceCm < targetDistanceCm) {
      return DistanceStatus.tooClose;
    } else {
      // ✅ Any distance >= targetDistanceCm is acceptable
      return DistanceStatus.optimal;
    }
  }

  /// Get distance stream
  Stream<Map<String, dynamic>>? get distanceStream => _streamController?.stream;

  /// Get acceptable distance range
  String get acceptableRange =>
      '${targetDistanceCm.toInt()}+ cm'; // ✅ Changed to "40+ cm" format

  /// Format distance string
  static String formatDistance(double distanceCm) {
    if (distanceCm <= 0) return 'No face detected';
    return '${distanceCm.toStringAsFixed(0)} cm';
  }

  /// Get guidance message based on status
  static String getGuidanceMessage(DistanceStatus status) {
    switch (status) {
      case DistanceStatus.tooClose:
        return 'Move back - You are too close';
      case DistanceStatus.tooFar:
        return 'Distance is good!'; // ✅ Not used anymore but kept for compatibility
      case DistanceStatus.optimal:
        return 'Perfect! Distance is correct';
      case DistanceStatus.noFaceDetected:
        return 'Position your face in the camera view';
    }
  }

  /// Get target distance message
  static String getTargetDistanceMessage() {
    return 'Maintain 1 meter distance (about arm\'s length extended)';
  }

  /// Check if current distance is acceptable
  bool isDistanceAcceptable(double distance) {
    // ✅ NEW: Only check minimum distance
    return distance >= targetDistanceCm;
  }

  /// Check if service is ready
  bool get isReady =>
      _cameraController != null && _cameraController!.value.isInitialized;

  /// Check if currently monitoring
  bool get isMonitoring =>
      _processingTimer != null && _processingTimer!.isActive;

  /// Dispose resources
  Future<void> dispose() async {
    await stopMonitoring();
    await _cameraController?.dispose();
    _cameraController = null;
    await _faceDetector.close();
  }
}
