class ShortDistanceResult {
  final int correctSentences;
  final int totalSentences;
  final double averageSimilarity;
  final String bestAcuity; // Best Snellen score achieved
  final int durationSeconds;
  final List responses;
  final String status;

  ShortDistanceResult({
    required this.correctSentences,
    required this.totalSentences,
    required this.averageSimilarity,
    required this.bestAcuity,
    required this.durationSeconds,
    required this.responses,
    required this.status,
  });

  factory ShortDistanceResult.fromMap(Map<String, dynamic> data) {
    return ShortDistanceResult(
      correctSentences: data['correctSentences'] ?? 0,
      totalSentences: data['totalSentences'] ?? 0,
      averageSimilarity: (data['averageSimilarity'] ?? 0.0).toDouble(),
      bestAcuity: data['bestAcuity'] ?? 'N/A',
      durationSeconds: data['durationSeconds'] ?? 0,
      responses:
          (data['responses'] as List?)
              ?.map((e) => SentenceResponse.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'correctSentences': correctSentences,
      'totalSentences': totalSentences,
      'averageSimilarity': averageSimilarity,
      'bestAcuity': bestAcuity,
      'durationSeconds': durationSeconds,
      'responses': responses.map((e) => e.toMap()).toList(),
      'status': status,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  double get accuracy =>
      totalSentences > 0 ? correctSentences / totalSentences : 0;

  bool get isNormal => averageSimilarity >= 70.0 && correctSentences >= 5;
}

/// Individual sentence response
class SentenceResponse {
  final int screenNumber;
  final String expectedSentence;
  final String userResponse;
  final double similarity;
  final bool passed;
  final String snellen;
  final double fontSize;

  SentenceResponse({
    required this.screenNumber,
    required this.expectedSentence,
    required this.userResponse,
    required this.similarity,
    required this.passed,
    required this.snellen,
    required this.fontSize,
  });

  factory SentenceResponse.fromMap(Map<String, dynamic> data) {
    return SentenceResponse(
      screenNumber: data['screenNumber'] ?? 0,
      expectedSentence: data['expectedSentence'] ?? '',
      userResponse: data['userResponse'] ?? '',
      similarity: (data['similarity'] ?? 0.0).toDouble(),
      passed: data['passed'] ?? false,
      snellen: data['snellen'] ?? '',
      fontSize: (data['fontSize'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'screenNumber': screenNumber,
      'expectedSentence': expectedSentence,
      'userResponse': userResponse,
      'similarity': similarity,
      'passed': passed,
      'snellen': snellen,
      'fontSize': fontSize,
    };
  }
}
