import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'data_cleanup_service.dart';

/// Session data structure for Firebase Realtime Database
class SessionData {
  final String sessionId;
  final String deviceInfo;
  final String loginTime;
  final String lastActive;
  final int lastActiveMillis;
  final bool isOnline;

  SessionData({
    required this.sessionId,
    required this.deviceInfo,
    required this.loginTime,
    required this.lastActive,
    required this.lastActiveMillis,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'deviceInfo': deviceInfo,
    'loginTime': loginTime,
    'lastActive': lastActive,
    'lastActiveMillis': lastActiveMillis,
    'isOnline': isOnline,
  };

  factory SessionData.fromMap(Map<dynamic, dynamic> map) {
    return SessionData(
      sessionId: map['sessionId'] as String? ?? '',
      deviceInfo: map['deviceInfo'] as String? ?? '',
      loginTime: map['loginTime']?.toString() ?? '',
      lastActive: map['lastActive']?.toString() ?? '',
      lastActiveMillis: map['lastActiveMillis'] as int? ?? 0,
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }
}

/// Service for monitoring active sessions and handling conflicts.
/// Ensures only one device can be logged in at a time per user account.
class SessionMonitorService with WidgetsBindingObserver {
  static final SessionMonitorService _instance =
      SessionMonitorService._internal();
  factory SessionMonitorService() => _instance;
  SessionMonitorService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  StreamSubscription<DatabaseEvent>? _sessionSubscription;
  String? _currentSessionId;
  bool _isMonitoring = false;
  bool _wasKickedOut = false;
  bool _isPractitioner = false;
  Timer? _heartbeatTimer;
  BuildContext? _currentContext;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  // Use WebOptions for web compatibility
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'visiaxx_secure_v2',
      publicKey: 'visiaxx_public_v2',
    ),
  );
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  static const String _sessionIdKey = 'visiaxx_session_id';
  static const String _userIdKey = 'visiaxx_user_id';
  static const String _identityStringKey = 'visiaxx_identity_string';

