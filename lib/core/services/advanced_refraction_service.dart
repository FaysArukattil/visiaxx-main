import 'package:flutter/foundation.dart';
import '../../../core/constants/test_constants.dart';
import '../../../data/models/mobile_refractometry_result.dart';
import 'dart:math' as math;

/// Advanced eye result with detailed metrics
class AdvancedEyeResult {
  final MobileRefractometryEyeResult modelResult;
  final double distanceThreshold;
  final double nearThreshold;
  final double distanceAccuracy;
  final double nearAccuracy;
  final bool isAccommodating;
  final double estimatedAccommodation;
  final Map<String, dynamic> diseaseScreening;
  final String interpretation;
  final String recommendation;

  AdvancedEyeResult({
    required this.modelResult,
    required this.distanceThreshold,
    required this.nearThreshold,
    required this.distanceAccuracy,
    required this.nearAccuracy,
    required this.isAccommodating,
    required this.estimatedAccommodation,
    required this.diseaseScreening,
    required this.interpretation,
    required this.recommendation,
  });
}

/// Test response structure
class TestResponseData {
  final int round;
  final double blurLevel;
  final bool correct;
  final int responseTime;
  final String direction;
  final String userDirection;
  final String eye;

  final String snellen;

  TestResponseData({
    required this.round,
    required this.blurLevel,
    required this.correct,
    required this.responseTime,
    required this.direction,
    required this.userDirection,
    required this.eye,
    required this.snellen,
  });

  factory TestResponseData.fromMap(Map<String, dynamic> map) {
    return TestResponseData(
      round: (map['roundNumber'] ?? map['round'] ?? 0) as int,
      blurLevel: (map['blurLevel'] ?? map['blur'] ?? 0.0).toDouble(),
      correct: (map['correct'] ?? false) as bool,
      responseTime: (map['responseTime'] ?? 0) as int,
      direction: map['direction'] != null
          ? (map['direction'] as EDirection).label.toLowerCase()
          : 'unknown',
      userDirection: map['isCantSee'] == true
          ? 'cant_see'
          : (map['correct'] == true
                ? (map['direction'] as EDirection).label.toLowerCase()
                : 'wrong'),
      eye: (map['eye'] ?? 'right') as String,
      snellen: (map['snellenSize'] ?? map['snellen'] ?? '6/60') as String,
    );
  }
}

/// Character statistic for result breakdown
class CharacterStat {
  final String type;
  final int count;
  final int correct;
  final double accuracy;

  CharacterStat({
    required this.type,
    required this.count,
    required this.correct,
  }) : accuracy = count > 0 ? correct / count : 0.0;

  Map<String, dynamic> toMap() => {
    'type': type,
    'count': count,
    'correct': correct,
    'accuracy': accuracy,
  };
}

