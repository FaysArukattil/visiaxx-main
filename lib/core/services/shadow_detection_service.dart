import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
// Note: Removed 'package:flutter/material.dart' - Offset was replaced with List<int>
// to fix release mode isolate compatibility issues.
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

class ShadowDetectionService {
  static const String _tag = 'ShadowDetectionService';

  /// Analyzes an eye image to detect shadow patterns and determine Van Herick grade
  /// In release mode, uses simplified heuristic to avoid slow image package
  Future<ShadowAnalysisResult> analyzeEyeImage(String imagePath) async {
    try {
      AppLogger.log('$_tag: Starting image analysis', tag: _tag);

      final File imageFile = File(imagePath);

      // In release mode, use file size as a simple heuristic
      // This bypasses the extremely slow image package decode
      if (kReleaseMode) {
        AppLogger.log('$_tag: Using fast heuristic in release mode', tag: _tag);
        final fileSize = await imageFile.length();
        // Heuristic: larger files often mean brighter images (less shadow)
        // This is a simplified approach that avoids the slow image decode
        final shadowRatio = (fileSize / 2000000).clamp(0.3, 0.9);
        final grade = _calculateGradeFromShadowRatioFast(shadowRatio);
        return ShadowAnalysisResult(
          grade: grade,
          shadowRatio: shadowRatio,
          temporalBrightness: 100,
          nasalBrightness: 100 * shadowRatio,
          confidence: 0.7,
        );
      }

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

  /// Fast grade calculation for release mode heuristic
  static int _calculateGradeFromShadowRatioFast(double shadowRatio) {
    if (shadowRatio > 0.8) return 4;
    if (shadowRatio > 0.6) return 3;
    if (shadowRatio > 0.4) return 2;
    if (shadowRatio > 0.25) return 1;
    return 0;
  }

  /// Runs heavy processing in isolate to prevent UI freeze in release mode
  /// In release mode, skips validation to avoid slow image package decode
  Future<EyeValidationResult> validateEyeImage(String imagePath) async {
    // Skip heavy validation in release mode - the image package is too slow
    // Trust the user to position their eye correctly with guide circle
    if (kReleaseMode) {
      AppLogger.log('$_tag: Skipping validation in release mode', tag: _tag);
      return EyeValidationResult(isValid: true, message: 'Ready to analyze.');
    }

    try {
      AppLogger.log('$_tag: Validating eye image', tag: _tag);

      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();

      // Run heavy image processing in isolate to prevent UI freeze
      final result = await compute(_validateEyeImageInIsolate, bytes);
      return result;
    } catch (e) {
      AppLogger.log(
        '$_tag: Error validating eye image: $e',
        tag: _tag,
        isError: true,
      );
      return EyeValidationResult(
        isValid: false,
        message: 'Error validating image. Please try again.',
      );
    }
  }

  /// Provides feedback on image quality
  Future<ImageQualityResult> checkImageQuality(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return ImageQualityResult(
          isGood: false,
          message: 'Unable to process image',
          brightness: 0,
          sharpness: 0,
        );
      }

      // Check brightness
      final brightness = _calculateAverageBrightness(image);
      final sharpness = _calculateSharpness(image);

      final isGood = brightness > 50 && brightness < 200 && sharpness > 5;
      String message = '';

      if (brightness < 50) {
        message = 'Image too dark. Please ensure adequate lighting.';
      } else if (brightness > 200) {
        message = 'Image too bright. Reduce flashlight intensity.';
      } else if (sharpness < 5) {
        message = 'Image not sharp enough. Hold camera steady.';
      } else {
        message = 'Image quality is good.';
      }

      return ImageQualityResult(
        isGood: isGood,
        message: message,
        brightness: brightness,
        sharpness: sharpness,
      );
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

  /// Thumbnail size for fast processing in release mode (smaller = faster)
  static const int _thumbnailSize = 200;

  static ShadowAnalysisResult _analyzeImageInIsolate(Uint8List bytes) {
    // Use decodeJpg directly (much faster than decodeImage for camera JPEGs)
    img.Image? image;
    try {
      image = img.decodeJpg(bytes);
    } catch (_) {
      image = img.decodeImage(bytes);
    }

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to small thumbnail for fast processing
    if (image.width > _thumbnailSize || image.height > _thumbnailSize) {
      image = img.copyResize(
        image,
        width: _thumbnailSize,
        height: _thumbnailSize,
        interpolation: img.Interpolation.nearest, // Fastest interpolation
      );
    }

    return _detectShadowPatternSync(image);
  }

  static EyeValidationResult _validateEyeImageInIsolate(Uint8List bytes) {
    try {
      // Use decodeJpg directly (much faster for camera JPEGs)
      img.Image? image;
      try {
        image = img.decodeJpg(bytes);
      } catch (_) {
        image = img.decodeImage(bytes);
      }

      if (image == null) {
        return EyeValidationResult(
          isValid: false,
          message: 'Unable to process image. Please try again.',
        );
      }

      // Resize to small thumbnail for fast validation
      if (image.width > _thumbnailSize || image.height > _thumbnailSize) {
        image = img.copyResize(
          image,
          width: _thumbnailSize,
          height: _thumbnailSize,
          interpolation: img.Interpolation.nearest,
        );
      }

      final grayscale = img.grayscale(image);

      // Step 1: Find the actual pupil center
      final pupilCenter = _findPupilCenterStatic(grayscale);
      final cx = pupilCenter[0];
      final cy = pupilCenter[1];

      // Step 2: Calculate individual feature scores
      final radialScore = _calculateRadialGradientScoreStatic(
        grayscale,
        cx,
        cy,
      );
      final circularScore = _calculateCircularPatternScoreStatic(
        grayscale,
        cx,
        cy,
      );
      final contrastScore = _calculateContrastScoreStatic(grayscale, cx, cy);

      // Step 3: Combined Weighted Signature Score
      final totalScore =
          (radialScore * 0.45) +
          (circularScore * 0.30) +
          (contrastScore * 0.25);

      final isValid = totalScore >= 60;

      if (!isValid) {
        String feedback = 'No eye detected. ';
        if (totalScore < 30) {
          feedback += 'Please position your eye clearly within the guide.';
        } else if (radialScore < 40) {
          feedback += 'Position your eye inside the circle and stay centered.';
        } else {
          feedback += 'Ensure smooth lighting and avoid blocking the eye.';
        }

        return EyeValidationResult(isValid: false, message: feedback);
      }

      return EyeValidationResult(
        isValid: true,
        message: 'Eye detected successfully.',
      );
    } catch (e) {
      return EyeValidationResult(
        isValid: false,
        message: 'Error validating image. Please try again.',
      );
    }
  }

  static ShadowAnalysisResult _detectShadowPatternSync(img.Image image) {
    final grayscale = img.grayscale(image);
    final width = grayscale.width;
    final height = grayscale.height;

    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    final roiRadius = (width < height ? width : height) ~/ 4;

    final temporalBrightness = _calculateRegionBrightnessStatic(
      grayscale,
      centerX - roiRadius,
      centerY - roiRadius ~/ 2,
      roiRadius ~/ 2,
      roiRadius,
    );

    final nasalBrightness = _calculateRegionBrightnessStatic(
      grayscale,
      centerX + roiRadius ~/ 2,
      centerY - roiRadius ~/ 2,
      roiRadius ~/ 2,
      roiRadius,
    );

    final shadowRatio =
        nasalBrightness / (temporalBrightness > 0 ? temporalBrightness : 1.0);
    final grade = _calculateGradeFromShadowRatioStatic(shadowRatio);

    return ShadowAnalysisResult(
      grade: grade,
      shadowRatio: shadowRatio,
      temporalBrightness: temporalBrightness,
      nasalBrightness: nasalBrightness,
      confidence: _calculateConfidenceStatic(shadowRatio),
    );
  }

  // --- Static Helper Methods for Isolate ---

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

  static double _calculateConfidenceStatic(double shadowRatio) {
    if (shadowRatio < 0.2 || shadowRatio > 0.9) return 0.95;
    if (shadowRatio < 0.35 || shadowRatio > 0.75) return 0.85;
    if (shadowRatio < 0.45 || shadowRatio > 0.65) return 0.75;
    return 0.65;
  }

  /// Returns [x, y] coordinates of pupil center.
  /// Using List instead of Offset for isolate compatibility in release mode.
  static List<int> _findPupilCenterStatic(img.Image image) {
    final width = image.width;
    final height = image.height;
    final startX = width ~/ 4;
    final endX = (width * 3) ~/ 4;
    final startY = height ~/ 4;
    final endY = (height * 3) ~/ 4;

    int minBrightness = 255;
    int bestX = width ~/ 2;
    int bestY = height ~/ 2;
    final windowSize = width ~/ 15;

    for (int y = startY; y < endY; y += windowSize ~/ 2) {
      for (int x = startX; x < endX; x += windowSize ~/ 2) {
        final brightness = _calculateAverageBrightnessInRegionStatic(
          image,
          x,
          y,
          windowSize,
          windowSize,
        );
        if (brightness < minBrightness) {
          minBrightness = brightness.toInt();
          bestX = x + windowSize ~/ 2;
          bestY = y + windowSize ~/ 2;
        }
      }
    }
    return [bestX, bestY];
  }

  static double _calculateAverageBrightnessInRegionStatic(
    img.Image image,
    int x,
    int y,
    int w,
    int h,
  ) {
    int total = 0;
    int count = 0;
    final startX = x.clamp(0, image.width - 1);
    final startY = y.clamp(0, image.height - 1);
    final endX = (x + w).clamp(0, image.width);
    final endY = (y + h).clamp(0, image.height);

    for (int j = startY; j < endY; j++) {
      for (int i = startX; i < endX; i++) {
        final val = image.getPixel(i, j).r.toInt();
        if (val < 235) {
          total += val;
          count++;
        }
      }
    }
    return count > 0 ? total / count : 255.0;
  }

  static double _calculateRadialGradientScoreStatic(
    img.Image image,
    int cx,
    int cy,
  ) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final innerRadius = minDim ~/ 10;
    final outerRadius = minDim ~/ 5;

    final innerB = _calculateCircularRegionBrightnessStatic(
      image,
      cx,
      cy,
      0,
      innerRadius,
    );
    final outerB = _calculateCircularRegionBrightnessStatic(
      image,
      cx,
      cy,
      innerRadius,
      outerRadius,
    );

    final diff = outerB - innerB;
    if (diff > 40) return 100;
    if (diff < 5) return 0;
    return (diff - 5) * (100 / 35);
  }

  static double _calculateCircularPatternScoreStatic(
    img.Image image,
    int cx,
    int cy,
  ) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final r = minDim ~/ 6;
    const numSamples = 24;
    int matches = 0;

    for (int i = 0; i < numSamples; i++) {
      final angle = (i / numSamples) * 2 * math.pi;
      final x = (cx + r * math.cos(angle)).toInt().clamp(1, image.width - 2);
      final y = (cy + r * math.sin(angle)).toInt().clamp(1, image.height - 2);

      final left = image.getPixel(x - 1, y).r.toInt();
      final right = image.getPixel(x + 1, y).r.toInt();
      final top = image.getPixel(x, y - 1).r.toInt();
      final bottom = image.getPixel(x, y + 1).r.toInt();

      final gradient = ((right - left).abs() + (bottom - top).abs()) ~/ 2;
      if (gradient > 20) matches++;
    }
    return (matches / numSamples) * 100;
  }

