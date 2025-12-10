import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../constants/test_constants.dart';

/// Distance status for visual feedback
enum DistanceStatus {
  tooClose,
  tooFar,
  optimal,
  noFaceDetected,
}

/// Distance detection service using Google ML Kit Face Detection
/// Uses face width to estimate distance from the camera
/// Configured for 1-meter testing distance as per Visiaxx specification
class DistanceDetectionService {
  final FaceDetector _faceDetector;
  CameraController? _cameraController;
  bool _isProcessing = false;
  
  // Callbacks
  Function(double distance, DistanceStatus status)? onDistanceUpdate;
  Function(String message)? onError;
  
  // Distance calculation constants
  // Average human face width is approximately 14cm
  // Using pinhole camera model: distance = (realWidth * focalLength) / pixelWidth
  static const double _averageFaceWidthCm = 14.0;
  
  // Calibrated focal length (needs calibration for accuracy)
  // This value should be calibrated per device for accurate distance
  double _focalLengthPixels = 500.0;
  
  // Target distance for vision test: 40cm as per user requirement
  static const double _targetDistanceCm = 40.0;
  static const double _toleranceCm = 5.0; // ±5cm tolerance (35-45cm acceptable)

  DistanceDetectionService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: false,
            enableClassification: false,
            enableLandmarks: false,
            enableTracking: true,
            performanceMode: FaceDetectorMode.fast,
            minFaceSize: 0.1,
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

      // Use front camera for face detection
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      
      // Calculate focal length based on camera properties
      _calibrateFocalLength();
      
      return _cameraController;
    } catch (e) {
      onError?.call('Failed to initialize camera: $e');
      return null;
    }
  }

  /// Calibrate focal length based on camera sensor info
  void _calibrateFocalLength() {
    // This is a simplified calibration
    // For production, you would need device-specific calibration
    // Default focal length works reasonably well for most devices
    if (_cameraController != null) {
      final presetSize = _cameraController!.value.previewSize;
      if (presetSize != null) {
        // Approximate focal length based on resolution
        // Higher resolution typically means higher focal length
        _focalLengthPixels = presetSize.width * 0.9;
      }
    }
  }

  /// Start continuous distance monitoring
  Future<void> startMonitoring() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      onError?.call('Camera not initialized');
      return;
    }

    await _cameraController!.startImageStream((image) {
      if (!_isProcessing) {
        _processImage(image);
      }
    });
  }

  /// Stop distance monitoring
  Future<void> stopMonitoring() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
  }

  /// Process camera image for face detection
  Future<void> _processImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        onDistanceUpdate?.call(0, DistanceStatus.noFaceDetected);
      } else {
        // Use the largest face (closest to camera)
        final largestFace = faces.reduce((a, b) =>
            a.boundingBox.width > b.boundingBox.width ? a : b);

        final distance = _calculateDistance(largestFace.boundingBox.width);
        final status = _getDistanceStatus(distance);
        
        onDistanceUpdate?.call(distance, status);
      }
    } catch (e) {
      onError?.call('Face detection error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      final rotation = InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      );

      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;
      
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance using face width
  /// Uses pinhole camera model: distance = (realWidth * focalLength) / pixelWidth
  double _calculateDistance(double faceWidthPixels) {
    if (faceWidthPixels <= 0) return 0;
    
    final distanceCm = (_averageFaceWidthCm * _focalLengthPixels) / faceWidthPixels;
    return distanceCm;
  }

  /// Get distance status based on calculated distance
  DistanceStatus _getDistanceStatus(double distanceCm) {
    final minDistance = _targetDistanceCm - _toleranceCm;
    final maxDistance = _targetDistanceCm + _toleranceCm;

    if (distanceCm < minDistance) {
      return DistanceStatus.tooClose;
    } else if (distanceCm > maxDistance) {
      return DistanceStatus.tooFar;
    } else {
      return DistanceStatus.optimal;
    }
  }

  /// Get distance in meters for display
  static double cmToMeters(double cm) => cm / 100;

  /// Get formatted distance string
  static String formatDistance(double distanceCm) {
    final meters = cmToMeters(distanceCm);
    return '${meters.toStringAsFixed(1)}m';
  }

  /// Get target distance message
  static String getTargetDistanceMessage() {
    return 'Please maintain ${TestConstants.targetDistanceMeters}m (${TestConstants.targetDistanceCm.toInt()}cm) distance';
  }

  /// Get guidance message based on status
  static String getGuidanceMessage(DistanceStatus status) {
    switch (status) {
      case DistanceStatus.tooClose:
        return 'Move back - You are too close';
      case DistanceStatus.tooFar:
        return 'Come closer - You are too far';
      case DistanceStatus.optimal:
        return 'Perfect! Distance is correct';
      case DistanceStatus.noFaceDetected:
        return 'Position your face in the camera view';
    }
  }

  /// Check if current distance is acceptable for testing
  bool isDistanceAcceptable(double distanceCm) {
    final status = _getDistanceStatus(distanceCm);
    return status == DistanceStatus.optimal;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopMonitoring();
    await _cameraController?.dispose();
    await _faceDetector.close();
  }
}
