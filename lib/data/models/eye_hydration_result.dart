import 'package:cloud_firestore/cloud_firestore.dart';

enum EyeHydrationStatus {
  normal('Normal', 'Healthy blink rate and eye hydration levels.'),
  dryness(
    'Urgent Consultation',
    'Low blink rate and excessive staring detected. Screen break and eye care consultation required.',
  ),
  suspicious(
    'Monitoring Advised',
    'Irregular blink patterns. Screen breaks recommended.',
  );

  final String label;
  final String description;
  const EyeHydrationStatus(this.label, this.description);
}

class EyeHydrationResult {
  final String id;
  final int blinkCount;
  final double averageBlinksPerMinute;
  final Duration totalTestTime;
  final double screenBrightness;
  final EyeHydrationStatus status;
  final DateTime timestamp;
  final List<String> recommendations;

  EyeHydrationResult({
    required this.id,
    required this.blinkCount,
    required this.averageBlinksPerMinute,
    required this.totalTestTime,
    required this.screenBrightness,
    required this.status,
    required this.recommendations,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory EyeHydrationResult.analyze({
    required int blinkCount,
    required Duration duration,
    required double screenBrightness,
  }) {
    double blinksPerMin = duration.inSeconds > 0
        ? blinkCount / (duration.inSeconds / 60)
        : 0;

    EyeHydrationStatus status;
    List<String> recommendations = [];

    if (blinksPerMin >= 12) {
      status = EyeHydrationStatus.normal;
      recommendations = [
        "Keep up your healthy habits.",
        "Maintain current lighting and distance.",
      ];
    } else if (blinksPerMin >= 6) {
      status = EyeHydrationStatus.suspicious;
      recommendations = [
        "Remember the 20-20-20 rule: Every 20 minutes, look at something 20 feet away for 20 seconds.",
        "Slightly reduce screen brightness to lower eye strain.",
        "Consciously try to blink more frequently while reading.",
      ];
    } else {
      status = EyeHydrationStatus.dryness;
      recommendations = [
        "High risk of Digital Eye Strain detected.",
        "Use artificial tears or lubricating eye drops as advised by a doctor.",
        "Significantly reduce continuous screen time.",
        "Ensure your screen is at least 15-20 degrees below eye level.",
        "Consult an ophthalmologist for a clinical dry eye assessment.",
      ];
    }

    return EyeHydrationResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      blinkCount: blinkCount,
      averageBlinksPerMinute: blinksPerMin,
      totalTestTime: duration,
      screenBrightness: screenBrightness,
      status: status,
      recommendations: recommendations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blinkCount': blinkCount,
      'averageBlinksPerMinute': averageBlinksPerMinute,
      'totalTestTime': totalTestTime.inSeconds,
      'screenBrightness': screenBrightness,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'recommendations': recommendations,
    };
  }

  factory EyeHydrationResult.fromJson(Map<String, dynamic> json) {
    return EyeHydrationResult(
      id: json['id'] ?? '',
      blinkCount: json['blinkCount'] ?? 0,
      averageBlinksPerMinute: (json['averageBlinksPerMinute'] ?? 0).toDouble(),
      totalTestTime: Duration(seconds: json['totalTestTime'] ?? 0),
      screenBrightness: (json['screenBrightness'] ?? 0.5).toDouble(),
      status: EyeHydrationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EyeHydrationStatus.normal,
      ),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => toJson();
}
