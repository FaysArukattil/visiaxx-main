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

  TestResponseData({
    required this.round,
    required this.blurLevel,
    required this.correct,
    required this.responseTime,
    required this.direction,
    required this.userDirection,
    required this.eye,
  });

  factory TestResponseData.fromMap(Map<String, dynamic> map) {
    return TestResponseData(
      round: map['round'] as int,
      blurLevel: (map['blur'] as num).toDouble(),
      correct: map['correct'] as bool,
      responseTime: map['responseTime'] as int,
      direction: (map['direction'] as EDirection).label.toLowerCase(),
      userDirection: map['isCantSee'] == true
          ? 'cant_see'
          : (map['direction'] as EDirection).label.toLowerCase(),
      eye: map['eye'] ?? 'right',
    );
  }
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

    // Calculate distance refraction
    final distanceThreshold = _calculateThreshold(distanceData);
    final distanceAccuracy = distanceData.isEmpty
        ? 0.0
        : distanceData.where((r) => r.correct).length / distanceData.length;

    // Calculate near refraction
    final nearThreshold = _calculateThreshold(nearData);
    final nearAccuracy = nearData.isEmpty
        ? 0.0
        : nearData.where((r) => r.correct).length / nearData.length;

    // Sphere from distance vision
    double sphere = _calculateSphereFromThreshold(distanceThreshold);

    // Accommodation adjustment
    final accommodationData = _analyzeAccommodation(distanceData, age);
    final isAccommodating = accommodationData['accommodating'] as bool;
    final estimatedAccommodation =
        accommodationData['estimated_accommodation'] as double;

    if (isAccommodating) {
      sphere += estimatedAccommodation;
    }

    // Cylinder calculation
    final cylData = _calculateCylinder(distanceData);

    // ADD power for presbyopia
    double baseAdd = TestConstants.calculateAddPower(age);
    double finalAdd = _refineAddPower(baseAdd, nearAccuracy);

    // Disease screening
    final allResponses = [...distanceData, ...nearData];
    final diseaseScreening = _screenForDiseases(allResponses, age);
    // ignore: unused_local_variable
    final cantSeeCount = allResponses
        .where((r) => r.userDirection == 'cant_see')
        .length;

    // Build result
    final modelResult = MobileRefractometryEyeResult(
      eye: eye,
      sphere: _formatDiopter(sphere),
      cylinder: _formatDiopter(cylData['cylinder'] as double),
      axis: cylData['axis'] as int,
      accuracy: (distanceAccuracy * 100).toStringAsFixed(1),
      avgBlur: distanceThreshold.toStringAsFixed(2),
      addPower: _formatDiopter(finalAdd),
    );

    return AdvancedEyeResult(
      modelResult: modelResult,
      distanceThreshold: distanceThreshold,
      nearThreshold: nearThreshold,
      distanceAccuracy: distanceAccuracy,
      nearAccuracy: nearAccuracy,
      isAccommodating: isAccommodating,
      estimatedAccommodation: estimatedAccommodation,
      diseaseScreening: diseaseScreening,
      interpretation: diseaseScreening['interpretation'] as String,
      recommendation: accommodationData['recommendation'] as String,
    );
  }

  static double _calculateThreshold(List<TestResponseData> responses) {
    if (responses.isEmpty) return 0.0;

    double maxSuccessBlur = 0.0;
    double minFailBlur = TestConstants.maxBlurLevel;
    bool hadFail = false;

    for (var r in responses) {
      if (r.correct) {
        maxSuccessBlur = math.max(maxSuccessBlur, r.blurLevel);
      } else {
        minFailBlur = math.min(minFailBlur, r.blurLevel);
        hadFail = true;
      }
    }

    return hadFail ? (maxSuccessBlur + minFailBlur) / 2 : maxSuccessBlur;
  }

  static double _calculateSphereFromThreshold(double threshold) {
    if (threshold >= 6.5) return 0.00;
    if (threshold >= 6.0) return -0.25;
    if (threshold >= 5.5) return -0.50;
    if (threshold >= 5.0) return -0.75;
    if (threshold >= 4.5) return -1.00;
    if (threshold >= 4.0) return -1.25;
    if (threshold >= 3.5) return -1.50;
    if (threshold >= 3.0) return -1.75;
    if (threshold >= 2.5) return -2.00;
    if (threshold >= 2.0) return -2.50;
    if (threshold >= 1.5) return -3.00;
    if (threshold >= 1.0) return -4.00;
    return -6.00;
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
    final validResponses = responses
        .where((r) => r.userDirection != 'cant_see')
        .toList();

    final hResponses = validResponses
        .where((r) => r.direction == 'left' || r.direction == 'right')
        .toList();
    final vResponses = validResponses
        .where((r) => r.direction == 'up' || r.direction == 'down')
        .toList();

    double hAccuracy = hResponses.isEmpty
        ? 1.0
        : hResponses.where((r) => r.correct).length / hResponses.length;
    double vAccuracy = vResponses.isEmpty
        ? 1.0
        : vResponses.where((r) => r.correct).length / vResponses.length;

    double diff = (hAccuracy - vAccuracy).abs();
    double cylinder = 0.0;
    int axis = 0;

    if (diff >= 0.50) {
      cylinder = -2.00;
    } else if (diff >= 0.40) {
      cylinder = -1.50;
    } else if (diff >= 0.30) {
      cylinder = -1.00;
    } else if (diff >= 0.20) {
      cylinder = -0.75;
    } else if (diff >= 0.12) {
      cylinder = -0.50;
    } else if (diff >= 0.08) {
      cylinder = -0.25;
    }

    if (cylinder < 0) {
      axis = vAccuracy < hAccuracy ? 180 : 90;
    }

    return {'cylinder': cylinder, 'axis': axis};
  }

  static double _refineAddPower(double baseAdd, double nearAccuracy) {
    if (nearAccuracy < 0.70) return baseAdd + 0.50;
    if (nearAccuracy > 0.90) return baseAdd - 0.50;
    return baseAdd;
  }

  static Map<String, dynamic> _screenForDiseases(
    List<TestResponseData> responses,
    int age,
  ) {
    final correctCount = responses.where((r) => r.correct).length;
    final accuracy = responses.isEmpty ? 0.0 : correctCount / responses.length;
    final cantSeeCount = responses
        .where((r) => r.userDirection == 'cant_see')
        .length;

    List<Map<String, dynamic>> risks = [];
    bool critical = false;
    String interpretation = 'Normal';

    if (accuracy == 0) {
      critical = true;
      risks.add({
        'conditionName': 'No Light Perception (NLP)',
        'riskLevel': 'high',
        'confidenceScore': 0.9,
        'recommendation': 'Emergency ophthalmic consult',
      });
      interpretation = 'CRITICAL: No light perception';
    } else if (accuracy < 0.10 && cantSeeCount >= 6) {
      critical = true;
      risks.add({
        'conditionName': 'Light Perception Only (LPO)',
        'riskLevel': 'high',
        'confidenceScore': 0.85,
        'recommendation': 'Urgent ophthalmic consult',
      });
      interpretation = 'CRITICAL: Light perception only';
    } else if (age >= 50 && accuracy < 0.50) {
      risks.add({
        'conditionName': 'ARMD/Cataract',
        'riskLevel': 'medium',
        'confidenceScore': 0.7,
        'recommendation': 'Fundus and slit lamp exam',
      });
      interpretation = 'Follow-up recommended';
    }

    return {
      'criticalAlert': critical,
      'identifiedRisks': risks,
      'interpretation': interpretation,
      'severity': critical
          ? 'CRITICAL'
          : (risks.isNotEmpty ? 'MODERATE' : 'NORMAL'),
    };
  }

  static String _formatDiopter(double val) {
    return (val >= 0 ? '+' : '') + val.toStringAsFixed(2);
  }
}
