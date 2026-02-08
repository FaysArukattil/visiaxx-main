import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:torch_light/torch_light.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
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

  Timer? _searchTimer;
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

      // 2. Stop search timer
      _searchTimer?.cancel();
      _searchTimer = null;

      // 3. Stop stream if active (if any left)
      if (_controller != null && _controller!.value.isStreamingImages) {
        try {
          await _controller!.stopImageStream();
        } catch (_) {}
      }

      // 4. Dispose controller
      await _controller?.dispose();
      _controller = null;

      // 5. Close face detector (ML Kit)
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

  /// Starts a periodic capture loop to check for eyes.
  /// Much more stable than raw image stream on Android.
  void startSearchingForEyes(Function(List<Face>, Size, bool) onDetected) {
    _searchTimer?.cancel();
    _searchTimer = Timer.periodic(const Duration(milliseconds: 600), (
      timer,
    ) async {
      if (_isProcessingImage ||
          _controller == null ||
          !_controller!.value.isInitialized) {
        return;
      }

      // Check for 'taking picture' or 'closed' status
      if (_controller!.value.isTakingPicture) return;

      _isProcessingImage = true;
      try {
        final image = await _controller!.takePicture();
        final faces = await processImageFromFile(image.path);

        // Get dimensions from preview
        final size = _controller!.value.previewSize != null
            ? Size(
                _controller!.value.previewSize!.height,
                _controller!.value.previewSize!.width,
              )
            : const Size(720, 1280);

        final isIrisManual =
            faces.isEmpty && await _detectIrisManual(image.path);
        onDetected(faces, size, isIrisManual);

        // Cleanup temp file
        final file = File(image.path);
        if (await file.exists()) await file.delete();
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        final isFatal =
            errorStr.contains('camera is closed') ||
            errorStr.contains('failed to submit capture request') ||
            errorStr.contains('imagecaptureexception');

        if (isFatal) {
          AppLogger.log(
            '$_tag: Fatal camera error in search loop. Stopping timer: $e',
            tag: _tag,
          );
          stopSearchingForEyes();
        } else {
          AppLogger.log('$_tag: Transient error in search loop: $e', tag: _tag);
        }
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  void stopSearchingForEyes() {
    _searchTimer?.cancel();
    _searchTimer = null;
  }

  // Image stream processing removed due to PlatformException(InputImageConverterError)
  // on certain Android devices. Using startSearchingForEyes (takePicture) instead.

  /// Checks if detected faces contain eyes that are within a central ROI
  bool isEyeInCenter(
    List<Face> faces,
    Size imageSize, {
    bool isIrisManual = false,
  }) {
    if (isIrisManual) return true;
    if (faces.isEmpty) return false;

    final face = faces.first;
    final faceBox = face.boundingBox;
    final centerX = imageSize.width / 2;
    final centerY = imageSize.height / 2;

    // Check for eye landmarks (ML Kit provides these if FaceDetectorOptions allows)
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    AppLogger.log(
      '$_tag: Face detected at ${faceBox.center}. Size: ${faceBox.width}x${faceBox.height}. Image: $imageSize',
      tag: _tag,
    );

    // LANDMARK-FIRST LOGIC:
    // If we have eye landmarks, use them as the primary indicator.
    // We check if either eye is reasonably near the center.
    if (leftEye != null || rightEye != null) {
      final leftPos = leftEye?.position;
      final rightPos = rightEye?.position;

      final isLeftCentered =
          leftPos != null &&
          (leftPos.x.toDouble() - centerX).abs() < (imageSize.width * 0.3) &&
          (leftPos.y.toDouble() - centerY).abs() < (imageSize.height * 0.3);

      final isRightCentered =
          rightPos != null &&
          (rightPos.x.toDouble() - centerX).abs() < (imageSize.width * 0.3) &&
          (rightPos.y.toDouble() - centerY).abs() < (imageSize.height * 0.3);

      if (isLeftCentered || isRightCentered) {
        AppLogger.log('$_tag: Eye landmark detected near center', tag: _tag);
        return true;
      }
    }

    // FALLBACK LOGIC:
    // If landmarks are missing (common when very close), use the bounding box.
    // We allow the face center to be further off-center (40% tolerance)
    // because if we are zoomed in on one eye, the "face" center will be shifted.
    final isFaceMostlyCentered =
        (faceBox.center.dx - centerX).abs() < (imageSize.width * 0.4) &&
        (faceBox.center.dy - centerY).abs() < (imageSize.height * 0.4);

    final isFaceLargeEnough = faceBox.width > (imageSize.width * 0.25);

    final result = isFaceMostlyCentered && isFaceLargeEnough;
    if (result) {
      AppLogger.log('$_tag: Face detected near center (fallback)', tag: _tag);
    }
    return result;
  }

  /// Manual fallback for iris detection when face recognition fails.
  /// Decodes the image and checks if the central ROI contains a high-contrast
  /// dark region (the iris/pupil).
  Future<bool> _detectIrisManual(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final image = await compute(_checkIrisInIsolate, bytes);
      return image;
    } catch (e) {
      AppLogger.log('$_tag: Manual iris detection error: $e', tag: _tag);
      return false;
    }
  }

  /// Static helper for isolate-based iris detection.
  static bool _checkIrisInIsolate(Uint8List bytes) {
    try {
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return false;

      // Resize for fast processing
      final small = img.copyResize(image, width: 200);
      final width = small.width;
      final height = small.height;

      final centerX = width ~/ 2;
      final centerY = height ~/ 2;
      final roiSize = width ~/ 4; // 25% of width

      int darkPixels = 0;
      int totalPixels = 0;
      double totalBrightness = 0;

      // Sample center ROI
      for (int y = centerY - roiSize; y < centerY + roiSize; y++) {
        for (int x = centerX - roiSize; x < centerX + roiSize; x++) {
          if (x < 0 || x >= width || y < 0 || y >= height) continue;

          final pixel = small.getPixel(x, y);
          final luminance =
              (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toDouble();

          totalBrightness += luminance;
          if (luminance < 60) {
            // Threshold for dark pupil/iris
            darkPixels++;
          }
          totalPixels++;
        }
      }

      if (totalPixels == 0) return false;

      final avgBrightness = totalBrightness / totalPixels;
      final darkPercentage = darkPixels / totalPixels;

      // An eye in extreme close-up should have a significant dark center
      // and reasonably low average brightness compared to skin.
      // Thresholds: >15% dark pixels and <130 avg brightness.
      final isIrisPresent = darkPercentage > 0.15 && avgBrightness < 130;

      if (isIrisPresent) {
        AppLogger.log(
          'ShadowTestCameraService: Manual iris fallback detected! (Dark: ${darkPercentage.toStringAsFixed(2)}, Bright: ${avgBrightness.toStringAsFixed(0)})',
        );
      }

      return isIrisPresent;
    } catch (_) {
      return false;
    }
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
