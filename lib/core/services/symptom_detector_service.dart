import '../../data/models/test_result_model.dart';
import '../../data/models/color_vision_result.dart';
import '../../data/models/stereopsis_result.dart';
import '../../data/models/eye_hydration_result.dart';
import '../../data/models/torchlight_test_result.dart';
import '../../data/models/cover_test_result.dart';

// ─── Data Models ───────────────────────────────────────────────

enum ConditionSeverity { informational, moderate, significant, critical }

enum ConditionCategory {
  refractive,
  retinal,
  glaucoma,
  neurological,
  surface,
  alignment,
  systemic,
}

class DetectedCondition {
  final String name;
  final ConditionCategory category;
  final ConditionSeverity severity;
  final List<String> detectedSymptoms;
  final List<String> possibleCauses;
  final List<String> contributingTests;
  final String recommendation;

  const DetectedCondition({
    required this.name,
    required this.category,
    required this.severity,
    required this.detectedSymptoms,
    required this.possibleCauses,
    required this.contributingTests,
    required this.recommendation,
  });
}

// ─── Service ───────────────────────────────────────────────────

class SymptomDetectorService {
  static List<DetectedCondition> analyze(TestResultModel result) {
    final conditions = <DetectedCondition>[];
    final age = result.profileAge;
    final sex = result.profileSex?.toLowerCase();
    final q = result.questionnaire;
    final cc = q?.chiefComplaints;
    final si = q?.systemicIllness;

    // Run all analyzers
    _analyzeVisualAcuity(result, age, cc, si, conditions);
    _analyzeNearVision(result, age, cc, conditions);
    _analyzeRefractometry(result, age, si, conditions);
    _analyzeColorVision(result, age, sex, si, conditions);
    _analyzeAmslerGrid(result, age, si, conditions);
    _analyzeContrastSensitivity(result, age, cc, si, conditions);
    _analyzeShadowTest(result, age, cc, si, conditions);
    _analyzeStereopsis(result, conditions);
    _analyzeEyeHydration(result, age, sex, cc, si, conditions);
    _analyzeVisualField(result, age, cc, si, conditions);
    _analyzeCoverTest(result, age, cc, conditions);
    _analyzeTorchlight(result, si, conditions);
    _analyzeQuestionnaireOnly(cc, si, conditions);

    // Sort: critical first, then significant, etc.
    conditions.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return conditions;
  }

  // ─── 1. Visual Acuity ──────────────────────────────────────

  static void _analyzeVisualAcuity(
    TestResultModel r,
    int? age,
    dynamic cc,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final right = r.visualAcuityRight;
    final left = r.visualAcuityLeft;
    if (right == null && left == null) return;

    final rLog = right?.logMAR ?? 0.0;
    final lLog = left?.logMAR ?? 0.0;
    final worse = rLog > lLog ? rLog : lLog;
    final diff = (rLog - lLog).abs();

    // Check for blurry responses
    final hasBlurry =
        (right?.responses.any((e) => e.wasBlurry) ?? false) ||
        (left?.responses.any((e) => e.wasBlurry) ?? false);

    if (hasBlurry) {
      out.add(
        const DetectedCondition(
          name: 'Possible Uncorrected Refractive Error',
          category: ConditionCategory.refractive,
          severity: ConditionSeverity.moderate,
          detectedSymptoms: ['Patient reported blurry vision during test'],
          possibleCauses: ['Myopia', 'Hyperopia', 'Astigmatism', 'Dry Eye'],
          contributingTests: ['Visual Acuity'],
          recommendation:
              'A refraction test is recommended to determine if corrective lenses are needed.',
        ),
      );
    }

    if (worse >= 0.7) {
      final isBilateral = rLog >= 0.7 && lLog >= 0.7;
      final causes = <String>[
        'Uncorrected Refractive Error',
        'Advanced Cataract',
        'Corneal Opacity',
      ];
      if (isBilateral) {
        causes.addAll(['Diabetic Retinopathy', 'Glaucoma', 'Optic Neuropathy']);
      }
      if (si?.hasDiabetes == true) causes.add('Diabetic Macular Edema');
      if (si?.hasHypertension == true) causes.add('Hypertensive Retinopathy');

      out.add(
        DetectedCondition(
          name: isBilateral
              ? 'Bilateral Significant Vision Impairment'
              : 'Significant Vision Impairment',
          category: ConditionCategory.refractive,
          severity: ConditionSeverity.significant,
          detectedSymptoms: [
            if (right != null)
              'Right eye: ${right.snellenScore} (${right.conditionCategory})',
            if (left != null)
              'Left eye: ${left.snellenScore} (${left.conditionCategory})',
          ],
          possibleCauses: causes,
          contributingTests: ['Visual Acuity (Distance)'],
          recommendation: 'Urgent comprehensive eye examination recommended.',
        ),
      );
    } else if (worse >= 0.3) {
      out.add(
        DetectedCondition(
          name: 'Moderate Vision Reduction',
          category: ConditionCategory.refractive,
          severity: ConditionSeverity.moderate,
          detectedSymptoms: [
            if (right != null && rLog >= 0.3)
              'Right eye: ${right.snellenScore}',
            if (left != null && lLog >= 0.3) 'Left eye: ${left.snellenScore}',
          ],
          possibleCauses: [
            'Myopia',
            'Hyperopia',
            'Astigmatism',
            if (age != null && age >= 50) 'Early Cataract',
          ],
          contributingTests: ['Visual Acuity (Distance)'],
          recommendation: 'Eye examination with refraction recommended.',
        ),
      );
    }

    if (diff >= 0.3 && right != null && left != null) {
      out.add(
        DetectedCondition(
          name: 'Anisometropia / Unilateral Pathology',
          category: ConditionCategory.refractive,
          severity: ConditionSeverity.moderate,
          detectedSymptoms: [
            'Significant asymmetry between eyes: R ${right.snellenScore} vs L ${left.snellenScore}',
          ],
          possibleCauses: [
            'Anisometropia',
            'Amblyopia',
            'Unilateral Cataract',
            'Retinal Pathology',
          ],
          contributingTests: ['Visual Acuity (Distance)'],
          recommendation: 'Investigate cause of asymmetric vision.',
        ),
      );
    }

    if (age != null && age >= 60 && worse >= 0.3) {
      out.add(
        DetectedCondition(
          name: 'Age-Related Cataract (suspected)',
          category: ConditionCategory.surface,
          severity: ConditionSeverity.moderate,
          detectedSymptoms: ['Reduced distance vision in patient aged $age'],
          possibleCauses: [
            'Nuclear Sclerotic Cataract',
            'Cortical Cataract',
            'Posterior Subcapsular Cataract',
          ],
          contributingTests: ['Visual Acuity', 'Patient Age'],
          recommendation:
              'Slit-lamp examination recommended to evaluate lens opacity.',
        ),
      );
    }
  }

