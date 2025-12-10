/// Color vision test result model
class ColorVisionResult {
  final int correctAnswers;
  final int totalPlates;
  final List<PlateResponse> plateResponses;
  final String status;
  final String? deficiencyType;
  final List<int> incorrectPlates;

  ColorVisionResult({
    required this.correctAnswers,
    required this.totalPlates,
    required this.plateResponses,
    required this.status,
    this.deficiencyType,
    required this.incorrectPlates,
  });

  factory ColorVisionResult.fromMap(Map<String, dynamic> data) {
    return ColorVisionResult(
      correctAnswers: data['correctAnswers'] ?? 0,
      totalPlates: data['totalPlates'] ?? 0,
      plateResponses: (data['plateResponses'] as List<dynamic>?)
              ?.map((e) => PlateResponse.fromMap(e))
              .toList() ??
          [],
      status: data['status'] ?? '',
      deficiencyType: data['deficiencyType'],
      incorrectPlates: List<int>.from(data['incorrectPlates'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'correctAnswers': correctAnswers,
      'totalPlates': totalPlates,
      'plateResponses': plateResponses.map((e) => e.toMap()).toList(),
      'status': status,
      'deficiencyType': deficiencyType,
      'incorrectPlates': incorrectPlates,
    };
  }

  double get accuracy => totalPlates > 0 ? correctAnswers / totalPlates : 0;
  bool get isNormal => accuracy >= 0.75; // 75% or better is considered normal

  String get resultSummary {
    if (isNormal) {
      return 'Normal color vision';
    } else if (deficiencyType != null) {
      return 'Color vision deficiency detected: $deficiencyType';
    } else {
      return 'Color vision deficiency detected';
    }
  }
}

/// Individual plate response record
class PlateResponse {
  final int plateNumber;
  final String expectedAnswer;
  final String userAnswer;
  final bool isCorrect;
  final int responseTimeMs;

  PlateResponse({
    required this.plateNumber,
    required this.expectedAnswer,
    required this.userAnswer,
    required this.isCorrect,
    required this.responseTimeMs,
  });

  factory PlateResponse.fromMap(Map<String, dynamic> data) {
    return PlateResponse(
      plateNumber: data['plateNumber'] ?? 0,
      expectedAnswer: data['expectedAnswer'] ?? '',
      userAnswer: data['userAnswer'] ?? '',
      isCorrect: data['isCorrect'] ?? false,
      responseTimeMs: data['responseTimeMs'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plateNumber': plateNumber,
      'expectedAnswer': expectedAnswer,
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'responseTimeMs': responseTimeMs,
    };
  }
}
