import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/family_member_model.dart';

/// Service for managing family members in Firebase
class FamilyMemberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection paths
  static const String _familyMembersCollection = 'family_members';

  /// Save a family member to Firebase
  Future<String> saveFamilyMember({
    required String userId,
    required FamilyMemberModel member,
  }) async {
    try {
      debugPrint('[FamilyMemberService] Saving member for user: $userId');

      final docRef = await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .add(member.toFirestore());

      debugPrint('[FamilyMemberService] ✅ Saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[FamilyMemberService] ❌ Save ERROR: $e');
      throw Exception('Failed to save family member: $e');
    }
  }

  /// Get all family members for a user
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
          members.add(FamilyMemberModel.fromFirestore(doc));
        } catch (e) {
          debugPrint('[FamilyMemberService] ❌ Error parsing ${doc.id}: $e');
        }
      }

      debugPrint('[FamilyMemberService] ✅ Loaded ${members.length} members');
      return members;
    } catch (e) {
      debugPrint('[FamilyMemberService] ❌ Get ERROR: $e');
      throw Exception('Failed to get family members: $e');
    }
  }

  /// Delete a family member
  Future<void> deleteFamilyMember(String userId, String memberId) async {
    try {
      await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .doc(memberId)
          .delete();

      debugPrint('[FamilyMemberService] ✅ Deleted member: $memberId');
    } catch (e) {
      debugPrint('[FamilyMemberService] ❌ Delete ERROR: $e');
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
      await _firestore
          .collection(_familyMembersCollection)
          .doc(userId)
          .collection('members')
          .doc(memberId)
          .update(member.toFirestore());

      debugPrint('[FamilyMemberService] ✅ Updated member: $memberId');
    } catch (e) {
      debugPrint('[FamilyMemberService] ❌ Update ERROR: $e');
      throw Exception('Failed to update family member: $e');
    }
  }
}