  // ─── 2. Near Vision ────────────────────────────────────────

  static void _analyzeNearVision(
    TestResultModel r,
    int? age,
    dynamic cc,
    List<DetectedCondition> out,
  ) {
    final sd = r.shortDistance;
    if (sd == null) return;

    if (!sd.isNormal) {
      final causes = <String>['Presbyopia', 'Accommodative Insufficiency'];
      if (age != null && age >= 40) {
        causes.insert(0, 'Presbyopia (age-related)');
      }
      if (age != null && age < 20) {
        causes.addAll(['Accommodative Spasm', 'Convergence Insufficiency']);
      }

      if (cc?.hasHeadache == true) {
        causes.add('Asthenopia (eye strain)');
      }
      if (cc?.hasDryness == true) {
        causes.add('Dry Eye–related reading difficulty');
      }

      out.add(
        DetectedCondition(
          name: age != null && age >= 40
              ? 'Presbyopia'
              : 'Near Vision Difficulty',
          category: ConditionCategory.refractive,
          severity: ConditionSeverity.moderate,
          detectedSymptoms: [
            'Reading accuracy: ${(sd.accuracy * 100).toStringAsFixed(0)}%',
            'Correct sentences: ${sd.correctSentences}/${sd.totalSentences}',
          ],
          possibleCauses: causes,
          contributingTests: ['Near Vision (Reading Test)'],
          recommendation:
              'Near-vision refraction and reading add assessment recommended.',
        ),
      );
    }
  }

  // ─── 3. Mobile Refractometry ───────────────────────────────

