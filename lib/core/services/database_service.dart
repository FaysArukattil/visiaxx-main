import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/patient_model.dart';
import '../../data/models/test_result_model.dart';
import 'auth_service.dart';

/// Service for database queries and analytics for practitioners
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Get all patients for a practitioner
  Future<List<PatientModel>> getPractitionerPatients(
    String practitionerId,
  ) async {
    try {
      final userModel = await _authService.getUserData(practitionerId);
      if (userModel == null) return [];

      final identity = userModel.identityString;

      final snapshot = await _firestore
          .collection('Practitioners')
          .doc(identity)
          .collection('patients')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PatientModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[DatabaseService] Error fetching patients: $e');
      return [];
    }
  }

  /// Get all test results for practitioner's patients with date filtering
  Future<List<TestResultModel>> getPractitionerTestResults({
    required String practitionerId,
    DateTime? startDate,
    DateTime? endDate,
    String? patientId,
  }) async {
    try {
      final userModel = await _authService.getUserData(practitionerId);
      if (userModel == null) return [];

      final identity = userModel.identityString;
      final List<TestResultModel> allResults = [];

      // Get all patients or specific patient
      List<String> patientIds;
      if (patientId != null) {
        patientIds = [patientId];
      } else {
        final patients = await getPractitionerPatients(practitionerId);
        patientIds = patients.map((p) => p.id).toList();
      }

      // Fetch results for each patient
      for (final pId in patientIds) {
        Query query = _firestore
            .collection('Practitioners')
            .doc(identity)
            .collection('patients')
            .doc(pId)
            .collection('tests')
            .orderBy('timestamp', descending: true);

        // Apply date filters
        if (startDate != null) {
          query = query.where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          );
        }
        if (endDate != null) {
          query = query.where(
            'timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          );
        }

        final snapshot = await query.get();

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          allResults.add(TestResultModel.fromJson(data));
        }
      }

      // Sort all results by timestamp
      allResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allResults;
    } catch (e) {
      debugPrint('[DatabaseService] Error fetching test results: $e');
      return [];
    }
  }

  /// Get test statistics for dashboard
  Future<Map<String, dynamic>> getTestStatistics({
    required String practitionerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final results = await getPractitionerTestResults(
        practitionerId: practitionerId,
        startDate: startDate,
        endDate: endDate,
      );

      // Count by refractive errors and conditions
      final Map<String, int> conditionCounts = {
        'Normal': 0,
        'Myopia': 0,
        'Hyperopia': 0,
        'Astigmatism': 0,
        'Presbyopia': 0,
        'Cataract': 0,
        'Macular Issue': 0,
        'Color Vision Deficiency': 0,
        'Vision Impairment': 0,
        'Low Contrast Sensitivity': 0,
      };

      final Map<String, int> statusCounts = {
        'normal': 0,
        'review': 0,
        'urgent': 0,
      };

      for (final result in results) {
        // Count status
        statusCounts[result.overallStatus.name] =
            (statusCounts[result.overallStatus.name] ?? 0) + 1;

        // Analyze conditions based on test results
        bool hasCondition = false;

        // Check for refractive errors from mobile refractometry
        if (result.mobileRefractometry != null) {
          final refrac = result.mobileRefractometry!;

          // Safely parse sphere and cylinder values
          double rightSphere = 0.0;
          double leftSphere = 0.0;
          double rightCyl = 0.0;
          double leftCyl = 0.0;

          if (refrac.rightEye != null) {
            rightSphere = double.tryParse(refrac.rightEye!.sphere) ?? 0.0;
            rightCyl = double.tryParse(refrac.rightEye!.cylinder) ?? 0.0;
          }

          if (refrac.leftEye != null) {
            leftSphere = double.tryParse(refrac.leftEye!.sphere) ?? 0.0;
            leftCyl = double.tryParse(refrac.leftEye!.cylinder) ?? 0.0;
          }

          if (rightSphere < -0.5 || leftSphere < -0.5) {
            conditionCounts['Myopia'] = (conditionCounts['Myopia'] ?? 0) + 1;
            hasCondition = true;
          }

          if (rightSphere > 0.5 || leftSphere > 0.5) {
            conditionCounts['Hyperopia'] =
                (conditionCounts['Hyperopia'] ?? 0) + 1;
            hasCondition = true;
          }

          if (rightCyl.abs() > 0.5 || leftCyl.abs() > 0.5) {
            conditionCounts['Astigmatism'] =
                (conditionCounts['Astigmatism'] ?? 0) + 1;
            hasCondition = true;
          }
        }

        // Check for common conditions using the standard dashboard logic
        final conditions = _getDashboardConditions(result);
        for (final condition in conditions) {
          if (condition != 'Normal') {
            conditionCounts[condition] = (conditionCounts[condition] ?? 0) + 1;
            hasCondition = true;
          }
        }

        if (!hasCondition) {
          conditionCounts['Normal'] = (conditionCounts['Normal'] ?? 0) + 1;
        }
      }

      return {
        'totalTests': results.length,
        'conditionCounts': conditionCounts,
        'statusCounts': statusCounts,
        'uniquePatients': results.map((r) => r.profileId).toSet().length,
      };
    } catch (e) {
      debugPrint('[DatabaseService] Error calculating statistics: $e');
      return {
        'totalTests': 0,
        'conditionCounts': <String, int>{},
        'statusCounts': <String, int>{},
        'uniquePatients': 0,
      };
    }
  }

  /// Helper to get conditions for dashboard statistics
  List<String> _getDashboardConditions(TestResultModel result) {
    final conditions = <String>[];

    // Reproduce logic from dashboard _getAllResultConditions
    final rightLogMAR = result.visualAcuityRight?.logMAR ?? 0;
    final leftLogMAR = result.visualAcuityLeft?.logMAR ?? 0;
    final worseLogMAR = rightLogMAR > leftLogMAR ? rightLogMAR : leftLogMAR;
    if (worseLogMAR > 0.3) conditions.add('Vision Impairment');

    if (result.colorVision != null && !result.colorVision!.isNormal) {
      conditions.add('Color Vision Deficiency');
    }

    if ((result.amslerGridRight?.hasDistortions ?? false) ||
        (result.amslerGridLeft?.hasDistortions ?? false)) {
      conditions.add('Macular Issue');
      final rightDistortions =
          result.amslerGridRight?.distortionPoints.length ?? 0;
      final leftDistortions =
          result.amslerGridLeft?.distortionPoints.length ?? 0;
      if (rightDistortions >= 5 || leftDistortions >= 5) {
        conditions.add('Cataract');
      }
    }

    if (result.pelliRobson != null && result.pelliRobson!.needsReferral) {
      conditions.add('Low Contrast Sensitivity');
    }

    if (result.mobileRefractometry != null) {
      final rightAdd =
          double.tryParse(
            result.mobileRefractometry!.rightEye?.addPower ?? '0',
          ) ??
          0;
      final leftAdd =
          double.tryParse(
            result.mobileRefractometry!.leftEye?.addPower ?? '0',
          ) ??
          0;
      if (rightAdd > 0.75 || leftAdd > 0.75) conditions.add('Presbyopia');
    }

    return conditions;
  }

  /// Get daily test counts for graph (last 30 days)
  Future<Map<DateTime, int>> getDailyTestCounts({
    required String practitionerId,
    required int days,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final results = await getPractitionerTestResults(
        practitionerId: practitionerId,
        startDate: startDate,
        endDate: endDate,
      );

      // Group by date
      final Map<DateTime, int> dailyCounts = {};

      for (final result in results) {
        final date = DateTime(
          result.timestamp.year,
          result.timestamp.month,
          result.timestamp.day,
        );
        dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
      }

      return dailyCounts;
    } catch (e) {
      debugPrint('[DatabaseService] Error getting daily counts: $e');
      return {};
    }
  }

  /// Get patient details with their latest test
  Future<Map<String, dynamic>?> getPatientWithLatestTest({
    required String practitionerId,
    required String patientId,
  }) async {
    try {
      final userModel = await _authService.getUserData(practitionerId);
      if (userModel == null) return null;

      final identity = userModel.identityString;

      // Get patient details
      final patientDoc = await _firestore
          .collection('Practitioners')
          .doc(identity)
          .collection('patients')
          .doc(patientId)
          .get();

      if (!patientDoc.exists) return null;

      final patient = PatientModel.fromFirestore(patientDoc);

      // Get latest test
      final testsSnapshot = await _firestore
          .collection('Practitioners')
          .doc(identity)
          .collection('patients')
          .doc(patientId)
          .collection('tests')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      TestResultModel? latestTest;
      if (testsSnapshot.docs.isNotEmpty) {
        final data = testsSnapshot.docs.first.data();
        data['id'] = testsSnapshot.docs.first.id;
        latestTest = TestResultModel.fromJson(data);
      }

      return {'patient': patient, 'latestTest': latestTest};
    } catch (e) {
      debugPrint('[DatabaseService] Error fetching patient details: $e');
      return null;
    }
  }

  /// Search patients by name or phone
  Future<List<PatientModel>> searchPatients({
    required String practitionerId,
    required String query,
  }) async {
    try {
      final allPatients = await getPractitionerPatients(practitionerId);

      if (query.isEmpty) return allPatients;

      final lowercaseQuery = query.toLowerCase();

      return allPatients.where((patient) {
        final fullName = patient.fullName.toLowerCase();
        final phone = patient.phone?.toLowerCase() ?? '';

        return fullName.contains(lowercaseQuery) ||
            phone.contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      debugPrint('[DatabaseService] Error searching patients: $e');
      return [];
    }
  }
}
