import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/questionnaire_model.dart';
import 'auth_service.dart';

/// Service for managing patient-linked questionnaires
/// Stores questionnaires as a subcollection under patient documents
class PatientQuestionnaireService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the organized collection path for patient questionnaires
  Future<String> _questionnairePath(
    String practitionerId,
    String patientId,
  ) async {
    final authService = AuthService();
    final practitioner = await authService.getUserData(practitionerId);
    if (practitioner == null) {
      return 'Practitioners/$practitionerId/patients/$patientId/questionnaires';
    }
    return 'Practitioners/${practitioner.identityString}/patients/$patientId/questionnaires';
  }

  /// Save a new questionnaire for a patient
  /// Returns the saved questionnaire ID
  Future<String> savePatientQuestionnaire({
    required String practitionerId,
    required String patientId,
    required QuestionnaireModel questionnaire,
  }) async {
    try {
      debugPrint(
        '[PatientQuestionnaireService] Saving questionnaire for patient: $patientId',
      );

      final path = await _questionnairePath(practitionerId, patientId);
      final collectionRef = _firestore.collection(path);

      // Save with auto-generated ID
      final docRef = await collectionRef.add(questionnaire.toFirestore());

      debugPrint(
        '[PatientQuestionnaireService] ✓ Saved questionnaire with ID: ${docRef.id}',
      );

      // Update patient's latest questionnaire reference
      await _updatePatientQuestionnaireRef(
        practitionerId,
        patientId,
        docRef.id,
      );

      return docRef.id;
    } catch (e) {
      debugPrint(
        '[PatientQuestionnaireService] ✗ Error saving questionnaire: $e',
      );
      rethrow;
    }
  }

  /// Get the latest questionnaire for a patient
  Future<QuestionnaireModel?> getPatientQuestionnaire({
    required String practitionerId,
    required String patientId,
  }) async {
    try {
      debugPrint(
        '[PatientQuestionnaireService] Loading questionnaire for patient: $patientId',
      );

      final path = await _questionnairePath(practitionerId, patientId);

      final snapshot = await _firestore
          .collection(path)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[PatientQuestionnaireService] No questionnaire found');
        return null;
      }

      final questionnaire = QuestionnaireModel.fromFirestore(
        snapshot.docs.first,
      );
      debugPrint('[PatientQuestionnaireService] ✓ Loaded questionnaire');
      return questionnaire;
    } catch (e) {
      debugPrint(
        '[PatientQuestionnaireService] ✗ Error loading questionnaire: $e',
      );
      return null;
    }
  }

  /// Update an existing questionnaire
  Future<void> updatePatientQuestionnaire({
    required String practitionerId,
    required String patientId,
    required String questionnaireId,
    required QuestionnaireModel questionnaire,
  }) async {
    try {
      debugPrint(
        '[PatientQuestionnaireService] Updating questionnaire: $questionnaireId',
      );

      final path = await _questionnairePath(practitionerId, patientId);

      await _firestore
          .collection(path)
          .doc(questionnaireId)
          .set(questionnaire.toFirestore());

      debugPrint('[PatientQuestionnaireService] ✓ Updated questionnaire');
    } catch (e) {
      debugPrint(
        '[PatientQuestionnaireService] ✗ Error updating questionnaire: $e',
      );
      rethrow;
    }
  }

  /// Check if a patient has pre-test questionnaire data
  Future<bool> hasPatientQuestionnaire({
    required String practitionerId,
    required String patientId,
  }) async {
    try {
      final path = await _questionnairePath(practitionerId, patientId);

      final snapshot = await _firestore.collection(path).limit(1).get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint(
        '[PatientQuestionnaireService] ✗ Error checking questionnaire: $e',
      );
      return false;
    }
  }

  /// Update the patient document with latest questionnaire reference
  Future<void> _updatePatientQuestionnaireRef(
    String practitionerId,
    String patientId,
    String questionnaireId,
  ) async {
    try {
      final authService = AuthService();
      final practitioner = await authService.getUserData(practitionerId);
      final practitionerPath = practitioner?.identityString ?? practitionerId;

      await _firestore
          .collection('Practitioners/$practitionerPath/patients')
          .doc(patientId)
          .update({
            'hasPreTestQuestions': true,
            'latestQuestionnaireId': questionnaireId,
            'questionnaireUpdatedAt': Timestamp.now(),
          });
    } catch (e) {
      debugPrint(
        '[PatientQuestionnaireService] ✗ Error updating patient ref: $e',
      );
      // Don't rethrow - this is a non-critical update
    }
  }
}
