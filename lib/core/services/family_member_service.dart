import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import 'package:visiaxx/core/services/local_storage_service.dart';
import '../../data/models/family_member_model.dart';

/// Service for managing family members in Firebase
class FamilyMemberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the organized collection path for family members
  Future<String> _familyMembersPath(String userId) async {
    // Try local storage FIRST for zero-latency offline path resolution
    final cachedUser = await LocalStorageService().getUserProfile();
    if (cachedUser != null && cachedUser.id == userId) {
      return 'NormalUsers/${cachedUser.identityString}/members';
    }

    // Fallback to AuthService (which has its own cache + fast timeout)
    final authService = AuthService();
    final user = await authService.getUserData(userId);
    if (user == null) {
      return 'NormalUsers/$userId/members';
    }
    return 'NormalUsers/${user.identityString}/members';
  }

  /// Save a family member to Firebase
  /// … ENHANCED: Returns the document ID and ensures proper error handling
  Future<String> saveFamilyMember({
    required String userId,
    required FamilyMemberModel member,
  }) async {
    try {
      debugPrint('[FamilyMemberService] Saving member for user: $userId');
      final path = await _familyMembersPath(userId);

      // Use descriptive IdentityString for document ID
      final identity = member.identityString;

      await _firestore.collection(path).doc(identity).set(member.toFirestore());

      debugPrint('[FamilyMemberService] … Saved with ID: $identity');
      return identity;
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] Œ Save ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to save family member: $e');
    }
  }

  /// Get all family members for a user
  /// … ENHANCED: Better error handling and real-time updates option
  Future<List<FamilyMemberModel>> getFamilyMembers(String userId) async {
    try {
      debugPrint('[FamilyMemberService] Getting members for user: $userId');
      final path = await _familyMembersPath(userId);

      final snapshot = await _firestore
          .collection(path)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      debugPrint('[FamilyMemberService] Found ${snapshot.docs.length} members');

      final List<FamilyMemberModel> members = [];
      for (final doc in snapshot.docs) {
        try {
          final member = FamilyMemberModel.fromFirestore(doc);
          if (!member.isDeleted) {
            members.add(member);
            debugPrint(
              '[FamilyMemberService] Loaded: ${member.firstName} (${doc.id})',
            );
          }
        } catch (e) {
          debugPrint('[FamilyMemberService] Œ Error parsing ${doc.id}: $e');
        }
      }

      debugPrint('[FamilyMemberService] … Loaded ${members.length} members');
      return members;
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] Œ Get ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to get family members: $e');
    }
  }

  /// … NEW: Stream for real-time updates of family members
  Stream<List<FamilyMemberModel>> getFamilyMembersStream(String userId) {
    return Stream.fromFuture(_familyMembersPath(userId)).asyncExpand((path) {
      return _firestore
          .collection(path)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            final List<FamilyMemberModel> members = [];
            for (final doc in snapshot.docs) {
              try {
                final member = FamilyMemberModel.fromFirestore(doc);
                if (!member.isDeleted) {
                  members.add(member);
                }
              } catch (e) {
                debugPrint(
                  '[FamilyMemberService] Œ Error parsing ${doc.id}: $e',
                );
              }
            }
            return members;
          });
    });
  }

  /// Delete a family member
  Future<void> deleteFamilyMember(String userId, String memberId) async {
    try {
      debugPrint('[FamilyMemberService] Soft deleting member: $memberId');
      final path = await _familyMembersPath(userId);

      await _firestore.collection(path).doc(memberId).update({
        'isDeleted': true,
      });

      debugPrint('[FamilyMemberService] … Soft deleted member: $memberId');
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService]  Œ Delete ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to delete family member: $e');
    }
  }

  /// Update an existing family member's details
  Future<void> updateFamilyMember({
    required String userId,
    required String memberId,
    required FamilyMemberModel member,
  }) async {
    try {
      debugPrint('[FamilyMemberService] Updating member: $memberId');

      // Extract stable ID from old identity or use current ID
      String stableId = member.id;
      if (memberId.contains('_')) {
        stableId = memberId.split('_').last;
      }

      // Generate new identity based on updated data
      final memberToUpdate = member.copyWith(id: stableId);
      final newIdentity = memberToUpdate.identityString;

      final path = await _familyMembersPath(userId);
      final collectionRef = _firestore.collection(path);

      if (memberId != newIdentity) {
        debugPrint(
          '[FamilyMemberService] Identity changed from $memberId to $newIdentity. Migrating results...',
        );

        // 1. Migrate test results
        await _migrateFamilyMemberTests(
          userId: userId,
          oldIdentity: memberId,
          newIdentity: newIdentity,
          newName: memberToUpdate.firstName,
          newAge: memberToUpdate.age,
          newSex: memberToUpdate.sex,
        );

        // 2. Delete old document
        await collectionRef.doc(memberId).delete();

        debugPrint(
          '[FamilyMemberService] ✅ Migration complete. Results will update via real-time stream.',
        );
      }

      // 3. Save new/updated document
      await collectionRef.doc(newIdentity).set(memberToUpdate.toFirestore());

      debugPrint('[FamilyMemberService] ✅ Member updated: $newIdentity');
    } catch (e) {
      debugPrint('[FamilyMemberService]  Œ Error updating member: $e');
      rethrow;
    }
  }

  /// Migrates test results for a family member
  Future<void> _migrateFamilyMemberTests({
    required String userId,
    required String oldIdentity,
    required String newIdentity,
    required String newName,
    required int newAge,
    required String newSex,
  }) async {
    try {
      debugPrint(
        '[FamilyMemberService] 🔄 Starting migration from $oldIdentity to $newIdentity',
      );

      // Fetch ALL tests from collectionGroup (no filters = no index needed!)
      // Then filter by userId AND profileId in memory
      debugPrint(
        '[FamilyMemberService] 📡 Fetching all tests from collectionGroup...',
      );
      final snapshot = await _firestore.collectionGroup('tests').get();

      debugPrint(
        '[FamilyMemberService] 📊 Found ${snapshot.docs.length} total tests in database',
      );

      // Filter in memory: first by userId, then by old profileId
      final docsToMigrate = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['userId'] == userId && data['profileId'] == oldIdentity;
      }).toList();

      debugPrint(
        '[FamilyMemberService] 🎯 Filtered to ${docsToMigrate.length} results to migrate for user $userId with profileId $oldIdentity',
      );

      if (docsToMigrate.isEmpty) {
        debugPrint(
          '[FamilyMemberService] ℹ️ No results to migrate for $oldIdentity',
        );
        return;
      }

      final batch = _firestore.batch();
      int movedCount = 0;
      int updatedCount = 0;

      for (final doc in docsToMigrate) {
        final oldPath = doc.reference.path;
        final data = doc.data();

        debugPrint('[FamilyMemberService] 📝 Processing result: ${doc.id}');
        debugPrint('[FamilyMemberService]    Old path: $oldPath');
        debugPrint(
          '[FamilyMemberService]    Old profileId: ${data['profileId']}',
        );
        debugPrint(
          '[FamilyMemberService]    Old profileName: ${data['profileName']}',
        );

        // Update metadata
        data['profileId'] = newIdentity;
        data['profileName'] = newName;
        data['profileAge'] = newAge;
        data['profileSex'] = newSex;

        // Check if the result is nested under the old member path
        // Family path: IdentifiedResults/{userId}/members/{memberId}/tests/{testId}
        if (oldPath.contains('/members/$oldIdentity/tests/')) {
          final newPath = oldPath.replaceFirst(
            '/members/$oldIdentity/tests/',
            '/members/$newIdentity/tests/',
          );
          debugPrint('[FamilyMemberService]    ➡️  Moving to: $newPath');
          debugPrint('[FamilyMemberService]    New profileId: $newIdentity');
          debugPrint('[FamilyMemberService]    New profileName: $newName');
          batch.set(_firestore.doc(newPath), data);
          batch.delete(doc.reference);
          movedCount++;
        } else {
          // Just update the fields in place
          debugPrint('[FamilyMemberService]    ✏️  Updating in place');
          debugPrint('[FamilyMemberService]    New profileId: $newIdentity');
          debugPrint('[FamilyMemberService]    New profileName: $newName');
          batch.update(doc.reference, {
            'profileId': newIdentity,
            'profileName': newName,
            'profileAge': newAge,
            'profileSex': newSex,
          });
          updatedCount++;
        }
      }

      debugPrint(
        '[FamilyMemberService] 💾 Committing batch: $movedCount moved, $updatedCount updated',
      );
      await batch.commit();
      debugPrint(
        '[FamilyMemberService] ✅ Migration complete! Migrated ${docsToMigrate.length} results (${movedCount} moved, ${updatedCount} updated in-place)',
      );

      // VERIFICATION: Check if results are actually accessible with new profileId
      debugPrint('[FamilyMemberService] 🔍 Verifying migration...');
      await Future.delayed(
        const Duration(milliseconds: 1000),
      ); // Wait for Firestore to process

      final verifySnapshot = await _firestore
          .collectionGroup('tests')
          .where('userId', isEqualTo: userId)
          .where('profileId', isEqualTo: newIdentity)
          .get();

      debugPrint(
        '[FamilyMemberService] ✓ Verification: Found ${verifySnapshot.docs.length} results with new profileId: $newIdentity',
      );

      if (verifySnapshot.docs.length != docsToMigrate.length) {
        debugPrint(
          '[FamilyMemberService] ⚠️ WARNING: Expected ${docsToMigrate.length} results but found ${verifySnapshot.docs.length} after migration!',
        );
      } else {
        debugPrint(
          '[FamilyMemberService] ✓ Verification successful! All results migrated correctly.',
        );
      }

      // Check for any orphaned results with old profileId
      final orphanedSnapshot = await _firestore
          .collectionGroup('tests')
          .where('userId', isEqualTo: userId)
          .where('profileId', isEqualTo: oldIdentity)
          .get();

      if (orphanedSnapshot.docs.isNotEmpty) {
        debugPrint(
          '[FamilyMemberService] ❌ ERROR: Found ${orphanedSnapshot.docs.length} orphaned results still with old profileId: $oldIdentity',
        );
        for (final doc in orphanedSnapshot.docs) {
          debugPrint(
            '[FamilyMemberService]    Orphaned: ${doc.id} at ${doc.reference.path}',
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] ❌ Error migrating family tests: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
    }
  }

  /// Recovery utility: Find and migrate orphaned results by matching names
  /// Call this to recover results that were lost during failed migrations
  Future<void> recoverOrphanedResults(String userId) async {
    try {
      debugPrint(
        '[FamilyMemberService] 🔧 Starting orphaned results recovery for user: $userId',
      );

      // Get all current family members
      final members = await getFamilyMembers(userId);
      debugPrint(
        '[FamilyMemberService] 👥 Found ${members.length} current family members',
      );

      // Fetch ALL tests for this user
      debugPrint('[FamilyMemberService] 📡 Fetching all tests...');
      final snapshot = await _firestore.collectionGroup('tests').get();

      final allUserTests = snapshot.docs
          .where((doc) => doc.data()['userId'] == userId)
          .toList();

      debugPrint(
        '[FamilyMemberService] 📊 Found ${allUserTests.length} total test results for user',
      );

      int recoveredCount = 0;
      final batch = _firestore.batch();

      // For each family member, find results that match their name but have wrong profileId
      for (final member in members) {
        final currentId = member.id; // Use member.id instead of identityString
        final memberName = member.firstName;

        debugPrint(
          '[FamilyMemberService] 🔍 Checking for orphaned results for: $memberName (current ID: $currentId)',
        );

        // Find results where name matches but profileId is different
        final orphanedResults = allUserTests.where((doc) {
          final data = doc.data();
          final profileName = data['profileName'];
          final profileId = data['profileId'];

          // Match by name but exclude if profileId is already correct
          // IMPORTANT: Also exclude if the current profileId looks like a corrupted duplicate
          final isDuplicate =
              currentId.contains(profileId) || profileId.contains(currentId);
          return profileName == memberName &&
              profileId != currentId &&
              !isDuplicate;
        }).toList();

        if (orphanedResults.isNotEmpty) {
          debugPrint(
            '[FamilyMemberService] 🎯 Found ${orphanedResults.length} orphaned results for $memberName',
          );

          for (final doc in orphanedResults) {
            final oldPath = doc.reference.path;
            final data = doc.data();
            final oldProfileId = data['profileId'];

            debugPrint('[FamilyMemberService]    📝 Recovering: ${doc.id}');
            debugPrint(
              '[FamilyMemberService]       Old profileId: $oldProfileId',
            );
            debugPrint('[FamilyMemberService]       New profileId: $currentId');

            // Update the data
            data['profileId'] = currentId;
            data['profileName'] = member.firstName;
            data['profileAge'] = member.age;
            data['profileSex'] = member.sex;

            // Move to correct path if needed
            if (oldPath.contains('/members/$oldProfileId/tests/')) {
              final newPath = oldPath.replaceFirst(
                '/members/$oldProfileId/tests/',
                '/members/$currentId/tests/',
              );
              debugPrint('[FamilyMemberService]       Moving to: $newPath');
              batch.set(_firestore.doc(newPath), data);
              batch.delete(doc.reference);
            } else {
              debugPrint('[FamilyMemberService]       Updating in place');
              batch.update(doc.reference, {
                'profileId': currentId,
                'profileName': member.firstName,
                'profileAge': member.age,
                'profileSex': member.sex,
              });
            }

            recoveredCount++;
          }
        }
      }

      if (recoveredCount > 0) {
        debugPrint(
          '[FamilyMemberService] 💾 Committing recovery batch for $recoveredCount results...',
        );
        await batch.commit();
        debugPrint(
          '[FamilyMemberService] ✅ Successfully recovered $recoveredCount orphaned results!',
        );
      } else {
        debugPrint(
          '[FamilyMemberService] ℹ️ No orphaned results found - all results are correctly linked',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] ❌ Error during recovery: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
    }
  }

  /// … NEW: Check if a user has any family members
  Future<bool> hasFamilyMembers(String userId) async {
    try {
      final path = await _familyMembersPath(userId);
      final snapshot = await _firestore.collection(path).limit(1).get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[FamilyMemberService] Œ Check ERROR: $e');
      return false;
    }
  }

  /// … NEW: Get a single family member by ID
  Future<FamilyMemberModel?> getFamilyMember(
    String userId,
    String memberId,
  ) async {
    try {
      final path = await _familyMembersPath(userId);
      final doc = await _firestore.collection(path).doc(memberId).get();

      if (!doc.exists) {
        return null;
      }

      return FamilyMemberModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[FamilyMemberService] Œ Get single member ERROR: $e');
      return null;
    }
  }
}
