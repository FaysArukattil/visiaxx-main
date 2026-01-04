/// Pelli-Robson Contrast Sensitivity Test Result Model
/// Clinical-grade contrast sensitivity measurement
library;

/// Individual triplet response during the test
class TripletResponse {
  final String tripletCode; // e.g., 'VRS', 'KDR'
  final double logCSValue; // e.g., 1.10, 1.15
  final String expectedLetters; // e.g., 'VRS'
  final String heardLetters; // What was recognized from speech
  final int correctLetters; // 0-3
  final int responseTimeMs;
  final bool wasAutoAdvanced; // True if timed out

  const TripletResponse({
    required this.tripletCode,
    required this.logCSValue,
    required this.expectedLetters,
    required this.heardLetters,
    required this.correctLetters,
    required this.responseTimeMs,
    this.wasAutoAdvanced = false,
  });

  bool get isFullyCorrect => correctLetters == 3;

  Map<String, dynamic> toMap() => {
    'tripletCode': tripletCode,
    'logCSValue': logCSValue,
    'expectedLetters': expectedLetters,
    'heardLetters': heardLetters,
    'correctLetters': correctLetters,
    'responseTimeMs': responseTimeMs,
    'wasAutoAdvanced': wasAutoAdvanced,
  };

  factory TripletResponse.fromMap(Map<String, dynamic> map) => TripletResponse(
    tripletCode: map['tripletCode'] ?? '',
    logCSValue: (map['logCSValue'] ?? 0.0).toDouble(),
    expectedLetters: map['expectedLetters'] ?? '',
    heardLetters: map['heardLetters'] ?? '',
    correctLetters: map['correctLetters'] ?? 0,
    responseTimeMs: map['responseTimeMs'] ?? 0,
    wasAutoAdvanced: map['wasAutoAdvanced'] ?? false,
  );
}

/// Result for a single Pelli-Robson test (one distance mode)
class PelliRobsonSingleResult {
  final String testMode; // 'short' (40cm) or 'long' (1m)
  final String
  lastFullTriplet; // Last triplet where all 3 correct (e.g., 'CDN')
  final int correctInNextTriplet; // 0-3 correct letters in next triplet
  final double uncorrectedScore; // Raw log CS score
  final double adjustedScore; // After distance adjustment (-0.15 for short)
  final String category; // 'Excellent', 'Normal', 'Borderline', 'Reduced'
  final List<TripletResponse> tripletResponses;
  final int durationSeconds;

  const PelliRobsonSingleResult({
    required this.testMode,
    required this.lastFullTriplet,
    required this.correctInNextTriplet,
    required this.uncorrectedScore,
    required this.adjustedScore,
    required this.category,
    required this.tripletResponses,
    required this.durationSeconds,
  });

  /// User-friendly explanation of the score
  String get explanation {
    switch (category) {
      case 'Excellent':
        return 'Your contrast sensitivity is excellent (${adjustedScore.toStringAsFixed(2)} log CS). '
            'You can distinguish very subtle differences in shading.';
      case 'Normal':
        return 'Your contrast sensitivity is normal (${adjustedScore.toStringAsFixed(2)} log CS). '
            'You can see well in most lighting conditions.';
      case 'Borderline':
        return 'Your contrast sensitivity shows early impairment (${adjustedScore.toStringAsFixed(2)} log CS). '
            'You may have difficulty in low light or foggy conditions.';
      case 'Reduced':
      default:
        return 'Your contrast sensitivity is reduced (${adjustedScore.toStringAsFixed(2)} log CS). '
            'This may affect daily activities like driving or reading. Please consult an eye care professional.';
    }
  }

  /// Professional clinical summary
  String get clinicalSummary =>
      'Pelli-Robson CS (${testMode == 'short' ? '40cm' : '1m'}): '
      '${adjustedScore.toStringAsFixed(2)} log CS ($category). '
      'Last full triplet: $lastFullTriplet, +$correctInNextTriplet/3 in next.';

  Map<String, dynamic> toMap() => {
    'testMode': testMode,
    'lastFullTriplet': lastFullTriplet,
    'correctInNextTriplet': correctInNextTriplet,
    'uncorrectedScore': uncorrectedScore,
    'adjustedScore': adjustedScore,
    'category': category,
    'tripletResponses': tripletResponses.map((r) => r.toMap()).toList(),
    'durationSeconds': durationSeconds,
  };

  factory PelliRobsonSingleResult.fromMap(Map<String, dynamic> map) {
    return PelliRobsonSingleResult(
      testMode: map['testMode'] ?? 'short',
      lastFullTriplet: map['lastFullTriplet'] ?? '',
      correctInNextTriplet: map['correctInNextTriplet'] ?? 0,
      uncorrectedScore: (map['uncorrectedScore'] ?? 0.0).toDouble(),
      adjustedScore: (map['adjustedScore'] ?? 0.0).toDouble(),
      category: map['category'] ?? 'Reduced',
      tripletResponses:
          (map['tripletResponses'] as List<dynamic>?)
              ?.map((r) => TripletResponse.fromMap(r))
              .toList() ??
          [],
      durationSeconds: map['durationSeconds'] ?? 0,
    );
  }
}

/// Complete Pelli-Robson result with both distance tests for a single eye
class PelliRobsonEyeResult {
  final PelliRobsonSingleResult? shortDistance; // 40cm test
  final PelliRobsonSingleResult? longDistance; // 1m test

  const PelliRobsonEyeResult({this.shortDistance, this.longDistance});

  Map<String, dynamic> toMap() => {
    'shortDistance': shortDistance?.toMap(),
    'longDistance': longDistance?.toMap(),
  };

