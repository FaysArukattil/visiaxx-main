import 'package:uuid/uuid.dart';

// Enums for classification
enum PupilShape { round, oval, irregular, peaked }

enum LightReflex { normal, sluggish, absent }

enum RAPDStatus { absent, present, inconclusive }

enum CranialNerve { cn3, cn4, cn6 }

enum MovementQuality { full, restricted, absent }

enum EyeSide { left, right, both }

/// Pupillary examination results
class PupillaryResult {
  final double leftPupilSize; // in mm
  final double rightPupilSize; // in mm
  final bool symmetric;
  final PupilShape leftShape;
  final PupilShape rightShape;
  final LightReflex directReflex;
  final LightReflex consensualReflex;
  final RAPDStatus rapdStatus;
  final EyeSide? rapdAffectedEye;
  final double? anisocoriaDifference; // mm difference between pupils

  PupillaryResult({
    required this.leftPupilSize,
    required this.rightPupilSize,
    required this.symmetric,
    required this.leftShape,
    required this.rightShape,
    required this.directReflex,
    required this.consensualReflex,
    required this.rapdStatus,
    this.rapdAffectedEye,
    this.anisocoriaDifference,
  });

  Map<String, dynamic> toJson() {
    return {
      'leftPupilSize': leftPupilSize,
      'rightPupilSize': rightPupilSize,
      'symmetric': symmetric,
      'leftShape': leftShape.name,
      'rightShape': rightShape.name,
      'directReflex': directReflex.name,
      'consensualReflex': consensualReflex.name,
      'rapdStatus': rapdStatus.name,
      'rapdAffectedEye': rapdAffectedEye?.name,
      'anisocoriaDifference': anisocoriaDifference,
    };
  }

  factory PupillaryResult.fromJson(Map<String, dynamic> json) {
    return PupillaryResult(
      leftPupilSize: (json['leftPupilSize'] as num).toDouble(),
      rightPupilSize: (json['rightPupilSize'] as num).toDouble(),
      symmetric: json['symmetric'],
      leftShape: PupilShape.values.firstWhere(
        (e) => e.name == json['leftShape'],
      ),
      rightShape: PupilShape.values.firstWhere(
        (e) => e.name == json['rightShape'],
      ),
      directReflex: LightReflex.values.firstWhere(
        (e) => e.name == json['directReflex'],
      ),
      consensualReflex: LightReflex.values.firstWhere(
        (e) => e.name == json['consensualReflex'],
      ),
      rapdStatus: RAPDStatus.values.firstWhere(
        (e) => e.name == json['rapdStatus'],
      ),
      rapdAffectedEye: json['rapdAffectedEye'] != null
          ? EyeSide.values.firstWhere((e) => e.name == json['rapdAffectedEye'])
          : null,
      anisocoriaDifference: (json['anisocoriaDifference'] as num?)?.toDouble(),
    );
  }
}

/// Extraocular muscle examination results
class ExtraocularResult {
  final Map<String, MovementQuality> movements; // Direction -> Quality
  final bool nystagmusDetected;
  final List<CranialNerve> affectedNerves;
  final bool ptosisDetected;
  final EyeSide? ptosisEye;
  final Map<String, double> restrictionMap; // Direction -> Restriction %
  final String patternUsed; // 'H' or 'Star'

  ExtraocularResult({
    required this.movements,
    required this.nystagmusDetected,
    required this.affectedNerves,
    required this.ptosisDetected,
    this.ptosisEye,
    required this.restrictionMap,
    required this.patternUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'movements': movements.map((k, v) => MapEntry(k, v.name)),
      'nystagmusDetected': nystagmusDetected,
      'affectedNerves': affectedNerves.map((e) => e.name).toList(),
      'ptosisDetected': ptosisDetected,
      'ptosisEye': ptosisEye?.name,
      'restrictionMap': restrictionMap,
      'patternUsed': patternUsed,
    };
  }

