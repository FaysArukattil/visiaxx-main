import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

class ShadowDetectionService {
  static const String _tag = 'ShadowDetectionService';

  /// Analyzes an eye image to detect shadow patterns and determine Van Herick grade
  Future<ShadowAnalysisResult> analyzeEyeImage(String imagePath) async {
    try {
      AppLogger.log('$_tag: Starting image analysis', tag: _tag);

      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Analyze the image for shadow patterns
      final result = await _detectShadowPattern(image);

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

  /// Detects shadow pattern in the iris area
  Future<ShadowAnalysisResult> _detectShadowPattern(img.Image image) async {
    // Convert to grayscale for easier analysis
    final grayscale = img.grayscale(image);

    // Get image dimensions
    final width = grayscale.width;
    final height = grayscale.height;

    // Define the region of interest (center area where iris typically is)
    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    final roiRadius = (width < height ? width : height) ~/ 4;

    // Analyze temporal (left) and nasal (right) sides of the iris
    final temporalBrightness = _calculateRegionBrightness(
      grayscale,
      centerX - roiRadius,
      centerY - roiRadius ~/ 2,
      roiRadius ~/ 2,
      roiRadius,
    );

    final nasalBrightness = _calculateRegionBrightness(
      grayscale,
      centerX + roiRadius ~/ 2,
      centerY - roiRadius ~/ 2,
      roiRadius ~/ 2,
      roiRadius,
    );

    // Calculate shadow ratio
    final shadowRatio =
        nasalBrightness / (temporalBrightness > 0 ? temporalBrightness : 1.0);

    // Determine grade based on shadow ratio
    final grade = _calculateGradeFromShadowRatio(shadowRatio);

    return ShadowAnalysisResult(
      grade: grade,
      shadowRatio: shadowRatio,
      temporalBrightness: temporalBrightness,
      nasalBrightness: nasalBrightness,
      confidence: _calculateConfidence(shadowRatio),
    );
  }

  /// Calculate average brightness in a specific region
  double _calculateRegionBrightness(
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
        // In the 'image' package v4+, getPixel returns a Pixel object which has r, g, b, a
        // We use red channel for grayscale comparison since we already called img.grayscale
        totalBrightness += pixel.r.toInt();
        pixelCount++;
      }
    }

    return pixelCount > 0 ? totalBrightness / pixelCount : 0.0;
  }

  /// Calculate Van Herick grade based on shadow ratio
  int _calculateGradeFromShadowRatio(double shadowRatio) {
    // shadowRatio = nasalBrightness / temporalBrightness
    // Lower ratio = darker nasal side relative to temporal = MORE shadow = Shallower Angle

    if (shadowRatio > 0.8) {
      return 4; // Wide open angle - minimal brightness difference
    } else if (shadowRatio > 0.6) {
      return 3; // Open angle
    } else if (shadowRatio > 0.4) {
      return 2; // Narrow angle
    } else if (shadowRatio > 0.25) {
      return 1; // Very narrow angle
    } else {
      return 0; // Closed angle - very high contrast/shadow
    }
  }

  /// Calculate confidence score for the analysis
  double _calculateConfidence(double shadowRatio) {
    // Higher confidence for clear distinctions
    if (shadowRatio < 0.2 || shadowRatio > 0.9) {
      return 0.95; // Very clear deep or shallow AC
    } else if (shadowRatio < 0.35 || shadowRatio > 0.75) {
      return 0.85; // Clear distinction
    } else if (shadowRatio < 0.45 || shadowRatio > 0.65) {
      return 0.75; // Moderate distinction
    } else {
      return 0.65; // Borderline case
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

  double _calculateAverageBrightness(img.Image image) {
    int totalBrightness = 0;
    final pixelCount = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        totalBrightness += pixel.r.toInt();
      }
    }

    return totalBrightness / (pixelCount > 0 ? pixelCount : 1);
  }

  double _calculateSharpness(img.Image image) {
    // Simple Laplacian-based sharpness metric
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

        final laplacian = (4 * center - top - bottom - left - right).abs();
        sharpnessSum += laplacian;
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