  /// Get device info for session tracking
  String _getDeviceInfo() {
    if (kIsWeb) return 'Web Browser';

    // We avoid Platform.isXXX to prevent crashes on web
    try {
      final platform = defaultTargetPlatform;
      if (platform == TargetPlatform.android) return 'Android Device';
      if (platform == TargetPlatform.iOS) return 'iOS Device';
      return 'Mobile Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Generate a new unique session ID
  String _generateSessionId() {
    return const Uuid().v4();
  }

  /// Create a new session for the user using their descriptive identity string
  /// Returns a [SessionCreationResult] containing the sessionId or an error message
  Future<SessionCreationResult> createSession(
    String userId,
    String identityString, {
    bool isPractitioner = false,
  }) async {
    try {
      debugPrint(
        '[SessionMonitor] Creating session for: $identityString (Practitioner: $isPractitioner)',
      );

      // If NOT a practitioner, we might want to clear old sessions first
      // However, usually we let the conflict logic handle it, or we clear it here.
      // For a clean transition, let's clear the whole node for regular users
      if (!isPractitioner) {
        debugPrint(
          '[SessionMonitor] Regular user login, clearing other sessions...',
        );
        await _database.ref('active_sessions/$identityString').remove();
      }

      final sessionId = _generateSessionId();
      final now = DateTime.now();
      final formattedTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final sessionData = SessionData(
        sessionId: sessionId,
        deviceInfo: _getDeviceInfo(),
        loginTime: formattedTime,
        lastActive: formattedTime,
        lastActiveMillis: now.millisecondsSinceEpoch,
        isOnline: true,
      );

      // Store session in Firebase Realtime Database using sessionId as a sub-node
      final sessionRef = _database.ref(
        'active_sessions/$identityString/$sessionId',
      );
      await sessionRef.set(sessionData.toMap());

      // Use onDisconnect to mark session as "Offline" with a special Kill Signal (-1)
      await sessionRef.onDisconnect().update({
        'isOnline': false,
        'lastActiveMillis': -1,
      });

      // Store session info locally
      await _secureStorage.write(key: _sessionIdKey, value: sessionId);
      await _secureStorage.write(key: _userIdKey, value: userId);
      await _secureStorage.write(
        key: _identityStringKey,
        value: identityString,
      );

      _currentSessionId = sessionId;

      debugPrint(
        '[SessionMonitor] â€¦ Session created: $sessionId under $identityString',
      );
      return SessionCreationResult(sessionId: sessionId);
    } catch (e) {
      debugPrint('[SessionMonitor] Å’ Failed to create session: $e');
      return SessionCreationResult(error: 'Failed to create session: $e');
    }
  }

  /// Check if an active session exists using the identity string
  /// For practitioners, this is just for info. For regular users, this blocks login.
  Future<SessionCheckResult> checkExistingSession(String identityString) async {
    try {
      final userSessionsRef = _database.ref('active_sessions/$identityString');
      final snapshot = await userSessionsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        return SessionCheckResult(exists: false);
      }

      // It's now a map of dynamic (sessionId) -> SessionData
      final Map<dynamic, dynamic> sessionsMap =
          snapshot.value as Map<dynamic, dynamic>;

      SessionData? conflictingSession;
      bool hasActiveOtherSession = false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final storedSessionId = await _secureStorage.read(key: _sessionIdKey);

      sessionsMap.forEach((key, value) {
        final sessionData = SessionData.fromMap(value as Map<dynamic, dynamic>);

        // Ownership Check
        if (storedSessionId != null &&
            sessionData.sessionId == storedSessionId) {
          return;
        }

        // Online Check
        final bool isKilled = sessionData.lastActiveMillis == -1;
        final bool isTimedOut =
            (now - sessionData.lastActiveMillis) > (45 * 1000);
        final bool isActuallyOnline =
            !isKilled && sessionData.isOnline && !isTimedOut;

        if (isActuallyOnline) {
          hasActiveOtherSession = true;
          conflictingSession = sessionData;
        }
      });

      if (hasActiveOtherSession) {
        return SessionCheckResult(
          exists: true,
          isOurSession: false,
          isOnline: true,
          sessionData: conflictingSession,
        );
      }

      return SessionCheckResult(exists: false);
    } catch (e) {
      debugPrint('[SessionMonitor] Å’ Failed to check session: $e');
      return SessionCheckResult(exists: false, error: e.toString());
    }
  }

  /// Start monitoring the user's session using identity string
  void startMonitoring(
    String identityString,
    BuildContext context, {
    bool isPractitioner = false,
  }) {
    _currentContext = context;
    _isPractitioner = isPractitioner;
    if (_isMonitoring) {
      debugPrint('[SessionMonitor] Already monitoring, updating context');
      return;
    }

    debugPrint(
      '[SessionMonitor] â€ â€ž Monitoring session for: $identityString',
    );
    _isMonitoring = true;

    final userSessionsRef = _database.ref('active_sessions/$identityString');

    _sessionSubscription = userSessionsRef.onValue.listen(
      (event) {
        if (_currentContext != null) {
          _handleSessionChange(event, _currentContext!);
        }
      },
      onError: (error) {
        debugPrint('[SessionMonitor] Å’ Stream error: $error');
      },
    );

    // Update OUR specific session node
    _updateMySessionStatus(identityString, true);

    // Listen to connection status to trigger re-verification on network recovery
    _connectionSubscription = _database.ref('.info/connected').onValue.listen((
      event,
    ) {
      final isConnected = event.snapshot.value == true;
      if (isConnected && _isMonitoring) {
        debugPrint('[SessionMonitor] Å’ Connection restored, re-verifying...');
        _verifyCurrentSession();
      }
    });

    // Start heartbeat
    _startHeartbeat();
  }

  Future<void> _updateMySessionStatus(
    String identityString,
    bool online,
  ) async {
    _currentSessionId ??= await _secureStorage.read(key: _sessionIdKey);
    if (_currentSessionId == null) return;

    final sessionRef = _database.ref(
      'active_sessions/$identityString/$_currentSessionId',
    );

    if (online) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await sessionRef.update({'isOnline': true, 'lastActiveMillis': now});

      // Ensure onDisconnect is refreshed
      await sessionRef.onDisconnect().update({
        'isOnline': false,
        'lastActiveMillis': -1, // Kill Signal
      });
    } else {
      await sessionRef.update({'isOnline': false});
    }
  }

  /// Handle session changes from Firebase
  void _handleSessionChange(DatabaseEvent event, BuildContext context) async {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      return;
    }

