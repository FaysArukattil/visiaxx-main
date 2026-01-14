import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/individual_test_result_model.dart';

/// Service for managing individual test results
class IndividualTestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save individual test result to Firebase
  Future<String> saveIndividualTest(IndividualTestResult result) async {
    try {
      debugPrint(
        '[IndividualTestService] 💾 Saving individual test: ${result.testType}',
      );

      final docRef = await _firestore
          .collection('users')
          .doc(result.userId)
          .collection('individualTests')
          .add(result.toFirestore());

      debugPrint('[IndividualTestService] ✅ Saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[IndividualTestService] ❌ Error saving test: $e');
      rethrow;
    }
  }

  /// Fetch all individual tests for a user
  Future<List<IndividualTestResult>> getUserIndividualTests(
    String userId,
  ) async {
    try {
      debugPrint(
        '[IndividualTestService] 📥 Fetching individual tests for user: $userId',
      );

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('individualTests')
          .where('isHidden', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      final tests = snapshot.docs
          .map((doc) => IndividualTestResult.fromFirestore(doc))
          .toList();

      debugPrint('[IndividualTestService] ✅ Fetched ${tests.length} tests');
      return tests;
    } catch (e) {
      debugPrint('[IndividualTestService] ❌ Error fetching tests: $e');
      return [];
    }
  }

  /// Update PDF URL after generation
  Future<void> updatePdfUrl(String userId, String testId, String pdfUrl) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('individualTests')
          .doc(testId)
          .update({'pdfUrl': pdfUrl});

      debugPrint('[IndividualTestService] ✅ Updated PDF URL for test: $testId');
    } catch (e) {
      debugPrint('[IndividualTestService] ❌ Error updating PDF URL: $e');
    }
  }

  /// Update AWS URL after upload
  Future<void> updateAwsUrl(String userId, String testId, String awsUrl) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('individualTests')
          .doc(testId)
          .update({'awsUrl': awsUrl});

      debugPrint('[IndividualTestService] ✅ Updated AWS URL for test: $testId');
    } catch (e) {
      debugPrint('[IndividualTestService] ❌ Error updating AWS URL: $e');
    }
  }

  /// Hide/soft delete a test
  Future<void> hideTest(String userId, String testId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('individualTests')
          .doc(testId)
          .update({'isHidden': true});

      debugPrint('[IndividualTestService] ✅ Hidden test: $testId');
    } catch (e) {
      debugPrint('[IndividualTestService] ❌ Error hiding test: $e');
    }
  }

  /// Get test count by type
  Future<Map<String, int>> getTestCountByType(String userId) async {
    try {
      final tests = await getUserIndividualTests(userId);
      final counts = <String, int>{};

      for (final test in tests) {
        counts[test.testType] = (counts[test.testType] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('[IndividualTestService] ❌ Error counting tests: $e');
      return {};
    }
  }
}
