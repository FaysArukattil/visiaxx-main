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
  }) async {
    try {
      debugPrint('[PatientService] Saving patient: ${patient.firstName}');
      final path = await _patientsPath(practitionerId);

      final collectionRef = _firestore.collection(path);

      // Use descriptive IdentityString for the document ID
      final identity = patient.identityString;

      await collectionRef.doc(identity).set(patient.toFirestore());
      debugPrint('[PatientService] … Saved patient with ID: $identity');
      return identity;
    } catch (e) {
      debugPrint('[PatientService] Œ Error saving patient: $e');
      rethrow;
    }
  }

  /// Delete a patient
  Future<void> deletePatient(String practitionerId, String patientId) async {
    try {
      debugPrint('[PatientService] Deleting patient: $patientId');
      final path = await _patientsPath(practitionerId);

      await _firestore.collection(path).doc(patientId).delete();

      debugPrint('[PatientService] … Deleted patient: $patientId');
    } catch (e) {
      debugPrint('[PatientService] Œ Error deleting patient: $e');
      rethrow;
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

