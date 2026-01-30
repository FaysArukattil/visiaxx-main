import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import '../../data/models/patient_model.dart';

/// Service for managing patient data for practitioners
class PatientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the organized collection path for patients under a practitioner
  Future<String> _patientsPath(String practitionerId) async {
    final authService = AuthService();
    final practitioner = await authService.getUserData(practitionerId);
    if (practitioner == null) {
      // Fallback for safety, though it shouldn't be hit with correct usage
      return 'Practitioners/$practitionerId/patients';
    }
    return 'Practitioners/${practitioner.identityString}/patients';
  }

  /// Get all patients for a practitioner
  Future<List<PatientModel>> getPatients(String practitionerId) async {
    try {
      debugPrint('[PatientService] Loading patients for: $practitionerId');
      final path = await _patientsPath(practitionerId);

      final snapshot = await _firestore
          .collection(path)
          .orderBy('createdAt', descending: true)
          .get();

      final patients = snapshot.docs
          .map((doc) => PatientModel.fromFirestore(doc))
          .where((p) => !p.isDeleted)
          .toList();

      debugPrint('[PatientService] … Loaded ${patients.length} patients');
      return patients;
    } catch (e) {
      debugPrint('[PatientService] Œ Error loading patients: $e');
      rethrow;
    }
  }

  /// Get a single patient by ID
  Future<PatientModel?> getPatient(
    String practitionerId,
    String patientId,
  ) async {
    try {
      final path = await _patientsPath(practitionerId);
      final doc = await _firestore.collection(path).doc(patientId).get();

      if (!doc.exists) return null;
      return PatientModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[PatientService] Œ Error getting patient: $e');
      rethrow;
    }
  }

  /// Save a new patient or update existing one
  Future<String> savePatient({
    required String practitionerId,
    required PatientModel patient,
    String? oldIdentity,
  }) async {
    try {
      debugPrint('[PatientService] Saving patient: ${patient.firstName}');
      final path = await _patientsPath(practitionerId);
      final collectionRef = _firestore.collection(path);

      // Extract stable ID from old identity or use current ID
      // This ensures the identityString always ends with the same stable UUID
      String stableId = patient.id;
      if (oldIdentity != null && oldIdentity.contains('_')) {
        stableId = oldIdentity.split('_').last;
      }

      // Re-create patient model with the stable ID for identity generation
      final patientToSave = patient.copyWith(id: stableId);
      final newIdentity = patientToSave.identityString;

      if (oldIdentity != null && oldIdentity != newIdentity) {
        debugPrint(
          '[PatientService] Identity changed from $oldIdentity to $newIdentity. Migrating data...',
        );

        // 1. Migrate test results and update metadata
        await _migratePatientTests(
          practitionerId: practitionerId,
          oldIdentity: oldIdentity,
          newIdentity: newIdentity,
          newName: patientToSave.fullName,
          newAge: patientToSave.age,
          newSex: patientToSave.sex,
        );

        // 2. Migrate questionnaires subcollection
        await _migratePatientQuestionnaires(
          practitionerId: practitionerId,
          oldIdentity: oldIdentity,
          newIdentity: newIdentity,
        );

        // 3. Delete old document to avoid duplicates
        await collectionRef.doc(oldIdentity).delete();
      }

      await collectionRef.doc(newIdentity).set(patientToSave.toFirestore());
      debugPrint('[PatientService] … Saved patient with ID: $newIdentity');
      return newIdentity;
    } catch (e) {
      debugPrint('[PatientService]  Œ Error saving patient: $e');
      rethrow;
    }
  }

  /// Delete a patient
  Future<void> deletePatient(String practitionerId, String patientId) async {
    try {
      debugPrint('[PatientService] Soft deleting patient: $patientId');
      final path = await _patientsPath(practitionerId);

      await _firestore.collection(path).doc(patientId).update({
        'isDeleted': true,
      });

      debugPrint('[PatientService] … Soft deleted patient: $patientId');
    } catch (e) {
      debugPrint('[PatientService]  Œ Error deleting patient: $e');
      rethrow;
    }
  }

  /// Migrates all test results for a patient when their name/identity changes
  Future<void> _migratePatientTests({
    required String practitionerId,
    required String oldIdentity,
    required String newIdentity,
    required String newName,
    required int newAge,
    required String newSex,
  }) async {
    try {
      // Find all results across the DB using collectionGroup
      // but filtered by the current practitioner and the old patient identity
      final snapshot = await _firestore
          .collectionGroup('tests')
          .where('userId', isEqualTo: practitionerId)
          .where('profileId', isEqualTo: oldIdentity)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[PatientService] No test results found for migration');
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final oldPath = doc.reference.path;
        final data = doc.data();

        // Update identification fields in the data
        data['profileId'] = newIdentity;
        data['profileName'] = newName;
        data['profileAge'] = newAge;
        data['profileSex'] = newSex;

        // Check if the result is nested under the old patient path
        if (oldPath.contains('/patients/$oldIdentity/tests/')) {
          final newPath = oldPath.replaceFirst(
            '/patients/$oldIdentity/tests/',
            '/patients/$newIdentity/tests/',
          );
          batch.set(_firestore.doc(newPath), data);
          batch.delete(doc.reference);
        } else {
          // Just update the fields in the existing location
          batch.update(doc.reference, {
            'profileId': newIdentity,
            'profileName': newName,
            'profileAge': newAge,
            'profileSex': newSex,
          });
        }
      }
      await batch.commit();
      debugPrint(
        '[PatientService] Migrated ${snapshot.docs.length} test results',
      );
    } catch (e) {
      debugPrint('[PatientService] Error migrating tests: $e');
    }
  }

  /// Migrates questionnaires and ensures they are linked to the new identity
  Future<void> _migratePatientQuestionnaires({
    required String practitionerId,
    required String oldIdentity,
    required String newIdentity,
  }) async {
    try {
      final basePath = await _patientsPath(practitionerId);
      final oldPath = '$basePath/$oldIdentity/questionnaires';
      final newPath = '$basePath/$newIdentity/questionnaires';

      final snapshot = await _firestore.collection(oldPath).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.set(_firestore.collection(newPath).doc(doc.id), doc.data());
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint(
        '[PatientService] Migrated ${snapshot.docs.length} questionnaires',
      );
    } catch (e) {
      debugPrint('[PatientService] Error migrating questionnaires: $e');
    }
  }

  /// Search patients by name
  Future<List<PatientModel>> searchPatients(
    String practitionerId,
    String query,
  ) async {
    try {
      final patients = await getPatients(practitionerId);
      final lowerQuery = query.toLowerCase();

      return patients.where((patient) {
        return patient.firstName.toLowerCase().contains(lowerQuery) ||
            (patient.lastName?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      debugPrint('[PatientService] Œ Error searching patients: $e');
      rethrow;
    }
  }
}
