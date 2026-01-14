import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/mobile_refractometry_result.dart';
import '../../data/models/refraction_prescription_model.dart';

/// Service for calculating and managing refraction prescriptions
class RefractionPrescriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate subjective refraction from mobile refractometry result
  SubjectiveRefractionData calculateSubjectiveRefraction(
    MobileRefractometryEyeResult mrResult,
  ) {
    // Map sphere directly
    final sph = mrResult.sphere;

    // Map cylinder directly
    final cyl = mrResult.cylinder;

    // Map axis directly
    final axis = '${mrResult.axis}';

    // Estimate visual acuity (vn) based on accuracy
    final accuracy = double.tryParse(mrResult.accuracy) ?? 0.0;
    final vn = _estimateVisualAcuity(accuracy);

    // Prism requires specialized testing, default to 0.00
    const prism = '0.00';

    // Map add power directly
    final add = mrResult.addPower;

    return SubjectiveRefractionData(
      sph: sph,
      cyl: cyl,
      axis: axis,
      vn: vn,
      prism: prism,
      add: add,
    );
  }

  /// Estimate visual acuity from test accuracy percentage
  String _estimateVisualAcuity(double accuracy) {
    // Convert accuracy (0-100) to visual acuity estimation
    if (accuracy >= 95) return '6/6'; // 20/20
    if (accuracy >= 85) return '6/7.5'; // 20/25
    if (accuracy >= 75) return '6/9'; // 20/30
    if (accuracy >= 65) return '6/12'; // 20/40
    if (accuracy >= 55) return '6/15'; // 20/50
    if (accuracy >= 45) return '6/18'; // 20/60
    if (accuracy >= 35) return '6/24'; // 20/80
    if (accuracy >= 25) return '6/30'; // 20/100
    return '6/60'; // 20/200
  }

  /// Calculate final prescription combining both eyes
  FinalPrescriptionData calculateFinalPrescription(
    SubjectiveRefractionData right,
    SubjectiveRefractionData left,
  ) {
    // For final prescription, typically use the subjective refraction values
    // In some cases, we might balance or adjust, but for now we use them as-is
    return FinalPrescriptionData(right: right, left: left);
  }

  /// Compare predicted vs actual prescriptions for ML training
  Map<String, dynamic> comparePrescriptions(
    SubjectiveRefractionData predicted,
    SubjectiveRefractionData actual,
  ) {
    final sphDiff = _calculateDiopterDifference(predicted.sph, actual.sph);
    final cylDiff = _calculateDiopterDifference(predicted.cyl, actual.cyl);
    final axisDiff = _calculateAxisDifference(predicted.axis, actual.axis);
    final addDiff = _calculateDiopterDifference(predicted.add, actual.add);

    return {
      'sphDifference': sphDiff,
      'cylDifference': cylDiff,
      'axisDifference': axisDiff,
      'addDifference': addDiff,
      'totalError': math.sqrt(
        sphDiff * sphDiff +
            cylDiff * cylDiff +
            (axisDiff / 180) * (axisDiff / 180),
      ),
    };
  }

  /// Calculate difference between two diopter values
  double _calculateDiopterDifference(String value1, String value2) {
    final val1 = double.tryParse(value1.replaceAll('+', '')) ?? 0.0;
    final val2 = double.tryParse(value2.replaceAll('+', '')) ?? 0.0;
    return (val1 - val2).abs();
  }

  /// Calculate difference between two axis values (considering circular nature)
  double _calculateAxisDifference(String axis1, String axis2) {
    final a1 = double.tryParse(axis1) ?? 0.0;
    final a2 = double.tryParse(axis2) ?? 0.0;

    // Calculate the minimum difference considering circular nature (0° = 180°)
    var diff = (a1 - a2).abs();
    if (diff > 90) {
      diff = 180 - diff;
    }
    return diff;
  }

  /// Save prescription to Firebase
  Future<void> savePrescriptionToFirebase(
    String userId,
    String testResultId,
    RefractionPrescriptionModel prescription,
  ) async {
    try {
      debugPrint(
        '[RefractionService] 💾 Saving prescription for test: $testResultId',
      );

      // Get user's identity string for collection path
      final userDoc = await _firestore
          .collection('all_users_lookup')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found in lookup');
      }

      final identityString = userDoc.data()!['identityString'] as String;

      // Save to refractionPrescriptions subcollection
      await _firestore
          .collection('IdentifiedResults')
          .doc(identityString)
          .collection('tests')
          .doc(testResultId)
          .collection('refractionPrescriptions')
          .doc('prescription')
          .set(prescription.toFirestore());

      debugPrint('[RefractionService] ✅ Prescription saved successfully');
    } catch (e) {
      debugPrint('[RefractionService] ❌ Error saving prescription: $e');
      rethrow;
    }
  }

  /// Get prescription for a test result
  Future<RefractionPrescriptionModel?> getPrescription(
    String userId,
    String testResultId,
  ) async {
    try {
      debugPrint(
        '[RefractionService] 📖 Fetching prescription for test: $testResultId',
      );

      // Get user's identity string
      final userDoc = await _firestore
          .collection('all_users_lookup')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('[RefractionService] ⚠️ User not found in lookup');
        return null;
      }

      final identityString = userDoc.data()!['identityString'] as String;

      // Get prescription document
      final prescriptionDoc = await _firestore
          .collection('IdentifiedResults')
          .doc(identityString)
          .collection('tests')
          .doc(testResultId)
          .collection('refractionPrescriptions')
          .doc('prescription')
          .get();

      if (!prescriptionDoc.exists) {
        debugPrint('[RefractionService] ℹ️ No prescription found');
        return null;
      }

      final prescription = RefractionPrescriptionModel.fromMap(
        prescriptionDoc.data()!,
      );

      debugPrint('[RefractionService] ✅ Prescription retrieved');
      return prescription;
    } catch (e) {
      debugPrint('[RefractionService] ❌ Error fetching prescription: $e');
      return null;
    }
  }

  /// Create initial prescription with auto-calculated suggestions
  RefractionPrescriptionModel createInitialPrescription(
    MobileRefractometryResult mrResult,
    String practitionerId,
    String practitionerName,
  ) {
    // Calculate subjective refraction for both eyes
    final predictedRight = mrResult.rightEye != null
        ? calculateSubjectiveRefraction(mrResult.rightEye!)
        : SubjectiveRefractionData.empty();

    final predictedLeft = mrResult.leftEye != null
        ? calculateSubjectiveRefraction(mrResult.leftEye!)
        : SubjectiveRefractionData.empty();

    // Use predictions as initial values (practitioner will edit)
    final rightEyeSubjective = predictedRight;
    final leftEyeSubjective = predictedLeft;

    // Calculate final prescription
    final finalPrescription = calculateFinalPrescription(
      rightEyeSubjective,
      leftEyeSubjective,
    );

    return RefractionPrescriptionModel(
      rightEyeSubjective: rightEyeSubjective,
      leftEyeSubjective: leftEyeSubjective,
      finalPrescription: finalPrescription,
      predictedRight: predictedRight,
      predictedLeft: predictedLeft,
      includeInResults: true, // Auto-checked
      hasManualEdits: false, // Will be set to true when practitioner edits
      practitionerId: practitionerId,
      practitionerName: practitionerName,
    );
  }

  /// Update prescription with manual edits and calculate accuracy metrics
  RefractionPrescriptionModel updateWithManualEdits(
    RefractionPrescriptionModel original,
    SubjectiveRefractionData editedRight,
    SubjectiveRefractionData editedLeft,
  ) {
    // Calculate accuracy metrics
    final rightDiff = comparePrescriptions(
      original.predictedRight,
      editedRight,
    );
    final leftDiff = comparePrescriptions(original.predictedLeft, editedLeft);

    final accuracyMetrics = {
      'rightEyeDiff': rightDiff,
      'leftEyeDiff': leftDiff,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Recalculate final prescription with edited values
    final finalPrescription = calculateFinalPrescription(
      editedRight,
      editedLeft,
    );

    return original.copyWith(
      rightEyeSubjective: editedRight,
      leftEyeSubjective: editedLeft,
      finalPrescription: finalPrescription,
      hasManualEdits: true,
      accuracyMetrics: accuracyMetrics,
    );
  }
}
