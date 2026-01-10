/// Visual acuity test result for a single eye
class VisualAcuityResult {
  final String eye; // 'right' or 'left'
  final String snellenScore; // e.g., '20/20'
  final double logMAR;
  final int correctResponses;
  final int totalResponses;
  final int durationSeconds;
  final List<EResponseRecord> responses;
  final String status;

  VisualAcuityResult({
    required this.eye,
    required this.snellenScore,
    required this.logMAR,
    required this.correctResponses,
    required this.totalResponses,
    required this.durationSeconds,
    required this.responses,
    required this.status,
  });

  factory VisualAcuityResult.fromMap(Map<String, dynamic> data) {
    return VisualAcuityResult(
      eye: data['eye'] ?? '',
      snellenScore: data['snellenScore'] ?? '',
      logMAR: (data['logMAR'] ?? 0.0).toDouble(),
      correctResponses: data['correctResponses'] ?? 0,
      totalResponses: data['totalResponses'] ?? 0,
      durationSeconds: data['durationSeconds'] ?? 0,
      responses:
          (data['responses'] as List<dynamic>?)
              ?.map((e) => EResponseRecord.fromMap(e))
              .toList() ??
          [],
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eye': eye,
      'snellenScore': snellenScore,
      'logMAR': logMAR,
      'correctResponses': correctResponses,
      'totalResponses': totalResponses,
      'durationSeconds': durationSeconds,
      'responses': responses.map((e) => e.toMap()).toList(),
      'status': status,
    };
  }

  double get accuracy =>
      totalResponses > 0 ? correctResponses / totalResponses : 0;

  bool get isNormal => logMAR <= 0.0; // 20/20 or better
  bool get needsReview => logMAR > 0.0 && logMAR <= 0.3; // 20/25 to 20/40
  bool get needsAttention => logMAR > 0.3; // Worse than 20/40
}

/// Individual E response record
class EResponseRecord {
  final int level;
  final double eSize;
  final String expectedDirection;
  final String userResponse;
  final bool isCorrect;
  final int responseTimeMs;
  final bool
  wasBlurry; // True if user responded with "Blurry/Can't see clearly"

  EResponseRecord({
    required this.level,
    required this.eSize,
    required this.expectedDirection,
    required this.userResponse,
    required this.isCorrect,
    required this.responseTimeMs,
    this.wasBlurry = false,
  });

  factory EResponseRecord.fromMap(Map<String, dynamic> data) {
    return EResponseRecord(
      level: data['level'] ?? 0,
      eSize: (data['eSize'] ?? 0.0).toDouble(),
      expectedDirection: data['expectedDirection'] ?? '',
      userResponse: data['userResponse'] ?? '',
      isCorrect: data['isCorrect'] ?? false,
      responseTimeMs: data['responseTimeMs'] ?? 0,
      wasBlurry: data['wasBlurry'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'eSize': eSize,
      'expectedDirection': expectedDirection,
      'userResponse': userResponse,
      'isCorrect': isCorrect,
      'responseTimeMs': responseTimeMs,
      'wasBlurry': wasBlurry,
    };
  }
}