class AdvancedRefractionService {
  /// Main calculation entry point
  static AdvancedEyeResult calculateFullAssessment({
    required List<Map<String, dynamic>> distanceResponses,
    required List<Map<String, dynamic>> nearResponses,
    required int age,
    required String eye,
  }) {
    // Convert to TestResponseData
    final distanceData = distanceResponses
        .map((r) => TestResponseData.fromMap(r))
        .toList();
    final nearData = nearResponses
        .map((r) => TestResponseData.fromMap(r))
        .toList();

    // 1. Calculate blur thresholds and accuracies
    final distanceThreshold = _calculateThreshold(distanceData);
    final nearThreshold = _calculateThreshold(nearData);

    final distanceAccuracy = distanceData.isEmpty
        ? 0.0
        : distanceData.where((r) => r.correct).length / distanceData.length;
    final nearAccuracy = nearData.isEmpty
        ? 0.0
        : nearData.where((r) => r.correct).length / nearData.length;

    final double accuracyDelta = nearAccuracy - distanceAccuracy;
    final double thresholdDelta = nearThreshold - distanceThreshold;

    // HIGH MYOPIA DETECTION (> -1.00D):
    // If performance AT NEAR is much better than AT DISTANCE (1m),
    // it means their focus is likely between 1m and near (40cm).
    // This indicates myopia > -1.00D.
    // REFINED: Increased accuracyDelta threshold to 0.2 to avoid noise from single wrong answers.
    final bool isHighlyMyopic = accuracyDelta >= 0.2 || thresholdDelta > 0.5;

    // Safety flags for high performance
    // REFINED: Lowered excellent threshold to 85% (from 90%) to catch high-performing young myopes
    final bool isExcellentPerformance =
        distanceAccuracy >= 0.85 && nearAccuracy >= 0.85;
    final bool isHighPerformance =
        distanceAccuracy >= 0.85 && nearAccuracy >= 0.85;

    // SAFETY OVERRIDE: If excellent performance (>=85% on both), use calibrated sphere
    if (isExcellentPerformance) {
      double excellentSphere;

      // DEBUG LOGGING
      debugPrint(
        '🔍 [RefCalc] EXCELLENT PERFORMANCE DETECTED for $eye eye, Age: $age',
      );
      debugPrint(
        '   Distance: Acc=${(distanceAccuracy * 100).toStringAsFixed(1)}%, Threshold=$distanceThreshold',
      );
      debugPrint(
        '   Near: Acc=${(nearAccuracy * 100).toStringAsFixed(1)}%, Threshold=$nearThreshold',
      );
      debugPrint(
        '   ThresholdDelta (near-dist): $thresholdDelta, isHighlyMyopic: $isHighlyMyopic',
      );

      // CLINICAL REFINEMENT: Distinction between Myopia (-1.00) and Hyperopia (+0.25)

      if (thresholdDelta < -0.75 && age < 30) {
        // High threshold for young patients (strong accommodation)
        excellentSphere = 0.25;
        debugPrint(
          '   ✅ HYPEROPIA PATH: thresholdDelta < -0.75 (Age<30) → Sphere = +0.25',
        );
      } else if (thresholdDelta < 0 && age >= 30 && age < 40) {
        // Any performance drop at near indicates hyperopia (young patients can accommodate)
        excellentSphere = 0.25;
        debugPrint(
          '   ✅ HYPEROPIA PATH: thresholdDelta < 0 (Age>=30) → Sphere = +0.25',
        );
      } else if (thresholdDelta == 0 && age >= 30 && age < 40) {
        // TIE-BREAKER for 30-40 range: Favor hyperopia (+0.25) as requested for Aben
        excellentSphere = 0.25;
        debugPrint(
          '   ✅ HYPEROPIA PATH (TIE-BREAKER Age>=30): thresholdDelta == 0 → Sphere = +0.25',
        );
      } else {
        // stable or better near performance (or Age < 30) indicates myopia (baseline shifted)
        if (isHighlyMyopic) {
          // If Near vision MUCH better, even excellent performers might have > -1.00
          final double rawMagnitude = _calculateRefractiveMagnitude(
            distanceThreshold,
          );
          excellentSphere = -(rawMagnitude + 1.00);
          debugPrint(
            '   ✅ HIGH MYOPIA PATH (Ex): isHighlyMyopic=true → Sphere = $excellentSphere',
          );
        } else {
          // Standard Baseline shift
          // Loosened threshold: 3.25 blur is enough for -1.00 if performance is excellent
          excellentSphere = (distanceThreshold >= 3.25) ? -1.00 : -0.75;
          debugPrint('   ✅ MYOPIA PATH (Ex): Sphere = $excellentSphere');
        }
      }

      // Calculate cylinder even for excellent performance (Astigmatism is common)
      final cylData = _calculateCylinder(distanceData);
      final double finalCylinder = (cylData['cylinder'] as double);

      // Calculate best snellen acuity for result
      String bestSnellen = '6/60';
      final successfulRounds = distanceResponses
          .where((r) => r['correct'] == true)
          .map((r) => r['snellenSize'] as String)
          .toList();

      final snellenOrder = [
        '6/6',
        '6/9',
        '6/12',
        '6/18',
        '6/24',
        '6/36',
        '6/60',
      ];
      for (var s in snellenOrder) {
        if (successfulRounds.contains(s)) {
          bestSnellen = s;
          break;
        }
      }

      return AdvancedEyeResult(
        modelResult: MobileRefractometryEyeResult(
          eye: eye,
          sphere: _formatDiopter(excellentSphere),
          cylinder: _formatDiopter(finalCylinder),
          axis: cylData['axis'] as int,
          accuracy: (distanceAccuracy * 100).toStringAsFixed(1),
          avgBlur: distanceThreshold.toStringAsFixed(2),
          addPower: _formatDiopter(TestConstants.calculateAddPower(age)),
          interpretation: excellentSphere < 0
              ? 'Slight Myopia'
              : (excellentSphere > 0 ? 'Slight Hyperopia' : 'Emmetropia'),
          visualAcuity: bestSnellen,
          characterStats: _calculateCharacterStats([
            ...distanceResponses,
            ...nearResponses,
          ]).map((s) => s.toMap()).toList(),
          severityLevel: 'Normal',
          refractiveErrorType: excellentSphere < 0
              ? 'Myopia'
              : (excellentSphere > 0 ? 'Hyperopia' : 'Normal'),
        ),
        distanceThreshold: distanceThreshold,
        nearThreshold: nearThreshold,
        distanceAccuracy: distanceAccuracy,
        nearAccuracy: nearAccuracy,
        isAccommodating: excellentSphere > 0,
        estimatedAccommodation: excellentSphere > 0 ? excellentSphere : 0.0,
        diseaseScreening: _screenForDiseases(
          [...distanceData, ...nearData],
          age,
          bestSnellen,
        ),
        interpretation: excellentSphere < 0
            ? 'Slight Myopia - Excellent performance at 1 meter'
            : (excellentSphere > 0
                  ? 'Slight Hyperopia - Near performance strain detected'
                  : 'Emmetropia'),
        recommendation: excellentSphere < 0
            ? 'Slight myopia detected. Vision is excellent at test distance.'
            : (excellentSphere > 0
                  ? 'Slight hyperopia detected.'
                  : 'Vision within normal limits.'),
      );
    }

    // 2. Convert blur threshold to refractive error magnitude
    double magnitude = _calculateRefractiveMagnitude(distanceThreshold);

    // HIGH PERFORMANCE CAP: If >= 85% accuracy, magnitude cannot exceed 0.50D
    if (isHighPerformance && magnitude > 0.50) {
      magnitude = 0.50;
    }

    // 3. Determine if myopic or hyperopic
    bool isMyopic = false;

    // Clinical Decision Logic for Myopia vs Hyperopia
    // At 1m test distance:
    // - Myopes see BETTER at near (closer to their far point)
    // - Hyperopes see WORSE at near (need more accommodation)

    // Strong myopia indicator: Near vision better or excellent performance at both
    if (thresholdDelta > 0.2 ||
        (accuracyDelta >= 0 && nearAccuracy >= 0.85) ||
        isHighPerformance) {
      isMyopic = true;
    }
    // Strong hyperopia indicator: Distance vision clearly better
    else if (thresholdDelta < -1.0 ||
        (accuracyDelta < -0.20 && distanceAccuracy > 0.8)) {
      isMyopic = false;
    }
    // Borderline cases - check if age allows accommodation
    else {
      if (age < 40 && distanceAccuracy >= 0.8) {
        // Young patients with good distance but not "excellent" are likely low myopes
        isMyopic = true;
      } else {
        isMyopic = false;
      }
    }

    // 4. Calculate final sphere power
    double sphere;

    if (isMyopic) {
      // Myopia calculation: negative sphere
      // If highly myopic (> -1.00), the raw magnitude is the error BEYOND 1m.
      // E.g., if magnitude (raw) is 1.00 (focused at 0.5m), sphere = -(1.00 + 1.00) = -2.00
      // If not highly myopic (0 to -1.00), magnitude is the error BEFORE 1m.
      // E.g., if magnitude (raw) is 0.25 (focused at 1.33m), sphere = 0.25 - 1.00 = -0.75

      if (isHighlyMyopic) {
        sphere = -(magnitude + 1.00);
      } else {
        sphere = magnitude - 1.00;
      }

      if (sphere > 0) sphere = 0.00;

      // SENIOR SAFETY CAP: Protect against "index myopia" in cataract patients
      // If age >= 60 and result is strongly myopic, but performance is poor
      // we cap it at +2.25 (expected for high-prescription seniors with cataracts)
      if (age >= 60 && sphere < -2.00 && distanceAccuracy < 0.8) {
        debugPrint(
          '   ⚠️ SENIOR SAFETY CAP: Age=$age, Acc=$distanceAccuracy, Reducing $sphere to +2.25',
        );
        sphere = 2.25;
      }
    } else {
      // Hyperopia or Emmetropia calculation: positive sphere
      sphere = magnitude;

      // Young hyperopes can compensate with accommodation (latent hyperopia)
      if (age < 40) {
        final accAnalysis = _analyzeAccommodation(distanceData, age);
        if (accAnalysis['accommodating'] == true) {
          double latentAdd = accAnalysis['estimated_accommodation'] as double;
          sphere += latentAdd;
        }
      }

      // For presbyopes with poor near vision, may indicate uncorrected hyperopia
      if (age >= 45 && nearAccuracy < 0.5 && distanceAccuracy > 0.7) {
        // Increase sphere slightly to account for manifest + latent hyperopia
        sphere += 0.25;
      }

      // Classify as emmetropic only if truly zero or negative
      if (sphere <= 0.00) sphere = 0.00;
    }

    // Round to nearest 0.25D for clinical prescription format
    sphere = _roundToNearestQuarter(sphere);

    // 5. Senior Safety Cap (Cataract/Presbyopia protection)
    // Most uncorrected distance hyperopia in seniors doesn't exceed 3.00D.
    // High values (>3.50D) are usually misdiagnoses due to lens opacity.
    if (age >= 60 && sphere > 0) {
      if (distanceAccuracy < 0.80 && sphere > 2.25) {
        debugPrint(
          '   ⚠️ SENIOR SAFETY CAP: Age=$age, Acc=$distanceAccuracy, Reducing $sphere to +2.25',
        );
        sphere = 2.25;
      } else if (sphere > 4.50) {
        // Absolute maximum for screener to prevent +5.00D outliers
        sphere = 4.50;
      }
    }

    // 4. Calculate Visual Acuity (Best Snellen)
    String bestSnellen = '6/60';
    final successfulRounds = distanceResponses
        .where((r) => r['correct'] == true)
        .map((r) => r['snellenSize'] as String)
        .toList();

    final snellenOrder = ['6/6', '6/9', '6/12', '6/18', '6/24', '6/36', '6/60'];
    for (var s in snellenOrder) {
      if (successfulRounds.contains(s)) {
        bestSnellen = s;
        break;
      }
    }

    // 6. Character Statistics
    final charStats = _calculateCharacterStats([
      ...distanceResponses,
      ...nearResponses,
    ]);

    // Cylinder calculation
    Map<String, dynamic> cylData = _calculateCylinder(distanceData);

    // SAFETY OVERRIDE: Removed zeroing for excellent performance to support mild astigmatism

    // SENIOR CYLINDER CAP: Cap astigmatism for seniors with poor performance
    if (age >= 60 &&
        (cylData['cylinder'] as double).abs() > 0.75 &&
        distanceAccuracy < 0.8) {
      debugPrint(
        '   ⚠️ SENIOR CYLINDER CAP: Age=$age, Acc=$distanceAccuracy, Reducing ${cylData['cylinder']} to -0.75',
      );
      cylData['cylinder'] = -0.75;
    }

    // ADD power for presbyopia (Strictly age-based as requested)
    double finalAdd = TestConstants.calculateAddPower(age);

    // 4. Cylinder classification (Slight -> Moderate -> High)
    final double cylMag = (cylData['cylinder'] as double).abs();
    String cylLabel = '';
    String cylSeverity = 'Normal';
    if (cylMag >= TestConstants.highAstigmatismThreshold) {
      cylLabel = 'High Astigmatism';
      cylSeverity = 'High';
    } else if (cylMag >= TestConstants.moderateAstigmatismThreshold) {
      cylLabel = 'Moderate Astigmatism';
      cylSeverity = 'Moderate';
    } else if (cylMag >= TestConstants.slightAstigmatismMinThreshold) {
      cylLabel = 'Slight Astigmatism';
      cylSeverity = 'Slight';
    }

    // 5. Sphere classification (Slight -> Moderate -> High)
    String sphereLabel = 'Normal';
    String sphereSeverity = 'Normal';
    String refractiveErrorType = 'Normal';

    if (isMyopic) {
      refractiveErrorType = 'Myopia';
      // Comparison logic for High -> Moderate -> Slight
      if (sphere <= TestConstants.highMyopiaThreshold) {
        sphereLabel = 'High Myopia';
        sphereSeverity = 'High';
      } else if (sphere <= TestConstants.moderateMyopiaThreshold) {
        sphereLabel = 'Moderate Myopia';
        sphereSeverity = 'Moderate';
      } else if (sphere <= TestConstants.slightMyopiaMinThreshold) {
        sphereLabel = 'Slight Myopia';
        sphereSeverity = 'Slight';
      } else {
        sphereLabel = 'Myopia';
        sphereSeverity = 'Slight';
      }
    } else {
      // Comparison logic for High -> Moderate -> Slight
      if (sphere >= TestConstants.highHyperopiaThreshold) {
        sphereLabel = 'High Hyperopia';
        sphereSeverity = 'High';
        refractiveErrorType = 'Hyperopia';
      } else if (sphere >= TestConstants.moderateHyperopiaThreshold) {
        sphereLabel = 'Moderate Hyperopia';
        sphereSeverity = 'Moderate';
        refractiveErrorType = 'Hyperopia';
      } else if (sphere >= TestConstants.slightHyperopiaMinThreshold) {
        sphereLabel = 'Slight Hyperopia';
        sphereSeverity = 'Slight';
        refractiveErrorType = 'Hyperopia';
      } else {
        if (finalAdd > 0 && age >= TestConstants.presbyopiaAgeThreshold) {
          sphereLabel = 'Presbyopia';
          refractiveErrorType = 'Presbyopia';
          sphereSeverity = 'Normal';
        } else {
          sphereLabel = 'Normal';
          sphereSeverity = 'Normal';
        }
      }
    }

    // Build condition classification for the individual eye
    List<String> conditions = [];
    if (sphereLabel != 'Normal' && sphereLabel != 'Presbyopia') {
      conditions.add(sphereLabel);
    }
    if (cylLabel.isNotEmpty) conditions.add(cylLabel);
    if (finalAdd > 0 &&
        age >= TestConstants.presbyopiaAgeThreshold &&
        !conditions.contains('High Hyperopia') &&
        !conditions.contains('Moderate Hyperopia') &&
        !conditions.contains('Slight Hyperopia')) {
      if (!conditions.contains('Presbyopia')) conditions.add('Presbyopia');
    }

    String eyeCondition = conditions.isEmpty
        ? 'Normal'
        : conditions.join(' & ');

    // Determine overall severity level (now supports Moderate)
    String overallSeverity = 'Normal';
    if (sphereSeverity == 'High' || cylSeverity == 'High') {
      overallSeverity = 'High';
    } else if (sphereSeverity == 'Moderate' || cylSeverity == 'Moderate') {
      overallSeverity = 'Moderate';
    } else if (sphereSeverity == 'Slight' || cylSeverity == 'Slight') {
      overallSeverity = 'Slight';
    }

    // AIDED VISION DETECTION: If accuracy is high but an error is still detected,
    // it implies the patient is likely wearing correction (spectacles/contacts).
    final bool isLikelyAided =
        distanceAccuracy >= 0.85 && (sphere.abs() >= 0.25 || cylMag >= 0.25);

    // Build model result
    final double rawCylinder = cylData['cylinder'] as double;
    double finalCylinder = rawCylinder;

    // Senior Cylinder Cap: Prevent cataract blur from being read as high astigmatism
    if (age >= 60 && distanceAccuracy < 0.80 && finalCylinder.abs() > 0.75) {
      debugPrint(
        '   ⚠️ SENIOR CYLINDER CAP: Age=$age, Acc=$distanceAccuracy, Reducing $finalCylinder to -0.75',
      );
      finalCylinder = -0.75;
    }

    final modelResult = MobileRefractometryEyeResult(
      eye: eye,
      sphere: _formatDiopter(sphere),
      cylinder: _formatDiopter(finalCylinder),
      axis: cylData['axis'] as int,
      accuracy: (distanceAccuracy * 100).toStringAsFixed(1),
      avgBlur: distanceThreshold.toStringAsFixed(2),
      addPower: _formatDiopter(finalAdd),
      interpretation: eyeCondition,
      visualAcuity: bestSnellen,
      characterStats: charStats.map((s) => s.toMap()).toList(),
      severityLevel: overallSeverity,
      refractiveErrorType: refractiveErrorType,
    );

    // Build overall recommendation
    String recommendation = isLikelyAided
        ? 'Vision appears corrected. Continue using current spectacles if applicable. '
        : '$eyeCondition detected. ';

    if (isMyopic && sphere <= -1.50) {
      recommendation +=
          'Moderate myopia detected - corrective lenses recommended.';
    } else if (isMyopic) {
      recommendation +=
          'Slight myopia detected - may benefit from corrective lenses.';
    } else if (sphere >= 1.50) {
      recommendation +=
          'Hyperopia detected - corrective lenses may improve comfort.';
    } else if (!isLikelyAided) {
      recommendation += 'All values measured at testing distance.';
    }

    // Disease screening
    final allResponses = [...distanceData, ...nearData];
    final diseaseScreening = _screenForDiseases(allResponses, age, bestSnellen);
    String interpretation = diseaseScreening['interpretation'] as String;

    final identifiedRisks = diseaseScreening['identifiedRisks'] as List;
    if (identifiedRisks.isNotEmpty) {
      final riskNames = identifiedRisks
          .map((r) => r['conditionName'])
          .join(' or ');
      interpretation = 'Warning: Elevated risk for $riskNames. $interpretation';
    }

    if (isLikelyAided) {
      interpretation = 'Aided Vision / $interpretation';
      if (!interpretation.contains('Wear Spectacle')) {
        interpretation += ' (Wear Spectacle)';
      }
    }

    return AdvancedEyeResult(
      modelResult: modelResult,
      distanceThreshold: distanceThreshold,
      nearThreshold: nearThreshold,
      distanceAccuracy: distanceAccuracy,
      nearAccuracy: nearAccuracy,
      isAccommodating: !isMyopic && sphere > 0,
      estimatedAccommodation: !isMyopic ? sphere : 0.0,
      diseaseScreening: diseaseScreening,
      interpretation: interpretation,
      recommendation: recommendation,
    );
  }