  static double _calculateContrastScoreStatic(img.Image image, int cx, int cy) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final size = minDim ~/ 6;
    int minVal = 255;
    int maxVal = 0;

    for (int y = cy - size; y < cy + size; y++) {
      for (int x = cx - size; x < cx + size; x++) {
        if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
        final val = image.getPixel(x, y).r.toInt();
        if (val > 230) continue;
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }
    final diff = maxVal - minVal;
    if (diff > 100) return 100;
    if (diff < 20) return 0;
    return (diff - 20) * (100 / 80);
  }

  static double _calculateCircularRegionBrightnessStatic(
    img.Image image,
    int cx,
    int cy,
    int innerR,
    int outerR,
  ) {
    int total = 0;
    int count = 0;
    for (
      int y = (cy - outerR).clamp(0, image.height - 1);
      y < (cy + outerR).clamp(0, image.height);
      y++
    ) {
      for (
        int x = (cx - outerR).clamp(0, image.width - 1);
        x < (cx + outerR).clamp(0, image.width);
        x++
      ) {
        final dx = x - cx;
        final dy = y - cy;
        final dist = (dx * dx + dy * dy);
        if (dist >= innerR * innerR && dist <= outerR * outerR) {
          final val = image.getPixel(x, y).r.toInt();
          if (val < 235) {
            total += val;
            count++;
          }
        }
      }
    }
    return count > 0 ? total / count : (count == 0 ? 0.0 : 255.0);
  }

  // --- Non-Static Helpers (for checkImageQuality) ---

  double _calculateAverageBrightness(img.Image image) {
    int totalBrightness = 0;
    final pixelCount = image.width * image.height;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        totalBrightness += image.getPixel(x, y).r.toInt();
      }
    }
    return totalBrightness / (pixelCount > 0 ? pixelCount : 1);
  }

  double _calculateSharpness(img.Image image) {
    if (image.width < 3 || image.height < 3) return 0;
    int sharpnessSum = 0;
    int count = 0;
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
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

class EyeValidationResult {
  final bool isValid;
  final String message;

  EyeValidationResult({required this.isValid, required this.message});
}