  factory PelliRobsonEyeResult.fromMap(Map<String, dynamic> map) {
    return PelliRobsonEyeResult(
      shortDistance: map['shortDistance'] != null
          ? PelliRobsonSingleResult.fromMap(map['shortDistance'])
          : null,
      longDistance: map['longDistance'] != null
          ? PelliRobsonSingleResult.fromMap(map['longDistance'])
          : null,
    );
  }
}

/// Complete Pelli-Robson result with per-eye tests
class PelliRobsonResult {
  final PelliRobsonEyeResult? rightEye;
  final PelliRobsonEyeResult? leftEye;
  final PelliRobsonEyeResult? bothEyes;

  // Legacy support for older tests (Both eyes only)
  final PelliRobsonSingleResult? shortDistance;
  final PelliRobsonSingleResult? longDistance;

  final DateTime timestamp;

  const PelliRobsonResult({
    this.rightEye,
    this.leftEye,
    this.bothEyes,
    this.shortDistance,
    this.longDistance,
    required this.timestamp,
  });

  /// Combined category based on all results (worst case)
  String get overallCategory {
    final categories = ['Excellent', 'Normal', 'Borderline', 'Reduced'];
    int worstIdx = 0;

    void updateWorst(PelliRobsonSingleResult? res) {
      if (res != null) {
        final idx = categories.indexOf(res.category);
        if (idx > worstIdx) worstIdx = idx;
      }
    }

    updateWorst(rightEye?.shortDistance);
    updateWorst(rightEye?.longDistance);
    updateWorst(leftEye?.shortDistance);
    updateWorst(leftEye?.longDistance);
    updateWorst(bothEyes?.shortDistance);
    updateWorst(bothEyes?.longDistance);

    // Legacy check
    updateWorst(shortDistance);
    updateWorst(longDistance);

    return categories[worstIdx];
  }

  /// Overall score (average of all available adjusted scores)
  double get averageScore {
    int count = 0;
    double sum = 0;

    void addScore(PelliRobsonSingleResult? res) {
      if (res != null) {
        sum += res.adjustedScore;
        count++;
      }
    }

    addScore(rightEye?.shortDistance);
    addScore(rightEye?.longDistance);
    addScore(leftEye?.shortDistance);
    addScore(leftEye?.longDistance);
    addScore(bothEyes?.shortDistance);
    addScore(bothEyes?.longDistance);

    // Legacy check
    addScore(shortDistance);
    addScore(longDistance);

    return count > 0 ? sum / count : 0;
  }

  /// User-friendly overall summary
  String get userSummary {
    if (overallCategory == 'Excellent' || overallCategory == 'Normal') {
      return 'Your contrast sensitivity is $overallCategory. '
          'You can distinguish subtle shading differences effectively.';
    } else if (overallCategory == 'Borderline') {
      return 'Your contrast sensitivity shows early impairment. '
          'Consider having a comprehensive eye exam.';
    } else {
      return 'Your contrast sensitivity is reduced. '
          'Please consult an eye care professional for further evaluation.';
    }
  }

  /// Clinical summary for professionals
  String get clinicalSummary {
    final buffer = StringBuffer('Pelli-Robson Contrast Sensitivity:\n');

    if (rightEye != null) {
      buffer.writeln(
        '• Right Eye: Near ${rightEye?.shortDistance?.adjustedScore.toStringAsFixed(2)}, Distance ${rightEye?.longDistance?.adjustedScore.toStringAsFixed(2)}',
      );
    }
    if (leftEye != null) {
      buffer.writeln(
        '• Left Eye: Near ${leftEye?.shortDistance?.adjustedScore.toStringAsFixed(2)}, Distance ${leftEye?.longDistance?.adjustedScore.toStringAsFixed(2)}',
      );
    }
    if (bothEyes != null) {
      buffer.writeln(
        '• Both Eyes: Near ${bothEyes?.shortDistance?.adjustedScore.toStringAsFixed(2)}, Distance ${bothEyes?.longDistance?.adjustedScore.toStringAsFixed(2)}',
      );
    }

    return buffer.toString().trim();
  }

  /// Check if results are concerning
  bool get needsReferral =>
      overallCategory == 'Borderline' || overallCategory == 'Reduced';

  /// Status for overall test result calculation
  String get status {
    if (overallCategory == 'Excellent' || overallCategory == 'Normal') {
      return 'Normal';
    } else if (overallCategory == 'Borderline') {
      return 'Review recommended';
    } else {
      return 'Professional consultation advised';
    }
  }

  Map<String, dynamic> toMap() => {
    'rightEye': rightEye?.toMap(),
    'leftEye': leftEye?.toMap(),
    'bothEyes': bothEyes?.toMap(),
    'shortDistance': shortDistance?.toMap(),
    'longDistance': longDistance?.toMap(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory PelliRobsonResult.fromMap(Map<String, dynamic> map) {
    return PelliRobsonResult(
      rightEye: map['rightEye'] != null
          ? PelliRobsonEyeResult.fromMap(map['rightEye'])
          : null,
      leftEye: map['leftEye'] != null
          ? PelliRobsonEyeResult.fromMap(map['leftEye'])
          : null,
      bothEyes: map['bothEyes'] != null
          ? PelliRobsonEyeResult.fromMap(map['bothEyes'])
          : null,
      shortDistance: map['shortDistance'] != null
          ? PelliRobsonSingleResult.fromMap(map['shortDistance'])
          : null,
      longDistance: map['longDistance'] != null
          ? PelliRobsonSingleResult.fromMap(map['longDistance'])
          : null,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