  static void _analyzeRefractometry(
    TestResultModel r,
    int? age,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final refr = r.mobileRefractometry;
    if (refr == null) {
      return;
    }

    for (final eye in [refr.rightEye, refr.leftEye]) {
      if (eye == null) {
        continue;
      }
      final label = eye.eye == 'right' ? 'Right' : 'Left';
      final sphere = double.tryParse(eye.sphere) ?? 0.0;
      final cyl = (double.tryParse(eye.cylinder) ?? 0.0).abs();
      final add = double.tryParse(eye.addPower) ?? 0.0;

      // Myopia
      if (eye.refractiveErrorType == 'Myopia' || sphere < -0.5) {
        final isHigh = sphere <= -6.0;
        out.add(
          DetectedCondition(
            name: isHigh ? 'High Myopia ($label Eye)' : 'Myopia ($label Eye)',
            category: ConditionCategory.refractive,
            severity: isHigh
                ? ConditionSeverity.significant
                : ConditionSeverity.moderate,
            detectedSymptoms: ['$label eye sphere: ${eye.sphere}D'],
            possibleCauses: isHigh
                ? [
                    'High Myopia',
                    'Risk of Retinal Detachment',
                    'Myopic Macular Degeneration',
                    'Glaucoma',
                  ]
                : ['Myopia (near-sightedness)'],
            contributingTests: ['Mobile Refractometry'],
            recommendation: isHigh
                ? 'Annual dilated retinal exam recommended due to high myopia risks.'
                : 'Corrective lenses recommended.',
          ),
        );
      }

      // Hyperopia
      if (eye.refractiveErrorType == 'Hyperopia' || sphere > 0.5) {
        final isHigh = sphere >= 3.0;
        out.add(
          DetectedCondition(
            name: isHigh
                ? 'High Hyperopia ($label Eye)'
                : 'Hyperopia ($label Eye)',
            category: ConditionCategory.refractive,
            severity: isHigh
                ? ConditionSeverity.significant
                : ConditionSeverity.moderate,
            detectedSymptoms: ['$label eye sphere: +${eye.sphere}D'],
            possibleCauses: isHigh
                ? [
                    'High Hyperopia',
                    'Risk of Angle-Closure Glaucoma',
                    'Accommodative Esotropia',
                  ]
                : ['Hyperopia (far-sightedness)'],
            contributingTests: ['Mobile Refractometry'],
            recommendation: isHigh
                ? 'Gonioscopy recommended to assess angle-closure risk.'
                : 'Corrective lenses recommended.',
          ),
        );
      }

      // Astigmatism
      if (eye.refractiveErrorType == 'Astigmatism' || cyl >= 1.0) {
        final isSignificant = cyl >= 2.0;
        out.add(
          DetectedCondition(
            name: isSignificant
                ? 'Significant Astigmatism ($label Eye)'
                : 'Astigmatism ($label Eye)',
            category: ConditionCategory.refractive,
            severity: isSignificant
                ? ConditionSeverity.moderate
                : ConditionSeverity.informational,
            detectedSymptoms: [
              '$label eye cylinder: ${eye.cylinder}D, axis: ${eye.axis}°',
            ],
            possibleCauses: isSignificant
                ? ['Corneal Astigmatism', 'Keratoconus', 'Corneal Scarring']
                : ['Corneal Astigmatism', 'Lenticular Astigmatism'],
            contributingTests: ['Mobile Refractometry'],
            recommendation: isSignificant
                ? 'Corneal topography recommended to rule out Keratoconus.'
                : 'Corrective lenses with cylinder correction recommended.',
          ),
        );
      }

      // Presbyopia
      if (eye.refractiveErrorType == 'Presbyopia' || add >= 1.0) {
        out.add(
          DetectedCondition(
            name: 'Presbyopia ($label Eye)',
            category: ConditionCategory.refractive,
            severity: ConditionSeverity.informational,
            detectedSymptoms: ['$label eye add power: +${eye.addPower}D'],
            possibleCauses: ['Presbyopia (age-related loss of near focus)'],
            contributingTests: ['Mobile Refractometry'],
            recommendation:
                'Reading glasses or progressive lenses recommended.',
          ),
        );
      }
    }

    // Anisometropia check
    if (refr.rightEye != null && refr.leftEye != null) {
      final rSph = (double.tryParse(refr.rightEye!.sphere) ?? 0.0).abs();
      final lSph = (double.tryParse(refr.leftEye!.sphere) ?? 0.0).abs();
      if ((rSph - lSph).abs() >= 1.5) {
        out.add(
          DetectedCondition(
            name: 'Anisometropia',
            category: ConditionCategory.refractive,
            severity: ConditionSeverity.moderate,
            detectedSymptoms: [
              'Sphere difference: R ${refr.rightEye!.sphere}D vs L ${refr.leftEye!.sphere}D',
            ],
            possibleCauses: ['Anisometropia', 'Risk of Amblyopia'],
            contributingTests: ['Mobile Refractometry'],
            recommendation: 'Binocular vision assessment recommended.',
          ),
        );
      }
    }

    // Urgent referral from refractometry
    if (refr.requiresUrgentReferral) {
      out.add(
        const DetectedCondition(
          name: 'Urgent Refractive Referral',
          category: ConditionCategory.refractive,
          severity: ConditionSeverity.critical,
          detectedSymptoms: ['Refractometry flagged urgent referral'],
          possibleCauses: [
            'Pathological Myopia',
            'Significant Anisometropia',
            'Suspicious Findings',
          ],
          contributingTests: ['Mobile Refractometry'],
          recommendation: 'Urgent ophthalmologist consultation recommended.',
        ),
      );
    }

    // Myopic shift in elderly suggesting cataract
    if (age != null && age >= 50 && refr.rightEye != null) {
      final sphere = double.tryParse(refr.rightEye!.sphere) ?? 0.0;
      if (sphere < -2.0) {
        out.add(
          DetectedCondition(
            name: 'Possible Nuclear Sclerotic Cataract',
            category: ConditionCategory.surface,
            severity: ConditionSeverity.moderate,
            detectedSymptoms: [
              'Myopic shift in patient aged $age (sphere: ${refr.rightEye!.sphere}D)',
            ],
            possibleCauses: ['Nuclear Sclerotic Cataract causing myopic shift'],
            contributingTests: ['Mobile Refractometry', 'Patient Age'],
            recommendation: 'Slit-lamp examination to evaluate lens opacity.',
          ),
        );
      }
    }
  }

  // ─── 4. Color Vision ───────────────────────────────────────

  static void _analyzeColorVision(
    TestResultModel r,
    int? age,
    String? sex,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final cv = r.colorVision;
    if (cv == null) {
      return;
    }

    final isAbnormal = cv.overallStatus != ColorVisionStatus.normal;
    if (!isAbnormal) {
      return;
    }

    final dt = cv.deficiencyType;
    String conditionName;
    final causes = <String>[];

    switch (dt) {
      case DeficiencyType.protanopia:
        conditionName = 'Protanopia (Red-blindness)';
        causes.addAll(['Congenital X-linked red cone absence']);
        break;
      case DeficiencyType.protanomaly:
        conditionName = 'Protanomaly (Red-weakness)';
        causes.addAll(['Congenital X-linked red cone dysfunction']);
        break;
      case DeficiencyType.deuteranopia:
        conditionName = 'Deuteranopia (Green-blindness)';
        causes.addAll(['Congenital X-linked green cone absence']);
        break;
      case DeficiencyType.deuteranomaly:
        conditionName = 'Deuteranomaly (Green-weakness)';
        causes.addAll([
          'Congenital X-linked green cone dysfunction (most common CVD)',
        ]);
        break;
      case DeficiencyType.protan:
        conditionName = 'Protan Deficiency (Red axis)';
        causes.addAll(['Congenital protan defect']);
        break;
      case DeficiencyType.deutan:
        conditionName = 'Deutan Deficiency (Green axis)';
        causes.addAll(['Congenital deutan defect']);
        break;
      default:
        conditionName = 'Red-Green Color Vision Deficiency';
        causes.addAll(['Congenital Color Vision Deficiency']);
    }

    if (sex == 'male') {
      causes.add('X-linked inheritance (8% of males)');
    }
    if (age != null && age >= 50) {
      causes.addAll([
        'Acquired loss from Cataract',
        'Optic Neuritis',
        'Macular Disease',
      ]);
    }
    if (si?.hasDiabetes == true) {
      causes.add('Diabetic Retinopathy (acquired dyschromatopsia)');
    }

    out.add(
      DetectedCondition(
        name: conditionName,
        category: ConditionCategory.retinal,
        severity: cv.severity == DeficiencySeverity.severe
            ? ConditionSeverity.significant
            : ConditionSeverity.moderate,
        detectedSymptoms: [
          'Status: ${cv.overallStatus.displayName}',
          'Severity: ${cv.severity.displayName}',
          'Type: ${dt.displayName}',
        ],
        possibleCauses: causes,
        contributingTests: ['Color Vision (Ishihara)'],
        recommendation:
            'Comprehensive color vision assessment with anomaloscope if occupationally relevant.',
      ),
    );
  }

