import 'dart:io';
import 'dart:math' as math;
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

  /// Validates if the image contains an eye based on visual characteristics
  Future<EyeValidationResult> validateEyeImage(String imagePath) async {
    try {
      AppLogger.log('$_tag: Validating eye image', tag: _tag);

      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return EyeValidationResult(
          isValid: false,
          message: 'Unable to process image. Please try again.',
        );
      }

      final grayscale = img.grayscale(image);

      // Step 1: Find the actual pupil center (handles misalignment)
      final pupilCenter = _findPupilCenter(grayscale);
      final cx = pupilCenter.dx.toInt();
      final cy = pupilCenter.dy.toInt();

      AppLogger.log('$_tag: Found pupil candidate at ($cx, $cy)', tag: _tag);

      // Step 2: Calculate individual feature scores
      final radialScore = _calculateRadialGradientScore(grayscale, cx, cy);
      final circularScore = _calculateCircularPatternScore(grayscale, cx, cy);
      final contrastScore = _calculateContrastScore(grayscale, cx, cy);

      // Step 3: Combined Weighted Signature Score (Total: 100)
      // Radial Gradient is the most specific eye feature (45%)
      // Circularity indicates the iris/pupil shape (30%)
      // Contrast indicates the pupil presence (25%)
      final totalScore =
          (radialScore * 0.45) +
          (circularScore * 0.30) +
          (contrastScore * 0.25);

      AppLogger.log(
        '$_tag: Eye Signature - Radial: ${radialScore.toStringAsFixed(1)}, Circular: ${circularScore.toStringAsFixed(1)}, Contrast: ${contrastScore.toStringAsFixed(1)}, Total: ${totalScore.toStringAsFixed(1)}',
        tag: _tag,
      );

      // Threshold for acceptance: 60/100 is typically a clear eye structure
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

  /// Finds the likely center of the pupil by scanning for the darkest robust region
  Offset _findPupilCenter(img.Image image) {
    final width = image.width;
    final height = image.height;

    // Scan the central 50% of the image
    final startX = width ~/ 4;
    final endX = (width * 3) ~/ 4;
    final startY = height ~/ 4;
    final endY = (height * 3) ~/ 4;

    int minBrightness = 255;
    int bestX = width ~/ 2;
    int bestY = height ~/ 2;

    // Use a small sliding window to find the darkest cluster (pupil)
    // This ignores single pixel noise or reflections
    final windowSize = width ~/ 15;

    for (int y = startY; y < endY; y += windowSize ~/ 2) {
      for (int x = startX; x < endX; x += windowSize ~/ 2) {
        final brightness = _calculateAverageBrightnessInRegion(
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

    return Offset(bestX.toDouble(), bestY.toDouble());
  }

  /// Calculates a score (0-100) based on the dark-center-bright-outer profile
  double _calculateRadialGradientScore(img.Image image, int cx, int cy) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final innerRadius = minDim ~/ 10;
    final outerRadius = minDim ~/ 5;

    final innerB = _calculateCircularRegionBrightness(
      image,
      cx,
      cy,
      0,
      innerRadius,
    );
    final outerB = _calculateCircularRegionBrightness(
      image,
      cx,
      cy,
      innerRadius,
      outerRadius,
    );

    // Ideal eye: inner (pupil) is much darker than outer (iris/sclera)
    final diff = outerB - innerB;

    if (diff > 40) return 100;
    if (diff < 5) return 0;
    return (diff - 5) * (100 / 35);
  }

  /// Calculates a score (0-100) based on circular edge detection
  double _calculateCircularPatternScore(img.Image image, int cx, int cy) {
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
      // Circular edges of eye/iris are typically sharp
      if (gradient > 20) matches++;
    }

    return (matches / numSamples) * 100;
  }

  /// Calculates a score (0-100) based on local contrast
  double _calculateContrastScore(img.Image image, int cx, int cy) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final size = minDim ~/ 6;

    int minVal = 255;
    int maxVal = 0;

    for (int y = cy - size; y < cy + size; y++) {
      for (int x = cx - size; x < cx + size; x++) {
        if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
        final val = image.getPixel(x, y).r.toInt();
        if (val > 230) continue; // Ignore flash reflections
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    final diff = maxVal - minVal;
    if (diff > 100) return 100;
    if (diff < 20) return 0;
    return (diff - 20) * (100 / 80);
  }

  double _calculateCircularRegionBrightness(
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
          // Ignore bright flash highlights (reflections)
          if (val < 235) {
            total += val;
            count++;
          }
        }
      }
    }

    return count > 0 ? total / count : (count == 0 ? 0.0 : 255.0);
  }

  double _calculateAverageBrightnessInRegion(
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
        // Ignore highlights
        if (val < 235) {
          total += val;
          count++;
        }
      }
    }
    return count > 0 ? total / count : 255.0;
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