  factory ExtraocularResult.fromJson(Map<String, dynamic> json) {
    return ExtraocularResult(
      movements: (json['movements'] as Map<String, dynamic>).map(
        (k, v) =>
            MapEntry(k, MovementQuality.values.firstWhere((e) => e.name == v)),
      ),
      nystagmusDetected: json['nystagmusDetected'],
      affectedNerves: (json['affectedNerves'] as List)
          .map((e) => CranialNerve.values.firstWhere((cn) => cn.name == e))
          .toList(),
      ptosisDetected: json['ptosisDetected'],
      ptosisEye: json['ptosisEye'] != null
          ? EyeSide.values.firstWhere((e) => e.name == json['ptosisEye'])
          : null,
      restrictionMap: Map<String, double>.from(json['restrictionMap']),
      patternUsed: json['patternUsed'],
    );
  }
}

/// Complete torchlight test result
class TorchlightTestResult {
  final String id;
  final PupillaryResult? pupillary;
  final ExtraocularResult? extraocular;
  final DateTime testDate;
  final String clinicalInterpretation;
  final List<String> recommendations;
  final bool requiresFollowUp;

  TorchlightTestResult({
    String? id,
    this.pupillary,
    this.extraocular,
    DateTime? testDate,
    required this.clinicalInterpretation,
    required this.recommendations,
    required this.requiresFollowUp,
  }) : id = id ?? const Uuid().v4(),
       testDate = testDate ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pupillary': pupillary?.toJson(),
      'extraocular': extraocular?.toJson(),
      'testDate': testDate.toIso8601String(),
      'clinicalInterpretation': clinicalInterpretation,
      'recommendations': recommendations,
      'requiresFollowUp': requiresFollowUp,
    };
  }

  factory TorchlightTestResult.fromJson(Map<String, dynamic> json) {
    return TorchlightTestResult(
      id: json['id'],
      pupillary: json['pupillary'] != null
          ? PupillaryResult.fromJson(json['pupillary'])
          : null,
      extraocular: json['extraocular'] != null
          ? ExtraocularResult.fromJson(json['extraocular'])
          : null,
      testDate: DateTime.parse(json['testDate']),
      clinicalInterpretation: json['clinicalInterpretation'],
      recommendations: List<String>.from(json['recommendations']),
      requiresFollowUp: json['requiresFollowUp'],
    );
  }

  /// Generate clinical interpretation based on results
  static String generateInterpretation({
    PupillaryResult? pupillary,
    ExtraocularResult? extraocular,
  }) {
    List<String> findings = [];

    if (pupillary != null) {
      // Anisocoria
      if (!pupillary.symmetric && (pupillary.anisocoriaDifference ?? 0) > 0.5) {
        findings.add(
          'Anisocoria detected (${pupillary.anisocoriaDifference?.toStringAsFixed(1)}mm difference) - may suggest nerve damage or pathology',
        );
      }

      // RAPD
      if (pupillary.rapdStatus == RAPDStatus.present) {
        findings.add(
          'RAPD (Marcus Gunn pupil) detected in ${pupillary.rapdAffectedEye?.name} eye - suggests optic nerve dysfunction',
        );
      }

      // Light reflexes
      if (pupillary.directReflex == LightReflex.absent) {
        findings.add(
          'Absent direct light reflex - may indicate optic nerve or brainstem damage',
        );
      }
      if (pupillary.consensualReflex == LightReflex.absent) {
        findings.add(
          'Absent consensual light reflex - requires further neurological assessment',
        );
      }
      if (pupillary.directReflex == LightReflex.sluggish ||
          pupillary.consensualReflex == LightReflex.sluggish) {
        findings.add('Sluggish pupillary responses detected');
      }

      // Pupil shape
      if (pupillary.leftShape != PupilShape.round ||
          pupillary.rightShape != PupilShape.round) {
        findings.add(
          'Irregular pupil shape detected - may indicate trauma, inflammation, or surgical intervention',
        );
      }
    }

    if (extraocular != null) {
      // Cranial nerve palsies
      if (extraocular.affectedNerves.contains(CranialNerve.cn3)) {
        findings.add(
          'CN III (Oculomotor) palsy suspected - restricted medial, superior, and/or inferior rectus movement',
        );
      }
      if (extraocular.affectedNerves.contains(CranialNerve.cn4)) {
        findings.add(
          'CN IV (Trochlear) palsy suspected - restricted superior oblique movement',
        );
      }
      if (extraocular.affectedNerves.contains(CranialNerve.cn6)) {
        findings.add(
          'CN VI (Abducens) palsy suspected - restricted lateral rectus movement',
        );
      }

      // Nystagmus
      if (extraocular.nystagmusDetected) {
        findings.add(
          'Nystagmus detected - requires comprehensive neurological and vestibular assessment',
        );
      }

      // Ptosis
      if (extraocular.ptosisDetected) {
        findings.add(
          'Ptosis detected in ${extraocular.ptosisEye?.name} eye - possible CN III involvement',
        );
      }

      // Movement restrictions
      final restrictedMovements = extraocular.movements.entries
          .where((e) => e.value != MovementQuality.full)
          .toList();
      if (restrictedMovements.isNotEmpty) {
        findings.add(
          'Movement restrictions detected: ${restrictedMovements.map((e) => e.key).join(", ")}',
        );
      }
    }

    return findings.isEmpty
        ? 'Normal pupillary and extraocular muscle function. No significant abnormalities detected.'
        : findings.join('\n\n');
  }

  /// Generate recommendations based on findings
  static List<String> generateRecommendations({
    PupillaryResult? pupillary,
    ExtraocularResult? extraocular,
  }) {
    List<String> recommendations = [];
    bool requiresUrgent = false;

    if (pupillary != null) {
      if (pupillary.rapdStatus == RAPDStatus.present) {
        recommendations.add(
          'URGENT: Consult ophthalmologist immediately for optic nerve assessment',
        );
        requiresUrgent = true;
      }
      if (pupillary.directReflex == LightReflex.absent ||
          pupillary.consensualReflex == LightReflex.absent) {
        recommendations.add(
          'Seek immediate medical attention - absent light reflex may indicate serious neurological condition',
        );
        requiresUrgent = true;
      }
      if (!pupillary.symmetric && (pupillary.anisocoriaDifference ?? 0) > 1.0) {
        recommendations.add(
          'Schedule comprehensive eye examination to rule out neurological causes of anisocoria',
        );
      }
    }

    if (extraocular != null) {
      if (extraocular.affectedNerves.isNotEmpty) {
        recommendations.add(
          'Consult neurologist and ophthalmologist for cranial nerve palsy evaluation',
        );
      }
      if (extraocular.nystagmusDetected) {
        recommendations.add(
          'Neurological and vestibular assessment recommended for nystagmus',
        );
      }
      if (extraocular.ptosisDetected) {
        recommendations.add(
          'Ophthalmology consultation for ptosis evaluation and potential CN III assessment',
        );
      }
    }

    if (!requiresUrgent && recommendations.isEmpty) {
      recommendations.add(
        'Continue regular eye examinations as per your eye care professional\'s schedule',
      );
      recommendations.add(
        'Monitor for any changes in vision, eye movement, or pupil appearance',
      );
    }

    return recommendations;
  }

  /// Determine if follow-up is required
  static bool determineFollowUp({
    PupillaryResult? pupillary,
    ExtraocularResult? extraocular,
  }) {
    if (pupillary != null) {
      if (pupillary.rapdStatus == RAPDStatus.present ||
          pupillary.directReflex == LightReflex.absent ||
          pupillary.consensualReflex == LightReflex.absent ||
          (pupillary.anisocoriaDifference != null &&
              pupillary.anisocoriaDifference! > 0.5)) {
        return true;
      }
    }

    if (extraocular != null) {
      if (extraocular.affectedNerves.isNotEmpty ||
          extraocular.nystagmusDetected ||
          extraocular.ptosisDetected) {
        return true;
      }
    }

    return false;
  }
}