  // ─── 5. Amsler Grid ────────────────────────────────────────

  static void _analyzeAmslerGrid(
    TestResultModel r,
    int? age,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final right = r.amslerGridRight;
    final left = r.amslerGridLeft;
    if (right == null && left == null) {
      return;
    }

    for (final eye in [right, left]) {
      if (eye == null || eye.isNormal) {
        continue;
      }
      final label = eye.eye == 'right' ? 'Right' : 'Left';
      final symptoms = <String>[];
      final causes = <String>[];

      if (eye.hasDistortions) {
        symptoms.add('Metamorphopsia (wavy/distorted lines) in $label eye');
        causes.addAll([
          'Macular Edema',
          'Epiretinal Membrane',
          'Central Serous Retinopathy',
        ]);
      }
      if (eye.hasMissingAreas) {
        symptoms.add('Scotoma (missing areas) in $label eye');
        causes.addAll([
          'Macular Degeneration (AMD)',
          'Macular Hole',
          'Optic Nerve Disease',
        ]);
      }
      if (eye.hasBlurryAreas) {
        symptoms.add('Blurry areas in $label eye');
        causes.addAll(['Macular Edema', 'Vitreomacular Traction']);
      }
      if (eye.hasDistortions && eye.hasMissingAreas) {
        causes.addAll([
          'Wet (Neovascular) AMD',
          'Choroidal Neovascularization',
        ]);
      }
      if (age != null && age < 40) {
        causes.add('Multiple Sclerosis (Optic Neuritis)');
      }
      if (age != null && age >= 50) {
        causes.add('Age-Related Macular Degeneration');
      }
      if (si?.hasDiabetes == true) {
        causes.add('Diabetic Macular Edema');
      }
      if (si?.hasHypertension == true) {
        causes.add('Hypertensive Maculopathy');
      }

      out.add(
        DetectedCondition(
          name: 'Macular Abnormality ($label Eye)',
          category: ConditionCategory.retinal,
          severity: (eye.hasDistortions && eye.hasMissingAreas)
              ? ConditionSeverity.significant
              : ConditionSeverity.moderate,
          detectedSymptoms: symptoms,
          possibleCauses: causes.toSet().toList(),
          contributingTests: ['Amsler Grid'],
          recommendation:
              'OCT scan and fundoscopy recommended for macular evaluation.',
        ),
      );
    }
  }

  // ─── 6. Contrast Sensitivity ───────────────────────────────

  static void _analyzeContrastSensitivity(
    TestResultModel r,
    int? age,
    dynamic cc,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final pr = r.pelliRobson;
    if (pr == null) {
      return;
    }
    if (!pr.needsReferral) {
      return;
    }

    final causes = <String>['Cataract', 'Glaucoma', 'Corneal Opacity'];
    if (age != null && age >= 50) {
      causes.addAll(["Age-related Cataract", "Fuchs' Dystrophy"]);
    }
    if (si?.hasDiabetes == true) {
      causes.add('Diabetic Retinopathy (early sign)');
    }
    if (cc?.hasFamilyGlaucomaHistory == true) {
      causes.add('Progressive Glaucomatous Damage');
    }
    if (cc?.hasLightSensitivity == true) {
      causes.addAll(['Corneal Edema', 'Cataract with Glare']);
    }

    out.add(
      DetectedCondition(
        name: 'Contrast Sensitivity Loss',
        category: ConditionCategory.surface,
        severity: pr.overallCategory == 'Reduced'
            ? ConditionSeverity.significant
            : ConditionSeverity.moderate,
        detectedSymptoms: [
          'Overall category: ${pr.overallCategory}',
          'Average score: ${pr.averageScore.toStringAsFixed(2)} log CS',
        ],
        possibleCauses: causes.toSet().toList(),
        contributingTests: ['Pelli-Robson Contrast Sensitivity'],
        recommendation:
            'Comprehensive eye exam to identify cause of reduced contrast sensitivity.',
      ),
    );
  }

  // ─── 7. Shadow Test ────────────────────────────────────────

