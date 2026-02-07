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
    double percentage = score / totalRounds;
    if (percentage >= 1.0) return StereopsisGrade.excellent;
    if (percentage >= 0.8) return StereopsisGrade.good;
    if (percentage >= 0.6) return StereopsisGrade.fair;
    if (percentage >= 0.4) return StereopsisGrade.poor;
    return StereopsisGrade.none;
  }
}

/// Result model for Stereopsis Test
class StereopsisResult {
  final String id;
  final StereopsisGrade grade;
  final int score;
  final int totalRounds;
  final DateTime testDate;
  final bool stereopsisPresent;

  StereopsisResult({
    required this.id,
    required this.grade,
    required this.score,
    required this.totalRounds,
    DateTime? testDate,
  }) : testDate = testDate ?? DateTime.now(),
       stereopsisPresent =
           grade != StereopsisGrade.none && grade != StereopsisGrade.poor;

  double get percentage => totalRounds > 0 ? (score / totalRounds) * 100 : 0;

  String get recommendation {
    if (stereopsisPresent) {
      return 'Your stereopsis (3D vision) is working! Continue regular eye check-ups to maintain healthy vision.';
    } else {
      return 'Please consult an optometrist or ophthalmologist for a comprehensive eye examination. Absent stereopsis can be due to various treatable conditions.';
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
      testDate: (json['testDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => toJson();

  StereopsisResult copyWith({
    String? id,
    StereopsisGrade? grade,
    int? score,
    int? totalRounds,
    DateTime? testDate,
  }) {
    return StereopsisResult(
      id: id ?? this.id,
      grade: grade ?? this.grade,
      score: score ?? this.score,
      totalRounds: totalRounds ?? this.totalRounds,
      testDate: testDate ?? this.testDate,
    );
  }
}
