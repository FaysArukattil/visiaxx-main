/// Test configuration constants for vision tests
///
/// Visual Acuity sizing follows the Visiaxx specification for 1-meter testing:
/// - 6/60: 14.5mm, 6/36: 9.09mm, 6/24: 5.82mm, 6/18: 4.85mm
/// - 6/12: 2.91mm, 6/9: 2.17mm, 6/6: 1.455mm
class TestConstants {
  TestConstants._();

  // Visual Acuity Test Settings
  static const int relaxationDurationSeconds = 10;
  static const int eDisplayDurationSeconds =
      5; // 5 seconds per E as per user requirement
  static const int maxTriesPerLevel = 3;
  static const int minCorrectToAdvance = 2;
  static const int totalLevelsVA = 7; // 7 levels for quick test (6/60 to 6/6)

  // Visual Acuity E Sizes for 1-meter testing
  // sizeMm is the actual size in millimeters as per Visiaxx specification
  // The 'size' in pixels is calculated at runtime based on device pixels per mm
  static const List visualAcuityLevels = [
    VisualAcuityLevel(
      sizeMm: 14.5,
      snellen: '6/60',
      logMAR: 1.0,
      flutterFontSize: 55.0,
    ),
    VisualAcuityLevel(
      sizeMm: 9.09,
      snellen: '6/36',
      logMAR: 0.78,
      flutterFontSize: 34.0,
    ),
    VisualAcuityLevel(
      sizeMm: 5.82,
      snellen: '6/24',
      logMAR: 0.60,
      flutterFontSize: 22.0,
    ),
    VisualAcuityLevel(
      sizeMm: 4.85,
      snellen: '6/18',
      logMAR: 0.48,
      flutterFontSize: 16.5,
    ),
    VisualAcuityLevel(
      sizeMm: 2.91,
      snellen: '6/12',
      logMAR: 0.30,
      flutterFontSize: 11.0,
    ),
    VisualAcuityLevel(
      sizeMm: 2.17,
      snellen: '6/9',
      logMAR: 0.18,
      flutterFontSize: 8.3,
    ),
    VisualAcuityLevel(
      sizeMm: 1.455,
      snellen: '6/6',
      logMAR: 0.0,
      flutterFontSize: 5.5,
    ),
  ];

  // E Rotations (directions)
  static const List<EDirection> eDirections = [
    EDirection.right,
    EDirection.left,
    EDirection.up,
    EDirection.down,
  ];

  // Distance Monitoring (using face detection) - 40cm with ±5cm tolerance
  static const double targetDistanceMeters = 0.4;
  static const double targetDistanceCm = 40.0;
  static const double distanceToleranceMeters = 0.05;
  static const double distanceToleranceCm = 5.0;
  static const double minAcceptableDistance = 0.35; // 35cm
  static const double maxAcceptableDistance = 0.45; // 45cm
  static const double minAcceptableDistanceCm = 35.0;
  static const double maxAcceptableDistanceCm = 45.0;

  // Face Detection Settings
  static const double referenceFaceWidthCm = 14.0; // Average human face width
  static const double focalLengthPixels =
      500.0; // Camera focal length (calibrated)

  // Color Vision Test Settings (Quick test: 3-5 plates)
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
  static const double vaPassThreshold = 0.3; // 20/40 or better
  static const double vaWarningThreshold = 0.5; // 20/60

  // Color Vision Thresholds
  static const double colorVisionPassPercentage = 0.75; // 75% correct

  // Flagging Criteria
  static const List<String> flaggingSymptoms = [
    'Sudden vision loss',
    'Flashes of light',
    'Floaters',
    'Eye pain',
    'Double vision',
  ];
  static const double shortDistanceTargetCm = 40.0;
  static const int shortDistanceScreens = 7;

  static const List shortDistanceSentences = [
    ShortDistanceSentence(
      sentence: 'The quick brown fox jumps over the lazy dog',
      fontSize: 55.0,
      snellen: '6/60',
    ),
    ShortDistanceSentence(
      sentence: 'Vision tests help monitor eye health regularly',
      fontSize: 34.0,
      snellen: '6/36',
    ),
    ShortDistanceSentence(
      sentence: 'Clear sight is important for daily activities',
      fontSize: 22.0,
      snellen: '6/24',
    ),
    ShortDistanceSentence(
      sentence: 'Reading small text requires good visual acuity',
      fontSize: 16.5,
      snellen: '6/18',
    ),
    ShortDistanceSentence(
      sentence: 'Regular eye exams detect problems early',
      fontSize: 11.0,
      snellen: '6/12',
    ),
    ShortDistanceSentence(
      sentence: 'Sharp focus makes reading much easier',
      fontSize: 8.3,
      snellen: '6/9',
    ),
    ShortDistanceSentence(
      sentence: 'Healthy eyes see clearly at all distances',
      fontSize: 5.5,
      snellen: '6/6',
    ),
  ];

  //need to remove this function later
  void printFontSizes() {
    print('=== FONT SIZE VERIFICATION ===');
    for (int i = 0; i < visualAcuityLevels.length; i++) {
      final level = visualAcuityLevels[i];
      print(
        'Plate ${i + 1}: ${level.snellen} → ${level.flutterFontSize}sp (${level.sizeMm}mm)',
      );
    }
    print('==============================');
  }
}

/// Represents a visual acuity level with E size in mm and Snellen notation
class VisualAcuityLevel {
  final double sizeMm;
  final String snellen;
  final double logMAR;
  final double flutterFontSize; // NEW: exact Flutter font size

  const VisualAcuityLevel({
    required this.sizeMm,
    required this.snellen,
    required this.logMAR,
    required this.flutterFontSize,
  });

  // Use exact Flutter font size instead of calculation
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
