import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';
import 'session_monitor_service.dart';

/// Firebase Authentication Service
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // Get user data from Firestore
        final userModel = await getUserData(credential.user!.uid);

        // Update last login
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });

        return AuthResult.success(user: userModel);
      }

      return AuthResult.failure(message: 'Sign in failed');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } on FirebaseException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Register with email and password
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required int age,
    required String sex,
    required String phone,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // Create user model
        final userModel = UserModel(
          id: credential.user!.uid,
          firstName: firstName,
          lastName: lastName,
          email: email.trim(),
          age: age,
          sex: sex,
          phone: phone,
          role: role,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          familyMemberIds: [],
        );

        // Save to Firestore
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userModel.toMap());

        // Update display name
        await credential.user!.updateDisplayName('$firstName $lastName');

        return AuthResult.success(user: userModel);
      }

      return AuthResult.failure(message: 'Registration failed');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } on FirebaseException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current user's role
  Future<UserRole?> getCurrentUserRole() async {
    if (currentUserId == null) return null;
    final user = await getUserData(currentUserId!);
    return user?.role;
  }

  /// Sign out with full session cleanup
  Future<void> signOut() async {
    try {
      // Remove session from Firebase Realtime Database
      final sessionMonitor = SessionMonitorService();
      await sessionMonitor.removeSession();
      sessionMonitor.stopMonitoring();

      debugPrint('[AuthService] ✅ Session removed, signing out...');
    } catch (e) {
      debugPrint('[AuthService] ⚠️ Error removing session: $e');
    }

    // Sign out from Firebase Auth
    await _auth.signOut();
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(message: 'Password reset email sent');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } on FirebaseException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(message: 'Failed to send reset email: $e');
    }
  }

  /// Delete user account
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete Firestore data
        await _firestore.collection('users').doc(user.uid).delete();
        // Delete auth account
        await user.delete();
        return AuthResult.success(message: 'Account deleted');
      }
      return AuthResult.failure(message: 'No user logged in');
    } catch (e) {
      return AuthResult.failure(message: 'Failed to delete account');
    }
  }

  /// Get friendly error message from Firebase error code
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Authentication error: $code';
    }
  }
}

/// Result class for auth operations
class AuthResult {
  final bool isSuccess;
  final String? message;
  final UserModel? user;

  AuthResult._({required this.isSuccess, this.message, this.user});

  factory AuthResult.success({UserModel? user, String? message}) {
    return AuthResult._(isSuccess: true, user: user, message: message);
  }

  factory AuthResult.failure({required String message}) {
    return AuthResult._(isSuccess: false, message: message);
  }
}
