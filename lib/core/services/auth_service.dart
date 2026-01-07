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
        // 1. Find user metadata (collection path) from lookup
        final lookupDoc = await _firestore
            .collection('all_users_lookup')
            .doc(credential.user!.uid)
            .get();

        UserModel? userModel;
        if (lookupDoc.exists && lookupDoc.data() != null) {
          final collection = lookupDoc.data()!['collection'] as String;
          final identityString = lookupDoc.data()!['identityString'] as String;

          // 2. Get full data from the role-specific collection
          final userDoc = await _firestore
              .collection(collection)
              .doc(identityString)
              .get();
          if (userDoc.exists) {
            userModel = UserModel.fromMap(userDoc.data()!, userDoc.id);

            // 3. Update last login in both places
            await _firestore.collection(collection).doc(identityString).update({
              'lastLoginAt': FieldValue.serverTimestamp(),
            });
            await _firestore
                .collection('all_users_lookup')
                .doc(credential.user!.uid)
                .update({'lastLoginAt': FieldValue.serverTimestamp()});
          }
        } else {
          // Fallback: This might happen if someone logs in but wasn't migrated/registered with new system
          userModel = await getUserData(credential.user!.uid);
        }

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
    String? practitionerCode,
  }) async {
    try {
      // 1. Backend Validation
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email.trim())) {
        return AuthResult.failure(message: 'Invalid email format');
      }

      if (password.length < 6) {
        return AuthResult.failure(
          message: 'Password must be at least 6 characters',
        );
      }

      if (firstName.isEmpty) {
        return AuthResult.failure(message: 'First name is required');
      }

      if (age < 1 || age > 120) {
        return AuthResult.failure(message: 'Please enter a valid age (1-120)');
      }

      // Phone validation (exactly 10 digits after +91)
      final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
      // If it starts with 91 and has 12 digits, we check the last 10
      final actualDigits =
          (phoneDigits.startsWith('91') && phoneDigits.length == 12)
          ? phoneDigits.substring(2)
          : phoneDigits;

      if (actualDigits.length != 10) {
        return AuthResult.failure(
          message: 'Phone number must be exactly 10 digits',
        );
      }

      // 2. If role is examiner, validate the access code first
      if (role == UserRole.examiner) {
        if (practitionerCode == null || practitionerCode.isEmpty) {
          return AuthResult.failure(
            message: 'Practitioner access code is required',
          );
        }

        final isValidCode = await validatePractitionerCode(practitionerCode);
        if (!isValidCode) {
          return AuthResult.failure(
            message: "You don't have access to this feature",
          );
        }
      }

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

        final identity = userModel.identityString;
        final collection = userModel.roleCollection;

        // 1. Save to role-specific collection with DESCRIPTIVE document ID
        await _firestore
            .collection(collection)
            .doc(identity)
            .set(userModel.toMap());

        // 2. Save to lookup collection for UID -> Path mapping
        await _firestore
            .collection('all_users_lookup')
            .doc(credential.user!.uid)
            .set({
              'uid': credential.user!.uid,
              'identityString': identity,
              'collection': collection,
              'role': role.name,
              'email': email.trim(),
              'fullName': userModel.fullName,
              'age': age,
              'sex': sex,
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
            });

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

  /// Validate the practitioner access code against Firestore
  Future<bool> validatePractitionerCode(String code) async {
    try {
      debugPrint('[AuthService] 🔍 Validating practitioner code: "$code"');
      final doc = await _firestore
          .collection('AppSettings')
          .doc('PractitionerAccess')
          .get();

      if (doc.exists && doc.data() != null) {
        final storedCode = doc.data()!['accessCode'] as String?;
        debugPrint('[AuthService] 📄 Found stored code: "$storedCode"');

        if (storedCode == null) {
          debugPrint('[AuthService] ⚠️ storedCode is null in Firestore');
          return false;
        }

        // Use trim() on both sides to avoid accidental space issues
        final bool isValid = storedCode.trim() == code.trim();
        debugPrint('[AuthService] ⚖️ Validation result: $isValid');
        return isValid;
      } else {
        debugPrint(
          '[AuthService] ❌ PractitionerAccess document does not exist in AppSettings collection',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[AuthService] ❌ validatePractitionerCode error: $e');
      return false;
    }
  }

  /// Get user data from Firestore using the lookup system
  Future<UserModel?> getUserData(String uid) async {
    try {
      // 1. Check lookup first
      final lookupDoc = await _firestore
          .collection('all_users_lookup')
          .doc(uid)
          .get();
      if (!lookupDoc.exists || lookupDoc.data() == null) {
        // Check legacy 'users' collection as fallback
        final legacyDoc = await _firestore.collection('users').doc(uid).get();
        if (legacyDoc.exists && legacyDoc.data() != null) {
          return UserModel.fromMap(legacyDoc.data()!, legacyDoc.id);
        }
        return null;
      }

      final collection = lookupDoc.data()!['collection'] as String;
      final identityString = lookupDoc.data()!['identityString'] as String;

      // 2. Get full data
      final doc = await _firestore
          .collection(collection)
          .doc(identityString)
          .get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] getUserData error: $e');
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

  /// Delete user account and associated data
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final uid = user.uid;

        // 1. Get info from lookup
        final lookupDoc = await _firestore
            .collection('all_users_lookup')
            .doc(uid)
            .get();
        if (lookupDoc.exists && lookupDoc.data() != null) {
          final data = lookupDoc.data()!;
          final collection = data['collection'] as String;
          final identityString = data['identityString'] as String;

          // 2. Delete role-specific user data
          await _firestore.collection(collection).doc(identityString).delete();

          // 3. Delete indexed test results
          final testResults = await _firestore
              .collection('IdentifiedResults')
              .doc(identityString)
              .collection('tests')
              .get();

          final batch = _firestore.batch();
          for (final doc in testResults.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();

          // Delete the root document in "IdentifiedResults"
          await _firestore
              .collection('IdentifiedResults')
              .doc(identityString)
              .delete();

          // 4. Delete lookup entry
          await _firestore.collection('all_users_lookup').doc(uid).delete();
        }

        // 5. Delete legacy data for safety
        await _firestore.collection('users').doc(uid).delete();

        // 6. Delete auth account
        await user.delete();

        debugPrint('[AuthService] ✅ Account and data deleted successfully');
        return AuthResult.success(message: 'Account deleted');
      }
      return AuthResult.failure(message: 'No user logged in');
    } catch (e) {
      debugPrint('[AuthService] ❌ Delete account ERROR: $e');
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
