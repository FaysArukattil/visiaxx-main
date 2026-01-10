import 'dart:async';
import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String? _currentUserId;
  bool _isMonitoring = false;
  bool _wasKickedOut = false;
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
    String identityString,
  ) async {
    try {
      debugPrint('[SessionMonitor] Creating session for: $identityString');

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

      // Store session in Firebase Realtime Database using identityString as key
      final sessionRef = _database.ref('active_sessions/$identityString');
      await sessionRef.set(sessionData.toMap());

      // Use onDisconnect to mark session as "Offline" with a special Kill Signal (-1)
      // This allows INSTANT takeover by other devices if this device is killed/crashed
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
      _currentUserId = userId;

      debugPrint(
        '[SessionMonitor] ✅ Session created: $sessionId under $identityString',
      );
      return SessionCreationResult(sessionId: sessionId);
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to create session: $e');
      return SessionCreationResult(error: 'Failed to create session: $e');
    }
  }

  /// Check if a session exists using the identity string
  Future<SessionCheckResult> checkExistingSession(String identityString) async {
    try {
      final sessionRef = _database.ref('active_sessions/$identityString');
      final snapshot = await sessionRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        return SessionCheckResult(exists: false);
      }

      final sessionData = SessionData.fromMap(
        snapshot.value as Map<dynamic, dynamic>,
      );

      // Instant Takeover Logic:
      // If lastActiveMillis is -1, it means the previous device was killed/disconnected
      final bool isKilled = sessionData.lastActiveMillis == -1;

      // Double-Lock Time Logic:
      // Only consider "Online" if isOnline is true AND it has been active within last 45 seconds
      // (reduced from 90s for tighter security, heartbeat is every 30s)
      final now = DateTime.now().millisecondsSinceEpoch;
      final bool isTimedOut =
          (now - sessionData.lastActiveMillis) > (45 * 1000);

      final bool isActuallyOnline =
          !isKilled && sessionData.isOnline && !isTimedOut;

      // Check if we have a stored session that matches
      final storedSessionId = await _secureStorage.read(key: _sessionIdKey);

      if (storedSessionId != null && storedSessionId == sessionData.sessionId) {
        return SessionCheckResult(
          exists: true,
          isOurSession: true,
          isOnline: isActuallyOnline,
          sessionData: sessionData,
        );
      }

      // Different session exists
      return SessionCheckResult(
        exists: true,
        isOurSession: false,
        isOnline: isActuallyOnline,
        sessionData: sessionData,
      );
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to check session: $e');
      return SessionCheckResult(exists: false, error: e.toString());
    }
  }

  /// Start monitoring the user's session using identity string
  void startMonitoring(String identityString, BuildContext context) {
    _currentContext = context;
    if (_isMonitoring) {
      debugPrint('[SessionMonitor] Already monitoring, updating context');
      return;
    }

    debugPrint('[SessionMonitor] 🔄 Monitoring session for: $identityString');
    _isMonitoring = true;

    final sessionRef = _database.ref('active_sessions/$identityString');

    _sessionSubscription = sessionRef.onValue.listen(
      (event) {
        if (_currentContext != null) {
          _handleSessionChange(event, _currentContext!);
        }
      },
      onError: (error) {
        debugPrint('[SessionMonitor] ❌ Stream error: $error');
      },
    );

    // Set online status and onDisconnect every time we start monitoring
    final now = DateTime.now().millisecondsSinceEpoch;
    _database.ref('active_sessions/$identityString').update({
      'isOnline': true,
      'lastActiveMillis': now,
    });

    // Ensure onDisconnect is refreshed
    _database.ref('active_sessions/$identityString').onDisconnect().update({
      'isOnline': false,
      'lastActiveMillis': -1, // Kill Signal
    });

    // Listen to connection status to trigger re-verification on network recovery
    _connectionSubscription = _database.ref('.info/connected').onValue.listen((
      event,
    ) {
      final isConnected = event.snapshot.value == true;
      if (isConnected && _isMonitoring) {
        debugPrint('[SessionMonitor] 🌐 Connection restored, re-verifying...');
        _verifyCurrentSession();
      }
    });

    // Start heartbeat
    _startHeartbeat();
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
    _wasKickedOut = true;

    // Clear local session info from memory immediately
    final oldSessionId = _currentSessionId;
    _currentSessionId = null;
    _currentUserId = null;

    if (!context.mounted) return;

    // Show alert to user
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
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
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
      // 1. If we were kicked out, don't delete the remote session
      // because it now belongs to the NEW device.
      if (_wasKickedOut) {
        debugPrint(
          '[SessionMonitor] Skipping remote remove: already kicked out',
        );
        _wasKickedOut = false; // Reset flag
        await _clearLocalSession();
        return;
      }

      // Load our current session ID if not in memory (e.g. at startup)
      _currentSessionId ??= await _secureStorage.read(key: _sessionIdKey);

      // 2. Try to get identityString from multiple sources
      String? identity = await _secureStorage.read(key: _identityStringKey);

      // If we don't have identityString, we might have userId (UID)
      String? userId =
          _currentUserId ?? await _secureStorage.read(key: _userIdKey);
      if (userId == null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        userId = currentUser?.uid;
      }

      if (identity != null) {
        debugPrint('[SessionMonitor] Checking session validity for: $identity');
        final sessionRef = _database.ref('active_sessions/$identity');

        // ONLY remove if the session ID in DB matches OUR session ID
        final snapshot = await sessionRef.get();
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          final dbSessionId = data['sessionId'] as String?;

          // CRITICAL: Must have a sessionId and it must match!
          // If _currentSessionId is null, we don't know who we are, so we MUST NOT delete.
          if (_currentSessionId != null && dbSessionId == _currentSessionId) {
            debugPrint(
              '[SessionMonitor] Removing session from Firebase: $identity',
            );
            await sessionRef.remove().timeout(
              const Duration(seconds: 5),
              onTimeout: () => debugPrint('[SessionMonitor] Remove timed out'),
            );
          } else {
            debugPrint(
              '[SessionMonitor] skipping remove: Session mismatch (Remote: $dbSessionId, Local: $_currentSessionId)',
            );
          }
        }
      } else if (userId != null) {
        debugPrint(
          '[SessionMonitor] No identityString, skipping legacy remove to be safe',
        );
        // We don't want to accidentally delete a descriptive session by UID path
      }

      await _clearLocalSession();
    } catch (e) {
      debugPrint('[SessionMonitor] ❌ Failed to remove session: $e');
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

    final result = await checkExistingSession(identity);
    if (result.exists && !result.isOurSession) {
      debugPrint('[SessionMonitor] 🚨 Resume conflict detected!');
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
    debugPrint('[SessionMonitor] ❤️ Heartbeat started (30s)');
  }

  /// Stop heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('[SessionMonitor] 💔 Heartbeat stopped');
  }

  /// Manually flag that this device was kicked out (used by SplashScreen)
  void markKickedOut() {
    _wasKickedOut = true;
    _currentSessionId = null;
    _currentUserId = null;
    debugPrint('[SessionMonitor] 🚩 Manually marked as kicked out');
  }

  /// Update last active timestamp
  Future<void> updateLastActive() async {
    String? identity = await _secureStorage.read(key: _identityStringKey);
    if (identity == null || _currentSessionId == null) return;

    try {
      final sessionRef = _database.ref('active_sessions/$identity');

      // Ownership Check: Fetch first to prevent double-logging
      final snapshot = await sessionRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final remoteSessionId = data['sessionId'] as String?;

        if (remoteSessionId != _currentSessionId) {
          debugPrint('[SessionMonitor] 🚨 Heartbeat detected conflict!');
          if (_currentContext != null) {
            final sessionData = SessionData.fromMap(data);
            _handleSessionConflict(_currentContext!, sessionData);
          }
          return;
        }
      }

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
      debugPrint('[SessionMonitor] ❌ Failed to update activity: $e');
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
