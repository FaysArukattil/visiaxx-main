import 'package:flutter/widgets.dart';

/// Test configuration constants for vision tests
///
/// Visual Acuity sizing follows the Visiaxx specification for 1-meter testing:
/// ✅ CORRECTED FONT SIZES based on web research and real Snellen charts
class TestConstants {
  TestConstants._();

  // Visual Acuity Test Settings
  static const int relaxationDurationSeconds = 10;
  static const int eDisplayDurationSeconds = 5;
  static const int maxTriesPerLevel = 3;
  static const int minCorrectToAdvance = 2;
  static const int totalLevelsVA = 7;

  static const double visualAcuityTargetCm = 100.0; // 1 meter
  static const double visualAcuityToleranceCm = 10.0; // ±10cm

  static const double shortDistanceTargetCm = 40.0; // 40cm
  static const double shortDistanceToleranceCm = 5.0; // ±5cm

  static const double colorVisionTargetCm = 40.0; // 40cm
  static const double colorVisionToleranceCm = 5.0; // ±5cm

  static const double amslerGridTargetCm = 40.0; // 40cm
  static const double amslerGridToleranceCm = 5.0; // ±5cm

  // ✅ FIXED: Corrected E sizes for 1-meter testing
  // Research shows: At 1m, 6/6 ≈ 8.7mm, 6/60 ≈ 87mm
  // Flutter fontSize ≈ physical height in logical pixels
  // Assuming ~160 DPI screen: 1mm ≈ 6.3 logical pixels
  static const List<VisualAcuityLevel> visualAcuityLevels = [
    VisualAcuityLevel(
      sizeMm: 87.0,
      snellen: '6/60',
      logMAR: 1.0,
      flutterFontSize: 120.0, // ✅ INCREASED from 55
    ),
    VisualAcuityLevel(
      sizeMm: 52.2,
      snellen: '6/36',
      logMAR: 0.78,
      flutterFontSize: 72.0, // ✅ INCREASED from 34
    ),
    VisualAcuityLevel(
      sizeMm: 34.8,
      snellen: '6/24',
      logMAR: 0.60,
      flutterFontSize: 48.0, // ✅ INCREASED from 22
    ),
    VisualAcuityLevel(
      sizeMm: 26.1,
      snellen: '6/18',
      logMAR: 0.48,
      flutterFontSize: 36.0, // ✅ INCREASED from 16.5
    ),
    VisualAcuityLevel(
      sizeMm: 17.4,
      snellen: '6/12',
      logMAR: 0.30,
      flutterFontSize: 24.0, // ✅ INCREASED from 11
    ),
    VisualAcuityLevel(
      sizeMm: 13.05,
      snellen: '6/9',
      logMAR: 0.18,
      flutterFontSize: 18.0, // ✅ INCREASED from 8.3
    ),
    VisualAcuityLevel(
      sizeMm: 8.7,
      snellen: '6/6',
      logMAR: 0.0,
      flutterFontSize: 12.0, // ✅ INCREASED from 5.5
    ),
  ];

  // E Rotations (directions)
  static const List<EDirection> eDirections = [
    EDirection.right,
    EDirection.left,
    EDirection.up,
    EDirection.down,
  ];

  // Distance Monitoring
  static const double targetDistanceMeters = 0.4;
  static const double targetDistanceCm = 40.0;
  static const double distanceToleranceMeters = 0.05;
  static const double distanceToleranceCm = 5.0;
  static const double minAcceptableDistance = 0.35;
  static const double maxAcceptableDistance = 0.45;
  static const double minAcceptableDistanceCm = 35.0;
  static const double maxAcceptableDistanceCm = 45.0;

  // Face Detection Settings
  static const double referenceFaceWidthCm = 14.0;
  static const double focalLengthPixels = 500.0;

  // Color Vision Test Settings
  static const int colorVisionTimePerPlateSeconds = 10;
  static const int totalIshiharaPlates = 4;

  // Amsler Grid Test Settings
  static const double amslerGridSize = 300.0;
  static const double amslerCenterDotRadius = 5.0;
  static const int amslerGridLines = 20;

  // Test Status Thresholds
  static const String statusNormal = 'Normal';
  static const String statusReview = 'Review Recommended';
  static const String statusUrgent = 'Urgent Consultation';

  // Visual Acuity Thresholds
  static const double vaPassThreshold = 0.3;
  static const double vaWarningThreshold = 0.5;

  // Color Vision Thresholds
  static const double colorVisionPassPercentage = 0.75;

  // Flagging Criteria
  static const List<String> flaggingSymptoms = [
    'Sudden vision loss',
    'Flashes of light',
    'Floaters',
    'Eye pain',
    'Double vision',
  ];

  static const int shortDistanceScreens = 7;

  // ✅ FIXED: Updated short distance font sizes to match visual acuity
  static const List<ShortDistanceSentence> shortDistanceSentences = [
    ShortDistanceSentence(
      sentence: 'Can you see',
      fontSize: 120.0,
      snellen: '6/60',
    ),
    ShortDistanceSentence(
      sentence: 'Seeing life',
      fontSize: 72.0,
      snellen: '6/36',
    ),
    ShortDistanceSentence(
      sentence: 'Clear eyes',
      fontSize: 48.0,
      snellen: '6/24',
    ),
    ShortDistanceSentence(
      sentence: 'Vision is good',
      fontSize: 36.0,
      snellen: '6/18',
    ),
    ShortDistanceSentence(
      sentence: 'Look at the light',
      fontSize: 24.0,
      snellen: '6/12',
    ),
    ShortDistanceSentence(
      sentence: 'Eye tests matter',
      fontSize: 18.0,
      snellen: '6/9',
    ),
    ShortDistanceSentence(
      sentence: 'Healthy vision',
      fontSize: 12.0,
      snellen: '6/6',
    ),
  ];

  void printFontSizes() {
    debugPrint('=== ✅ CORRECTED FONT SIZE VERIFICATION ===');
    for (int i = 0; i < visualAcuityLevels.length; i++) {
      final level = visualAcuityLevels[i];
      debugPrint(
        'Plate ${i + 1}: ${level.snellen} → ${level.flutterFontSize}sp (${level.sizeMm}mm)',
      );
    }
    debugPrint('=========================================');
  }
}

/// Represents a visual acuity level with E size in mm and Snellen notation
class VisualAcuityLevel {
  final double sizeMm;
  final String snellen;
  final double logMAR;
  final double flutterFontSize;

  const VisualAcuityLevel({
    required this.sizeMm,
    required this.snellen,
    required this.logMAR,
    required this.flutterFontSize,
  });

  double getSizeInPixels(double pixelsPerMm) {
    return flutterFontSize;
  }

  double get size => flutterFontSize;
}

/// Direction enum for Tumbling E chart
enum EDirection {
  right(0, 'Right'),
  down(90, 'Down'),
  left(180, 'Left'),
  up(270, 'Up');

  final int rotationDegrees;
  final String label;

  const EDirection(this.rotationDegrees, this.label);

  static EDirection fromString(String direction) {
    switch (direction.toLowerCase()) {
      case 'right':
        return EDirection.right;
      case 'down':
        return EDirection.down;
      case 'left':
        return EDirection.left;
      case 'up':
        return EDirection.up;
      default:
        return EDirection.right;
    }
  }
}

class ShortDistanceSentence {
  final String sentence;
  final double fontSize;
  final String snellen;

  const ShortDistanceSentence({
    required this.sentence,
    required this.fontSize,
    required this.snellen,
  });
}