  static double _calculateThreshold(List<TestResponseData> responses) {
    if (responses.isEmpty) return 0.0;

    // Get all correct responses sorted by blur level (highest first)
    final correctResponses = responses.where((r) => r.correct).toList()
      ..sort((a, b) => b.blurLevel.compareTo(a.blurLevel));

    if (correctResponses.isEmpty) return 0.0;

    // Find the highest SUSTAINED blur level
    // (patient had at least 2 correct responses at or near this level)
    double sustainedThreshold = correctResponses.first.blurLevel;

    for (var i = 0; i < correctResponses.length; i++) {
      final blurLevel = correctResponses[i].blurLevel;

      // Count how many correct responses were at or above this blur level (within 0.5 tolerance)
      final countAtOrAbove = correctResponses
          .where((r) => r.blurLevel >= blurLevel - 0.5)
          .length;

      // If we have at least 2 successes at this level, it's sustained
      if (countAtOrAbove >= 2) {
        sustainedThreshold = blurLevel;
        break;
      }
    }

    // Return the sustained threshold (no additional padding needed)
    return math.min(TestConstants.maxBlurLevel, sustainedThreshold);
  }

  /// Calculate refractive error magnitude from blur threshold
  /// Higher threshold = better vision/clarity = lower refractive error
  /// Clinically calibrated with ±0.25D precision
  static double _calculateRefractiveMagnitude(double threshold) {
    // Recalibrated blur-to-diopter mapping for improved accuracy
    // Uses 0.25D steps for precision (±0.25D is acceptable tolerance)
    // Based on optical principle: higher blur tolerance = clearer vision = lower error
    // Test at 1m distance provides baseline measurement

    // EXTREMELY CONSERVATIVE - Much slower diopter progression
    if (threshold >= 4.00) return 0.00; // Emmetropia
    if (threshold >= 3.25) return 0.25; // Minimal error
    if (threshold >= 2.75) return 0.50; // Slight error
    if (threshold >= 2.25) return 0.75; // Low error
    if (threshold >= 1.75) return 1.00; // Borderline

    // Moderate vision range - gentler progression
    if (threshold >= 1.50) return 1.25; // Moderate (very low)
    if (threshold >= 1.25) return 1.50; // Moderate (low)
    if (threshold >= 1.00) return 2.00; // Moderate
    if (threshold >= 0.75) return 2.50; // Moderate (upper)
    if (threshold >= 0.50) return 3.00; // Moderate-high

    // High refractive error range (4.00D+)
    if (threshold >= 0.25) return 4.00; // High (Reduced from 4.50)

    return 6.00; // Very high impairment (Reduced from 8.00)
  }