    try {
      // It's a map of sessions
      final Map<dynamic, dynamic> sessionsMap =
          event.snapshot.value as Map<dynamic, dynamic>;

      _currentSessionId ??= await _secureStorage.read(key: _sessionIdKey);
      if (_currentSessionId == null) return;

      // Check for cached practitioner status
      if (_isPractitioner) {
        // Practitioners allow multiple sessions, so no conflict handling needed here
        return;
      }

      SessionData? conflictingSession;
      bool conflictDetected = false;

      final now = DateTime.now().millisecondsSinceEpoch;

      sessionsMap.forEach((key, value) {
        if (conflictDetected) return;

        final sessionData = SessionData.fromMap(value as Map<dynamic, dynamic>);
        if (sessionData.sessionId == _currentSessionId) return;

        final bool isKilled = sessionData.lastActiveMillis == -1;
        final bool isTimedOut =
            (now - sessionData.lastActiveMillis) > (45 * 1000);

        if (!isKilled && sessionData.isOnline && !isTimedOut) {
          // This session is active and NOT ours. For non-practitioners, this is a conflict.
          conflictDetected = true;
          conflictingSession = sessionData;
        }
      });

      if (conflictDetected && conflictingSession != null) {
        debugPrint(
          '[SessionMonitor] âš  Session conflict detected for regular user!',
        );
        if (!context.mounted) return;
        await _handleSessionConflict(context, conflictingSession!);
      }
    } catch (e) {
      debugPrint('[SessionMonitor] âš  Error handling session change: $e');
    }
  }

  /// Handle session conflict - another device logged in
  Future<void> _handleSessionConflict(
    BuildContext context,
    SessionData remoteSession,
  ) async {
    debugPrint('[SessionMonitor] â€¼ Handling session conflict...');

    // Stop monitoring first to prevent loops
    stopMonitoring();
    _wasKickedOut = true;

    // Clear local session info from memory immediately
    _currentSessionId = null;

    if (!context.mounted) return;

    // Show alert to user
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF9800),
              size: 28,
            ),
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
              style: TextStyle(fontSize: 13, color: Colors.grey),
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
    if (!context.mounted) return;
    await DataCleanupService.cleanupAllData(context);

    if (!context.mounted) return;

    // Navigate to login
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  /// Remove the session from Firebase when logging out
  Future<void> removeSession() async {
    try {
      if (_wasKickedOut) {
        debugPrint(
          '[SessionMonitor] Skipping remote remove: already kicked out',
        );
        _wasKickedOut = false; // Reset flag
        await _clearLocalSession();
        return;
      }

      _currentSessionId ??= await _secureStorage.read(key: _sessionIdKey);
      String? identity = await _secureStorage.read(key: _identityStringKey);

      if (identity != null && _currentSessionId != null) {
        debugPrint(
          '[SessionMonitor] Removing session $_currentSessionId for: $identity',
        );
        final sessionRef = _database.ref(
          'active_sessions/$identity/$_currentSessionId',
        );
        await sessionRef.remove().timeout(
          const Duration(seconds: 5),
          onTimeout: () => debugPrint('[SessionMonitor] Remove timed out'),
        );
      }

      await _clearLocalSession();
    } catch (e) {
      debugPrint('[SessionMonitor] âš  Failed to remove session: $e');
      await _clearLocalSession();
    }
  }

  /// Clear local session storage
  Future<void> _clearLocalSession() async {
    try {
      await _secureStorage.delete(key: _sessionIdKey);
      await _secureStorage.delete(key: _userIdKey);
      _currentSessionId = null;
    } catch (e) {
      debugPrint('[SessionMonitor] âš  Failed to clear local session: $e');
    }
  }

  /// Stop monitoring session changes
  void stopMonitoring() {
    debugPrint('[SessionMonitor] Stopping session monitoring');
    _stopHeartbeat();
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _isMonitoring = false;
    _currentContext = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isMonitoring) {
      debugPrint('[SessionMonitor] App resumed, re-verifying session...');
      _verifyCurrentSession();
    }
  }

  /// Proactively verify current session (used on resume/reconnect)
  Future<void> _verifyCurrentSession() async {
    String? identity = await _secureStorage.read(key: _identityStringKey);
    if (identity == null) return;

    // If we're a practitioner, we don't care about other sessions
    if (_isPractitioner) return;

    final result = await checkExistingSession(identity);
    if (result.exists && !result.isOurSession) {
      debugPrint('[SessionMonitor] â€¼ Resume conflict detected!');
      if (_currentContext != null) {
        _handleSessionConflict(_currentContext!, result.sessionData!);
      }
    }
  }

  /// Start periodic heartbeat to keep session "Online"
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      updateLastActive();
    });
    debugPrint('[SessionMonitor] Â¤ï¸  Heartbeat started (30s)');
  }

  /// Stop heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('[SessionMonitor] â€™â€  Heartbeat stopped');
  }

  /// Manually flag that this device was kicked out (used by SplashScreen)
  void markKickedOut() {
    _wasKickedOut = true;
    _currentSessionId = null;
    debugPrint('[SessionMonitor] Å¡Â© Manually marked as kicked out');
  }

  /// Update last active timestamp
  Future<void> updateLastActive() async {
    String? identity = await _secureStorage.read(key: _identityStringKey);
    _currentSessionId ??= await _secureStorage.read(key: _sessionIdKey);
    if (identity == null || _currentSessionId == null) return;

    try {
      final sessionRef = _database.ref(
        'active_sessions/$identity/$_currentSessionId',
      );

      final now = DateTime.now();
      final formattedTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      await sessionRef.update({
        'lastActive': formattedTime,
        'lastActiveMillis': now.millisecondsSinceEpoch,
        'isOnline': true,
      });
    } catch (e) {
      debugPrint('[SessionMonitor] Å’ Failed to update activity: $e');
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
  final bool isOnline; // New field
  final SessionData? sessionData;
  final String? error;

  SessionCheckResult({
    required this.exists,
    this.isOurSession = false,
    this.isOnline = false,
    this.sessionData,
    this.error,
  });
}

/// Result of a session creation attempt
class SessionCreationResult {
  final String? sessionId;
  final String? error;

  bool get isSuccess => sessionId != null;

  SessionCreationResult({this.sessionId, this.error});
}
