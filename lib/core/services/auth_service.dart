import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';
import 'session_monitor_service.dart';
import 'local_storage_service.dart';

/// Firebase Authentication Service
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache to prevent redundant fetches during navigation
  static UserModel? _cachedUser;

  /// Get cached user if available
  UserModel? get cachedUser => _cachedUser;

  /// Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Wait for the first valid auth state (to handle cold starts)
  /// Returns the current user or null if definitely not logged in
  Future<User?> getInitialUser() async {
    return waitForAuth(timeout: const Duration(seconds: 5));
  }

  /// Explicitly wait for Firebase Auth to stabilize.
  /// This handles cases where authStateChanges emits null initially before restoration.
  Future<User?> waitForAuth({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    debugPrint(
      '[AuthService] ⏳ Waiting for auth stabilization (${timeout.inSeconds}s max)...',
    );

    // Check immediate state first
    if (_auth.currentUser != null) {
      debugPrint(
        '[AuthService] ✅ Auth ready immediately: ${_auth.currentUser!.uid}',
      );
      return _auth.currentUser;
    }

    try {
      // Use authStateChanges stream - skip the first null if it happens immediately
      final user = await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(timeout);

      debugPrint('[AuthService] ✅ Auth stabilized via stream: ${user?.uid}');
      return user;
    } catch (e) {
      debugPrint('[AuthService] ⚠️ Auth stabilization timeout or no user: $e');
      return _auth.currentUser; // Final fallback to current state
    }
  }

  /// Sign in with email and password
  /// OPTIMIZED: Uses cache-first reads and defers non-critical updates
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
        final uid = credential.user!.uid;
        UserModel? userModel;

        // OPTIMIZATION 1: Try to get metadata from local cache first to avoid lookup hit
        final cachedMetadata = await LocalStorageService().getUserMetadata(uid);
        String? collection = cachedMetadata?['collection'];
        String? identityString = cachedMetadata?['identityString'];

        if (collection == null || identityString == null) {
          // Metadata miss or first login: Must check lookup
          try {
            final lookupDoc = await _firestore
                .collection('all_users_lookup')
                .doc(uid)
                .get(const GetOptions(source: Source.serverAndCache))
                .timeout(
                  const Duration(seconds: 30),
                ); // Increased for better resiliency on slow networks

            if (lookupDoc.exists && lookupDoc.data() != null) {
              collection = lookupDoc.data()!['collection'] as String?;
              identityString = lookupDoc.data()!['identityString'] as String?;

              if (collection != null && identityString != null) {
                // Cache it for next time
                unawaited(
                  LocalStorageService().saveUserMetadata(uid, {
                    'collection': collection,
                    'identityString': identityString,
                  }),
                );
              }
            }
          } catch (e) {
            debugPrint('[AuthService] Lookup failed or timed out: $e');
          }
        }

        // OPTIMIZATION 2: If we have identity (from cache or lookup), fetch user doc
        if (collection != null && identityString != null) {
          try {
            // Priority: Cache first (fast), then Server
            final userDoc = await _firestore
                .collection(collection)
                .doc(identityString)
                .get(const GetOptions(source: Source.serverAndCache))
                .timeout(const Duration(seconds: 30));

            if (userDoc.exists && userDoc.data() != null) {
              userModel = UserModel.fromMap(userDoc.data()!, userDoc.id);

              // Refresh cache - Ensure persisted before proceeding
              await LocalStorageService().saveUserProfile(userModel);

              // Fire-and-forget server updates (no await)
              unawaited(
                _firestore
                    .collection(collection)
                    .doc(identityString)
                    .update({'lastLoginAt': FieldValue.serverTimestamp()})
                    .catchError(
                      (e) =>
                          debugPrint('[AuthService] Error updating user: $e'),
                    ),
              );
              unawaited(
                _firestore
                    .collection('all_users_lookup')
                    .doc(uid)
                    .update({'lastLoginAt': FieldValue.serverTimestamp()})
                    .catchError(
                      (e) =>
                          debugPrint('[AuthService] Error updating lookup: $e'),
                    ),
              );
            }
          } catch (e) {
            debugPrint('[AuthService] User doc fetch failed or timed out: $e');
            // Try to load from previously saved full profile as absolute last resort
            userModel = await LocalStorageService().getUserProfile();
            if (userModel?.id != identityString) userModel = null;
          }
        }

        // Check verification
        if (!credential.user!.emailVerified) {
          return AuthResult.success(
            user: userModel,
            isVerified: false,
            message: 'Please verify your email address.',
          );
        }

        _cachedUser = userModel;
        return AuthResult.success(user: userModel, isVerified: true);
      }

      return AuthResult.failure(message: 'Sign in failed');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AuthService] FirebaseAuthException: ${e.code} - ${e.message}',
      );
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } on FirebaseException catch (e) {
      debugPrint('[AuthService] FirebaseException: ${e.code}');
      // Handle the 'unavailable' error specifically
      if (e.code == 'unavailable') {
        // Try to recover using ONLY cache if available
        final user = await LocalStorageService().getUserProfile();
        if (user != null) {
          _cachedUser = user;
          return AuthResult.success(user: user, isVerified: true);
        }
        return AuthResult.failure(
          message: 'Network unavailable. Please check your connection.',
        );
      }
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('[AuthService] Unexpected error: $e');
      return AuthResult.failure(message: 'Login error: $e');
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

        // Save to local cache
        await LocalStorageService().saveUserProfile(userModel);

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

        // Send verification email
        await sendEmailVerification();

        return AuthResult.success(
          user: userModel,
          isVerified: false,
          message: 'Verification email sent. Please check your inbox.',
        );
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
      debugPrint('[AuthService] ” Validating practitioner code: "$code"');
      final doc = await _firestore
          .collection('AppSettings')
          .doc('PractitionerAccess')
          .get();

      if (doc.exists && doc.data() != null) {
        final storedCode = doc.data()!['accessCode'] as String?;
        debugPrint('[AuthService] “„ Found stored code: "$storedCode"');

        if (storedCode == null) {
          debugPrint('[AuthService]  ï¸ storedCode is null in Firestore');
          return false;
        }

        // Use trim() on both sides to avoid accidental space issues
        final bool isValid = storedCode.trim() == code.trim();
        debugPrint('[AuthService] –ï¸ Validation result: $isValid');
        return isValid;
      } else {
        debugPrint(
          '[AuthService] Œ PractitionerAccess document does not exist in AppSettings collection',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[AuthService] Œ validatePractitionerCode error: $e');
      return false;
    }
  }

  /// Get user data from Firestore using the lookup system
  Future<UserModel?> getUserData(String uid) async {
    try {
      // 0. Security Check: ONLY allow fetching if we are authenticated
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint(
          '[AuthService] 🚫 getUserData: No authenticated user. Returning null.',
        );
        return null;
      }

      if (user.uid != uid) {
        // NOTE: Practitioners might fetch patient data, so this check is context-dependent
        // For now, we allow it but log it
        debugPrint(
          '[AuthService] ℹ️ Fetching data for different UID: $uid (Current: ${user.uid})',
        );
      }

      // 1. Check IN-MEMORY cache (Instant)
      if (_cachedUser != null && _cachedUser!.id == uid) {
        debugPrint('[AuthService] Returning in-memory cached user');
        unawaited(_refreshUserDataInBackground(uid));
        return _cachedUser;
      }

      // 1. Check local cache SECOND (Fastest)
      final cachedUser = await LocalStorageService().getUserProfile();
      if (cachedUser != null && cachedUser.id == uid) {
        debugPrint('[AuthService] Returning local storage cached user');
        _cachedUser = cachedUser;
        // Still try to refresh in background or later, but return immediately for UI
        _refreshUserDataInBackground(uid);
        return cachedUser;
      }

      // 2. Check lookup if not in cache or wrong user
      final lookupDoc = await _firestore
          .collection('all_users_lookup')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
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
          .get(const GetOptions(source: Source.serverAndCache));
      if (doc.exists && doc.data() != null) {
        final user = UserModel.fromMap(doc.data()!, doc.id);
        _cachedUser = user;
        // Save to cache
        await LocalStorageService().saveUserProfile(user);
        return user;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] getUserData error: $e');
      // Final fallback to cache on error
      return await LocalStorageService().getUserProfile();
    }
  }

  /// Get real-time user stream
  Stream<UserModel?> getUserStream(String uid) {
    // We first need the lookup to know which collection to listen to
    return _firestore
        .collection('all_users_lookup')
        .doc(uid)
        .snapshots()
        .asyncExpand((lookupSnap) {
          if (!lookupSnap.exists || lookupSnap.data() == null) {
            return Stream.value(null);
          }

          final collection = lookupSnap.data()!['collection'] as String;
          final identityString = lookupSnap.data()!['identityString'] as String;

          // Return the truly reactive stream of the user document
          return _firestore
              .collection(collection)
              .doc(identityString)
              .snapshots()
              .map((userDoc) {
                if (userDoc.exists && userDoc.data() != null) {
                  final user = UserModel.fromMap(userDoc.data()!, userDoc.id);
                  // Update local cache whenever we get a fresh stream update
                  LocalStorageService().saveUserProfile(user);
                  return user;
                }
                return null;
              });
        });
  }

  Future<void> _refreshUserDataInBackground(String uid) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null || currentUid != uid) {
        return;
      }
      // Background refresh should be silent and not block
      final lookupDoc = await _firestore
          .collection('all_users_lookup')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Background lookup timed out'),
          );

      if (lookupDoc.exists && lookupDoc.data() != null) {
        final collection = lookupDoc.data()!['collection'] as String;
        final identityString = lookupDoc.data()!['identityString'] as String;

        final doc = await _firestore
            .collection(collection)
            .doc(identityString)
            .get(const GetOptions(source: Source.serverAndCache));

        if (doc.exists && doc.data() != null) {
          final user = UserModel.fromMap(doc.data()!, doc.id);
          await LocalStorageService().saveUserProfile(user);
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Background refresh error: $e');
    }
  }

  /// Get current user's role
  Future<UserRole?> getCurrentUserRole() async {
    final user = await waitForAuth(timeout: const Duration(seconds: 3));
    if (user == null) return null;
    final userData = await getUserData(user.uid);
    return userData?.role;
  }

  /// Update user's agreement to terms and conditions status
  Future<bool> updateAgreementStatus(String uid, bool agreed) async {
    try {
      final lookupDoc = await _firestore
          .collection('all_users_lookup')
          .doc(uid)
          .get();

      if (lookupDoc.exists && lookupDoc.data() != null) {
        final collection = lookupDoc.data()!['collection'] as String;
        final identityString = lookupDoc.data()!['identityString'] as String;

        await _firestore.collection(collection).doc(identityString).update({
          'agreedToTerms': agreed,
        });

        // Update local cache
        final cachedUser = await LocalStorageService().getUserProfile();
        if (cachedUser != null && cachedUser.id == uid) {
          final updatedUser = cachedUser.copyWith(agreedToTerms: agreed);
          await LocalStorageService().saveUserProfile(updatedUser);
        }

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Error updating agreement status: $e');
      return false;
    }
  }

  /// Sign out with full session cleanup
  Future<void> signOut() async {
    try {
      // Remove session from Firebase Realtime Database
      final sessionMonitor = SessionMonitorService();
      await sessionMonitor.removeSession();
      sessionMonitor.stopMonitoring();

      debugPrint('[AuthService] … Session removed, signing out...');
    } catch (e) {
      debugPrint('[AuthService]  ï¸ Error removing session: $e');
    }

    // Clear local cache
    _cachedUser = null;
    await LocalStorageService().clearUserData();

    // Sign out from Firebase Auth
    await _auth.signOut();
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(
        message: 'Password reset link has been sent to your email.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } on FirebaseException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(message: 'Failed to send reset email: $e');
    }
  }

  /// Send email verification
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return AuthResult.success(message: 'Verification email sent');
      }
      return AuthResult.failure(message: 'No user to verify');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(message: 'Failed to send verification: $e');
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

        debugPrint('[AuthService] … Account and data deleted successfully');
        return AuthResult.success(message: 'Account deleted');
      }
      return AuthResult.failure(message: 'No user logged in');
    } catch (e) {
      debugPrint('[AuthService] Œ Delete account ERROR: $e');
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
  final bool isEmailVerified;

  AuthResult._({
    required this.isSuccess,
    this.message,
    this.user,
    this.isEmailVerified = true,
  });

  factory AuthResult.success({
    UserModel? user,
    String? message,
    bool isVerified = true,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
      isEmailVerified: isVerified,
    );
  }

  factory AuthResult.failure({required String message}) {
    return AuthResult._(isSuccess: false, message: message);
  }
}
