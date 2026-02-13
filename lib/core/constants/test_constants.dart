import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Test configuration constants for vision tests
///
/// Visual Acuity sizing follows the Visiaxx specification for 1-meter testing:
/// … CORRECTED FONT SIZES based on web research and real Snellen charts
class TestConstants {
  TestConstants._();

  // Visual Acuity Test Settings
  static const int relaxationDurationSeconds = 6;
  static const int eDisplayDurationSeconds = 6;
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

  // … FIXED: Corrected E sizes for 1-meter testing
  // Research shows: At 1m, 6/6 ‰ˆ 8.7mm, 6/60 ‰ˆ 87mm
  // Flutter fontSize ‰ˆ physical height in logical pixels
  // Assuming ~160 DPI screen: 1mm ‰ˆ 6.3 logical pixels
  static const List<VisualAcuityLevel> visualAcuityLevels = [
    VisualAcuityLevel(
      sizeMm: 87.0,
      snellen: '6/60',
      logMAR: 1.0,
      flutterFontSize: 120.0,
    ),
    VisualAcuityLevel(
      sizeMm: 52.2,
      snellen: '6/36',
      logMAR: 0.78,
      flutterFontSize: 72.0,
    ),
    VisualAcuityLevel(
      sizeMm: 34.8,
      snellen: '6/24',
      logMAR: 0.60,
      flutterFontSize: 48.0,
    ),
    VisualAcuityLevel(
      sizeMm: 26.1,
      snellen: '6/18',
      logMAR: 0.48,
      flutterFontSize: 36.0,
    ),
    VisualAcuityLevel(
      sizeMm: 17.4,
      snellen: '6/12',
      logMAR: 0.30,
      flutterFontSize: 24.0,
    ),
    VisualAcuityLevel(
      sizeMm: 13.05,
      snellen: '6/9',
      logMAR: 0.18,
      flutterFontSize: 18.0,
    ),
    VisualAcuityLevel(
      sizeMm: 8.7,
      snellen: '6/6',
      logMAR: 0.0,
      flutterFontSize: 12.0,
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
  static const int totalIshiharaPlates = 14;

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

  // Mobile Refractometry Test Settings
  static const int mobileRefractometryMaxRounds = 24;
  static const double mobileRefractometryDistanceCm = 100.0;
  static const double mobileRefractometryNearCm = 40.0;
  static const double mobileRefractometryToleranceCm =
      40.0; // ±40cm (optimal ~60cm)
  static const int mobileRefractometryRelaxationSeconds = 6;
  static const int mobileRefractometryTimePerRoundSeconds = 8;

  // Blur level constants for adaptive difficulty
  // Clear → Slight Blur (50% = 2.0) → Blurry (75-80% = 3.0-3.2)
  static const double initialBlurLevel = 0.0; // Start clear
  static const double minBlurLevel = 0.0;
  static const double maxBlurLevel = 4.0; // Caps at 75-80% blur
  static const double blurIncrementOnCorrect =
      0.8; // Faster progression to slight blur
  static const double blurDecrementOnWrong = 0.5; // Moderate reduction
  static const double blurDecrementOnCantSee =
      0.6; // Larger reduction for "can't see"

  // Mobile Refractometry E Size Levels (font size → Snellen score)
  static const List<MobileRefractometryLevel> mobileRefractometryLevels = [
    MobileRefractometryLevel(
      fontSize: 150.0,
      snellen: '6/60',
      description: 'Legal blindness threshold',
    ),
    MobileRefractometryLevel(
      fontSize: 120.0,
      snellen: '6/48',
      description: 'Severe visual impairment',
    ),
    MobileRefractometryLevel(
      fontSize: 100.0,
      snellen: '6/36',
      description: 'Moderate impairment',
    ),
    MobileRefractometryLevel(
      fontSize: 80.0,
      snellen: '6/24',
      description: 'Mild impairment',
    ),
    MobileRefractometryLevel(
      fontSize: 70.0,
      snellen: '6/18',
      description: 'Borderline',
    ),
    MobileRefractometryLevel(
      fontSize: 60.0,
      snellen: '6/12',
      description: 'Driving minimum',
    ),
    MobileRefractometryLevel(
      fontSize: 50.0,
      snellen: '6/9',
      description: 'Good vision',
    ),
    MobileRefractometryLevel(
      fontSize: 40.0,
      snellen: '6/6',
      description: 'Normal vision',
    ),
  ];

  /// Calculate ADD power for presbyopia based on age
  static double calculateAddPower(int age) {
    if (age < 40) return 0.00;
    if (age >= 40 && age <= 42) return 0.50; // -0.25
    if (age >= 43 && age <= 44) return 0.75; // -0.25
    if (age >= 45 && age <= 47) return 1.00; // -0.25
    if (age >= 48 && age <= 49) return 1.25; // -0.25
    if (age >= 50 && age <= 52) return 1.50; // -0.25
    if (age >= 53 && age <= 54) return 1.75; // -0.25
    if (age >= 55 && age <= 58) return 2.00; // -0.25
    if (age >= 59 && age <= 61) return 2.25; // -0.25
    if (age >= 62 && age <= 65) return 2.50; // -0.25
    return 2.75; // -0.25
  }

  // ═══════════════════════════════════════════════════════════
  // REFRACTIVE ERROR CLASSIFICATION CONSTANTS
  // ═══════════════════════════════════════════════════════════

  /// Myopia classification thresholds (in diopters)
  /// Three-tier system: Slight -> Moderate -> High
  static const double slightMyopiaMinThreshold = -0.25;
  static const double slightMyopiaMaxThreshold = -3.00;
  static const double moderateMyopiaThreshold = -3.00; // Previously "high"
  static const double moderateMyopiaMaxThreshold = -8.00;
  static const double highMyopiaThreshold = -8.00; // New severe threshold

  /// Hyperopia classification thresholds (in diopters)
  /// Three-tier system: Slight -> Moderate -> High
  static const double slightHyperopiaMinThreshold = 0.25;
  static const double slightHyperopiaMaxThreshold = 3.00;
  static const double moderateHyperopiaThreshold = 3.00; // Previously "high"
  static const double moderateHyperopiaMaxThreshold = 6.00;
  static const double highHyperopiaThreshold = 6.00; // New severe threshold

  /// Astigmatism classification thresholds (in diopters, absolute value)
  /// Three-tier system: Slight -> Moderate -> High
  static const double slightAstigmatismMinThreshold = 0.25;
  static const double slightAstigmatismMaxThreshold = 1.50;
  static const double moderateAstigmatismThreshold = 1.50; // Moderate starts
  static const double moderateAstigmatismMaxThreshold =
      2.75; // Moderate: -1.50 to -2.75
  static const double highAstigmatismThreshold =
      2.75; // High starts at >= -2.75

  /// Presbyopia age threshold
  static const int presbyopiaAgeThreshold = 40;

  // ═══════════════════════════════════════════════════════════
  // DISEASE SCREENING THRESHOLDS BASED ON VISUAL ACUITY
  // ═══════════════════════════════════════════════════════════

  /// Visual acuity thresholds for disease screening
  /// (Snellen denominator values - smaller = better vision)
  static const int vaExcellent = 6; // 6/6
  static const int vaGood = 9; // 6/9
  static const int vaNormal = 12; // 6/12
  static const int vaBorderline = 18; // 6/18
  static const int vaMildImpairment = 24; // 6/24
  static const int vaModerateImpairment = 36; // 6/36
  static const int vaSevereImpairment = 60; // 6/60

  /// Age-Related Macular Degeneration (ARMD) screening criteria
  static const int armdMinAge = 50;
  static const int armdVaThreshold = 24; // 6/24 or worse

  /// Cataract screening criteria
  static const int cataractMinAge = 55;
  static const int cataractVaThreshold = 18; // 6/18 or worse
  static const int cataractResponseTimeMs = 3500; // Slow responses

  /// Diabetic Retinopathy screening criteria
  static const int diabeticRetinopathyVaThreshold = 18; // 6/18 or worse
  static const double diabeticRetinopathyBlurThreshold = 2.5;

  /// Severe visual impairment threshold
  static const int severeImpairmentVaThreshold = 60; // 6/60 or worse

  /// Parse Snellen string to denominator value
  static int parseSnellenDenominator(String snellen) {
    // Extract denominator from formats like "6/6", "6/12", etc.
    final parts = snellen.split('/');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 60;
    }
    return 60; // Default to worst case
  }

  /// Check if visual acuity indicates potential disease
  static bool requiresUrgentReferral(String visualAcuity, int age) {
    final vaDenominator = parseSnellenDenominator(visualAcuity);

    // Critical: Severe visual impairment
    if (vaDenominator >= severeImpairmentVaThreshold) {
      return true;
    }

    // ARMD risk for older patients with moderate impairment
    if (age >= armdMinAge && vaDenominator >= armdVaThreshold) {
      return true;
    }

    return false;
  }

  // … FIXED: Updated short distance font sizes to match visual acuity
  static const List<ShortDistanceSentence> shortDistanceSentences = [
    ShortDistanceSentence(
      sentence: 'Clear vision',
      fontSize: 72.0, // … Snellen-accurate for 40cm and fits on one row
      snellen: '6/60',
    ),
    ShortDistanceSentence(
      sentence: 'I can read this text',
      fontSize: 65.0,
      snellen: '6/36',
    ),
    ShortDistanceSentence(
      sentence: 'Focus on the bright light',
      fontSize: 48.0,
      snellen: '6/24',
    ),
    ShortDistanceSentence(
      sentence: 'The sky is clear and blue',
      fontSize: 36.0,
      snellen: '6/18',
    ),
    ShortDistanceSentence(
      sentence: 'look at the light', // … Changed as requested
      fontSize: 24.0,
      snellen: '6/12',
    ),
    ShortDistanceSentence(
      sentence: 'Keep your eyes healthy',
      fontSize: 18.0,
      snellen: '6/9',
    ),
    ShortDistanceSentence(
      sentence: 'Beauty of life', // … Shortened as requested
      fontSize: 12.0,
      snellen: '6/6',
    ),
  ];

  void printFontSizes() {
    debugPrint('=== … CORRECTED FONT SIZE VERIFICATION ===');
    for (int i = 0; i < visualAcuityLevels.length; i++) {
      final level = visualAcuityLevels[i];
      debugPrint(
        'Plate ${i + 1}: ${level.snellen} †’ ${level.flutterFontSize}sp (${level.sizeMm}mm)',
      );
    }
    debugPrint('=========================================');
  }

  // ADD THESE TO YOUR EXISTING TestConstants CLASS
  // Location: lib/core/constants/test_constants.dart
  // Add at the end of the TestConstants class, before the closing brace

  // ═══════════════════════════════════════════════════════════
  // AGE-BASED TEST PROTOCOLS (24 ROUNDS EACH)
  // ═══════════════════════════════════════════════════════════

  /// Test protocol for young patients (< 40 years)
  /// Focus: Distance refractive error only - 24 rounds total
  /// Each size shown 3 times for reliability (8 sizes × 3 cycles)
  static List<TestRound> getYoungPatientProtocol() {
    return [
      // First cycle (Rounds 1-8)
      TestRound(
        fontSize: 150.0,
        testType: TestType.distance,
        difficulty: '6/60 - Very Easy',
      ),
      TestRound(
        fontSize: 120.0,
        testType: TestType.distance,
        difficulty: '6/48 - Easy',
      ),
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36 - Moderate',
      ),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24 - Medium',
      ),
      TestRound(
        fontSize: 70.0,
        testType: TestType.distance,
        difficulty: '6/18 - Medium',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12 - Challenging',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.distance,
        difficulty: '6/9 - Difficult',
      ),
      TestRound(
        fontSize: 40.0,
        testType: TestType.distance,
        difficulty: '6/6 - Very Difficult',
      ),

      // Second cycle (Rounds 9-16)
      TestRound(
        fontSize: 150.0,
        testType: TestType.distance,
        difficulty: '6/60 - Very Easy',
      ),
      TestRound(
        fontSize: 120.0,
        testType: TestType.distance,
        difficulty: '6/48 - Easy',
      ),
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36 - Moderate',
      ),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24 - Medium',
      ),
      TestRound(
        fontSize: 70.0,
        testType: TestType.distance,
        difficulty: '6/18 - Medium',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12 - Challenging',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.distance,
        difficulty: '6/9 - Difficult',
      ),
      TestRound(
        fontSize: 40.0,
        testType: TestType.distance,
        difficulty: '6/6 - Very Difficult',
      ),

      // Third cycle (Rounds 17-24)
      TestRound(
        fontSize: 150.0,
        testType: TestType.distance,
        difficulty: '6/60 - Very Easy',
      ),
      TestRound(
        fontSize: 120.0,
        testType: TestType.distance,
        difficulty: '6/48 - Easy',
      ),
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36 - Moderate',
      ),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24 - Medium',
      ),
      TestRound(
        fontSize: 70.0,
        testType: TestType.distance,
        difficulty: '6/18 - Medium',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12 - Challenging',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.distance,
        difficulty: '6/9 - Difficult',
      ),
      TestRound(
        fontSize: 40.0,
        testType: TestType.distance,
        difficulty: '6/6 - Very Difficult',
      ),
    ];
  }

  /// Test protocol for early presbyopes (40-49 years)
  /// Distance + Near testing - 24 rounds total
  static List<TestRound> getEarlyPresbyopeProtocol() {
    return [
      // Distance vision assessment (Rounds 1-8)
      TestRound(
        fontSize: 150.0,
        testType: TestType.distance,
        difficulty: '6/60',
      ),
      TestRound(
        fontSize: 120.0,
        testType: TestType.distance,
        difficulty: '6/48',
      ),
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36',
      ),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24',
      ),
      TestRound(
        fontSize: 70.0,
        testType: TestType.distance,
        difficulty: '6/18',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12',
      ),
      TestRound(fontSize: 50.0, testType: TestType.distance, difficulty: '6/9'),
      TestRound(fontSize: 40.0, testType: TestType.distance, difficulty: '6/6'),

      // Near vision assessment (Rounds 9-16)
      TestRound(
        fontSize: 70.0,
        testType: TestType.near,
        difficulty: 'N10 - Large Print',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.near,
        difficulty: 'N8 - Headlines',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.near,
        difficulty: 'N6 - Newspaper',
      ),
      TestRound(
        fontSize: 45.0,
        testType: TestType.near,
        difficulty: 'N5 - Magazine',
      ),
      TestRound(
        fontSize: 35.0,
        testType: TestType.near,
        difficulty: 'N4 - Fine Print',
      ),
      TestRound(
        fontSize: 28.0,
        testType: TestType.near,
        difficulty: 'N3 - Labels',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.near,
        difficulty: 'N8 - Recheck',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.near,
        difficulty: 'N6 - Recheck',
      ),

      // Mixed verification (Rounds 17-24)
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36',
      ),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12',
      ),
      TestRound(fontSize: 50.0, testType: TestType.distance, difficulty: '6/9'),
      TestRound(fontSize: 60.0, testType: TestType.near, difficulty: 'N8'),
      TestRound(fontSize: 50.0, testType: TestType.near, difficulty: 'N6'),
      TestRound(fontSize: 45.0, testType: TestType.near, difficulty: 'N5'),
      TestRound(fontSize: 35.0, testType: TestType.near, difficulty: 'N4'),
    ];
  }

  /// Test protocol for moderate presbyopes (50-59 years)
  /// More emphasis on near vision - 24 rounds total
  static List<TestRound> getModeratePresbyopeProtocol() {
    return [
      // Distance (Rounds 1-6)
      TestRound(
        fontSize: 150.0,
        testType: TestType.distance,
        difficulty: '6/60',
      ),
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36',
      ),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12',
      ),
      TestRound(fontSize: 50.0, testType: TestType.distance, difficulty: '6/9'),
      TestRound(fontSize: 40.0, testType: TestType.distance, difficulty: '6/6'),

      // Near (Rounds 7-18) - MORE emphasis
      TestRound(fontSize: 70.0, testType: TestType.near, difficulty: 'N10'),
      TestRound(fontSize: 60.0, testType: TestType.near, difficulty: 'N8'),
      TestRound(fontSize: 50.0, testType: TestType.near, difficulty: 'N6'),
      TestRound(fontSize: 45.0, testType: TestType.near, difficulty: 'N5'),
      TestRound(fontSize: 35.0, testType: TestType.near, difficulty: 'N4'),
      TestRound(fontSize: 28.0, testType: TestType.near, difficulty: 'N3'),
      TestRound(
        fontSize: 70.0,
        testType: TestType.near,
        difficulty: 'N10 - Cycle 2',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.near,
        difficulty: 'N8 - Cycle 2',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.near,
        difficulty: 'N6 - Cycle 2',
      ),
      TestRound(
        fontSize: 45.0,
        testType: TestType.near,
        difficulty: 'N5 - Cycle 2',
      ),
      TestRound(
        fontSize: 35.0,
        testType: TestType.near,
        difficulty: 'N4 - Cycle 2',
      ),
      TestRound(
        fontSize: 28.0,
        testType: TestType.near,
        difficulty: 'N3 - Cycle 2',
      ),

      // Mixed (Rounds 19-24)
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36',
      ),
      TestRound(fontSize: 60.0, testType: TestType.near, difficulty: 'N8'),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24',
      ),
      TestRound(fontSize: 50.0, testType: TestType.near, difficulty: 'N6'),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12',
      ),
      TestRound(fontSize: 45.0, testType: TestType.near, difficulty: 'N5'),
    ];
  }

  /// Test protocol for advanced presbyopes (60+ years)
  /// Maximum emphasis on near vision - 24 rounds total
  static List<TestRound> getAdvancedPresbyopeProtocol() {
    return [
      // Distance (Rounds 1-4)
      TestRound(
        fontSize: 120.0,
        testType: TestType.distance,
        difficulty: '6/48',
      ),
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36',
      ),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.distance,
        difficulty: '6/12',
      ),

      // Near (Rounds 5-20) - MAXIMUM emphasis
      TestRound(fontSize: 70.0, testType: TestType.near, difficulty: 'N10'),
      TestRound(fontSize: 60.0, testType: TestType.near, difficulty: 'N8'),
      TestRound(fontSize: 50.0, testType: TestType.near, difficulty: 'N6'),
      TestRound(fontSize: 45.0, testType: TestType.near, difficulty: 'N5'),
      TestRound(fontSize: 35.0, testType: TestType.near, difficulty: 'N4'),
      TestRound(fontSize: 28.0, testType: TestType.near, difficulty: 'N3'),
      TestRound(
        fontSize: 70.0,
        testType: TestType.near,
        difficulty: 'N10 - Cycle 2',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.near,
        difficulty: 'N8 - Cycle 2',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.near,
        difficulty: 'N6 - Cycle 2',
      ),
      TestRound(
        fontSize: 45.0,
        testType: TestType.near,
        difficulty: 'N5 - Cycle 2',
      ),
      TestRound(
        fontSize: 35.0,
        testType: TestType.near,
        difficulty: 'N4 - Cycle 2',
      ),
      TestRound(
        fontSize: 28.0,
        testType: TestType.near,
        difficulty: 'N3 - Cycle 2',
      ),
      TestRound(
        fontSize: 60.0,
        testType: TestType.near,
        difficulty: 'N8 - Cycle 3',
      ),
      TestRound(
        fontSize: 50.0,
        testType: TestType.near,
        difficulty: 'N6 - Cycle 3',
      ),
      TestRound(
        fontSize: 45.0,
        testType: TestType.near,
        difficulty: 'N5 - Cycle 3',
      ),
      TestRound(
        fontSize: 35.0,
        testType: TestType.near,
        difficulty: 'N4 - Cycle 3',
      ),

      // Mixed (Rounds 21-24)
      TestRound(
        fontSize: 100.0,
        testType: TestType.distance,
        difficulty: '6/36',
      ),
      TestRound(fontSize: 60.0, testType: TestType.near, difficulty: 'N8'),
      TestRound(
        fontSize: 80.0,
        testType: TestType.distance,
        difficulty: '6/24',
      ),
      TestRound(fontSize: 50.0, testType: TestType.near, difficulty: 'N6'),
    ];
  }

  /// Get test round configuration based on round number and patient age
  static SimplifiedTestRound getTestRoundConfiguration(
    int round,
    int? patientAge,
  ) {
    List<SimplifiedTestRound> protocol;

    if (patientAge == null || patientAge < 40) {
      protocol = getSimplifiedRefractometryProtocolYoung();
    } else {
      protocol = getSimplifiedRefractometryProtocolPresbyope();
    }

    // Use modulo to cycle through protocol if round exceeds length
    int index = (round - 1) % protocol.length;
    return protocol[index];
  }

  /// NEW 7-ROUND ENHANCED PROTOCOL (Legacy - for backward compatibility)
  static List<EnhancedTestRound> getMobileRefractometry7RoundProtocol() {
    return [
      EnhancedTestRound(
        snellen: '6/60',
        fontSize: 150.0,
        characters: [RefractCharacter.e],
      ),
      EnhancedTestRound(
        snellen: '6/36',
        fontSize: 120.0,
        characters: [RefractCharacter.e, RefractCharacter.c],
      ),
      EnhancedTestRound(
        snellen: '6/24',
        fontSize: 100.0,
        characters: [
          RefractCharacter.c,
          RefractCharacter.e,
          RefractCharacter.c,
        ],
      ),
      EnhancedTestRound(
        snellen: '6/18',
        fontSize: 80.0,
        characters: [
          RefractCharacter.c,
          RefractCharacter.e,
          RefractCharacter.c,
          RefractCharacter.e,
        ],
      ),
      EnhancedTestRound(
        snellen: '6/12',
        fontSize: 60.0,
        characters: [
          RefractCharacter.c,
          RefractCharacter.c,
          RefractCharacter.e,
          RefractCharacter.e,
          RefractCharacter.c,
        ],
      ),
      EnhancedTestRound(
        snellen: '6/9',
        fontSize: 50.0,
        characters: [
          RefractCharacter.e,
          RefractCharacter.c,
          RefractCharacter.e,
          RefractCharacter.c,
          RefractCharacter.c,
          RefractCharacter.e,
        ],
      ),
      EnhancedTestRound(
        snellen: '6/6',
        fontSize: 40.0,
        characters: [
          RefractCharacter.c,
          RefractCharacter.e,
          RefractCharacter.c,
          RefractCharacter.e,
          RefractCharacter.c,
          RefractCharacter.c,
          RefractCharacter.e,
        ],
      ),
    ];
  }

  /// SIMPLIFIED 14-ROUND PROTOCOL (Presbyope)
  /// Optimized for speed and engagement while maintaining clinical accuracy
  /// 7 Distance + 4 Near + 3 Mixed = 14 total rounds
  /// Ages 40+: Presbyopia detection
  static List<SimplifiedTestRound>
  getSimplifiedRefractometryProtocolPresbyope() {
    return [
      // DISTANCE TESTS (Rounds 1-7) - 100cm
      SimplifiedTestRound(
        snellen: '6/60',
        fontSize: 150.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/48',
        fontSize: 120.0,
        testType: TestType.distance,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/36',
        fontSize: 100.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/24',
        fontSize: 80.0,
        testType: TestType.distance,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/18',
        fontSize: 70.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/12',
        fontSize: 60.0,
        testType: TestType.distance,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/6',
        fontSize: 40.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),

      // NEAR TESTS (Rounds 8-14) - 40cm
      SimplifiedTestRound(
        snellen: '6/60',
        fontSize: 150.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/48',
        fontSize: 120.0,
        testType: TestType.near,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/36',
        fontSize: 100.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/24',
        fontSize: 80.0,
        testType: TestType.near,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/18',
        fontSize: 70.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/12',
        fontSize: 60.0,
        testType: TestType.near,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/6',
        fontSize: 40.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
    ];
  }

  /// SIMPLIFIED 14-ROUND PROTOCOL (Young Patient 15-40)
  /// 7 Distance (100cm) + 7 Near (40cm) = 14 total rounds
  /// Each round randomized between E and C
  static List<SimplifiedTestRound> getSimplifiedRefractometryProtocolYoung() {
    return [
      // DISTANCE TESTS (Rounds 1-7) - 100cm
      SimplifiedTestRound(
        snellen: '6/60',
        fontSize: 150.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/48',
        fontSize: 120.0,
        testType: TestType.distance,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/36',
        fontSize: 100.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/24',
        fontSize: 80.0,
        testType: TestType.distance,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/18',
        fontSize: 70.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/12',
        fontSize: 60.0,
        testType: TestType.distance,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/6',
        fontSize: 40.0,
        testType: TestType.distance,
        characterType: RefractCharacter.e,
      ),

      // NEAR TESTS (Rounds 8-14) - 40cm
      SimplifiedTestRound(
        snellen: '6/60',
        fontSize: 150.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/48',
        fontSize: 120.0,
        testType: TestType.near,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/36',
        fontSize: 100.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/24',
        fontSize: 80.0,
        testType: TestType.near,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/18',
        fontSize: 70.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
      SimplifiedTestRound(
        snellen: '6/12',
        fontSize: 60.0,
        testType: TestType.near,
        characterType: RefractCharacter.e,
      ),
      SimplifiedTestRound(
        snellen: '6/6',
        fontSize: 40.0,
        testType: TestType.near,
        characterType: RefractCharacter.c,
      ),
    ];
  }
}

// ADD THESE CLASSES AT THE END OF test_constants.dart
// After the TestConstants class closes, add these:

/// Test type for mobile refractometry
enum TestType {
  distance, // Distance vision (100cm simulation)
  near, // Near vision (40cm simulation)
}

/// Represents a single test round configuration
class TestRound {
  final double fontSize;
  final TestType testType;
  final String difficulty;

  const TestRound({
    required this.fontSize,
    required this.testType,
    required this.difficulty,
  });

  /// Get color coding for UI
  Color getTypeColor() {
    return testType == TestType.distance
        ? const Color(0xFF2196F3) // Blue for distance
        : const Color(0xFFFF9800); // Orange for near
  }

  /// Get icon for test type
  IconData getTypeIcon() {
    return testType == TestType.distance
        ? Icons.remove_red_eye
        : Icons.menu_book;
  }

  /// Get display label
  String getTypeLabel() {
    return testType == TestType.distance
        ? 'DISTANCE VISION'
        : 'NEAR VISION (Reading)';
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
  up(270, 'Up'),
  blurry(-1, 'Blurry'); // Special case: user cannot see clearly

  final int rotationDegrees;
  final String label;

  const EDirection(this.rotationDegrees, this.label);

  static EDirection fromString(String direction) {
    switch (direction.toLowerCase()) {
      case 'right':
      case 'gap right':
        return EDirection.right;
      case 'down':
      case 'gap down':
        return EDirection.down;
      case 'left':
      case 'gap left':
        return EDirection.left;
      case 'up':
      case 'gap up':
        return EDirection.up;
      case 'blurry':
      case 'blur':
      case 'cannot see':
      case 'can\'t see':
      case 'cant see':
        return EDirection.blurry;
      default:
        return EDirection.right;
    }
  }
}

/// Character type for refractometry
enum RefractCharacter {
  e('E'),
  c('C'),
  random('Random');

  final String label;
  const RefractCharacter(this.label);

  /// Get actual character label, randomizing if needed
  String getActualLabel() {
    if (this == RefractCharacter.random) {
      return math.Random().nextBool() ? 'E' : 'C';
    }
    return label;
  }
}

/// Enhanced test round with multiple characters
class EnhancedTestRound {
  final String snellen;
  final double fontSize;
  final List<RefractCharacter> characters;

  const EnhancedTestRound({
    required this.snellen,
    required this.fontSize,
    required this.characters,
  });
}

/// Simplified test round with single character per round
/// Used for the new 11-round protocol with randomized directions
class SimplifiedTestRound {
  final String snellen;
  final double fontSize;
  final TestType testType;
  final RefractCharacter characterType;

  const SimplifiedTestRound({
    required this.snellen,
    required this.fontSize,
    required this.testType,
    required this.characterType,
  });

  /// Generate random direction for this round
  EDirection getRandomDirection() {
    final random = math.Random();
    final directions = [
      EDirection.up,
      EDirection.down,
      EDirection.left,
      EDirection.right,
    ];
    return directions[random.nextInt(directions.length)];
  }

  /// Get color coding for UI
  Color getTypeColor() {
    return testType == TestType.distance
        ? const Color(0xFF2196F3) // Blue for distance
        : const Color(0xFFFF9800); // Orange for near
  }

  /// Get icon for test type
  IconData getTypeIcon() {
    return testType == TestType.distance
        ? Icons.remove_red_eye
        : Icons.menu_book;
  }

  /// Get display label
  String getTypeLabel() {
    return testType == TestType.distance
        ? 'DISTANCE VISION'
        : 'NEAR VISION (Reading)';
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

/// Represents a Mobile Refractometry E size level with Snellen notation
class MobileRefractometryLevel {
  final double fontSize;
  final String snellen;
  final String description;

  const MobileRefractometryLevel({
    required this.fontSize,
    required this.snellen,
    required this.description,
  });
}