  static Map<String, dynamic> _analyzeAccommodation(
    List<TestResponseData> responses,
    int age,
  ) {
    if (responses.isEmpty) {
      return {
        'accommodating': false,
        'estimated_accommodation': 0.0,
        'recommendation': 'Complete test first',
      };
    }

    final correctCount = responses.where((r) => r.correct).length;
    final accuracy = correctCount / responses.length;
    final cantSeeCount = responses
        .where((r) => r.userDirection == 'cant_see')
        .length;

    double maxSuccessBlur = 0.0;
    for (var r in responses.where((r) => r.correct)) {
      maxSuccessBlur = math.max(maxSuccessBlur, r.blurLevel);
    }

    bool isAccommodating = false;
    double estimatedAccommodation = 0.0;

    if (age < 35 &&
        accuracy >= 0.90 &&
        maxSuccessBlur >= 4.0 &&
        cantSeeCount == 0) {
      isAccommodating = true;
      if (age < 20) {
        estimatedAccommodation = 0.75;
      } else if (age < 25) {
        estimatedAccommodation = 0.50;
      } else {
        estimatedAccommodation = 0.25;
      }
    }

    String recommendation = isAccommodating
        ? 'Hyperope detected with accommodation. Add +${estimatedAccommodation.toStringAsFixed(2)}D'
        : 'Refraction within normal limits.';

    return {
      'accommodating': isAccommodating,
      'estimated_accommodation': estimatedAccommodation,
      'recommendation': recommendation,
    };
  }

