import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Provider for monitoring network connectivity status
class NetworkConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  bool _isOnline = false;
  bool _wasOffline = false;

  // Queue for pending operations that need network
  final List<Function> _pendingOperations = [];

  NetworkConnectivityProvider() {
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  /// Check if device is connected to internet
  bool get isOnline => _isOnline;

  /// Check if device was offline and just came back online
  bool get justCameOnline => _wasOffline && _isOnline;

  /// Get current connection type
  List<ConnectivityResult> get connectionStatus => _connectionStatus;

  /// Initialize connectivity status
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('[NetworkConnectivity] Error checking connectivity: $e');
      _connectionStatus = [ConnectivityResult.none];
      _isOnline = false;
      notifyListeners();
    }
  }

  /// Update connection status when connectivity changes
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final wasOnline = _isOnline;
    _connectionStatus = result;

    // Check if we have any connection
    _isOnline = result.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    // Track if we just came back online
    if (!wasOnline && _isOnline) {
      _wasOffline = true;
      debugPrint('[NetworkConnectivity] ✅ Back online: $result');
      _processPendingOperations();

      // Reset the flag after a short delay
      Future.delayed(const Duration(seconds: 3), () {
        _wasOffline = false;
        notifyListeners();
      });
    } else if (wasOnline && !_isOnline) {
      debugPrint('[NetworkConnectivity] ⚠️ Went offline');
    }

    debugPrint(
      '[NetworkConnectivity] Status: ${_isOnline ? "Online" : "Offline"} - $result',
    );
    notifyListeners();
  }

  /// Add operation to pending queue
  void queueOperation(Function operation) {
    if (_isOnline) {
      debugPrint(
        '[NetworkConnectivity] ⚡ Already online, executing operation immediately',
      );
      _executeOperation(operation);
    } else {
      _pendingOperations.add(operation);
      debugPrint(
        '[NetworkConnectivity] 📥 Queued operation. Total pending: ${_pendingOperations.length}',
      );
    }
  }

  Future<void> _executeOperation(Function operation) async {
    try {
      if (operation is Future Function()) {
        await operation();
      } else {
        operation();
      }
    } catch (e) {
      debugPrint('[NetworkConnectivity] ❌ Error executing operation: $e');
    }
  }

  /// Process all pending operations when back online
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    debugPrint(
      '[NetworkConnectivity] Processing ${_pendingOperations.length} pending operations...',
    );

    final operations = List<Function>.from(_pendingOperations);
    _pendingOperations.clear();

    for (final operation in operations) {
      try {
        await operation();
      } catch (e) {
        debugPrint(
          '[NetworkConnectivity] Error processing pending operation: $e',
        );
      }
    }
  }

  /// Check connectivity and return result
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isOnline;
    } catch (e) {
      debugPrint('[NetworkConnectivity] Error checking connectivity: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
