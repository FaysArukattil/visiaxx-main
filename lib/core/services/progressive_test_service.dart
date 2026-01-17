import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/progressive_test_session_model.dart';

/// Service for managing progressive comprehensive test sessions
class ProgressiveTestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Create a new progressive test session
  Future<String> createSession({
    required String userId,
    required String profileId,
    required String profileName,
  }) async {
    try {
      final sessionId = _uuid.v4();
      final session = ProgressiveTestSession(
        sessionId: sessionId,
        userId: userId,
        profileId: profileId,
        profileName: profileName,
        startedAt: DateTime.now(),
        completedTests: [],
        testResults: {},
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('progressiveSessions')
          .doc(sessionId)
          .set(session.toFirestore());

      debugPrint('[ProgressiveTestService] … Created session: $sessionId');
      return sessionId;
    } catch (e) {
      debugPrint('[ProgressiveTestService] Œ Error creating session: $e');
      rethrow;
    }
  }

  /// Save test progress after each test completion
  Future<void> saveTestProgress({
    required String sessionId,
    required String userId,
    required String testType,
    required Map<String, dynamic> testData,
  }) async {
    try {
      debugPrint('[ProgressiveTestService] ’¾ Saving progress: $testType');

      final sessionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('progressiveSessions')
          .doc(sessionId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(sessionRef);

        if (!snapshot.exists) {
          throw Exception('Session not found: $sessionId');
        }

        final session = ProgressiveTestSession.fromJson(snapshot.data()!);

        final updatedResults = Map<String, dynamic>.from(session.testResults);
        updatedResults[testType] = testData;

        final updatedTests = List<String>.from(session.completedTests);
        if (!updatedTests.contains(testType)) {
          updatedTests.add(testType);
        }

        transaction.update(sessionRef, {
          'completedTests': updatedTests,
          'testResults': updatedResults,
          'lastUpdated': Timestamp.now(),
        });
      });

      debugPrint('[ProgressiveTestService] … Progress saved for: $testType');
    } catch (e) {
      debugPrint('[ProgressiveTestService] Œ Error saving progress: $e');
      rethrow;
    }
  }

  /// Get incomplete session for a user (if exists)
  Future<ProgressiveTestSession?> getIncompleteSession(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('progressiveSessions')
          .where('isComplete', isEqualTo: false)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final session = ProgressiveTestSession.fromFirestore(snapshot.docs.first);

      // Check if session is expired
      if (session.isExpired) {
        debugPrint('[ProgressiveTestService] ° Session expired, cleaning up');
        await _markSessionComplete(userId, session.sessionId);
        return null;
      }

      debugPrint(
        '[ProgressiveTestService] … Found incomplete session: ${session.sessionId}',
      );
      return session;
    } catch (e) {
      debugPrint('[ProgressiveTestService] Œ Error fetching session: $e');
      return null;
    }
  }

  /// Mark session as complete
  Future<void> completeSession(
    String userId,
    String sessionId, {
    String? pdfUrl,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('progressiveSessions')
          .doc(sessionId)
          .update({
            'isComplete': true,
            'lastUpdated': Timestamp.now(),
            if (pdfUrl != null) 'finalPdfUrl': pdfUrl,
          });

      debugPrint(
        '[ProgressiveTestService] … Session marked complete: $sessionId',
      );
    } catch (e) {
      debugPrint('[ProgressiveTestService] Œ Error completing session: $e');
    }
  }

  /// Private helper to mark session complete
  Future<void> _markSessionComplete(String userId, String sessionId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('progressiveSessions')
          .doc(sessionId)
          .update({'isComplete': true});
    } catch (e) {
      debugPrint(
        '[ProgressiveTestService] Œ Error marking session complete: $e',
      );
    }
  }

  /// Delete/cancel a session
  Future<void> deleteSession(String userId, String sessionId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('progressiveSessions')
          .doc(sessionId)
          .delete();

      debugPrint('[ProgressiveTestService] … Session deleted: $sessionId');
    } catch (e) {
      debugPrint('[ProgressiveTestService] Œ Error deleting session: $e');
    }
  }

  /// Get all sessions for a user (for debugging/admin)
  Future<List<ProgressiveTestSession>> getAllSessions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('progressiveSessions')
          .orderBy('startedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProgressiveTestSession.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[ProgressiveTestService] Œ Error fetching all sessions: $e');
      return [];
    }
  }
}

