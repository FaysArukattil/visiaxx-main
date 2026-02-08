import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

class ShadowDetectionService {
  static const String _tag = 'ShadowDetectionService';

  /// Analyzes an eye image to detect shadow patterns and determine Van Herick grade.
  /// Uses Isolates to prevent UI thread blocking which causes the "stuck" issue.
  Future<ShadowAnalysisResult> analyzeEyeImage(String imagePath) async {
    try {
      AppLogger.log('$_tag: Starting clinical image analysis', tag: _tag);

      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();

      // Run heavy image processing in isolate to prevent UI freeze
      final result = await compute(_analyzeImageInIsolate, bytes);

      AppLogger.log(
        '$_tag: Analysis complete. Grade: ${result.grade}',
        tag: _tag,
      );
      return result;
    } catch (e) {
      AppLogger.log(
        '$_tag: Error analyzing image: $e',
        tag: _tag,
        isError: true,
      );
      rethrow;
    }
  }

  /// Provides feedback on image quality
  Future<ImageQualityResult> checkImageQuality(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();

      // Perform quality check in isolate
      return await compute(_checkImageQualityInIsolate, bytes);
    } catch (e) {
      return ImageQualityResult(
        isGood: false,
        message: 'Error checking image quality: $e',
        brightness: 0,
        sharpness: 0,
      );
    }
  }

  // --- Static Isolate Methods ---

  static const int _processingSize = 600;

  static ShadowAnalysisResult _analyzeImageInIsolate(Uint8List bytes) {
    // Decoding
    img.Image? image;
    try {
      image = img.decodeJpg(bytes);
    } catch (_) {
      image = img.decodeImage(bytes);
    }

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Standardize size for analysis consistency
    if (image.width > _processingSize || image.height > _processingSize) {
      image = img.copyResize(
        image,
        width: _processingSize,
        height: _processingSize,
        interpolation: img.Interpolation.linear,
      );
    }

    return _detectShadowPatternSync(image);
  }

  static ImageQualityResult _checkImageQualityInIsolate(Uint8List bytes) {
    img.Image? image;
    try {
      image = img.decodeJpg(bytes);
    } catch (_) {
      image = img.decodeImage(bytes);
    }

    if (image == null) {
      return ImageQualityResult(
        isGood: false,
        message: 'Unable to process image',
        brightness: 0,
        sharpness: 0,
      );
    }

    // Resize for faster quality check
    final smallImg = img.copyResize(image, width: 256, height: 256);

    final brightness = _calculateAverageBrightnessStatic(smallImg);
    final sharpness = _calculateSharpnessStatic(smallImg);

    final isGood = brightness > 50 && brightness < 230 && sharpness > 8;
    String message = '';

    if (brightness < 50) {
      message = 'Image too dark. Please ensure flashlight is on.';
    } else if (brightness > 230) {
      message = 'Image too bright. Adjust distance slightly.';
    } else if (sharpness < 8) {
      message = 'Image not sharp enough. Hold camera steady or tap to focus.';
    } else {
      message = 'Image quality is good.';
    }

    return ImageQualityResult(
      isGood: isGood,
      message: message,
      brightness: brightness,
      sharpness: sharpness,
    );
  }

  /// The core clinical logic: Nasal vs Temporal brightness comparison
  static ShadowAnalysisResult _detectShadowPatternSync(img.Image image) {
    final grayscale = img.grayscale(image);
    final width = grayscale.width;
    final height = grayscale.height;

    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    // Iris typically occupies the middle quarter to third
    final roiRadius = width ~/ 4;

    // Temporal side (left for right eye image, assuming standard orientation)
    final temporalBrightness = _calculateRegionBrightnessStatic(
      grayscale,
      centerX - roiRadius,
      centerY - roiRadius ~/ 2,
      roiRadius ~/ 2,
      roiRadius,
    );

    // Nasal side (right for right eye image)
    final nasalBrightness = _calculateRegionBrightnessStatic(
      grayscale,
      centerX + roiRadius ~/ 2,
      centerY - roiRadius ~/ 2,
      roiRadius ~/ 2,
      roiRadius,
    );

    // shadowRatio = nasalBrightness / temporalBrightness
    // Lower ratio = darker nasal side relative to temporal = MORE shadow = Shallower Angle
    final shadowRatio = temporalBrightness > 0
        ? nasalBrightness / temporalBrightness
        : 0.0;

    final grade = _calculateGradeFromShadowRatioStatic(shadowRatio);

    return ShadowAnalysisResult(
      grade: grade,
      shadowRatio: shadowRatio,
      temporalBrightness: temporalBrightness,
      nasalBrightness: nasalBrightness,
      confidence: _calculateConfidenceStatic(shadowRatio, temporalBrightness),
    );
  }

  // --- Helper Methods ---

  static double _calculateRegionBrightnessStatic(
    img.Image image,
    int startX,
    int startY,
    int regionWidth,
    int regionHeight,
  ) {
    int totalBrightness = 0;
    int pixelCount = 0;

    final endX = (startX + regionWidth).clamp(0, image.width);
    final endY = (startY + regionHeight).clamp(0, image.height);
    final actualStartX = startX.clamp(0, image.width);
    final actualStartY = startY.clamp(0, image.height);

    for (int y = actualStartY; y < endY; y++) {
      for (int x = actualStartX; x < endX; x++) {
        final pixel = image.getPixel(x, y);
        totalBrightness += pixel.r.toInt();
        pixelCount++;
      }
    }
    return pixelCount > 0 ? totalBrightness / pixelCount : 0.0;
  }

  static int _calculateGradeFromShadowRatioStatic(double shadowRatio) {
    if (shadowRatio > 0.8) return 4;
    if (shadowRatio > 0.6) return 3;
    if (shadowRatio > 0.4) return 2;
    if (shadowRatio > 0.25) return 1;
    return 0;
  }

  static double _calculateConfidenceStatic(
    double shadowRatio,
    double baseBrightness,
  ) {
    // Low brightness reduces confidence
    double brightnessFactor = (baseBrightness / 100).clamp(0.5, 1.0);

    if (shadowRatio < 0.2 || shadowRatio > 0.9) return 0.95 * brightnessFactor;
    if (shadowRatio < 0.35 || shadowRatio > 0.75) {
      return 0.85 * brightnessFactor;
    }
    return 0.7 * brightnessFactor;
  }

  static double _calculateAverageBrightnessStatic(img.Image image) {
    int totalBrightness = 0;
    for (final pixel in image) {
      totalBrightness += pixel.r.toInt();
    }
    return totalBrightness / (image.width * image.height);
  }

  static double _calculateSharpnessStatic(img.Image image) {
    if (image.width < 3 || image.height < 3) return 0;
    int sharpnessSum = 0;
    int count = 0;
    for (int y = 1; y < image.height - 1; y += 2) {
      for (int x = 1; x < image.width - 1; x += 2) {
        final center = image.getPixel(x, y).r.toInt();
        final top = image.getPixel(x, y - 1).r.toInt();
        final bottom = image.getPixel(x, y + 1).r.toInt();
        final left = image.getPixel(x - 1, y).r.toInt();
        final right = image.getPixel(x + 1, y).r.toInt();
        sharpnessSum += (4 * center - top - bottom - left - right).abs();
        count++;
      }
    }
    return count > 0 ? sharpnessSum / count : 0;
  }
}

class ShadowAnalysisResult {
  final int grade;
  final double shadowRatio;
  final double temporalBrightness;
  final double nasalBrightness;
  final double confidence;

  ShadowAnalysisResult({
    required this.grade,
    required this.shadowRatio,
    required this.temporalBrightness,
    required this.nasalBrightness,
    required this.confidence,
  });
}

class ImageQualityResult {
  final bool isGood;
  final String message;
  final double brightness;
  final double sharpness;

  ImageQualityResult({
    required this.isGood,
    required this.message,
    required this.brightness,
    required this.sharpness,
  });
}
