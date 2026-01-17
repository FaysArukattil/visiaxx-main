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
          members.add(member);
          debugPrint(
            '[FamilyMemberService] Loaded: ${member.firstName} (${doc.id})',
          );
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
                members.add(FamilyMemberModel.fromFirestore(doc));
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
      debugPrint('[FamilyMemberService] Deleting member: $memberId');
      final path = await _familyMembersPath(userId);

      await _firestore.collection(path).doc(memberId).delete();

      debugPrint('[FamilyMemberService] … Deleted member: $memberId');
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] Œ Delete ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to delete family member: $e');
    }
  }

  /// Update a family member
  Future<void> updateFamilyMember({
    required String userId,
    required String memberId,
    required FamilyMemberModel member,
  }) async {
    try {
      debugPrint('[FamilyMemberService] Updating member: $memberId');
      final path = await _familyMembersPath(userId);

      await _firestore
          .collection(path)
          .doc(memberId)
          .update(member.toFirestore());

      debugPrint('[FamilyMemberService] … Updated member: $memberId');
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] Œ Update ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to update family member: $e');
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