  static void _analyzeShadowTest(
    TestResultModel r,
    int? age,
    dynamic cc,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final st = r.shadowTest;
    if (st == null) {
      return;
    }

    final rGrade = st.rightEye.grade.grade;
    final lGrade = st.leftEye.grade.grade;
    final minGrade = rGrade < lGrade ? rGrade : lGrade;

    if (minGrade >= 3) {
      return; // Normal
    }

    final severity = minGrade == 0
        ? ConditionSeverity.critical
        : minGrade <= 1
        ? ConditionSeverity.significant
        : ConditionSeverity.moderate;

    final causes = <String>[];
    if (minGrade == 0) {
      causes.add('Angle-Closure Glaucoma (CRITICAL)');
    }
    if (minGrade <= 1) {
      causes.addAll(['Primary Angle-Closure Suspect', 'Plateau Iris Syndrome']);
    }
    if (minGrade == 2) {
      causes.add('Narrow Angle — risk of Acute Angle-Closure Crisis');
    }
    if (age != null && age >= 50) {
      causes.add('Primary Angle-Closure Glaucoma risk');
    }
    if (cc?.hasFamilyGlaucomaHistory == true) {
      causes.add('Familial Glaucoma (Genetic predisposition)');
    }

    out.add(
      DetectedCondition(
        name: minGrade == 0
            ? 'Closed Angle (CRITICAL)'
            : 'Narrow Anterior Chamber Angle',
        category: ConditionCategory.glaucoma,
        severity: severity,
        detectedSymptoms: [
          'Right eye: Grade $rGrade (${st.rightEye.grade.angleStatus})',
          'Left eye: Grade $lGrade (${st.leftEye.grade.angleStatus})',
          'Overall risk: ${st.overallRisk}',
        ],
        possibleCauses: causes,
        contributingTests: ['Shadow Test (Van Herick)'],
        recommendation: st.requiresReferral
            ? 'URGENT: Glaucoma specialist referral required immediately.'
            : 'Gonioscopy and IOP measurement recommended.',
      ),
    );
  }

  // ─── 8. Stereopsis ─────────────────────────────────────────

  static void _analyzeStereopsis(
    TestResultModel r,
    List<DetectedCondition> out,
  ) {
    final s = r.stereopsis;
    if (s == null) {
      return;
    }
    if (s.grade == StereopsisGrade.excellent ||
        s.grade == StereopsisGrade.good) {
      return;
    }

    final causes = <String>[];
    if (s.grade == StereopsisGrade.none) {
      causes.addAll([
        'Amblyopia',
        'Strabismus',
        'Monocular Vision',
        'Suppression',
      ]);
    } else if (s.grade == StereopsisGrade.poor) {
      causes.addAll(['Amblyopia', 'Microstrabismus', 'Aniseikonia']);
    } else {
      causes.addAll(['Mild Amblyopia', 'Decompensating Phoria']);
    }

    out.add(
      DetectedCondition(
        name: s.stereopsisPresent
            ? 'Reduced Binocular Vision'
            : 'Absent Stereopsis',
        category: ConditionCategory.alignment,
        severity: s.stereopsisPresent
            ? ConditionSeverity.moderate
            : ConditionSeverity.significant,
        detectedSymptoms: [
          'Grade: ${s.grade.label}',
          if (s.bestArc != null) 'Best arc: ${s.bestArc} seconds of arc',
          'Score: ${s.score}/${s.totalRounds}',
        ],
        possibleCauses: causes,
        contributingTests: ['Stereopsis Test'],
        recommendation:
            'Cover test and comprehensive binocular vision assessment recommended.',
      ),
    );
  }

  // ─── 9. Eye Hydration ──────────────────────────────────────

  static void _analyzeEyeHydration(
    TestResultModel r,
    int? age,
    String? sex,
    dynamic cc,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final eh = r.eyeHydration;
    if (eh == null || eh.status == EyeHydrationStatus.normal) {
      return;
    }

    final causes = <String>['Dry Eye Disease (DED)'];
    if (eh.status == EyeHydrationStatus.dryness) {
      causes.addAll(['Evaporative Dry Eye', 'Aqueous Deficient Dry Eye']);
      if (eh.averageBlinksPerMinute < 6) {
        causes.add('Risk of Corneal Erosion');
      }
    } else {
      causes.addAll([
        'Pre-clinical Dry Eye',
        'Meibomian Gland Dysfunction (MGD)',
      ]);
    }
    if (cc?.hasDryness == true) {
      causes.add('Confirmed symptomatic Dry Eye');
    }
    if (age != null && age >= 50 && sex == 'female') {
      causes.add('Hormonal Dry Eye (post-menopausal)');
    }
    if (si?.hasDiabetes == true) {
      causes.add('Diabetic Dry Eye (neuropathic)');
    }
    if (cc?.hasLightSensitivity == true) {
      causes.add('Chronic Dry Eye with Photophobia');
    }

    out.add(
      DetectedCondition(
        name: eh.status == EyeHydrationStatus.dryness
            ? 'Dry Eye Disease'
            : 'Pre-clinical Dry Eye',
        category: ConditionCategory.surface,
        severity: eh.status == EyeHydrationStatus.dryness
            ? ConditionSeverity.significant
            : ConditionSeverity.moderate,
        detectedSymptoms: [
          'Blink rate: ${eh.averageBlinksPerMinute.toStringAsFixed(1)}/min',
          'Total blinks: ${eh.blinkCount} in ${eh.totalTestTime.inSeconds}s',
        ],
        possibleCauses: causes.toSet().toList(),
        contributingTests: ['Eye Hydration (Blink Test)'],
        recommendation: 'Tear film assessment and dry eye workup recommended.',
      ),
    );
  }

  // ─── 10. Visual Field ──────────────────────────────────────

