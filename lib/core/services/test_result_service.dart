import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/models/test_result_model.dart';

/// Service for storing and retrieving test results from Firebase
class TestResultService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection paths
  static const String _testResultsCollection = 'test_results';

  /// Save a complete test result to Firebase
  /// Returns the document ID of the saved result
  Future<String> saveTestResult({
    required String userId,
    required TestResultModel result,
  }) async {
    try {
      debugPrint('[TestResultService] Saving result for user: $userId');

      // 1. Upload images if they exist
      final updatedResult = await _uploadImagesIfExist(userId, result);

      final docRef = await _firestore
          .collection(_testResultsCollection)
          .doc(userId)
          .collection('results')
          .add(updatedResult.toFirestore());

      debugPrint('[TestResultService] ✅ Saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[TestResultService] ❌ Save ERROR: $e');
      throw Exception('Failed to save test result: $e');
    }
  }

  Future<TestResultModel> _uploadImagesIfExist(
    String userId,
    TestResultModel result,
  ) async {
    final amslerRight = result.amslerGridRight;
    final amslerLeft = result.amslerGridLeft;

    String? rightUrl;
    String? leftUrl;

    if (amslerRight?.annotatedImagePath != null &&
        !amslerRight!.annotatedImagePath!.startsWith('http')) {
      rightUrl = await _uploadFile(
        userId,
        amslerRight.annotatedImagePath!,
        'amsler_right',
      );
    }

    if (amslerLeft?.annotatedImagePath != null &&
        !amslerLeft!.annotatedImagePath!.startsWith('http')) {
      leftUrl = await _uploadFile(
        userId,
        amslerLeft.annotatedImagePath!,
        'amsler_left',
      );
    }

    if (rightUrl == null && leftUrl == null) return result;

    return result.copyWith(
      amslerGridRight: rightUrl != null
          ? amslerRight?.copyWith(annotatedImagePath: rightUrl)
          : amslerRight,
      amslerGridLeft: leftUrl != null
          ? amslerLeft?.copyWith(annotatedImagePath: leftUrl)
          : amslerLeft,
    );
  }

  Future<String?> _uploadFile(
    String userId,
    String localPath,
    String type,
  ) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance
          .ref()
          .child('test_results')
          .child(userId)
          .child(fileName);

      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[TestResultService] Error uploading file: $e');
      return null;
    }
  }

  /// Get all test results for a user
  Future<List<TestResultModel>> getTestResults(String userId) async {
    try {
      debugPrint('[TestResultService] Getting results for user: $userId');
      debugPrint(
        '[TestResultService] Query path: $_testResultsCollection/$userId/results',
      );

      final snapshot = await _firestore
          .collection(_testResultsCollection)
          .doc(userId)
          .collection('results')
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint('[TestResultService] Found ${snapshot.docs.length} documents');

      final List<TestResultModel> results = [];
      for (final doc in snapshot.docs) {
        try {
          // Get document data as Map and add the ID
          final data = doc.data();
          data['id'] = doc.id;
          debugPrint('[TestResultService] Loading doc ${doc.id}');
          results.add(TestResultModel.fromJson(data));
        } catch (e) {
          // Skip malformed documents but log error
          debugPrint('[TestResultService] ❌ Error parsing ${doc.id}: $e');
        }
      }

      debugPrint(
        '[TestResultService] ✅ Successfully loaded ${results.length} results',
      );
      return results;
    } catch (e) {
      debugPrint('[TestResultService] ❌ Get ERROR: $e');
      throw Exception('Failed to get test results: $e');
    }
  }

  /// Get a specific test result by ID
  Future<TestResultModel?> getTestResultById(
    String userId,
    String resultId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_testResultsCollection)
          .doc(userId)
          .collection('results')
          .doc(resultId)
          .get();

      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return TestResultModel.fromJson(data);
    } catch (e) {
      throw Exception('Failed to get test result: $e');
    }
  }

  /// Get test results for a specific profile (self or family member)
  Future<List<TestResultModel>> getTestResultsByProfile(
    String userId,
    String profileId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_testResultsCollection)
          .doc(userId)
          .collection('results')
          .where('profileId', isEqualTo: profileId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TestResultModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get profile test results: $e');
    }
  }

  /// Delete a test result
  Future<void> deleteTestResult(String userId, String resultId) async {
    try {
      await _firestore
          .collection(_testResultsCollection)
          .doc(userId)
          .collection('results')
          .doc(resultId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete test result: $e');
    }
  }

  /// Get the most recent test result for a user
  Future<TestResultModel?> getLatestTestResult(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_testResultsCollection)
          .doc(userId)
          .collection('results')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return TestResultModel.fromJson({...doc.data(), 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to get latest test result: $e');
    }
  }

  /// Get all test results for a practitioner's patients
  Future<List<TestResultModel>> getPractitionerPatientResults(
    String practitionerId,
  ) async {
    try {
      // Get all patient IDs linked to this practitioner
      final patientsSnapshot = await _firestore
          .collection('practitioners')
          .doc(practitionerId)
          .collection('patients')
          .get();

      final patientIds = patientsSnapshot.docs.map((d) => d.id).toList();

      if (patientIds.isEmpty) return [];

      // Get results for each patient
      final List<TestResultModel> allResults = [];

      for (final patientId in patientIds) {
        final results = await getTestResults(patientId);
        allResults.addAll(results);
      }

      // Sort by timestamp descending
      allResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allResults;
    } catch (e) {
      throw Exception('Failed to get practitioner patient results: $e');
    }
  }

  /// Calculate average scores from multiple test attempts
  static Map<String, double> calculateAverageScores(
    List<TestResultModel> results,
  ) {
    if (results.isEmpty) return {};

    double totalLogMARRight = 0;
    double totalLogMARLeft = 0;
    int rightCount = 0;
    int leftCount = 0;

    for (final result in results) {
      if (result.visualAcuityRight != null) {
        totalLogMARRight += result.visualAcuityRight!.logMAR;
        rightCount++;
      }
      if (result.visualAcuityLeft != null) {
        totalLogMARLeft += result.visualAcuityLeft!.logMAR;
        leftCount++;
      }
    }

    return {
      'averageLogMARRight': rightCount > 0 ? totalLogMARRight / rightCount : 0,
      'averageLogMARLeft': leftCount > 0 ? totalLogMARLeft / leftCount : 0,
      'testCount': results.length.toDouble(),
    };
  }
}