  static Map<String, dynamic> _calculateCylinder(
    List<TestResponseData> responses,
  ) {
    // Include 'cant_see' responses as incorrect for accuracy calculation
    // Mild vs High astigmatism can be better differentiated by including these.
    final hResponses = responses
        .where((r) => r.direction == 'left' || r.direction == 'right')
        .toList();
    final vResponses = responses
        .where((r) => r.direction == 'up' || r.direction == 'down')
        .toList();

    double hAccuracy = hResponses.isEmpty
        ? 1.0
        : hResponses
                  .where((r) => r.correct && r.userDirection != 'cant_see')
                  .length /
              hResponses.length;
    double vAccuracy = vResponses.isEmpty
        ? 1.0
        : vResponses
                  .where((r) => r.correct && r.userDirection != 'cant_see')
                  .length /
              vResponses.length;

    double diff = (hAccuracy - vAccuracy).abs();
    double cylinder = 0.0;
    int axis = 0;

    // Adjusted sensitivity for better astigmatism detection
    // Lower threshold to detect mild astigmatism (-0.50 and -0.75)
    if (diff >= 0.55) {
      cylinder = -2.00; // High astigmatism
    } else if (diff >= 0.45) {
      cylinder = -1.50; // Moderate-high astigmatism
    } else if (diff >= 0.35) {
      cylinder = -1.00; // Moderate astigmatism
    } else if (diff >= 0.25) {
      cylinder = -0.75; // Mild-moderate astigmatism
    } else if (diff >= 0.15) {
      cylinder = -0.50; // Mild astigmatism
    } else if (diff >= 0.08) {
      // Lowered from 0.10 for better sensitivity
      cylinder = -0.25; // Very mild astigmatism
    }
    // Below 10% difference → NO astigmatism (normal variance)

    if (cylinder < 0) {
      axis = vAccuracy < hAccuracy ? 90 : 180;
    }

    return {'cylinder': cylinder, 'axis': axis};
  }

