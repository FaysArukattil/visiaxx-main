import 'package:cloud_firestore/cloud_firestore.dart';

/// Grade for stereopsis (depth perception) test results
enum StereopsisGrade {
  excellent('Excellent', 'Superior depth perception (40 seconds of arc)'),
  good('Good', 'Normal depth perception (100 seconds of arc)'),
  fair('Fair', 'Subnormal depth perception (200-400 seconds of arc)'),
  poor('Poor', 'Limited depth perception'),
  none('None', 'No stereopsis detected');

  final String label;
  final String description;
  const StereopsisGrade(this.label, this.description);

  static StereopsisGrade fromScore(int score, int totalRounds) {
    // Map score (out of 4) to specific ARC thresholds
    switch (score) {
      case 4:
        return StereopsisGrade.excellent; // 40 ARC
      case 3:
        return StereopsisGrade.good; // 100 ARC
      case 2:
        return StereopsisGrade.fair; // 200 ARC
      case 1:
        return StereopsisGrade.poor; // 400 ARC
      default:
        return StereopsisGrade.none;
    }
  }
}

/// Result model for Stereopsis Test
class StereopsisResult {
  final String id;
  final StereopsisGrade grade;
  final int score;
  final int totalRounds;
  final int? bestArc; // The smallest seconds of arc detected
  final DateTime testDate;
  final bool stereopsisPresent;

  StereopsisResult({
    required this.id,
    required this.grade,
    required this.score,
    required this.totalRounds,
    this.bestArc,
    DateTime? testDate,
  }) : testDate = testDate ?? DateTime.now(),
       stereopsisPresent =
           grade != StereopsisGrade.none && grade != StereopsisGrade.poor;

  double get percentage => totalRounds > 0 ? (score / totalRounds) * 100 : 0;

  String get recommendation {
    // If the user achieved the best possible result (40 seconds of arc)
    if (grade == StereopsisGrade.excellent) {
      return 'Excellent! Your stereopsis (3D vision) is normal (40 seconds of arc). Continue regular eye check-ups to maintain healthy vision.';
    } else if (stereopsisPresent) {
      // User identified some 3D, but not the finest level
      return 'Normally, more than 40 seconds of arc have some defects. We advise you to take the Cover Eye test or go for an amblyopia test.';
    } else {
      // No stereopsis detected or very poor
      return 'No stereopsis detected. Please consult an optometrist for a comprehensive eye examination. We strongly advise you to take the Cover Eye test and go for an amblyopia test.';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade': grade.name,
      'gradeLabel': grade.label,
      'gradeDescription': grade.description,
      'score': score,
      'totalRounds': totalRounds,
      'bestArc': bestArc,
      'testDate': Timestamp.fromDate(testDate),
      'stereopsisPresent': stereopsisPresent,
      'percentage': percentage,
    };
  }

  factory StereopsisResult.fromJson(Map<String, dynamic> json) {
    return StereopsisResult(
      id: json['id'] ?? '',
      grade: StereopsisGrade.values.firstWhere(
        (e) => e.name == json['grade'],
        orElse: () => StereopsisGrade.none,
      ),
      score: json['score'] ?? 0,
      totalRounds: json['totalRounds'] ?? 5,
      bestArc: json['bestArc'],
      testDate: (json['testDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => toJson();

  StereopsisResult copyWith({
    String? id,
    StereopsisGrade? grade,
    int? score,
    int? totalRounds,
    int? bestArc,
    DateTime? testDate,
  }) {
    return StereopsisResult(
      id: id ?? this.id,
      grade: grade ?? this.grade,
      score: score ?? this.score,
      totalRounds: totalRounds ?? this.totalRounds,
      bestArc: bestArc ?? this.bestArc,
      testDate: testDate ?? this.testDate,
    );
  }
}
