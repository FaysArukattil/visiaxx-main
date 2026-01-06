import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/patient_model.dart';

/// Service for managing patient data for practitioners
class PatientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection path for patients under a practitioner
  String _patientsPath(String practitionerId) =>
      'users/$practitionerId/patients';

  /// Get all patients for a practitioner
  Future<List<PatientModel>> getPatients(String practitionerId) async {
    try {
      debugPrint('[PatientService] Loading patients for: $practitionerId');

      final snapshot = await _firestore
          .collection(_patientsPath(practitionerId))
          .orderBy('createdAt', descending: true)
          .get();

      final patients = snapshot.docs
          .map((doc) => PatientModel.fromFirestore(doc))
          .toList();

      debugPrint('[PatientService] ✅ Loaded ${patients.length} patients');
      return patients;
    } catch (e) {
      debugPrint('[PatientService] ❌ Error loading patients: $e');
      rethrow;
    }
  }

  /// Get a single patient by ID
  Future<PatientModel?> getPatient(
    String practitionerId,
    String patientId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_patientsPath(practitionerId))
          .doc(patientId)
          .get();

      if (!doc.exists) return null;
      return PatientModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[PatientService] ❌ Error getting patient: $e');
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

      final collectionRef = _firestore.collection(
        _patientsPath(practitionerId),
      );

      if (patient.id.isEmpty ||
          patient.id == DateTime.now().millisecondsSinceEpoch.toString()) {
        // New patient - create with auto-generated ID
        final docRef = await collectionRef.add(patient.toFirestore());
        debugPrint('[PatientService] ✅ Created patient with ID: ${docRef.id}');
        return docRef.id;
      } else {
        // Update existing patient
        await collectionRef.doc(patient.id).set(patient.toFirestore());
        debugPrint('[PatientService] ✅ Updated patient: ${patient.id}');
        return patient.id;
      }
    } catch (e) {
      debugPrint('[PatientService] ❌ Error saving patient: $e');
      rethrow;
    }
  }

  /// Delete a patient
  Future<void> deletePatient(String practitionerId, String patientId) async {
    try {
      debugPrint('[PatientService] Deleting patient: $patientId');

      await _firestore
          .collection(_patientsPath(practitionerId))
          .doc(patientId)
          .delete();

      debugPrint('[PatientService] ✅ Deleted patient: $patientId');
    } catch (e) {
      debugPrint('[PatientService] ❌ Error deleting patient: $e');
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
      debugPrint('[PatientService] ❌ Error searching patients: $e');
      rethrow;
    }
  }
}