  static void _analyzeVisualField(
    TestResultModel r,
    int? age,
    dynamic cc,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    // Check per-eye or combined
    final results = <_VFData>[];
    if (r.visualFieldRight != null) {
      results.add(
        _VFData(
          'Right',
          r.visualFieldRight!.overallSensitivity,
          r.visualFieldRight!.quadrantSensitivity,
        ),
      );
    }
    if (r.visualFieldLeft != null) {
      results.add(
        _VFData(
          'Left',
          r.visualFieldLeft!.overallSensitivity,
          r.visualFieldLeft!.quadrantSensitivity,
        ),
      );
    }
    if (r.visualField != null) {
      results.add(
        _VFData(
          'Combined',
          r.visualField!.overallSensitivity,
          r.visualField!.quadrantSensitivity,
        ),
      );
    }
    if (results.isEmpty) {
      return;
    }

    for (final vf in results) {
      if (vf.sensitivity >= 0.90) {
        continue;
      }

      final causes = <String>[];
      ConditionSeverity severity;

      if (vf.sensitivity < 0.50) {
        severity = ConditionSeverity.significant;
        causes.addAll([
          'Advanced Glaucoma',
          'Optic Nerve Compression',
          'Stroke (visual pathway)',
        ]);
      } else if (vf.sensitivity < 0.75) {
        severity = ConditionSeverity.moderate;
        causes.addAll(['Open-Angle Glaucoma', 'Retinal Detachment']);
      } else {
        severity = ConditionSeverity.moderate;
        causes.addAll(['Early Glaucoma', 'Optic Nerve Disease']);
      }

      if (si?.hasDiabetes == true) {
        causes.add('Diabetic Retinopathy (ischemic field loss)');
      }
      if (si?.hasHypertension == true) {
        causes.addAll([
          'Hypertensive Retinopathy',
          'Branch Retinal Vein Occlusion',
        ]);
      }
      if (age != null && age >= 40) {
        causes.add('Primary Open-Angle Glaucoma');
      }
      if (cc?.hasFamilyGlaucomaHistory == true) {
        causes.add('Familial Glaucoma');
      }

      out.add(
        DetectedCondition(
          name: 'Peripheral Vision Loss (${vf.label} Eye)',
          category: ConditionCategory.glaucoma,
          severity: severity,
          detectedSymptoms: [
            'Overall sensitivity: ${(vf.sensitivity * 100).toStringAsFixed(0)}%',
          ],
          possibleCauses: causes.toSet().toList(),
          contributingTests: ['Visual Field (Perimetry)'],
          recommendation:
              'IOP measurement, optic nerve evaluation, and repeat visual field test recommended.',
        ),
      );
    }
  }

  // ─── 11. Cover Test ────────────────────────────────────────

  static void _analyzeCoverTest(
    TestResultModel r,
    int? age,
    dynamic cc,
    List<DetectedCondition> out,
  ) {
    final ct = r.coverTest;
    if (ct == null || !ct.hasDeviation) return;

    for (final entry in [
      {'status': ct.rightEyeStatus, 'label': 'Right'},
      {'status': ct.leftEyeStatus, 'label': 'Left'},
    ]) {
      final status = entry['status'] as AlignmentStatus;
      final label = entry['label'] as String;
      if (status == AlignmentStatus.normal ||
          status == AlignmentStatus.inconclusive) {
        continue;
      }

      final causes = <String>[];
      String condName;

      switch (status) {
        case AlignmentStatus.esotropia:
          condName = 'Esotropia ($label Eye)';
          causes.addAll([
            'Accommodative Esotropia',
            'Infantile Esotropia',
            'Sixth Nerve Palsy',
          ]);
          break;
        case AlignmentStatus.exotropia:
          condName = 'Exotropia ($label Eye)';
          causes.addAll([
            'Intermittent Exotropia',
            'Divergence Excess',
            'Sensory Exotropia',
          ]);
          break;
        case AlignmentStatus.hypertropia:
          condName = 'Hypertropia ($label Eye)';
          causes.addAll([
            'Superior Oblique Palsy (CN IV)',
            'Thyroid Eye Disease',
          ]);
          break;
        case AlignmentStatus.hypotropia:
          condName = 'Hypotropia ($label Eye)';
          causes.addAll(['Blowout Fracture', 'Brown Syndrome']);
          break;
        case AlignmentStatus.esophoria:
          condName = 'Esophoria ($label Eye)';
          causes.addAll(['Convergence Excess', 'Decompensating Phoria']);
          break;
        case AlignmentStatus.exophoria:
          condName = 'Exophoria ($label Eye)';
          causes.addAll(['Convergence Insufficiency']);
          break;
        default:
          condName = 'Eye Alignment Issue ($label Eye)';
          causes.add('Undetermined deviation');
      }

      if (age != null && age < 8) {
        causes.add('Amblyopia risk from Strabismus');
      }
      if (cc?.hasHeadache == true) {
        causes.add('Binocular Vision Dysfunction');
      }

      final isManifest =
          status == AlignmentStatus.esotropia ||
          status == AlignmentStatus.exotropia ||
          status == AlignmentStatus.hypertropia ||
          status == AlignmentStatus.hypotropia;

      out.add(
        DetectedCondition(
          name: condName,
          category: ConditionCategory.alignment,
          severity: isManifest
              ? ConditionSeverity.significant
              : ConditionSeverity.moderate,
          detectedSymptoms: ['$label eye: ${status.description}'],
          possibleCauses: causes,
          contributingTests: ['Cover Test'],
          recommendation: isManifest
              ? 'Referral to strabismus specialist recommended.'
              : 'Binocular vision assessment and possible vision therapy.',
        ),
      );
    }
  }

