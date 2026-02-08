import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:torch_light/torch_light.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../utils/app_logger.dart';

class ShadowTestCameraService {
  static const String _tag = 'ShadowTestCameraService';

  CameraController? _controller;
  bool _isFlashlightOn = false;
  List<CameraDescription>? _cameras;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableTracking: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.05,
    ),
  );

  bool _isProcessingImage = false;

  Future<void> initialize() async {
    try {
      AppLogger.log('$_tag: Initializing camera service', tag: _tag);

      // Request permissions
      final cameraPermission = await Permission.camera.request();

      if (!cameraPermission.isGranted) {
        throw Exception('Camera permission not granted');
      }

      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Find back camera
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Dispose previous controller if any to prevent hardware locks
      if (_controller != null) {
        await _controller?.dispose();
        _controller = null;
      }

      // Initialize camera controller
      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium, // Medium resolution is faster for analysis
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      AppLogger.log('$_tag: Camera initialized successfully', tag: _tag);
    } catch (e) {
      AppLogger.log(
        '$_tag: Error initializing camera: $e',
        tag: _tag,
        isError: true,
      );
      rethrow;
    }
  }

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> toggleFlashlight() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        // Use camera controller for flash if available - more reliable during active camera session
        final newMode = _isFlashlightOn ? FlashMode.off : FlashMode.torch;
        await _controller!.setFlashMode(newMode);
        _isFlashlightOn = !_isFlashlightOn;
        AppLogger.log(
          '$_tag: Flashlight toggled via camera controller: $_isFlashlightOn',
          tag: _tag,
        );
      } else {
        // Fallback to TorchLight package
        if (_isFlashlightOn) {
          await TorchLight.disableTorch();
          _isFlashlightOn = false;
        } else {
          await TorchLight.enableTorch();
          _isFlashlightOn = true;
        }
        AppLogger.log(
          '$_tag: Flashlight toggled via TorchLight: $_isFlashlightOn',
          tag: _tag,
        );
      }
    } catch (e) {
      AppLogger.log(
        '$_tag: Error toggling flashlight: $e',
        tag: _tag,
        isError: true,
      );
      // Last ditch effort: try TorchLight if camera failed, or vice versa
      try {
        if (_isFlashlightOn) {
          await TorchLight.disableTorch();
          _isFlashlightOn = false;
        } else {
          await TorchLight.enableTorch();
          _isFlashlightOn = true;
        }
      } catch (_) {}
    }
  }

  Future<void> turnOnFlashlight() async {
    if (!_isFlashlightOn) {
      await toggleFlashlight();
    }
  }

  Future<void> turnOffFlashlight() async {
    if (_isFlashlightOn) {
      await toggleFlashlight();
    }
  }

  bool get isFlashlightOn => _isFlashlightOn;

  Future<String?> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      AppLogger.log('$_tag: Camera not initialized', tag: _tag, isError: true);
      return null;
    }

    try {
      final XFile image = await _controller!.takePicture();

      // Save to app directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/shadow_test_$timestamp.jpg';

      await File(image.path).copy(filePath);

      AppLogger.log('$_tag: Image captured: $filePath', tag: _tag);
      return filePath;
    } catch (e) {
      AppLogger.log(
        '$_tag: Error capturing image: $e',
        tag: _tag,
        isError: true,
      );
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      AppLogger.log('$_tag: Disposing camera service', tag: _tag);

      // 1. Force flash off through all possible channels
      if (_controller != null && _controller!.value.isInitialized) {
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (_) {}
      }
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
      _isFlashlightOn = false;

      // 2. Stop stream if active
      if (_controller != null && _controller!.value.isStreamingImages) {
        try {
          await _controller!.stopImageStream();
        } catch (_) {}
      }

      // 3. Dispose controller
      await _controller?.dispose();
      _controller = null;

      // 4. Close face detector (ML Kit)
      await _faceDetector.close();
      AppLogger.log('$_tag: Camera service disposed successfully', tag: _tag);
    } catch (e) {
      AppLogger.log(
        '$_tag: Error during camera service disposal: $e',
        tag: _tag,
        isError: true,
      );
    }
  }

  void startImageStream(Function(List<Face>, Size) onFaceDetected) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessingImage) return;
      _isProcessingImage = true;

      try {
        final faces = await _processCameraImage(image);
        onFaceDetected(
          faces,
          Size(image.width.toDouble(), image.height.toDouble()),
        );
      } catch (e) {
        AppLogger.log(
          '$_tag: Error in image stream: $e',
          tag: _tag,
          isError: true,
        );
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  Future<List<Face>> _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageRotation = _getImageRotation();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: Platform.isAndroid
            ? InputImageFormat.yuv420
            : InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    return await _faceDetector.processImage(inputImage);
  }

  Future<List<Face>> processImageFromFile(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      AppLogger.log('$_tag: Error processing image file: $e', isError: true);
      return [];
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      await _controller!.setFlashMode(mode);
      _isFlashlightOn = mode == FlashMode.torch;
    } catch (e) {
      AppLogger.log('$_tag: Error setting flash mode: $e', isError: true);
    }
  }

  InputImageRotation _getImageRotation() {
    if (_controller == null) return InputImageRotation.rotation0deg;

    final rotation = _controller!.description.sensorOrientation;
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation90deg;
      case 90:
        return InputImageRotation.rotation180deg;
      case 180:
        return InputImageRotation.rotation270deg;
      case 270:
        return InputImageRotation.rotation0deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<bool> hasFlashlightSupport() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (e) {
      return false;
    }
  }

  // Helper method to set focus point
  Future<void> setFocusPoint(Offset point) async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.setFocusPoint(point);
        await _controller!.setExposurePoint(point);
      } catch (e) {
        AppLogger.log(
          '$_tag: Error setting focus: $e',
          tag: _tag,
          isError: true,
        );
      }
    }
  }

  // Helper method to adjust exposure
  Future<void> setExposureOffset(double offset) async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.setExposureOffset(offset);
      } catch (e) {
        AppLogger.log(
          '$_tag: Error setting exposure: $e',
          tag: _tag,
          isError: true,
        );
      }
    }
  }
}
