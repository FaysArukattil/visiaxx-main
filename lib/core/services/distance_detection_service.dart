// File: lib/core/services/distance_detection_service.dart

import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Distance status for visual feedback
/// - noFaceDetected: No face visible in camera at all
/// - faceDetectedNoDistance: Face is visible but can't calculate distance (e.g., one eye covered)
enum DistanceStatus {
  tooClose,
  tooFar,
  optimal,
  noFaceDetected,
  faceDetectedNoDistance,
}

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
  final double? minDistanceCm;
  final double? maxDistanceCm;

  // Smoothing for stable readings
  double _smoothedDistance = 0.0;
  static const double _smoothingFactor = 0.3;

  // Cache last known good distance for when face is partially obscured
  double _lastKnownGoodDistance = 0.0;

  // Processing interval
  static const int _processingIntervalMs = 250;

  // Error tracking
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 10;

  // … New: Face-width fallback for when eyes are covered
  double _calibratedFaceWidthRatio = 1.0;
  bool _isFaceWidthCalibrated = false;
  static const double _averageFaceWidthCm = 14.3; // Average human face width

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

  /// Detect distance from a single image file
  Future<double> detectDistance(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return -1.0;

      final face = faces.reduce(
        (a, b) => a.boundingBox.width > b.boundingBox.width ? a : b,
      );

      return _calculateDistanceFromFace(face);
    } catch (e) {
      debugPrint('[DistanceService] detectDistance error: $e');
      return -1.0;
    }
  }

  /// Initialize camera for face detection
  Future<CameraController?> initializeCamera() async {
    try {
      // … FIX: Properly dispose old controller if it exists
      if (_cameraController != null) {
        debugPrint(
          '[DistanceService] Disposing old camera controller before re-init',
        );
        try {
          await _cameraController!.dispose();
        } catch (e) {
          debugPrint('[DistanceService] Error disposing old controller: $e');
        }
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

      // … DEBUG: Comprehensive camera diagnostics
      debugPrint('”””””””””””””””””””””””””””');
      debugPrint('Ž¥ CAMERA DIAGNOSTICS');
      debugPrint('”””””””””””””””””””””””””””');
      debugPrint('“ Initialized: ${_cameraController!.value.isInitialized}');
      debugPrint('“ Preview Size: ${_cameraController!.value.previewSize}');
      debugPrint('“ Aspect Ratio: ${_cameraController!.value.aspectRatio}');
      debugPrint('“ Streaming: ${_cameraController!.value.isStreamingImages}');
      debugPrint('“ Recording: ${_cameraController!.value.isRecordingVideo}');
      if (_cameraController!.value.errorDescription != null) {
        debugPrint('Œ Error: ${_cameraController!.value.errorDescription}');
      }
      debugPrint('”””””””””””””””””””””””””””');

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
        // … User requested: show distance even if face temporarily lost
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

        final distance = _calculateDistanceFromFace(face);

        if (distance > 0) {
          if (_smoothedDistance <= 0.0) {
            _smoothedDistance = distance;
          } else {
            // Apply smoothing: smooth = alpha * new + (1-alpha) * old
            _smoothedDistance =
                _smoothingFactor * distance +
                (1 - _smoothingFactor) * _smoothedDistance;
          }

          // Cache this as last known good distance
          _lastKnownGoodDistance = _smoothedDistance;

          final status = _getDistanceStatus(_smoothedDistance);
          _updateDistance(_smoothedDistance, status);
          _consecutiveErrors = 0;
        } else {
          // Face detected but can't calculate distance (e.g., one eye covered)
          // Use last known good distance instead of showing "no face detected"
          if (_lastKnownGoodDistance > 0) {
            debugPrint(
              '[DistanceService] Face detected but landmarks missing - using cached distance: $_lastKnownGoodDistance cm',
            );

            // … IMPROVED: Sync smoothed distance to cached value to prevent JUMPING
            _smoothedDistance = _lastKnownGoodDistance;

            _updateDistance(
              _lastKnownGoodDistance,
              DistanceStatus.faceDetectedNoDistance,
            );
            // Don't increment errors - face IS detected
          } else {
            _updateDistance(0, DistanceStatus.noFaceDetected);
            _consecutiveErrors++;
          }
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

  // Calculate distance using interpupillary distance (IPD) or face width fallback
  double _calculateDistanceFromFace(Face face) {
    try {
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final faceWidth = face.boundingBox.width;

      // 1. Try IPD method first (most accurate)
      if (leftEye != null && rightEye != null) {
        final dx = leftEye.position.x - rightEye.position.x;
        final dy = leftEye.position.y - rightEye.position.y;
        final pixelIPD = math.sqrt(dx * dx + dy * dy);

        if (pixelIPD > 0) {
          const double focalLengthPixels = 600.0;
          final distanceCm = (_averageIPDCm * focalLengthPixels) / pixelIPD;

          // … Calibrate face-width method against this accurate IPD distance
          if (faceWidth > 0 && distanceCm > 10 && distanceCm < 300) {
            _calibrateFaceWidth(distanceCm, faceWidth);
          }

          if (distanceCm >= 10 && distanceCm <= 300) {
            return distanceCm;
          }
        }
      }

      // 2. Fallback to Face Width method if one/both eyes obscured
      if (faceWidth > 0) {
        final fallbackDistance = _calculateDistanceFromFaceWidth(faceWidth);
        if (fallbackDistance >= 10 && fallbackDistance <= 300) {
          return fallbackDistance;
        }
      }

      return -1.0;
    } catch (e) {
      debugPrint('[DistanceService] calculation error: $e');
      return -1.0;
    }
  }

  /// … NEW: Calculate distance based on face width (fallback)
  double _calculateDistanceFromFaceWidth(double faceWidthPixels) {
    if (faceWidthPixels <= 0) return -1.0;

    // Use same focal length approach
    const double focalLengthPixels = 600.0;
    double rawDistance =
        (_averageFaceWidthCm * focalLengthPixels) / faceWidthPixels;

    // Apply calibration ratio if we have one from a previous IPD reading
    if (_isFaceWidthCalibrated) {
      return rawDistance * _calibratedFaceWidthRatio;
    }

    return rawDistance;
  }

  /// … NEW: Calibrate the face-width method relative to the IPD method
  void _calibrateFaceWidth(double ipdDistance, double faceWidthPixels) {
    if (ipdDistance <= 0 || faceWidthPixels <= 0) return;

    // Calculate what the raw face width distance would be
    const double focalLengthPixels = 600.0;
    double rawFaceWidthDistance =
        (_averageFaceWidthCm * focalLengthPixels) / faceWidthPixels;

    if (rawFaceWidthDistance > 0) {
      // Store the ratio to correct future face-width estimates
      _calibratedFaceWidthRatio = ipdDistance / rawFaceWidthDistance;
      _isFaceWidthCalibrated = true;
    }
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

  DistanceStatus _getDistanceStatus(double distanceCm) {
    if (distanceCm <= 0) return DistanceStatus.noFaceDetected;

    // Use explicit bounds if provided, otherwise fallback to target +/- tolerance
    final minDistance = minDistanceCm ?? (targetDistanceCm - toleranceCm);
    final maxDistance = maxDistanceCm ?? (targetDistanceCm + toleranceCm);

    if (distanceCm < minDistance) {
      return DistanceStatus.tooClose;
    } else if (distanceCm > maxDistance) {
      return DistanceStatus.tooFar;
    } else {
      return DistanceStatus.optimal;
    }
  }

  /// Get distance stream
  Stream<Map<String, dynamic>>? get distanceStream => _streamController?.stream;

  /// Get acceptable distance range
  String get acceptableRange =>
      '${(targetDistanceCm - toleranceCm).toInt()}-${(targetDistanceCm + toleranceCm).toInt()} cm';

  /// Format distance string
  static String formatDistance(double distanceCm) {
    if (distanceCm <= 0) return 'Searching...';
    return '${distanceCm.toStringAsFixed(0)} cm';
  }

  static String getGuidanceMessage(DistanceStatus status) {
    switch (status) {
      case DistanceStatus.tooClose:
        return 'Move back - You are too close';
      case DistanceStatus.tooFar:
        return 'Move closer - You are too far';
      case DistanceStatus.optimal:
        return 'Perfect! Distance is correct';
      case DistanceStatus.noFaceDetected:
        return 'Distance search active';
      case DistanceStatus.faceDetectedNoDistance:
        return 'Continue - Using last known distance';
    }
  }

  /// Get target distance message
  static String getTargetDistanceMessage() {
    return 'Maintain 1 meter distance (about arm\'s length extended)';
  }

  /// Check if current distance is acceptable
  bool isDistanceAcceptable(double distance) {
    if (distance <= 0) return false;
    final minDistance = targetDistanceCm - toleranceCm;
    final maxDistance = targetDistanceCm + toleranceCm;
    return distance >= minDistance && distance <= maxDistance;
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