  // ─── 12. Torchlight ────────────────────────────────────────

  static void _analyzeTorchlight(
    TestResultModel r,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    final tl = r.torchlight;
    if (tl == null) return;

    final pup = tl.pupillary;
    final eom = tl.extraocular;

    if (pup != null) {
      // RAPD
      if (pup.rapdStatus == RAPDStatus.present) {
        out.add(
          const DetectedCondition(
            name: 'Relative Afferent Pupillary Defect (RAPD)',
            category: ConditionCategory.neurological,
            severity: ConditionSeverity.significant,
            detectedSymptoms: ['RAPD detected — asymmetric pupillary response'],
            possibleCauses: [
              'Optic Neuritis',
              'Optic Nerve Compression',
              'Retinal Detachment',
              'Asymmetric Glaucoma',
              'Multiple Sclerosis',
            ],
            contributingTests: ['Torchlight (Pupillary)'],
            recommendation: 'Urgent neuro-ophthalmic evaluation recommended.',
          ),
        );
      }

      // Anisocoria
      if (!pup.symmetric && (pup.anisocoriaDifference ?? 0) > 1.0) {
        out.add(
          DetectedCondition(
            name: 'Pathological Anisocoria',
            category: ConditionCategory.neurological,
            severity: ConditionSeverity.significant,
            detectedSymptoms: [
              if (pup.anisocoriaDifference != null)
                'Pupil difference: ${(pup.anisocoriaDifference ?? 0).toStringAsFixed(1)}mm',
              'Shape: L-${pup.leftShape.name} R-${pup.rightShape.name}',
            ],
            possibleCauses: [
              "Horner's Syndrome",
              'Third Nerve Palsy',
              "Adie's Tonic Pupil",
            ],
            contributingTests: ['Torchlight (Pupillary)'],
            recommendation: 'Neuro-ophthalmic evaluation recommended.',
          ),
        );
      }

      // Sluggish reflex
      if (pup.directReflex == LightReflex.sluggish ||
          pup.directReflex == LightReflex.absent) {
        out.add(
          DetectedCondition(
            name: 'Abnormal Light Reflex',
            category: ConditionCategory.neurological,
            severity: ConditionSeverity.moderate,
            detectedSymptoms: ['Direct reflex: ${pup.directReflex.name}'],
            possibleCauses: [
              'Optic Nerve Disease',
              'Iris Sphincter Damage',
              'CN III Palsy',
            ],
            contributingTests: ['Torchlight (Pupillary)'],
            recommendation: 'Further pupillary evaluation recommended.',
          ),
        );
      }

      // Irregular shape
      if (pup.leftShape != PupilShape.round ||
          pup.rightShape != PupilShape.round) {
        out.add(
          const DetectedCondition(
            name: 'Irregular Pupil Shape',
            category: ConditionCategory.surface,
            severity: ConditionSeverity.moderate,
            detectedSymptoms: ['Non-round pupil shape detected'],
            possibleCauses: [
              'Posterior Synechiae (iritis)',
              'Trauma',
              'Previous Surgery',
            ],
            contributingTests: ['Torchlight (Pupillary)'],
            recommendation: 'Slit-lamp examination recommended.',
          ),
        );
      }
    }

    if (eom != null) {
      // Nystagmus
      if (eom.nystagmusDetected) {
        out.add(
          const DetectedCondition(
            name: 'Nystagmus',
            category: ConditionCategory.neurological,
            severity: ConditionSeverity.significant,
            detectedSymptoms: [
              'Nystagmus detected during extraocular examination',
            ],
            possibleCauses: [
              'Vestibular Disease',
              'Cerebellar Lesion',
              'Congenital Nystagmus',
            ],
            contributingTests: ['Torchlight (Extraocular)'],
            recommendation: 'Neuro-ophthalmic referral recommended.',
          ),
        );
      }

      // Ptosis
      if (eom.ptosisDetected) {
        out.add(
          DetectedCondition(
            name: 'Ptosis',
            category: ConditionCategory.neurological,
            severity: ConditionSeverity.moderate,
            detectedSymptoms: [
              'Ptosis detected, affected eye: ${eom.ptosisEye?.name ?? "unknown"}',
            ],
            possibleCauses: [
              'Myasthenia Gravis',
              'CN III Palsy',
              "Horner's Syndrome",
              'Aponeurotic Ptosis',
            ],
            contributingTests: ['Torchlight (Extraocular)'],
            recommendation: 'Evaluate for neurogenic vs. myogenic cause.',
          ),
        );
      }

      // Cranial nerve involvement
      for (final cn in eom.affectedNerves) {
        String nerveName;
        List<String> causes;
        switch (cn) {
          case CranialNerve.cn3:
            nerveName = 'CN III (Oculomotor)';
            causes = ['Third Nerve Palsy', 'Aneurysm', 'Diabetes'];
            break;
          case CranialNerve.cn4:
            nerveName = 'CN IV (Trochlear)';
            causes = ['Superior Oblique Palsy', 'Congenital', 'Trauma'];
            break;
          case CranialNerve.cn6:
            nerveName = 'CN VI (Abducens)';
            causes = [
              'Sixth Nerve Palsy',
              'Raised Intracranial Pressure',
              'Diabetes',
              'Multiple Sclerosis',
            ];
            break;
        }
        out.add(
          DetectedCondition(
            name: '$nerveName Palsy',
            category: ConditionCategory.neurological,
            severity: ConditionSeverity.significant,
            detectedSymptoms: ['$nerveName involvement detected'],
            possibleCauses: causes,
            contributingTests: ['Torchlight (Extraocular)'],
            recommendation:
                'Urgent neuroimaging and neuro-ophthalmic referral.',
          ),
        );
      }

      // Restricted movements
      final hasRestriction = eom.movements.values.any(
        (m) => m != MovementQuality.full,
      );
      if (hasRestriction) {
        out.add(
          const DetectedCondition(
            name: 'Restricted Extraocular Movements',
            category: ConditionCategory.neurological,
            severity: ConditionSeverity.moderate,
            detectedSymptoms: ['Restricted eye movement detected'],
            possibleCauses: [
              "Thyroid Eye Disease (Graves')",
              'Orbital Floor Fracture',
              'Myasthenia Gravis',
            ],
            contributingTests: ['Torchlight (Extraocular)'],
            recommendation:
                'Orbital imaging and further evaluation recommended.',
          ),
        );
      }
    }
  }