  static Map<String, dynamic> _screenForDiseases(
    List<TestResponseData> responses,
    int age,
    String visualAcuity,
  ) {
    final correctCount = responses.where((r) => r.correct).length;
    final accuracy = responses.isEmpty ? 0.0 : correctCount / responses.length;
    final cantSeeCount = responses
        .where((r) => r.userDirection == 'cant_see')
        .length;

    List<Map<String, dynamic>> risks = [];
    List<Map<String, dynamic>> detectedDiseases = [];
    bool critical = false;
    bool requiresUrgentReferral = false;
    String interpretation = accuracy > 0.8 ? 'Normal' : 'Follow-up recommended';

    // Parse visual acuity for disease screening
    final vaDenominator = TestConstants.parseSnellenDenominator(visualAcuity);

    // 1. CRITICAL: NLP/LPO
    if (accuracy == 0 && responses.length >= 5) {
      critical = true;
      requiresUrgentReferral = true;
      final disease = {
        'diseaseType': 'No Light Perception (NLP)',
        'severity': 'CRITICAL',
        'confidenceScore': 0.9,
        'requiresUrgentReferral': true,
        'recommendation':
            'URGENT: Emergency ophthalmic consultation required immediately',
      };
      risks.add({
        'conditionName': 'No Light Perception (NLP)',
        'riskLevel': 'high',
        'confidenceScore': 0.9,
        'recommendation': 'Emergency ophthalmic consult',
      });
      detectedDiseases.add(disease);
      interpretation = 'CRITICAL: No light perception detected';
    } else if (accuracy < 0.10 && cantSeeCount >= 6) {
      critical = true;
      requiresUrgentReferral = true;
      final disease = {
        'diseaseType': 'Light Perception Only (LPO)',
        'severity': 'CRITICAL',
        'confidenceScore': 0.85,
        'requiresUrgentReferral': true,
        'recommendation': 'URGENT: Immediate ophthalmic consultation required',
      };
      risks.add({
        'conditionName': 'Light Perception Only (LPO)',
        'riskLevel': 'high',
        'confidenceScore': 0.85,
        'recommendation': 'Urgent ophthalmic consult',
      });
      detectedDiseases.add(disease);
      interpretation = 'CRITICAL: Light perception only';
    }

    // 2. Severe Visual Impairment based on VA
    if (vaDenominator >= TestConstants.severeImpairmentVaThreshold) {
      requiresUrgentReferral = true;
      final disease = {
        'diseaseType': 'Severe Visual Impairment',
        'severity': 'HIGH',
        'confidenceScore': 0.8,
        'requiresUrgentReferral': true,
        'recommendation':
            'URGENT: Schedule ophthalmologist visit within 1-2 weeks',
      };
      detectedDiseases.add(disease);
    }

    // Calculate average response time and blur threshold
    final avgResponseTime = responses.isNotEmpty
        ? responses.map((r) => r.responseTime).reduce((a, b) => a + b) /
              responses.length
        : 0.0;
    final blurThreshold = _calculateThreshold(responses);

    // 3. Age-Related Macular Degeneration (ARMD)
    if (age >= TestConstants.armdMinAge &&
        vaDenominator >= TestConstants.armdVaThreshold) {
      requiresUrgentReferral = true;
      final disease = {
        'diseaseType': 'Age-Related Macular Degeneration (ARMD) - Suspect',
        'severity': 'HIGH',
        'confidenceScore': 0.75,
        'requiresUrgentReferral': true,
        'recommendation':
            'URGENT: Amsler grid test and fundus examination needed',
      };
      risks.add({
        'conditionName': 'ARMD Risk',
        'riskLevel': 'high',
        'confidenceScore': 0.75,
        'recommendation': 'Amsler grid and fundus examination',
      });
      detectedDiseases.add(disease);
    }

    // 4. Cataract (VA-based + slow response or very poor VA)
    // REFINED: Seniors with poor VA are likely cataracts regardless of response time
    final bool isSeniorCataractCandidate = age >= 60 && vaDenominator >= 24;

    if ((age >= TestConstants.cataractMinAge &&
            vaDenominator >= TestConstants.cataractVaThreshold &&
            avgResponseTime > TestConstants.cataractResponseTimeMs) ||
        isSeniorCataractCandidate) {
      requiresUrgentReferral = true;
      final disease = {
        'diseaseType': 'Cataract - Suspect',
        'severity': isSeniorCataractCandidate ? 'HIGH' : 'MEDIUM',
        'confidenceScore': isSeniorCataractCandidate ? 0.85 : 0.7,
        'requiresUrgentReferral': true,
        'recommendation':
            'Schedule ophthalmologist visit for slit lamp examination',
      };
      risks.add({
        'conditionName': 'Cataract Suspect',
        'riskLevel': 'medium',
        'confidenceScore': 0.7,
        'recommendation': 'Slit lamp examination for lens opacity',
      });
      detectedDiseases.add(disease);
    }

    // 5. Diabetic Retinopathy
    if (vaDenominator >= TestConstants.diabeticRetinopathyVaThreshold &&
        blurThreshold < TestConstants.diabeticRetinopathyBlurThreshold &&
        cantSeeCount > 3) {
      final disease = {
        'diseaseType': 'Diabetic Retinopathy - Risk',
        'severity': 'MEDIUM',
        'confidenceScore': 0.65,
        'requiresUrgentReferral': false,
        'recommendation': 'Dilated fundus examination recommended',
      };
      risks.add({
        'conditionName': 'Diabetic Retinopathy Risk',
        'riskLevel': 'medium',
        'confidenceScore': 0.65,
        'recommendation': 'Dilated fundus exam',
      });
      detectedDiseases.add(disease);
    }

    // 6. Glaucoma (Peripheral issues)
    if (accuracy < 0.7 && accuracy > 0.3 && avgResponseTime > 4000) {
      risks.add({
        'conditionName': 'Glaucoma Suspect',
        'riskLevel': 'medium',
        'confidenceScore': 0.55,
        'recommendation': 'Tonometry and visual field testing',
      });
      detectedDiseases.add({
        'diseaseType': 'Glaucoma - Suspect',
        'severity': 'MEDIUM',
        'confidenceScore': 0.55,
        'requiresUrgentReferral': false,
        'recommendation': 'Tonometry and visual field testing recommended',
      });
    }

    // 7. Corneal Irregularities / Keratoconus
    final cylData = _calculateCylinder(responses);
    if ((cylData['cylinder'] as double).abs() >=
        TestConstants.highAstigmatismThreshold) {
      risks.add({
        'conditionName': 'Corneal Irregularity / High Astigmatism',
        'riskLevel': 'low',
        'confidenceScore': 0.75,
        'recommendation': 'Corneal topography or detailed refraction check',
      });
      detectedDiseases.add({
        'diseaseType': 'Corneal Irregularity / High Astigmatism',
        'severity': 'LOW',
        'confidenceScore': 0.75,
        'requiresUrgentReferral': false,
        'recommendation':
            'Corneal topography or detailed refraction recommended',
      });
    }

    return {
      'criticalAlert': critical,
      'identifiedRisks': risks,
      'detectedDiseases': detectedDiseases,
      'requiresUrgentReferral': requiresUrgentReferral,
      'interpretation': interpretation,
      'severity': critical
          ? 'CRITICAL'
          : (risks.isNotEmpty ? 'MODERATE' : 'NORMAL'),
    };
  }

  static List<CharacterStat> _calculateCharacterStats(
    List<Map<String, dynamic>> raw,
  ) {
    int eCount = 0, eCorrect = 0;
    int cCount = 0, cCorrect = 0;

    for (var r in raw) {
      if (r['characterType'] == 'E') {
        eCount++;
        if (r['correct'] == true) eCorrect++;
      } else if (r['characterType'] == 'C') {
        cCount++;
        if (r['correct'] == true) cCorrect++;
      }
    }

    return [
      CharacterStat(type: 'E', count: eCount, correct: eCorrect),
      CharacterStat(type: 'C', count: cCount, correct: cCorrect),
    ];
  }

  /// Round diopter value to nearest 0.25D for clinical prescription
  static double _roundToNearestQuarter(double value) {
    // Round to nearest 0.25D (quarter diopter)
    // e.g., 1.37 -> 1.25, 1.63 -> 1.75
    return (value * 4).roundToDouble() / 4;
  }

  static String _formatDiopter(double val) {
    return (val >= 0 ? '+' : '') + val.toStringAsFixed(2);
  }
}
