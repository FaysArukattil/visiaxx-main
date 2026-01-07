import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visiaxx/core/services/aws_s3_storage_service.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import 'dart:io';
import '../../data/models/test_result_model.dart';
import 'package:intl/intl.dart';

/// Service for storing and retrieving test results from Firebase
class TestResultService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AWSS3StorageService _awsStorageService = AWSS3StorageService();

  /// New organized collection path
  static const String _identifiedResultsCollection = 'IdentifiedResults';

  /// Save a complete test result to Firestore and AWS
  Future<String> saveTestResult({
    required String userId,
    required TestResultModel result,
    File? pdfFile,
  }) async {
    try {
      debugPrint('[TestResultService] Processing result for user: $userId');

      // 1. Get user identity for path organization
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);

      if (userModel == null) {
        throw Exception(
          'User details not found. Cannot save organized result.',
        );
      }

      final identity = userModel.identityString;
      final roleCol = userModel.roleCollection;

      // Map technical testType to descriptive category for storage
      final testCategory = result.testType == 'comprehensive'
          ? 'FullExam'
          : 'QuickTest';

      // 2. Upload images to AWS with descriptive path
      TestResultModel updatedResult = await _uploadImagesIfExist(
        userId: userId,
        identityString: identity,
        roleCollection: roleCol,
        testCategory: testCategory,
        result: result,
      );

      // 3. Upload PDF report to AWS if provided
      if (pdfFile != null && await pdfFile.exists()) {
        debugPrint('[TestResultService] 📤 Uploading PDF report to AWS...');
        final pdfUrl = await _awsStorageService.uploadPdfReport(
          userId: userId,
          identityString: identity,
          roleCollection: roleCol,
          testCategory: testCategory,
          testId: result.id,
          pdfFile: pdfFile,
        );

        if (pdfUrl != null) {
          debugPrint('[TestResultService] ✅ PDF upload successful');
          updatedResult = updatedResult.copyWith(pdfUrl: pdfUrl);
        }
      }

      // 4. Save to Firestore in the organized "IdentifiedResults" collection
      // Document ID: [TIMESTAMP]_[STATUS]_[TYPE]
      final timestampStr = DateFormat(
        'yyyy-MM-dd_HH-mm',
      ).format(result.timestamp);
      final customDocId =
          '${timestampStr}_${result.overallStatus.name}_$testCategory';

      await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(customDocId)
          .set(updatedResult.toFirestore());

      debugPrint('[TestResultService] ✅ Saved to Firestore: $customDocId');
      return customDocId;
    } catch (e) {
      debugPrint('[TestResultService] ❌ Save ERROR: $e');
      throw Exception('Failed to save test result: $e');
    }
  }

  /// Check if AWS S3 is configured and reachable
  Future<bool> checkAWSConnection() async {
    try {
      return await _awsStorageService.isAvailable &&
          await _awsStorageService.testConnection();
    } catch (e) {
      debugPrint('[TestResultService] ❌ AWS Connection Check Failed: $e');
      return false;
    }
  }

  Future<TestResultModel> _uploadImagesIfExist({
    required String userId,
    required String identityString,
    required String roleCollection,
    required String testCategory,
    required TestResultModel result,
  }) async {
    debugPrint('[TestResultService] 📤 Starting AWS image upload process...');

    // Check if AWS is available
    final bool awsAvailable = _awsStorageService.isAvailable;
    if (!awsAvailable) {
      debugPrint('[TestResultService] ⚠️ AWS not available, skipping uploads');
      return result;
    }

    TestResultModel updatedResult = result;

    // Upload Right Eye Amsler Grid Image
    if (result.amslerGridRight?.annotatedImagePath != null) {
      final localPath = result.amslerGridRight!.annotatedImagePath!;
      final file = File(localPath);

      if (await file.exists()) {
        debugPrint(
          '[TestResultService] 📤 Uploading right eye image to AWS...',
        );

        final awsUrl = await _awsStorageService.uploadAmslerGridImage(
          userId: userId,
          identityString: identityString,
          roleCollection: roleCollection,
          testCategory: testCategory,
          testId: result.id,
          eye: 'right',
          imageFile: file,
        );

        if (awsUrl != null) {
          updatedResult = updatedResult.copyWith(
            amslerGridRight: updatedResult.amslerGridRight!.copyWith(
              awsImageUrl: awsUrl,
            ),
          );
        }
      }
    }

    // Upload Left Eye Amsler Grid Image
    if (result.amslerGridLeft?.annotatedImagePath != null) {
      final localPath = result.amslerGridLeft!.annotatedImagePath!;
      final file = File(localPath);

      if (await file.exists()) {
        debugPrint('[TestResultService] 📤 Uploading left eye image to AWS...');

        final awsUrl = await _awsStorageService.uploadAmslerGridImage(
          userId: userId,
          identityString: identityString,
          roleCollection: roleCollection,
          testCategory: testCategory,
          testId: result.id,
          eye: 'left',
          imageFile: file,
        );

        if (awsUrl != null) {
          updatedResult = updatedResult.copyWith(
            amslerGridLeft: updatedResult.amslerGridLeft!.copyWith(
              awsImageUrl: awsUrl,
            ),
          );
        }
      }
    }

    return updatedResult;
  }

  /// Get all test results for a user
  Future<List<TestResultModel>> getTestResults(String userId) async {
    try {
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      if (userModel == null) return [];

      final identity = userModel.identityString;

      debugPrint('[TestResultService] Getting results for: $identity');

      final snapshot = await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
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
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      if (userModel == null) return null;

      final identity = userModel.identityString;

      final doc = await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
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
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      if (userModel == null) return [];

      final identity = userModel.identityString;

      final snapshot = await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
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
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      if (userModel == null) return;

      final identity = userModel.identityString;

      await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(resultId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete test result: $e');
    }
  }

  /// Get the most recent test result for a user
  Future<TestResultModel?> getLatestTestResult(String userId) async {
    try {
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      if (userModel == null) return null;

      final identity = userModel.identityString;

      final snapshot = await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
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
      final authService = AuthService();
      final practitioner = await authService.getUserData(practitionerId);
      if (practitioner == null) return [];

      final identity = practitioner.identityString;

      // Get all patient IDs linked to this practitioner
      final patientsSnapshot = await _firestore
          .collection('Practitioners')
          .doc(identity)
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
