import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'data_cleanup_service.dart';

/// Session data structure for Firebase Realtime Database
class SessionData {
  final String sessionId;
  final String deviceInfo;
  final int loginTime;
  final int lastActive;

  SessionData({
    required this.sessionId,
    required this.deviceInfo,
    required this.loginTime,
    required this.lastActive,
  });

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'deviceInfo': deviceInfo,
    'loginTime': loginTime,
    'lastActive': lastActive,
  };

  factory SessionData.fromMap(Map<dynamic, dynamic> map) {
    return SessionData(
      sessionId: map['sessionId'] as String? ?? '',
      deviceInfo: map['deviceInfo'] as String? ?? '',
      loginTime: map['loginTime'] as int? ?? 0,
      lastActive: map['lastActive'] as int? ?? 0,
    );
  }
}

/// Service for monitoring active sessions and handling conflicts.
/// Ensures only one device can be logged in at a time per user account.
class SessionMonitorService {
  static final SessionMonitorService _instance =
      SessionMonitorService._internal();
  factory SessionMonitorService() => _instance;
  SessionMonitorService._internal();

  StreamSubscription<DatabaseEvent>? _sessionSubscription;
  String? _currentSessionId;
  String? _currentUserId;
  bool _isMonitoring = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  static const String _sessionIdKey = 'visiaxx_session_id';
  static const String _userIdKey = 'visiaxx_user_id';

  /// Get device info for session tracking
  String _getDeviceInfo() {
    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      } else {
        return 'Unknown Device';
      }
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Generate a new unique session ID
  String _generateSessionId() {
    return const Uuid().v4();
  }

  /// Create a new session for the user
  /// Returns the session ID if successful, null otherwise
  Future<String?> createSession(String userId) async {
    try {
      debugPrint('[SessionMonitor] Creating session for user: $userId');

      final sessionId = _generateSessionId();
      final sessionData = SessionData(
        sessionId: sessionId,
        deviceInfo: _getDeviceInfo(),
        loginTime: DateTime.now().millisecondsSinceEpoch,
        lastActive: DateTime.now().millisecondsSinceEpoch,
      );

      // Store session in Firebase Realtime Database
      final sessionRef = _database.ref('active_sessions/$userId');
      await sessionRef.set(sessionData.toMap());

      // Store session ID locally
      await _secureStorage.write(key: _sessionIdKey, value: sessionId);
      await _secureStorage.write(key: _userIdKey, value: userId);

      _currentSessionId = sessionId;
      _currentUserId = userId;

      debugPrint('[SessionMonitor] ✅ Session created: $sessionId');
      return sessionId;
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to create session: $e');
      return null;
    }
  }

