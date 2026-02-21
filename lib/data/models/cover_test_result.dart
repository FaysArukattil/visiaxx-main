import 'package:cloud_firestore/cloud_firestore.dart';

enum EyeMovement {
  none('No Movement', 'The eye remained steady'),
  inward('Inward', 'Movement towards the nose (adduction)'),
  outward('Outward', 'Movement away from the nose (abduction)'),
  upward('Upward', 'Movement towards the forehead'),
  downward('Downward', 'Movement towards the cheek');

  final String label;
  final String description;
  const EyeMovement(this.label, this.description);
}

enum AlignmentStatus {
  normal('Normal', 'No significant ocular deviation detected'),
  esotropia('Esotropia', 'Inward eye deviation (in-turning)'),
  exotropia('Exotropia', 'Outward eye deviation (out-turning)'),
  hypertropia('Hypertropia', 'Upward eye deviation'),
  hypotropia('Hypotropia', 'Downward eye deviation'),
  esophoria('Esophoria', 'Latent inward deviation revealed on uncovering'),
  exophoria('Exophoria', 'Latent outward deviation revealed on uncovering'),
  inconclusive('Inconclusive', 'Movement detected but pattern unclear');

  final String label;
  final String description;
  const AlignmentStatus(this.label, this.description);
}

class CoverTestObservation {
  final String eye; // 'Right' or 'Left'
  final String phase; // 'Covering Right', 'Uncovering Right', etc.
  final EyeMovement movement;
  final String? videoPath; // Local path
  final String? videoUrl; // AWS URL

  CoverTestObservation({
    required this.eye,
    required this.phase,
    required this.movement,
    this.videoPath,
    this.videoUrl,
  });

  Map<String, dynamic> toJson() => {
    'eye': eye,
    'phase': phase,
    'movement': movement.name,
    'videoPath': videoPath,
    'videoUrl': videoUrl,
  };

  factory CoverTestObservation.fromJson(Map<String, dynamic> json) =>
      CoverTestObservation(
        eye: json['eye'] ?? '',
        phase: json['phase'] ?? '',
        movement: EyeMovement.values.firstWhere(
          (e) => e.name == json['movement'],
          orElse: () => EyeMovement.none,
        ),
        videoPath: json['videoPath'],
        videoUrl: json['videoUrl'],
      );

  Map<String, dynamic> toMap() => toJson();
}

class CoverTestResult {
  final String id;
  final String patientId;
  final String? patientName;
  final DateTime date;
  final AlignmentStatus rightEyeStatus;
  final AlignmentStatus leftEyeStatus;
  final List<CoverTestObservation> observations;

  CoverTestResult({
    required this.id,
    required this.patientId,
    this.patientName,
    DateTime? date,
    required this.rightEyeStatus,
    required this.leftEyeStatus,
    required this.observations,
  }) : date = date ?? DateTime.now();

  bool get hasDeviation =>
      rightEyeStatus != AlignmentStatus.normal ||
      leftEyeStatus != AlignmentStatus.normal;

  String get overallInterpretation {
    if (!hasDeviation) {
      return 'Both eyes demonstrate normal alignment with no significant deviation detected during cover-uncover testing.';
    }

    final deviations = <String>[];
    if (rightEyeStatus != AlignmentStatus.normal) {
      deviations.add('Right eye: ${rightEyeStatus.description}');
    }
    if (leftEyeStatus != AlignmentStatus.normal) {
      deviations.add('Left eye: ${leftEyeStatus.description}');
    }

    return '${deviations.join('. ')}.';
  }

  String get recommendation {
    if (!hasDeviation) {
      return 'Continue routine eye examinations. No immediate concerns with eye alignment.';
    }

    // Check for manifest deviations (tropias)
    final hasManifestDeviation =
        rightEyeStatus == AlignmentStatus.esotropia ||
        rightEyeStatus == AlignmentStatus.exotropia ||
        rightEyeStatus == AlignmentStatus.hypertropia ||
        rightEyeStatus == AlignmentStatus.hypotropia ||
        leftEyeStatus == AlignmentStatus.esotropia ||
        leftEyeStatus == AlignmentStatus.exotropia ||
        leftEyeStatus == AlignmentStatus.hypertropia ||
        leftEyeStatus == AlignmentStatus.hypotropia;

    if (hasManifestDeviation) {
      return 'Manifest strabismus detected. Immediate referral to an ophthalmologist or optometrist specializing in binocular vision is strongly recommended for comprehensive evaluation and treatment planning.';
    } else {
      return 'Latent deviation (phoria) detected. Schedule comprehensive eye examination with binocular vision assessment. May require vision therapy or corrective lenses.';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'date': Timestamp.fromDate(date),
      'rightEyeStatus': rightEyeStatus.name,
      'leftEyeStatus': leftEyeStatus.name,
      'observations': observations.map((o) => o.toJson()).toList(),
    };
  }

  factory CoverTestResult.fromJson(Map<String, dynamic> json) {
    return CoverTestResult(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'],
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rightEyeStatus: AlignmentStatus.values.firstWhere(
        (e) => e.name == json['rightEyeStatus'],
        orElse: () => AlignmentStatus.normal,
      ),
      leftEyeStatus: AlignmentStatus.values.firstWhere(
        (e) => e.name == json['leftEyeStatus'],
        orElse: () => AlignmentStatus.normal,
      ),
      observations:
          (json['observations'] as List?)
              ?.map((o) => CoverTestObservation.fromJson(o))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => toJson();

  CoverTestResult copyWith({
    String? id,
    String? patientId,
    String? patientName,
    DateTime? date,
    AlignmentStatus? rightEyeStatus,
    AlignmentStatus? leftEyeStatus,
    List<CoverTestObservation>? observations,
  }) {
    return CoverTestResult(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      date: date ?? this.date,
      rightEyeStatus: rightEyeStatus ?? this.rightEyeStatus,
      leftEyeStatus: leftEyeStatus ?? this.leftEyeStatus,
      observations: observations ?? this.observations,
    );
  }
}
