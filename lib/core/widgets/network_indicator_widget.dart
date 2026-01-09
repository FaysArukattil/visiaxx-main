import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_connectivity_provider.dart';

/// Non-intrusive network status indicator that appears on the right side as overlay
class NetworkIndicatorWidget extends StatefulWidget {
  final Widget child;

  const NetworkIndicatorWidget({super.key, required this.child});

  @override
  State<NetworkIndicatorWidget> createState() => _NetworkIndicatorWidgetState();
}

class _NetworkIndicatorWidgetState extends State<NetworkIndicatorWidget> {
  bool _hasShownInitialStatus = false;

  // Routes where offline message should be persistent
  static const _persistentOfflineRoutes = {
    '/login',
    '/register',
    '/forgot-password',
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Pure overlay in top-right corner
        Positioned(
          top: 12,
          right: 12,
          child: Consumer<NetworkConnectivityProvider>(
            builder: (context, connectivity, _) {
              // Show snackbar notifications
              if (!_hasShownInitialStatus) {
                _hasShownInitialStatus = true;
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final currentRoute = ModalRoute.of(context)?.settings.name;
                  final isOnSplashScreen = currentRoute == '/';
                  final isPersistentRoute = _persistentOfflineRoutes.contains(
                    currentRoute,
                  );

                  if (!connectivity.isOnline) {
                    // Skip all offline snackbars on splash screen
                    if (isOnSplashScreen) return;

                    // Show persistent offline snackbar on auth screens, temporary on others
                    if (isPersistentRoute) {
                      _showPersistentOfflineSnackbar(context);
                    } else {
                      _showTemporaryOfflineSnackbar(context);
                    }
                  } else if (connectivity.justCameOnline) {
                    // Dismiss any existing snackbar
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();

                    // Only show "Connected to Network" if not on splash screen
                    if (!isOnSplashScreen) {
                      _showConnectedSnackbar(context);
                    }
                  }
                });
              }

              // Only show icon when offline
              if (!connectivity.isOnline) {
                return const _NetworkIcon();
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  void _showPersistentOfflineSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Internet Connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Please connect to network',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 365), // Persistent until dismissed
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showTemporaryOfflineSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Network disconnected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3), // Temporary - goes away
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showConnectedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Connected to Network',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _NetworkIcon extends StatefulWidget {
  const _NetworkIcon();

  @override
  State<_NetworkIcon> createState() => _NetworkIconState();
}

class _NetworkIconState extends State<_NetworkIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Icon(
        Icons.wifi_off_rounded,
        color: Theme.of(context).primaryColor,
        size: 24,
      ),
    );
  }
}