  /// Check if a session exists for the user and if it matches our session
  Future<SessionCheckResult> checkExistingSession(String userId) async {
    try {
      final sessionRef = _database.ref('active_sessions/$userId');
      final snapshot = await sessionRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        return SessionCheckResult(exists: false);
      }

      final sessionData = SessionData.fromMap(
        snapshot.value as Map<dynamic, dynamic>,
      );

      // Check if we have a stored session that matches
      final storedSessionId = await _secureStorage.read(key: _sessionIdKey);

      if (storedSessionId != null && storedSessionId == sessionData.sessionId) {
        // This is our session, we can continue
        return SessionCheckResult(
          exists: true,
          isOurSession: true,
          sessionData: sessionData,
        );
      }

      // Different session exists
      return SessionCheckResult(
        exists: true,
        isOurSession: false,
        sessionData: sessionData,
      );
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to check session: $e');
      return SessionCheckResult(exists: false, error: e.toString());
    }
  }

  /// Start monitoring the user's session for conflicts
  void startMonitoring(String userId, BuildContext context) {
    if (_isMonitoring) {
      debugPrint('[SessionMonitor] Already monitoring, skipping');
      return;
    }

    debugPrint('[SessionMonitor] 🔄 Starting session monitoring for: $userId');

    _currentUserId = userId;
    _isMonitoring = true;

    final sessionRef = _database.ref('active_sessions/$userId');

    _sessionSubscription = sessionRef.onValue.listen(
      (event) {
        _handleSessionChange(event, context);
      },
      onError: (error) {
        debugPrint('[SessionMonitor] ❌ Stream error: $error');
      },
    );
  }

  /// Handle session changes from Firebase
  void _handleSessionChange(DatabaseEvent event, BuildContext context) async {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      // Session was removed - likely we logged out, ignore
      debugPrint('[SessionMonitor] Session removed from database');
      return;
    }

    try {
      final sessionData = SessionData.fromMap(
        event.snapshot.value as Map<dynamic, dynamic>,
      );

      // Load our stored session ID if we don't have it
      _currentSessionId ??= await _secureStorage.read(key: _sessionIdKey);

      if (_currentSessionId == null) {
        // No local session ID, this shouldn't happen
        debugPrint('[SessionMonitor] ⚠️ No local session ID found');
        return;
      }

      if (sessionData.sessionId != _currentSessionId) {
        // Different device logged in!
        debugPrint(
          '[SessionMonitor] ⚠️ Session conflict detected! Remote: ${sessionData.sessionId}, Local: $_currentSessionId',
        );
        await _handleSessionConflict(context, sessionData);
      }
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Error handling session change: $e');
    }
  }

  /// Handle session conflict - another device logged in
  Future<void> _handleSessionConflict(
    BuildContext context,
    SessionData remoteSession,
  ) async {
    debugPrint('[SessionMonitor] 🚨 Handling session conflict...');

    // Stop monitoring first to prevent loops
    stopMonitoring();

    // Clear local session
    await _clearLocalSession();

    if (!context.mounted) return;

    // Show alert to user
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Logged Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account has been logged in on another device.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              'Device: ${remoteSession.deviceInfo}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToLogin(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Navigate to login screen after cleanup
  Future<void> _navigateToLogin(BuildContext context) async {
    // Perform full cleanup
    await DataCleanupService.cleanupAllData(context);

    if (!context.mounted) return;

    // Navigate to login
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  /// Remove the session from Firebase when logging out
  Future<void> removeSession() async {
    try {
      final userId =
          _currentUserId ?? await _secureStorage.read(key: _userIdKey);

      if (userId != null) {
        debugPrint('[SessionMonitor] Removing session for user: $userId');
        final sessionRef = _database.ref('active_sessions/$userId');
        await sessionRef.remove();
      }

      await _clearLocalSession();
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to remove session: $e');
      // Still clear local session even if Firebase fails
      await _clearLocalSession();
    }
  }

  /// Clear local session storage
  Future<void> _clearLocalSession() async {
    try {
      await _secureStorage.delete(key: _sessionIdKey);
      await _secureStorage.delete(key: _userIdKey);
      _currentSessionId = null;
      _currentUserId = null;
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to clear local session: $e');
    }
  }

  /// Stop monitoring session changes
  void stopMonitoring() {
    debugPrint('[SessionMonitor] Stopping session monitoring');
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _isMonitoring = false;
  }

  /// Update last active timestamp (optional, for session timeout)
  Future<void> updateLastActive() async {
    if (_currentUserId == null) return;

    try {
      final sessionRef = _database.ref(
        'active_sessions/$_currentUserId/lastActive',
      );
      await sessionRef.set(DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to update last active: $e');
    }
  }

  /// Check if currently monitoring
  bool get isMonitoring => _isMonitoring;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}

/// Result of checking for existing sessions
class SessionCheckResult {
  final bool exists;
  final bool isOurSession;
  final SessionData? sessionData;
  final String? error;

  SessionCheckResult({
    required this.exists,
    this.isOurSession = false,
    this.sessionData,
    this.error,
  });
}
