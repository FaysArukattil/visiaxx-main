/// Test configuration constants for vision tests
/// 
/// Visual Acuity sizing follows the Visiaxx specification for 1-meter testing:
/// - 6/60: 14.5mm, 6/36: 9.09mm, 6/24: 5.82mm, 6/18: 4.85mm
/// - 6/12: 2.91mm, 6/9: 2.17mm, 6/6: 1.455mm
class TestConstants {
  TestConstants._();

  // Visual Acuity Test Settings
  static const int relaxationDurationSeconds = 10;
  static const int eDisplayDurationSeconds = 5; // 5 seconds per E as per user requirement
  static const int maxTriesPerLevel = 3;
  static const int minCorrectToAdvance = 2;
  static const int totalLevelsVA = 7; // 7 levels for quick test (6/60 to 6/6)

  // Visual Acuity E Sizes for 1-meter testing
  // sizeMm is the actual size in millimeters as per Visiaxx specification
  // The 'size' in pixels is calculated at runtime based on device pixels per mm
  static const List<VisualAcuityLevel> visualAcuityLevels = [
    VisualAcuityLevel(sizeMm: 14.5, snellen: '6/60', logMAR: 1.0),   // Largest
    VisualAcuityLevel(sizeMm: 9.09, snellen: '6/36', logMAR: 0.78),
    VisualAcuityLevel(sizeMm: 5.82, snellen: '6/24', logMAR: 0.60),
    VisualAcuityLevel(sizeMm: 4.85, snellen: '6/18', logMAR: 0.48),
    VisualAcuityLevel(sizeMm: 2.91, snellen: '6/12', logMAR: 0.30),
    VisualAcuityLevel(sizeMm: 2.17, snellen: '6/9', logMAR: 0.18),
    VisualAcuityLevel(sizeMm: 1.455, snellen: '6/6', logMAR: 0.0),  // Smallest (normal vision)
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
  static const double focalLengthPixels = 500.0; // Camera focal length (calibrated)

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
}

/// Represents a visual acuity level with E size in mm and Snellen notation
class VisualAcuityLevel {
  /// Size of the E in millimeters (physical size at 1 meter)
  final double sizeMm;
  final String snellen;
  final double logMAR;

  const VisualAcuityLevel({
    required this.sizeMm,
    required this.snellen,
    required this.logMAR,
  });

  /// Calculate the size in logical pixels based on device pixels per mm
  /// pixelsPerMm should be calculated as: MediaQuery.of(context).devicePixelRatio * 
  /// (MediaQuery.of(context).size.width / devicePhysicalWidthMm)
  /// A reasonable default for most phones is approximately 6-8 pixels per mm
  double getSizeInPixels(double pixelsPerMm) {
    return sizeMm * pixelsPerMm;
  }

  /// Legacy getter for backward compatibility - uses default pixels per mm
  double get size => sizeMm * 6.0; // Default ~6 pixels per mm for most devices
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
