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
      final width = grayscale.width;
      final height = grayscale.height;
      final centerX = width ~/ 2;
      final centerY = height ~/ 2;

      // Check 1: Central region (pupil candidate) must be DARK
      final centerBrightness = _calculateAverageBrightnessInRegion(
        grayscale,
        centerX - width ~/ 10,
        centerY - height ~/ 10,
        width ~/ 5,
        height ~/ 5,
      );

      // Typical pupil should be dark, but allow higher threshold for flash reflections (< 100 on 255 scale)
      final isCenterDark = centerBrightness < 100;

      // Check 2: Look for radial brightness gradient (dark center, brighter edges)
      final hasRadialGradient = _checkRadialBrightnessGradient(
        grayscale,
        centerX,
        centerY,
      );

      // Check 3: Look for circular pattern (pupil/iris edge) with higher threshold
      final hasCircularPattern = _detectCircularPattern(
        grayscale,
        centerX,
        centerY,
      );

      // Check 4: Check for appropriate contrast in center region
      final hasSufficientContrast = _checkCenterContrast(
        grayscale,
        centerX,
        centerY,
      );

      final passedChecks = [
        isCenterDark,
        hasRadialGradient,
        hasCircularPattern,
        hasSufficientContrast,
      ].where((v) => v).length;

      AppLogger.log(
        '$_tag: Eye validation - darkCenter: $isCenterDark, radial: $hasRadialGradient, circular: $hasCircularPattern, contrast: $hasSufficientContrast',
        tag: _tag,
      );

      // Relaxed logic: Require at least 3 out of 4 checks to pass
      // This allows for flash reflections which might make the center not "dark"
      final isValid = passedChecks >= 3;

      if (!isValid) {
        String feedback = 'No eye detected. ';
        if (!isCenterDark) {
          feedback += 'Please center your eye correctly.';
        } else {
          feedback +=
              'Please position your eye within the circle and try again.';
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

  /// Check for radial brightness gradient (dark center, brighter edges)
  bool _checkRadialBrightnessGradient(img.Image image, int cx, int cy) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final innerRadius = minDim ~/ 8; // Center region (pupil area)
    final middleRadius = minDim ~/ 4; // Middle region (iris area)
    final outerRadius = minDim ~/ 3; // Outer region (sclera area)

    final innerBrightness = _calculateCircularRegionBrightness(
      image,
      cx,
      cy,
      0,
      innerRadius,
    );
    final middleBrightness = _calculateCircularRegionBrightness(
      image,
      cx,
      cy,
      innerRadius,
      middleRadius,
    );
    final outerBrightness = _calculateCircularRegionBrightness(
      image,
      cx,
      cy,
      middleRadius,
      outerRadius,
    );

    // Eye pattern: center should be darker than outer regions
    // Allow some tolerance (center could be medium due to flash reflection)
    return innerBrightness < outerBrightness + 30 &&
        middleBrightness < outerBrightness + 20;
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
      int y = (cy - outerR).clamp(0, image.height);
      y < (cy + outerR).clamp(0, image.height);
      y++
    ) {
      for (
        int x = (cx - outerR).clamp(0, image.width);
        x < (cx + outerR).clamp(0, image.width);
        x++
      ) {
        final dx = x - cx;
        final dy = y - cy;
        final dist = (dx * dx + dy * dy);
        if (dist >= innerR * innerR && dist <= outerR * outerR) {
          total += image.getPixel(x, y).r.toInt();
          count++;
        }
      }
    }

    return count > 0 ? total / count : 0.0;
  }

  /// Detect circular patterns using edge detection on concentric rings
  bool _detectCircularPattern(img.Image image, int cx, int cy) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final searchRadius = minDim ~/ 4;

    // Sample points around circles at different radii
    int edgeCount = 0;
    const radii = [0.15, 0.25, 0.35]; // Proportions of search radius

    for (final radiusProp in radii) {
      final r = (searchRadius * radiusProp).toInt();
      if (r < 3) continue;

      const numSamples = 16;
      int localEdges = 0;

      for (int i = 0; i < numSamples; i++) {
        final angle = (i / numSamples) * 2 * 3.14159;
        final x = (cx + r * math.cos(angle)).toInt().clamp(1, image.width - 2);
        final y = (cy + r * math.sin(angle)).toInt().clamp(1, image.height - 2);

        // Simple gradient magnitude
        final left = image.getPixel(x - 1, y).r.toInt();
        final right = image.getPixel(x + 1, y).r.toInt();
        final top = image.getPixel(x, y - 1).r.toInt();
        final bottom = image.getPixel(x, y + 1).r.toInt();

        final gradient = ((right - left).abs() + (bottom - top).abs()) ~/ 2;
        if (gradient > 15) localEdges++;
      }

      // Expect at least 30% of samples to show edges for circular structure
      if (localEdges >= numSamples * 0.3) edgeCount++;
    }

    // At least 2 of 3 radii should show circular edge patterns
    return edgeCount >= 2;
  }

  /// Check for sufficient contrast in the center region
  bool _checkCenterContrast(img.Image image, int cx, int cy) {
    final minDim = (image.width < image.height ? image.width : image.height);
    final regionSize = minDim ~/ 5;

    int minVal = 255;
    int maxVal = 0;

    final startX = (cx - regionSize).clamp(0, image.width);
    final endX = (cx + regionSize).clamp(0, image.width);
    final startY = (cy - regionSize).clamp(0, image.height);
    final endY = (cy + regionSize).clamp(0, image.height);

    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final val = image.getPixel(x, y).r.toInt();
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    final contrast = maxVal - minVal;
    // Eyes typically have high contrast (pupil vs iris/sclera)
    return contrast > 80;
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
        total += image.getPixel(i, j).r.toInt();
        count++;
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
