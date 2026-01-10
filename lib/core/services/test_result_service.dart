import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visiaxx/core/services/aws_s3_storage_service.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import 'dart:io';
import '../../data/models/test_result_model.dart';
import 'package:intl/intl.dart';
import 'package:visiaxx/core/services/family_member_service.dart';
import '../providers/network_connectivity_provider.dart';

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

      // 4. Document ID: [TIMESTAMP]_[STATUS]_[TYPE]
      final timestampStr = DateFormat(
        'yyyy-MM-dd_HH-mm',
      ).format(result.timestamp);
      final customDocId =
          '${timestampStr}_${result.overallStatus.name}_$testCategory';

      // 5. Initial save to Firestore (FAST)
      // If it's a family member, nest under members/{profileId}
      var testDocRef = _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(customDocId);

      if (result.profileType == 'family' && result.profileId.isNotEmpty) {
        testDocRef = _firestore
            .collection(_identifiedResultsCollection)
            .doc(identity)
            .collection('members')
            .doc(result.profileId)
            .collection('tests')
            .doc(customDocId);
      }

      await testDocRef.set(result.toFirestore());

      // Start AWS uploads in background - don't await!
      performBackgroundAWSUploads(
        userId: userId,
        identity: identity,
        roleCol: roleCol,
        testCategory: testCategory,
        customDocId: customDocId,
        result: result,
        pdfFile: pdfFile,
      );

      debugPrint('[TestResultService] ✅ Initial save successful: $customDocId');
      return customDocId;
    } catch (e) {
      debugPrint('[TestResultService] ❌ Save ERROR: $e');
      // If organized save fails, try quick fallback to UID path
      try {
        await _firestore
            .collection(_identifiedResultsCollection)
            .doc(userId)
            .collection('tests')
            .add(result.toFirestore());
      } catch (_) {}
      throw Exception('Failed to save test result: $e');
    }
  }

  /// Start background AWS uploads (public for sync retry)
  Future<void> performBackgroundAWSUploads({
    required String userId,
    required String identity,
    required String roleCol,
    required String testCategory,
    required String customDocId,
    required TestResultModel result,
    File? pdfFile,
  }) async {
    try {
      debugPrint(
        '[TestResultService] ☁️ Starting background AWS uploads for ID: $customDocId',
      );

      // 0. Wait for AWS credentials to be ready (up to 10 seconds)
      int retryCount = 0;
      while (!_awsStorageService.isAvailable && retryCount < 10) {
        debugPrint(
          '[TestResultService] ⏳ Waiting for AWS credentials... (Attempt ${retryCount + 1})',
        );
        await Future.delayed(const Duration(seconds: 1));
        retryCount++;
      }

      if (!_awsStorageService.isAvailable) {
        debugPrint(
          '[TestResultService] ❌ AWS S3 not available after waiting. Aborting sync.',
        );
        return;
      }

      // Check connection specifically to AWS endpoint
      final isConnected = await _awsStorageService.testConnection();
      debugPrint('[TestResultService]    AWS Endpoint Reachable: $isConnected');

      // 1. Upload Images
      final String? memberId = result.profileType == 'family'
          ? result.profileId
          : null;

      TestResultModel updatedResult = await _uploadImagesIfExist(
        userId: userId,
        identityString: identity,
        roleCollection: roleCol,
        testCategory: testCategory,
        testId: customDocId,
        result: result,
        memberId: memberId,
      );

      // 2. Upload PDF
      if (pdfFile != null && await pdfFile.exists()) {
        final fileSize = await pdfFile.length();
        debugPrint(
          '[TestResultService] 📤 Uploading PDF: ${pdfFile.path} ($fileSize bytes)',
        );

        final pdfUrl = await _awsStorageService.uploadPdfReport(
          userId: userId,
          identityString: identity,
          roleCollection: roleCol,
          testCategory: testCategory,
          testId: customDocId,
          pdfFile: pdfFile,
          memberIdentityString: memberId,
        );

        if (pdfUrl != null) {
          debugPrint('[TestResultService] ✅ PDF uploaded: $pdfUrl');
          updatedResult = updatedResult.copyWith(pdfUrl: pdfUrl);
        } else {
          debugPrint('[TestResultService] ❌ PDF upload FAILED (returned null)');
        }
      } else {
        debugPrint(
          '[TestResultService] ⚠️ PDF missing or empty: ${pdfFile?.path}',
        );
      }

      // 3. Update Firestore with new AWS URLs
      debugPrint('[TestResultService] 🔄 Updating Firestore with AWS URLs...');
      await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(customDocId)
          .update(updatedResult.toFirestore());

      debugPrint(
        '[TestResultService] ✅ Background AWS sync COMPLETE for $customDocId',
      );
    } catch (e) {
      debugPrint('[TestResultService] ❌ Background AWS sync ERROR: $e');
    }
  }

  /// Save result locally when offline and queue for upload
  Future<String> saveResultOffline({
    required String userId,
    required TestResultModel result,
    required NetworkConnectivityProvider connectivity,
    File? pdfFile,
  }) async {
    try {
      debugPrint(
        '[TestResultService] 💾 Saving result OFFLINE for user: $userId',
      );

      // 1. Generate ID and save to Firestore (local cache)
      final testCategory = result.testType == 'comprehensive'
          ? 'FullExam'
          : 'QuickTest';
      final timestampStr = DateFormat(
        'yyyy-MM-dd_HH-mm',
      ).format(result.timestamp);
      final customDocId =
          '${timestampStr}_${result.overallStatus.name}_$testCategory';

      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      final identity = userModel?.identityString ?? userId;
      final roleCol = userModel?.roleCollection ?? 'Patients';

      await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(customDocId)
          .set(result.toFirestore());

      if (identity != userId) {
        await _firestore
            .collection(_identifiedResultsCollection)
            .doc(userId)
            .collection('tests')
            .doc(customDocId)
            .set(result.toFirestore());
      }

      debugPrint('[TestResultService] ✅ Saved to local queue: $customDocId');

      // 2. Queue AWS Sync (This survives screen disposal)
      debugPrint(
        '[TestResultService] 📥 Queuing background sync for $customDocId',
      );
      connectivity.queueOperation(() async {
        debugPrint(
          '[TestResultService] 🔄 Executing queued AWS sync for $customDocId',
        );
        await performBackgroundAWSUploads(
          userId: userId,
          identity: identity,
          roleCol: roleCol,
          testCategory: testCategory,
          customDocId: customDocId,
          result: result,
          pdfFile: pdfFile,
        );
      });

      return customDocId;
    } catch (e) {
      debugPrint('[TestResultService] ❌ Offline Save ERROR: $e');
      throw Exception('Failed to save result offline: $e');
    }
  }

  /// Check if AWS S3 is configured and reachable
  Future<bool> checkAWSConnection() async {
    try {
      return _awsStorageService.isAvailable &&
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
    required String testId,
    required TestResultModel result,
    String? memberId,
  }) async {
    debugPrint(
      '[TestResultService] 📤 Checking for images to upload for $testId...',
    );

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
          testId: testId, // ⚡ Use testId instead of result.id
          eye: 'right',
          imageFile: file,
          memberIdentityString: memberId,
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
          testId: testId, // ⚡ Use testId instead of result.id
          eye: 'left',
          imageFile: file,
          memberIdentityString: memberId,
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
  Future<List<TestResultModel>> getTestResults(
    String userId, {
    Source source = Source.serverAndCache,
  }) async {
    try {
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      if (userModel == null) return [];

      final identity = userModel.identityString;

      debugPrint('[TestResultService] Getting results for: $identity');

      // Helper to fetch results with timeout and automatic cache fallback
      Future<QuerySnapshot> fetchResults(String docId, int timeoutSecs) async {
        try {
          return await _firestore
              .collection(_identifiedResultsCollection)
              .doc(docId)
              .collection('tests')
              .orderBy('timestamp', descending: true)
              .get(GetOptions(source: source))
              .timeout(Duration(seconds: timeoutSecs));
        } catch (e) {
          debugPrint(
            '[TestResultService] ⚡ Fetch failed/timed out for $docId, trying CACHE: $e',
          );
          try {
            // Fallback: Fetch strictly from local cache (fast)
            return await _firestore
                .collection(_identifiedResultsCollection)
                .doc(docId)
                .collection('tests')
                .orderBy('timestamp', descending: true)
                .get(const GetOptions(source: Source.cache));
          } catch (cacheError) {
            debugPrint(
              '[TestResultService] ❌ Cache fetch also failed: $cacheError',
            );
            rethrow; // Final failure
          }
        }
      }

      // 1. Fetch from Identity path
      final identitySnapshot = await fetchResults(identity, 4);

      // 2. Fetch from UID path (fallback)
      QuerySnapshot? uidSnapshot;
      if (identity != userId) {
        uidSnapshot = await fetchResults(userId, 2);
      }

      final List<TestResultModel> results = [];
      final List<String> hiddenIds = userModel.hiddenResultIds;
      final Set<String> processedDocIds = {};

      void processDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
        for (final doc in docs) {
          if (processedDocIds.contains(doc.id)) continue;
          if (hiddenIds.contains(doc.id)) continue;

          try {
            final data = doc.data();
            data['id'] = doc.id;
            results.add(TestResultModel.fromJson(data));
            processedDocIds.add(doc.id);
          } catch (e) {
            debugPrint('[TestResultService] ❌ Error parsing ${doc.id}: $e');
          }
        }
      }

      processDocs(
        identitySnapshot.docs
            .cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      );
      if (uidSnapshot != null) {
        processDocs(
          uidSnapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
        );
      }

      // 3. NEW: Fetch results from all family member nested collections
      try {
        final familyMemberService = FamilyMemberService();
        final members = await familyMemberService.getFamilyMembers(userId);

        if (members.isNotEmpty) {
          debugPrint(
            '[TestResultService] 👨‍👩‍👧‍👦 Fetching results for ${members.length} family members...',
          );
          final List<Future<QuerySnapshot>> memberFetches = [];
          for (final member in members) {
            memberFetches.add(
              _firestore
                  .collection(_identifiedResultsCollection)
                  .doc(identity)
                  .collection('members')
                  .doc(member.id)
                  .collection('tests')
                  .orderBy('timestamp', descending: true)
                  .get(GetOptions(source: source))
                  .timeout(
                    const Duration(seconds: 2),
                    onTimeout: () {
                      // Fallback to cache for this specific member
                      return _firestore
                          .collection(_identifiedResultsCollection)
                          .doc(identity)
                          .collection('members')
                          .doc(member.id)
                          .collection('tests')
                          .orderBy('timestamp', descending: true)
                          .get(GetOptions(source: Source.cache));
                    },
                  ),
            );
          }

          final memberSnapshots = await Future.wait(memberFetches);
          for (final snap in memberSnapshots) {
            processDocs(
              snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[TestResultService] ⚠️ Error fetching family member results: $e',
        );
      }

      // Sort merged results by timestamp descending
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint(
        '[TestResultService] ✅ Successfully loaded ${results.length} results (Identified: ${identitySnapshot.docs.length}, UID-fallback: ${uidSnapshot?.docs.length ?? 0})',
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

      // Try main collection first
      var doc = await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(resultId)
          .get();

      // If not found, it might be in a nested family member collection
      if (!doc.exists) {
        debugPrint(
          '[TestResultService] Result $resultId not in main tests, searching members...',
        );
        final familyMemberService = FamilyMemberService();
        final members = await familyMemberService.getFamilyMembers(userId);

        for (final member in members) {
          doc = await _firestore
              .collection(_identifiedResultsCollection)
              .doc(identity)
              .collection('members')
              .doc(member.id)
              .collection('tests')
              .doc(resultId)
              .get();
          if (doc.exists) break;
        }
      }

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
      final hiddenIds = userModel.hiddenResultIds;

      // 1. Try legacy path (flat collection)
      final legacySnapshot = await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .where('profileId', isEqualTo: profileId)
          .get();

      // 2. Try nested path (new organized structure)
      final nestedSnapshot = await _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('members')
          .doc(profileId)
          .collection('tests')
          .get();

      final List<TestResultModel> results = [];
      final Set<String> processedIds = {};

      void addDocs(QuerySnapshot snap) {
        for (final doc in snap.docs) {
          if (processedIds.contains(doc.id)) continue;
          if (hiddenIds.contains(doc.id)) continue;

          results.add(
            TestResultModel.fromJson({
              ...doc.data() as Map<String, dynamic>,
              'id': doc.id,
            }),
          );
          processedIds.add(doc.id);
        }
      }

      addDocs(legacySnapshot);
      addDocs(nestedSnapshot);

      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return results;
    } catch (e) {
      throw Exception('Failed to get profile test results: $e');
    }
  }

  /// Soft delete a test result (add to user's hiddenResultIds instead of actual deletion)
  Future<void> deleteTestResult(String userId, String resultId) async {
    try {
      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      if (userModel == null) return;

      final identity = userModel.identityString;
      final collection = userModel.roleCollection;

      debugPrint(
        '[TestResultService] Soft deleting result $resultId for $identity',
      );

      // Add to user's hidden list in Firestore
      await _firestore.collection(collection).doc(identity).update({
        'hiddenResultIds': FieldValue.arrayUnion([resultId]),
      });

      debugPrint('[TestResultService] ✅ Result $resultId added to hidden list');
    } catch (e) {
      debugPrint('[TestResultService] ❌ Soft delete ERROR: $e');
      throw Exception('Failed to hide test result: $e');
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