  // ─── Questionnaire-Only ────────────────────────────────────

  static void _analyzeQuestionnaireOnly(
    dynamic cc,
    dynamic si,
    List<DetectedCondition> out,
  ) {
    if (cc == null) return;

    if (cc.hasRedness == true) {
      out.add(
        const DetectedCondition(
          name: 'Eye Redness (Reported)',
          category: ConditionCategory.surface,
          severity: ConditionSeverity.informational,
          detectedSymptoms: ['Patient reported eye redness'],
          possibleCauses: [
            'Conjunctivitis',
            'Uveitis/Iritis',
            'Subconjunctival Hemorrhage',
            'Episcleritis',
            'Acute Glaucoma',
          ],
          contributingTests: ['Pre-test Questionnaire'],
          recommendation:
              'Slit-lamp examination to determine cause of redness.',
        ),
      );
    }

    if (cc.hasStickyDischarge == true) {
      out.add(
        const DetectedCondition(
          name: 'Sticky Discharge (Reported)',
          category: ConditionCategory.surface,
          severity: ConditionSeverity.moderate,
          detectedSymptoms: ['Patient reported sticky discharge'],
          possibleCauses: [
            'Bacterial Conjunctivitis',
            'Dacryocystitis',
            'Chlamydial Conjunctivitis',
          ],
          contributingTests: ['Pre-test Questionnaire'],
          recommendation:
              'Clinical examination and possible culture/sensitivity testing.',
        ),
      );
    }

    if (cc.hasLightSensitivity == true) {
      out.add(
        const DetectedCondition(
          name: 'Photophobia (Reported)',
          category: ConditionCategory.surface,
          severity: ConditionSeverity.moderate,
          detectedSymptoms: ['Patient reported light sensitivity'],
          possibleCauses: [
            'Uveitis/Iritis',
            'Corneal Abrasion',
            'Migraine',
            'Acute Glaucoma',
          ],
          contributingTests: ['Pre-test Questionnaire'],
          recommendation:
              'Anterior segment examination to rule out inflammatory causes.',
        ),
      );
    }

    if (cc.hasPreviousCataractOperation == true) {
      out.add(
        const DetectedCondition(
          name: 'Post-Cataract Surgery',
          category: ConditionCategory.surface,
          severity: ConditionSeverity.informational,
          detectedSymptoms: ['History of cataract surgery'],
          possibleCauses: [
            'Posterior Capsular Opacification (PCO)',
            'Post-surgical Complications',
          ],
          contributingTests: ['Pre-test Questionnaire'],
          recommendation:
              'Monitor for PCO — YAG laser capsulotomy may be required if vision worsens.',
        ),
      );
    }

    if (cc.hasFamilyGlaucomaHistory == true) {
      out.add(
        const DetectedCondition(
          name: 'Family History of Glaucoma',
          category: ConditionCategory.glaucoma,
          severity: ConditionSeverity.informational,
          detectedSymptoms: ['Family member has glaucoma'],
          possibleCauses: ['Primary Open-Angle Glaucoma (4-9x increased risk)'],
          contributingTests: ['Pre-test Questionnaire'],
          recommendation:
              'Annual IOP measurement and optic nerve evaluation recommended.',
        ),
      );
    }

    // Systemic illness correlations
    if (si?.hasDiabetes == true) {
      out.add(
        const DetectedCondition(
          name: 'Diabetic Patient — Ocular Screening',
          category: ConditionCategory.systemic,
          severity: ConditionSeverity.informational,
          detectedSymptoms: ['Patient has diabetes'],
          possibleCauses: [
            'Diabetic Retinopathy',
            'Diabetic Macular Edema',
            'Neovascular Glaucoma',
          ],
          contributingTests: ['Pre-test Questionnaire'],
          recommendation: 'Annual dilated fundus examination mandatory.',
        ),
      );
    }

    if (si?.hasHypertension == true) {
      out.add(
        const DetectedCondition(
          name: 'Hypertensive Patient — Ocular Screening',
          category: ConditionCategory.systemic,
          severity: ConditionSeverity.informational,
          detectedSymptoms: ['Patient has hypertension'],
          possibleCauses: [
            'Hypertensive Retinopathy',
            'CRVO/BRVO',
            'Ischemic Optic Neuropathy',
          ],
          contributingTests: ['Pre-test Questionnaire'],
          recommendation:
              'Fundoscopy recommended to assess retinal vascular status.',
        ),
      );
    }
  }
}

// Helper class for visual field analysis
class _VFData {
  final String label;
  final double sensitivity;
  final Map<dynamic, double> quadrants;
  _VFData(this.label, this.sensitivity, this.quadrants);
}
