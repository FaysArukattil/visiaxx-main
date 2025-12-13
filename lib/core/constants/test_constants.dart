/// Test configuration constants for vision tests
class TestConstants {
  TestConstants._();

  // Visual Acuity Test Settings
  static const int relaxationDurationSeconds = 10;
  static const int eDisplayDurationSeconds = 5;
  static const int maxTriesPerLevel = 3;
  static const int minCorrectToAdvance = 2;
  static const int totalLevelsVA = 11;

  // Visual Acuity E Sizes (in logical pixels, representing 20/xx vision)
  static const List<VisualAcuityLevel> visualAcuityLevels = [
    VisualAcuityLevel(size: 180.0, snellen: '20/200', logMAR: 1.0),
    VisualAcuityLevel(size: 144.0, snellen: '20/160', logMAR: 0.9),
    VisualAcuityLevel(size: 108.0, snellen: '20/120', logMAR: 0.8),
    VisualAcuityLevel(size: 90.0, snellen: '20/100', logMAR: 0.7),
    VisualAcuityLevel(size: 72.0, snellen: '20/80', logMAR: 0.6),
    VisualAcuityLevel(size: 54.0, snellen: '20/60', logMAR: 0.5),
    VisualAcuityLevel(size: 45.0, snellen: '20/50', logMAR: 0.4),
    VisualAcuityLevel(size: 36.0, snellen: '20/40', logMAR: 0.3),
    VisualAcuityLevel(size: 27.0, snellen: '20/30', logMAR: 0.2),
    VisualAcuityLevel(size: 18.0, snellen: '20/20', logMAR: 0.0),
    VisualAcuityLevel(size: 14.0, snellen: '20/15', logMAR: -0.1),
  ];

  // E Rotations (directions)
  static const List<EDirection> eDirections = [
    EDirection.right,
    EDirection.left,
    EDirection.up,
    EDirection.down,
  ];

  // Distance Monitoring (using face detection)
  static const double targetDistanceMeters = 3.0;
  static const double distanceToleranceMeters = 0.2;
  static const double minAcceptableDistance = 2.8;
  static const double maxAcceptableDistance = 3.2;

  // Face Detection Settings
  static const double referenceFaceWidthCm = 14.0; // Average human face width
  static const double focalLengthPixels = 500.0; // Camera focal length (calibrated)

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
}

/// Represents a visual acuity level with E size and Snellen notation
class VisualAcuityLevel {
  final double size;
  final String snellen;
  final double logMAR;

  const VisualAcuityLevel({
    required this.size,
    required this.snellen,
    required this.logMAR,
  });
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
