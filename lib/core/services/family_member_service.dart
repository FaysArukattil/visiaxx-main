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
      }

      // 3. Save new/updated document
      await collectionRef.doc(newIdentity).set(memberToUpdate.toFirestore());

      debugPrint('[FamilyMemberService] … Member updated: $newIdentity');
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
      // Find all results across the DB using collectionGroup
      // but filtered by the current user and old member identity
      final snapshot = await _firestore
          .collectionGroup('tests')
          .where('userId', isEqualTo: userId)
          .where('profileId', isEqualTo: oldIdentity)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final oldPath = doc.reference.path;
        final data = doc.data();

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
          batch.set(_firestore.doc(newPath), data);
          batch.delete(doc.reference);
        } else {
          // Just update the fields in place
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
        '[FamilyMemberService] Migrated ${snapshot.docs.length} family member results',
      );
    } catch (e) {
      debugPrint('[FamilyMemberService] Error migrating family tests: $e');
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
