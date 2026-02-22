import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visiaxx/core/services/aws_s3_storage_service.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import 'dart:io';
import '../../data/models/test_result_model.dart';
import 'package:intl/intl.dart';
import 'package:visiaxx/core/services/family_member_service.dart';
import '../providers/network_connectivity_provider.dart';
import 'package:visiaxx/core/services/dashboard_persistence_service.dart';
import '../../data/models/patient_model.dart';
import '../../data/models/cover_test_result.dart';

/// Service for storing and retrieving test results from Firebase
class TestResultService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AWSS3StorageService _awsStorageService = AWSS3StorageService();

  static const String _identifiedResultsCollection = 'IdentifiedResults';

  // Short-term in-memory cache to prevent redundant loops on startup
  static List<TestResultModel>? _fallbackCache;
  static DateTime? _lastCacheTime;

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
      final testCategory = _getTestFolderName(result.testType);

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
      } else if (result.profileType == 'patient' &&
          result.profileId.isNotEmpty) {
        // Save under Practitioner's patient path
        testDocRef = _firestore
            .collection('Practitioners')
            .doc(identity)
            .collection('patients')
            .doc(result.profileId)
            .collection('tests')
            .doc(customDocId);
      }

      await testDocRef.set(result.toFirestore());

      // NEW: Update local cache INSTANTLY
      try {
        final persistence = DashboardPersistenceService();
        final stored = await persistence.getStoredResults(
          customKey: 'user_results',
        );
        final updatedResult = result.copyWith(id: customDocId);
        await persistence.saveResults([
          updatedResult,
          ...stored,
        ], customKey: 'user_results');
        debugPrint('[TestResultService] ✅ Local cache updated instantly');
      } catch (e) {
        debugPrint('[TestResultService] ❌ Cache update failed: $e');
      }

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

      debugPrint('[TestResultService] … Initial save successful: $customDocId');
      return customDocId;
    } catch (e) {
      debugPrint('[TestResultService] Œ Save ERROR: $e');
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
        '[TestResultService] ˜ï¸ Starting background AWS uploads for ID: $customDocId',
      );

      // 0. Wait for AWS credentials to be ready (up to 10 seconds)
      int retryCount = 0;
      while (!_awsStorageService.isAvailable && retryCount < 10) {
        debugPrint(
          '[TestResultService] ³ Waiting for AWS credentials... (Attempt ${retryCount + 1})',
        );
        await Future.delayed(const Duration(seconds: 1));
        retryCount++;
      }

      if (!_awsStorageService.isAvailable) {
        debugPrint(
          '[TestResultService] Œ AWS S3 not available after waiting. Aborting sync.',
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
          '[TestResultService] “¤ Uploading PDF: ${pdfFile.path} ($fileSize bytes)',
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
          debugPrint('[TestResultService] … PDF uploaded: $pdfUrl');
          updatedResult = updatedResult.copyWith(pdfUrl: pdfUrl);
        } else {
          debugPrint(
            '[TestResultService] Œ PDF upload FAILED (returned null)',
          );
        }
      } else {
        debugPrint(
          '[TestResultService]  ï¸ PDF missing or empty: ${pdfFile?.path}',
        );
      }

      // 3. Update Firestore with new AWS URLs
      debugPrint('[TestResultService] ”„ Updating Firestore with AWS URLs...');
      var updateDocRef = _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(customDocId);

      if (result.profileType == 'family' && result.profileId.isNotEmpty) {
        updateDocRef = _firestore
            .collection(_identifiedResultsCollection)
            .doc(identity)
            .collection('members')
            .doc(result.profileId)
            .collection('tests')
            .doc(customDocId);
      } else if (result.profileType == 'patient' &&
          result.profileId.isNotEmpty) {
        updateDocRef = _firestore
            .collection('Practitioners')
            .doc(identity)
            .collection('patients')
            .doc(result.profileId)
            .collection('tests')
            .doc(customDocId);
      }

      await updateDocRef.update(updatedResult.toFirestore());

      debugPrint(
        '[TestResultService] … Background AWS sync COMPLETE for $customDocId',
      );
    } catch (e) {
      debugPrint('[TestResultService] Œ Background AWS sync ERROR: $e');
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
        '[TestResultService] ’¾ Saving result OFFLINE for user: $userId',
      );

      // 1. Generate ID and save to Firestore (local cache)
      final testCategory = _getTestFolderName(result.testType);
      final timestampStr = DateFormat(
        'yyyy-MM-dd_HH-mm',
      ).format(result.timestamp);
      final customDocId =
          '${timestampStr}_${result.overallStatus.name}_$testCategory';

      final authService = AuthService();
      final userModel = await authService.getUserData(userId);
      final identity = userModel?.identityString ?? userId;
      final roleCol = userModel?.roleCollection ?? 'Patients';

      var offlineDocRef = _firestore
          .collection(_identifiedResultsCollection)
          .doc(identity)
          .collection('tests')
          .doc(customDocId);

      if (result.profileType == 'family' && result.profileId.isNotEmpty) {
        offlineDocRef = _firestore
            .collection(_identifiedResultsCollection)
            .doc(identity)
            .collection('members')
            .doc(result.profileId)
            .collection('tests')
            .doc(customDocId);
      } else if (result.profileType == 'patient' &&
          result.profileId.isNotEmpty) {
        offlineDocRef = _firestore
            .collection('Practitioners')
            .doc(identity)
            .collection('patients')
            .doc(result.profileId)
            .collection('tests')
            .doc(customDocId);
      }

      await offlineDocRef.set(result.toFirestore());

      if (identity != userId && result.profileType != 'patient') {
        await _firestore
            .collection(_identifiedResultsCollection)
            .doc(userId)
            .collection('tests')
            .doc(customDocId)
            .set(result.toFirestore());
      }

      debugPrint('[TestResultService] … Saved to local queue: $customDocId');

      // 2. Queue AWS Sync (This survives screen disposal)
      debugPrint(
        '[TestResultService] “¥ Queuing background sync for $customDocId',
      );
      connectivity.queueOperation(() async {
        debugPrint(
          '[TestResultService] ”„ Executing queued AWS sync for $customDocId',
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
      debugPrint('[TestResultService] Œ Offline Save ERROR: $e');
      throw Exception('Failed to save result offline: $e');
    }
  }

  /// Update a specific field in a test result with a new URL (e.g. for background media uploads)
  Future<void> updateTestResultUrl({
    required String resultId,
    required String field,
    required String url,
  }) async {
    try {
      debugPrint(
        '[TestResultService] ”„ Updating $field with URL for result: $resultId',
      );

      // Try searching for the document using collection group query to get its reference
      final query = await _firestore
          .collectionGroup('tests')
          .where(FieldPath.documentId, isEqualTo: resultId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({field: url});
        debugPrint('[TestResultService] ✅ Field $field updated successfully');
      } else {
        debugPrint(
          '[TestResultService]  ï¸  Could not find document $resultId to update field $field',
        );
      }
    } catch (e) {
      debugPrint('[TestResultService]  Œ Error updating field $field: $e');
    }
  }

  /// Check if AWS S3 is configured and reachable
  Future<bool> checkAWSConnection() async {
    try {
      return _awsStorageService.isAvailable &&
          await _awsStorageService.testConnection();
    } catch (e) {
      debugPrint('[TestResultService] Œ AWS Connection Check Failed: $e');
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
      '[TestResultService] “¤ Checking for images to upload for $testId...',
    );

    // Check if AWS is available
    final bool awsAvailable = _awsStorageService.isAvailable;
    if (!awsAvailable) {
      debugPrint(
        '[TestResultService]  ï¸ AWS not available, skipping uploads',
      );
      return result;
    }

    TestResultModel updatedResult = result;

    // Upload Right Eye Amsler Grid Image
    if (result.amslerGridRight?.annotatedImagePath != null) {
      final localPath = result.amslerGridRight!.annotatedImagePath!;
      final file = File(localPath);

      if (await file.exists()) {
        debugPrint(
          '[TestResultService] “¤ Uploading right eye image to AWS...',
        );

        final awsUrl = await _awsStorageService.uploadAmslerGridImage(
          userId: userId,
          identityString: identityString,
          roleCollection: roleCollection,
          testCategory: testCategory,
          testId: testId,
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
        debugPrint('[TestResultService] “¤ Uploading left eye image to AWS...');

        final awsUrl = await _awsStorageService.uploadAmslerGridImage(
          userId: userId,
          identityString: identityString,
          roleCollection: roleCollection,
          testCategory: testCategory,
          testId: testId,
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

    // Upload Left Eye Amsler Grid Image (from previous chunk)
    // ... (lines 404-431)

    // Upload Right Eye Shadow Test Image
    if (result.shadowTest?.rightEye.imagePath != null) {
      final localPath = result.shadowTest!.rightEye.imagePath!;
      final file = File(localPath);

      if (await file.exists()) {
        debugPrint(
          '[TestResultService] “¤ Uploading right eye shadow image...',
        );
        final awsUrl = await _awsStorageService.uploadShadowTestImage(
          userId: userId,
          identityString: identityString,
          roleCollection: roleCollection,
          testCategory: testCategory,
          testId: testId,
          eye: 'right',
          imageFile: file,
          memberIdentityString: memberId,
        );

        if (awsUrl != null) {
          updatedResult = updatedResult.copyWith(
            shadowTest: updatedResult.shadowTest!.copyWith(
              rightEye: updatedResult.shadowTest!.rightEye.copyWith(
                awsImageUrl: awsUrl,
              ),
            ),
          );
        }
      }
    }

    // Upload Left Eye Shadow Test Image
    if (result.shadowTest?.leftEye.imagePath != null) {
      final localPath = result.shadowTest!.leftEye.imagePath!;
      final file = File(localPath);

      if (await file.exists()) {
        debugPrint('[TestResultService] “¤ Uploading left eye shadow image...');
        final awsUrl = await _awsStorageService.uploadShadowTestImage(
          userId: userId,
          identityString: identityString,
          roleCollection: roleCollection,
          testCategory: testCategory,
          testId: testId,
          eye: 'left',
          imageFile: file,
          memberIdentityString: memberId,
        );

        if (awsUrl != null) {
          updatedResult = updatedResult.copyWith(
            shadowTest: updatedResult.shadowTest!.copyWith(
              leftEye: updatedResult.shadowTest!.leftEye.copyWith(
                awsImageUrl: awsUrl,
              ),
            ),
          );
        }
      }
    }

    // Upload Cover Test Videos
    if (result.coverTest != null && result.coverTest!.observations.isNotEmpty) {
      debugPrint('[TestResultService] “¤ Checking for Cover Test videos...');
      final List<CoverTestObservation> updatedObservations = [];

      for (var observation in updatedResult.coverTest!.observations) {
        if (observation.videoPath != null &&
            observation.videoPath!.isNotEmpty &&
            observation.videoUrl == null) {
          final file = File(observation.videoPath!);
          if (await file.exists()) {
            debugPrint(
              '[TestResultService] “¤ Uploading video for ${observation.eye} - ${observation.phase}',
            );
            final awsUrl = await _awsStorageService.uploadCoverTestVideo(
              userId: userId,
              identityString: identityString,
              roleCollection: roleCollection,
              testCategory: testCategory,
              testId: testId,
              phase: '${observation.eye}_${observation.phase}'
                  .toLowerCase()
                  .replaceAll(' ', '_'),
              videoFile: file,
              memberIdentityString: memberId,
            );

            if (awsUrl != null) {
              updatedObservations.add(
                CoverTestObservation(
                  eye: observation.eye,
                  phase: observation.phase,
                  movement: observation.movement,
                  videoPath: observation.videoPath,
                  videoUrl: awsUrl,
                ),
              );
              continue; // Skip the default addition
            }
          }
        }
        updatedObservations.add(observation);
      }

      updatedResult = updatedResult.copyWith(
        coverTest: updatedResult.coverTest!.copyWith(
          observations: updatedObservations,
        ),
      );
    }

    // 4. Upload Torchlight Media (NEW)
    if (updatedResult.torchlight != null) {
      // Upload Pupillary RAPD Image
      if (updatedResult.torchlight!.pupillary?.rapdImagePath != null &&
          updatedResult.torchlight!.pupillary!.rapdImageUrl == null) {
        final file = File(updatedResult.torchlight!.pupillary!.rapdImagePath!);
        if (await file.exists()) {
          debugPrint(
            '[TestResultService] “¤ Uploading Torchlight RAPD image...',
          );
          final awsUrl = await _awsStorageService.uploadRAPDImage(
            userId: userId,
            identityString: identityString,
            roleCollection: roleCollection,
            testCategory: testCategory,
            testId: testId,
            imageFile: file,
            memberIdentityString: memberId,
          );

          if (awsUrl != null) {
            updatedResult = updatedResult.copyWith(
              torchlight: updatedResult.torchlight!.copyWith(
                pupillary: updatedResult.torchlight!.pupillary!.copyWith(
                  rapdImageUrl: awsUrl,
                ),
              ),
            );
          }
        }
      }

      // Upload Pupillary RAPD Video (NEW)
      if (updatedResult.torchlight!.pupillary?.rapdVideoPath != null &&
          updatedResult.torchlight!.pupillary!.rapdVideoUrl == null) {
        final file = File(updatedResult.torchlight!.pupillary!.rapdVideoPath!);
        if (await file.exists()) {
          debugPrint(
            '[TestResultService] 🎥 Uploading Torchlight RAPD video...',
          );
          final awsUrl = await _awsStorageService.uploadRAPDVideo(
            userId: userId,
            identityString: identityString,
            roleCollection: roleCollection,
            testCategory: testCategory,
            testId: testId,
            videoFile: file,
            memberIdentityString: memberId,
          );

          if (awsUrl != null) {
            updatedResult = updatedResult.copyWith(
              torchlight: updatedResult.torchlight!.copyWith(
                pupillary: updatedResult.torchlight!.pupillary!.copyWith(
                  rapdVideoUrl: awsUrl,
                ),
              ),
            );
          }
        }
      }

      // Upload Extraocular Video
      if (updatedResult.torchlight!.extraocular?.videoPath != null &&
          updatedResult.torchlight!.extraocular!.videoUrl == null) {
        final file = File(updatedResult.torchlight!.extraocular!.videoPath!);
        if (await file.exists()) {
          debugPrint(
            '[TestResultService] “¤ Uploading Torchlight extraocular video...',
          );
          final awsUrl = await _awsStorageService.uploadExtraocularVideo(
            userId: userId,
            identityString: identityString,
            roleCollection: roleCollection,
            testCategory: testCategory,
            testId: testId,
            videoFile: file,
            memberIdentityString: memberId,
          );

          if (awsUrl != null) {
            updatedResult = updatedResult.copyWith(
              torchlight: updatedResult.torchlight!.copyWith(
                extraocular: updatedResult.torchlight!.extraocular!.copyWith(
                  videoUrl: awsUrl,
                ),
              ),
            );
          }
        }
      }
    }

    return updatedResult;
  }

  /// Get test results stream for a user
  Stream<List<TestResultModel>> getTestResultsStream(String userId) {
    debugPrint(
      '[TestResultService] 🔄 Setting up universal collection-group stream for: $userId',
    );
    final controller = StreamController<List<TestResultModel>>();

    AuthService()
        .getUserData(userId)
        .then((user) {
          if (user == null) {
            controller.add([]);
            controller.close();
            return;
          }

          final identity = user.identityString;
          final roleCol = user.roleCollection;

          List<QueryDocumentSnapshot<Map<String, dynamic>>> lastTests = [];
          List<String> lastHidden = [];
          bool hasInitialTests = false;
          bool hasInitialHidden = false;

          void emit() {
            // Only emit when BOTH streams have provided initial data
            if (!hasInitialTests || !hasInitialHidden) {
              debugPrint(
                '[TestResultService] ⏳ Waiting for both streams (tests: $hasInitialTests, hidden: $hasInitialHidden)',
              );
              return;
            }

            debugPrint(
              '[TestResultService] 📊 Emitting: ${lastTests.length} total tests, ${lastHidden.length} hidden',
            );

            final results = lastTests
                .where((doc) {
                  final isHidden = lastHidden.contains(doc.id);
                  if (isHidden) {
                    debugPrint(
                      '[TestResultService] 🚫 Filtering out hidden: ${doc.id}',
                    );
                  }
                  return !isHidden;
                })
                .map((doc) {
                  try {
                    final data = doc.data();
                    data['id'] = doc.id;
                    final result = TestResultModel.fromJson(data);
                    debugPrint(
                      '[TestResultService] ✅ Including result: ${result.id} - ${result.profileName}',
                    );
                    return result;
                  } catch (e) {
                    debugPrint(
                      '[TestResultService] ❌ Parse error in stream: $e',
                    );
                    return null;
                  }
                })
                .where((r) => r != null)
                .cast<TestResultModel>()
                .toList();

            debugPrint(
              '[TestResultService] 📤 Emitting ${results.length} results to UI',
            );
            controller.add(results);
          }

          // Single stream using collectionGroup to get self + family tests
          final subTests = _firestore
              .collectionGroup('tests')
              .where('userId', isEqualTo: userId)
              .orderBy('timestamp', descending: true)
              .snapshots()
              .listen(
                (snap) {
                  debugPrint(
                    '[TestResultService] 🔄 Tests stream update: ${snap.docs.length} docs',
                  );
                  lastTests = snap.docs;
                  hasInitialTests = true;
                  emit();
                },
                onError: (e) {
                  debugPrint('[TestResultService] ❌ Group stream error: $e');
                  controller.addError(e);
                },
              );

          // User Doc: hiddenResultIds
          final subUser = _firestore
              .collection(roleCol)
              .doc(identity)
              .snapshots()
              .listen(
                (snap) {
                  final newHidden = List<String>.from(
                    snap.data()?['hiddenResultIds'] ?? [],
                  );
                  debugPrint(
                    '[TestResultService] 🔄 Hidden IDs update: ${newHidden.length} hidden',
                  );
                  lastHidden = newHidden;
                  hasInitialHidden = true;
                  emit();
                },
                onError: (e) {
                  debugPrint('[TestResultService] ❌ User sub error: $e');
                  // Even if hidden IDs fail to load, we should still show results
                  lastHidden = [];
                  hasInitialHidden = true;
                  emit();
                },
              );

          controller.onCancel = () {
            debugPrint('[TestResultService] 🛑 Stream cancelled');
            subTests.cancel();
            subUser.cancel();
          };
        })
        .catchError((e) {
          debugPrint('[TestResultService] ❌ getUserData error: $e');
          controller.addError(e);
          controller.close();
        });

    return controller.stream;
  }

  /// Get a stream of all results for a practitioner, including those of patients
  /// Uses collection group query to find all tests where the practitioner's ID is the userId
  Stream<List<TestResultModel>> getPractitionerResultsStream(
    String practitionerId,
  ) {
    debugPrint(
      '[TestResultService] 📦 Creating collection group stream for practitioner: $practitionerId',
    );

    // NOTE: We remove the 'isDeleted' filter from the Firestore query itself
    // to reduce complex index requirements. We filter it in-memory instead.
    return _firestore
        .collectionGroup('tests')
        .where('userId', isEqualTo: practitionerId)
        .orderBy('timestamp', descending: true)
        .limit(300)
        .snapshots()
        .map((snapshot) {
          final results = snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  data['id'] = doc.id;
                  final model = TestResultModel.fromJson(data);

                  // Filter deleted items in memory
                  if (model.isDeleted) return null;

                  return model;
                } catch (e) {
                  return null;
                }
              })
              .where((r) => r != null)
              .cast<TestResultModel>()
              .toList();

          debugPrint(
            '[TestResultService] ✅ Practitioner stream updated with ${results.length} results (filtered in-memory)',
          );
          return results;
        });
  }

  /// Get test results for a practitioner created after a specific timestamp
  /// Uses collection group query for efficiency
  Future<List<TestResultModel>> getPractitionerResultsIncremental({
    required String practitionerId,
    required DateTime since,
  }) async {
    try {
      debugPrint(
        '[TestResultService] 🔄 Fetching incremental results for $practitionerId since $since',
      );
      try {
        // 1. Try optimized query
        try {
          final snapshot = await _firestore
              .collectionGroup('tests')
              .where('userId', isEqualTo: practitionerId)
              .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final results = snapshot.docs
                .map((doc) {
                  try {
                    final data = doc.data();
                    data['id'] = doc.id;
                    final model = TestResultModel.fromJson(data);
                    return model.isDeleted ? null : model;
                  } catch (e) {
                    return null;
                  }
                })
                .where((r) => r != null)
                .cast<TestResultModel>()
                .toList();
            return results;
          }
        } catch (e) {
          if (!e.toString().contains('failed-precondition')) rethrow;
          debugPrint(
            '[TestResultService] Incremental index missing, falling back',
          );
        }

        // 2. Fallback: Full sync if incremental fails (replaces incremental with a full poll since it's rare)
        return await getPractitionerPatientResults(practitionerId);
      } catch (e) {
        debugPrint('[TestResultService] Incremental fetch error: $e');
        return [];
      }
    } catch (e) {
      debugPrint('[TestResultService] ❌ Incremental fetch ERROR: $e');
      return [];
    }
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
            '[TestResultService] ¡ Fetch failed/timed out for $docId, trying CACHE: $e',
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
              '[TestResultService] Œ Cache fetch also failed: $cacheError',
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

      Future<void> processDocs(
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
        for (final doc in docs) {
          if (processedDocIds.contains(doc.id)) continue;
          if (hiddenIds.contains(doc.id)) continue;

          try {
            final data = doc.data();
            data['id'] = doc.id;
            final result = TestResultModel.fromJson(data);

            // DON'T load prescription here - only practitioners need it
            // and they'll load it separately in their dashboard

            results.add(result);
            processedDocIds.add(doc.id);
          } catch (e) {
            debugPrint('[TestResultService] ❌ Error parsing ${doc.id}: $e');
          }
        }
      }

      await processDocs(
        identitySnapshot.docs
            .cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      );
      if (uidSnapshot != null) {
        await processDocs(
          uidSnapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
        );
      }

      // 3. NEW: Fetch results from all family member nested collections
      try {
        final familyMemberService = FamilyMemberService();
        final members = await familyMemberService.getFamilyMembers(userId);

        if (members.isNotEmpty) {
          debugPrint(
            '[TestResultService] ‘¨€‘©€‘§€‘¦ Fetching results for ${members.length} family members...',
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
                          .get(const GetOptions(source: Source.cache));
                    },
                  ),
            );
          }

          final memberSnapshots = await Future.wait(memberFetches);
          for (final snap in memberSnapshots) {
            await processDocs(
              snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[TestResultService]  ï¸ Error fetching family member results: $e',
        );
      }

      // Sort merged results by timestamp descending
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint(
        '[TestResultService] … Successfully loaded ${results.length} results (Identified: ${identitySnapshot.docs.length}, UID-fallback: ${uidSnapshot?.docs.length ?? 0})',
      );
      return results;
    } catch (e) {
      debugPrint('[TestResultService] Œ Get ERROR: $e');
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

      // If not found, search in Practitioner patients (broad search)
      if (!doc.exists) {
        debugPrint(
          '[TestResultService] Result $resultId not in main tests, trying collectionGroup search...',
        );
        final groupQuery = await _firestore
            .collectionGroup('tests')
            .where('id', isEqualTo: resultId)
            .get();

        if (groupQuery.docs.isNotEmpty) {
          doc = groupQuery.docs.first;
        } else {
          // Fallback searching member collections manually
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
      }

      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      final result = TestResultModel.fromJson(data);

      // Prescription loading removed - only needed in practitioner dashboard

      return result;
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

      Future<void> addDocs(QuerySnapshot snap) async {
        for (final doc in snap.docs) {
          if (processedIds.contains(doc.id)) continue;
          if (hiddenIds.contains(doc.id)) continue;

          final result = TestResultModel.fromJson({
            ...doc.data() as Map<String, dynamic>,
            'id': doc.id,
          });

          // Prescription loading removed

          results.add(result);
          processedIds.add(doc.id);
        }
      }

      await addDocs(legacySnapshot);
      await addDocs(nestedSnapshot);

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

      debugPrint('[TestResultService] … Result $resultId added to hidden list');
    } catch (e) {
      debugPrint('[TestResultService] Œ Soft delete ERROR: $e');
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
      final result = TestResultModel.fromJson({...doc.data(), 'id': doc.id});

      // Prescription loading removed

      return result;
    } catch (e) {
      throw Exception('Failed to get latest test result: $e');
    }
  }

  /// Get specific test results by their IDs
  Future<List<TestResultModel>> getTestResultsByIds(
    List<String> resultIds, {
    String? userId,
  }) async {
    if (resultIds.isEmpty) return [];

    try {
      debugPrint(
        '[TestResultService] Fetching ${resultIds.length} results by ID (User: $userId)',
      );

      if (userId != null) {
        // If we have userId, we can use getTestResults which handles self + family
        final allResults = await getTestResults(userId);
        return allResults.where((r) => resultIds.contains(r.id)).toList();
      }

      // Fallback: This is what produced the bug. We'll try to refine it or search by userId if available in booking
      // Note: FieldPath.documentId in collectionGroup requires full path.
      // As a fallback, we'll try to find any document that matches.
      // Better yet, we'll suggest using userId.
      final futures = resultIds.map((id) async {
        debugPrint(
          '[TestResultService] Warning: getTestResultsByIds without userId is unreliable.',
        );
        return null;
      });

      final results = await Future.wait(futures);
      return results.where((r) => r != null).cast<TestResultModel>().toList();
    } catch (e) {
      debugPrint('[TestResultService] Error fetching results by IDs: $e');
      return [];
    }
  }

  /// Get all test results for a practitioner's patients
  /// OPTIMIZED: Uses collectionGroup for O(1) fetch, with O(N) fallback if index building
  Future<List<TestResultModel>> getPractitionerPatientResults(
    String practitionerId,
  ) async {
    try {
      debugPrint(
        '[TestResultService] 📦 Fetching results for: $practitionerId',
      );

      // 1. Try optimized collectionGroup query
      try {
        final snapshot = await _firestore
            .collectionGroup('tests')
            .where('userId', isEqualTo: practitionerId)
            .orderBy('timestamp', descending: true)
            .limit(300)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final results = snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  data['id'] = doc.id;
                  final model = TestResultModel.fromJson(data);
                  return model.isDeleted ? null : model;
                } catch (e) {
                  return null;
                }
              })
              .where((r) => r != null)
              .cast<TestResultModel>()
              .toList();
          debugPrint(
            '[TestResultService] ✅ Loaded ${results.length} results via collectionGroup (filtered in-memory)',
          );
          return results;
        }
      } catch (e) {
        if (!e.toString().contains('failed-precondition')) {
          debugPrint('[TestResultService] Query error: $e');
        }
        debugPrint(
          '[TestResultService] ⚠️ Index missing or error, starting patient-by-patient fallback',
        );
      }

      // 2. FALLBACK: Patient-by-Patient lookup (Slow but 100% reliable without composite indexes)
      if (_fallbackCache != null &&
          _lastCacheTime != null &&
          DateTime.now().difference(_lastCacheTime!).inSeconds < 30) {
        debugPrint('[TestResultService] 🚀 Using in-memory fallback cache');
        return _fallbackCache!;
      }

      final List<TestResultModel> allResults = [];
      final auth = AuthService();
      final pData = await auth.getUserData(practitionerId);

      if (pData != null) {
        final pPath = 'Practitioners/${pData.identityString}/patients';
        final pDocs = await _firestore.collection(pPath).get();

        // Optimized: Parallel fetch for all patients to significantly speed up slow connections
        final List<Future<List<TestResultModel>>>
        fetchFutures = pDocs.docs.map((pDoc) async {
          final patient = PatientModel.fromFirestore(pDoc);
          final List<TestResultModel> results = [];

          try {
            // Path 1: Practitioner-specific patient tests
            final pTests = await _firestore
                .collection(pPath)
                .doc(patient.id)
                .collection('tests')
                .orderBy('timestamp', descending: true)
                .get(const GetOptions(source: Source.serverAndCache));

            for (final tDoc in pTests.docs) {
              final data = tDoc.data();
              data['id'] = tDoc.id;
              final res = TestResultModel.fromJson(data);
              if (!res.isDeleted) results.add(res);
            }

            // Path 2: IdentifiedResults (for patients with their own accounts)
            final iTests = await _firestore
                .collection('IdentifiedResults')
                .doc(patient.identityString)
                .collection('tests')
                .orderBy('timestamp', descending: true)
                .get(const GetOptions(source: Source.serverAndCache));

            for (final tDoc in iTests.docs) {
              final data = tDoc.data();
              data['id'] = tDoc.id;
              final res = TestResultModel.fromJson(data);
              // Prevent duplicates and filter deleted
              if (!res.isDeleted && !results.any((r) => r.id == tDoc.id)) {
                results.add(res);
              }
            }
          } catch (e) {
            debugPrint(
              '[TestResultService] ⚠️ Fallback fetch error for patient ${patient.id}: $e',
            );
          }
          return results;
        }).toList();

        final resultsLists = await Future.wait(fetchFutures);
        for (final list in resultsLists) {
          allResults.addAll(list);
        }
      }

      // Sort and deduplicate if necessary
      allResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final finalResults = allResults.take(300).toList();

      // Update cache
      _fallbackCache = finalResults;
      _lastCacheTime = DateTime.now();

      debugPrint(
        '[TestResultService] ✅ Loaded ${finalResults.length} results via fallback',
      );
      return finalResults;
    } catch (e) {
      debugPrint('[TestResultService] ❌ Sync Error: $e');
      return [];
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

  /// Get total count of results for a practitioner using Firestore aggregation
  Future<int> getPractitionerResultsCount(String practitionerId) async {
    try {
      // 1. Try optimized query
      try {
        final snapshot = await _firestore
            .collectionGroup('tests')
            .where('userId', isEqualTo: practitionerId)
            .count()
            .get();
        return snapshot.count ?? 0;
      } catch (e) {
        if (!e.toString().contains('failed-precondition')) rethrow;
        debugPrint('[TestResultService] Count index building, using fallback');
      }

      // 2. Fallback: Just get the full list and count it (since sync will do this anyway)
      final results = await getPractitionerPatientResults(practitionerId);
      return results.length;
    } catch (e) {
      debugPrint('[TestResultService] count error: $e');
      return 0;
    }
  }

  /// Get a page of test results for a practitioner
  Future<List<TestResultModel>> getPractitionerResultsPaged({
    required String practitionerId,
    required int limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // 1. Try optimized query
      try {
        var query = _firestore
            .collectionGroup('tests')
            .where('userId', isEqualTo: practitionerId)
            .orderBy('timestamp', descending: true)
            .limit(limit);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          _lastProcessedDoc = snapshot.docs.last;
          return snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  data['id'] = doc.id;
                  final model = TestResultModel.fromJson(data);
                  return model.isDeleted ? null : model;
                } catch (e) {
                  return null;
                }
              })
              .where((r) => r != null)
              .cast<TestResultModel>()
              .toList();
        }
        return [];
      } catch (e) {
        if (!e.toString().contains('failed-precondition')) rethrow;
        debugPrint('[TestResultService] Paged index building, using fallback');
      }

      // 2. Fallback: If paged fails, return the full set (usually small enough for fallback)
      if (startAfter == null) {
        return await getPractitionerPatientResults(practitionerId);
      }
      return [];
    } catch (e) {
      debugPrint('[TestResultService] paged error: $e');
      return [];
    }
  }

  DocumentSnapshot? _lastProcessedDoc;
  DocumentSnapshot? get lastProcessedDoc => _lastProcessedDoc;

  /// Helper to map technical test types to descriptive folder/category names
  String _getTestFolderName(String testType) {
    switch (testType) {
      case 'comprehensive':
        return 'FullExam';
      case 'quick':
        return 'QuickTest';
      case 'visual_acuity':
        return 'VisualAcuity';
      case 'color_vision':
        return 'ColorVision';
      case 'amsler_grid':
        return 'AmslerGrid';
      case 'reading_test':
        return 'ReadingTest';
      case 'contrast_sensitivity':
        return 'ContrastSensitivity';
      case 'mobile_refractometry':
        return 'MobileRefractometry';
      case 'shadow_test':
        return 'ShadowTest';
      default:
        // Capitalize default
        if (testType.isEmpty) return 'UnknownTest';
        return testType[0].toUpperCase() + testType.substring(1);
    }
  }
}
