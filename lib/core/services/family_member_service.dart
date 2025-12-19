import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/family_member_model.dart';

/// Service for managing family members in Firebase
class FamilyMemberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection paths
  static const String _familyMembersCollection = 'family_members';

  /// Save a family member to Firebase
  /// ✅ ENHANCED: Returns the document ID and ensures proper error handling
  Future<String> saveFamilyMember({
    required String userId,
    required FamilyMemberModel member,
  }) async {
    try {
      debugPrint('[FamilyMemberService] Saving member for user: $userId');
      debugPrint('[FamilyMemberService] Member data: ${member.toFirestore()}');

      // ✅ FIX: Add the member with auto-generated ID
      final docRef = await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .add(member.toFirestore());

      debugPrint('[FamilyMemberService] ✅ Saved with ID: ${docRef.id}');

      // ✅ VERIFY: Read back to ensure it was saved
      final verification = await docRef.get();
      if (!verification.exists) {
        throw Exception('Verification failed: Document not found after save');
      }

      return docRef.id;
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] ❌ Save ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to save family member: $e');
    }
  }

  /// Get all family members for a user
  /// ✅ ENHANCED: Better error handling and real-time updates option
  Future<List<FamilyMemberModel>> getFamilyMembers(String userId) async {
    try {
      debugPrint('[FamilyMemberService] Getting members for user: $userId');

      final snapshot = await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .orderBy('createdAt', descending: true)
          .get();

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
          debugPrint('[FamilyMemberService] ❌ Error parsing ${doc.id}: $e');
        }
      }

      debugPrint('[FamilyMemberService] ✅ Loaded ${members.length} members');
      return members;
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] ❌ Get ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to get family members: $e');
    }
  }

  /// ✅ NEW: Stream for real-time updates of family members
  Stream<List<FamilyMemberModel>> getFamilyMembersStream(String userId) {
    return _firestore
        .collection(_familyMembersCollection)
        .doc(userId)
        .collection('members')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '[FamilyMemberService] Stream update: ${snapshot.docs.length} members',
          );

          final List<FamilyMemberModel> members = [];
          for (final doc in snapshot.docs) {
            try {
              members.add(FamilyMemberModel.fromFirestore(doc));
            } catch (e) {
              debugPrint('[FamilyMemberService] ❌ Error parsing ${doc.id}: $e');
            }
          }
          return members;
        });
  }

  /// Delete a family member
  Future<void> deleteFamilyMember(String userId, String memberId) async {
    try {
      debugPrint('[FamilyMemberService] Deleting member: $memberId');

      await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .doc(memberId)
          .delete();

      debugPrint('[FamilyMemberService] ✅ Deleted member: $memberId');
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] ❌ Delete ERROR: $e');
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

      await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .doc(memberId)
          .update(member.toFirestore());

      debugPrint('[FamilyMemberService] ✅ Updated member: $memberId');
    } catch (e, stackTrace) {
      debugPrint('[FamilyMemberService] ❌ Update ERROR: $e');
      debugPrint('[FamilyMemberService] Stack trace: $stackTrace');
      throw Exception('Failed to update family member: $e');
    }
  }

  /// ✅ NEW: Check if a user has any family members
  Future<bool> hasFamilyMembers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[FamilyMemberService] ❌ Check ERROR: $e');
      return false;
    }
  }

  /// ✅ NEW: Get a single family member by ID
  Future<FamilyMemberModel?> getFamilyMember(
    String userId,
    String memberId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .doc(memberId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return FamilyMemberModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[FamilyMemberService] ❌ Get single member ERROR: $e');
      return null;
    }
  }
}
