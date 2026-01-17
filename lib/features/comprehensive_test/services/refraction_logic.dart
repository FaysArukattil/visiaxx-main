/// Legacy wrapper for refraction calculations
/// Most logic now handled by AdvancedRefractionService
class RefractionLogic {
  /// Map visual threshold (blur level) to Sphere power (SPH)
  static double calculateSphereFromThreshold(double threshold) {
    if (threshold >= 6.5) return 0.00;
    if (threshold >= 6.0) return -0.25;
    if (threshold >= 5.5) return -0.50;
    if (threshold >= 5.0) return -0.75;
    if (threshold >= 4.5) return -1.00;
    if (threshold >= 4.0) return -1.25;
    if (threshold >= 3.5) return -1.50;
    if (threshold >= 3.0) return -1.75;
    if (threshold >= 2.5) return -2.00;
    if (threshold >= 2.0) return -2.50;
    if (threshold >= 1.5) return -3.00;
    if (threshold >= 1.0) return -4.00;
    return -6.00;
  }

  /// Calculate Latent Hyperopia adjustment for young patients
  static double calculateAccommodationAdjustment(
    int age,
    double sphere,
    double accuracy,
  ) {
    if (age < 35 && sphere == 0.0 && accuracy > 0.95) {
      if (age < 20) return 0.75;
      if (age < 25) return 0.50;
      if (age < 35) return 0.25;
    }
    return 0.0;
  }

  /// Calculate Cylinder (Astigmatism) from directional accuracy
  static Map<String, dynamic> calculateCylinder(
    double hAccuracy,
    double vAccuracy,
  ) {
    final diff = (hAccuracy - vAccuracy).abs();
    double cylinder = 0.0;
    int axis = 0;

    if (diff >= 0.50) {
      cylinder = -2.00;
    } else if (diff >= 0.40) {
      cylinder = -1.50;
    } else if (diff >= 0.30) {
      cylinder = -1.00;
    } else if (diff >= 0.20) {
      cylinder = -0.75;
    } else if (diff >= 0.12) {
      cylinder = -0.50;
    } else if (diff >= 0.08) {
      cylinder = -0.25;
    }

    if (cylinder < 0) {
      axis = vAccuracy < hAccuracy ? 180 : 90;
    }

    return {'cylinder': cylinder, 'axis': axis};
  }

  /// Refine ADD power based on near test performance
  static double refineAddPower(double baseAdd, double nearAccuracy) {
    if (nearAccuracy < 0.70) return baseAdd + 0.50;
    if (nearAccuracy > 0.90) return baseAdd - 0.50;
    return baseAdd;
  }

  /// Final AI evaluation and disease screening
  static Map<String, dynamic> screenForPathology(
    double accuracy,
    int cantSeeCount,
    int age,
  ) {
    List<Map<String, dynamic>> risks = [];
    bool critical = false;

    if (accuracy == 0) {
      critical = true;
      risks.add({
        'conditionName': 'NLP',
        'riskLevel': 'high',
        'confidenceScore': 0.9,
        'recommendation': 'Emergency ophthalmic consult',
      });
    } else if (accuracy < 0.10 && cantSeeCount >= 6) {
      critical = true;
      risks.add({
        'conditionName': 'LPO',
        'riskLevel': 'high',
        'confidenceScore': 0.85,
        'recommendation': 'Urgent ophthalmic consult',
      });
    }

    if (age >= 50 && accuracy < 0.50) {
      risks.add({
        'conditionName': 'ARMD/Cataract',
        'riskLevel': 'medium',
        'confidenceScore': 0.7,
        'recommendation': 'Fundus and slit lamp exam',
      });
    }

    return {
      'criticalAlert': critical,
      'identifiedRisks': risks,
      'interpretation': critical
          ? 'Urgent attention required'
          : (risks.isNotEmpty
                ? 'Follow-up recommended'
                : 'Vision within expected range'),
    };
  }
}
