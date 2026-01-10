import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_connectivity_provider.dart';
import '../constants/app_status.dart';
import '../utils/snackbar_utils.dart';
import 'package:visiaxx/main.dart';

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
                  // ModalRoute.of(context) is null here because we're above Navigator
                  // Use the global navigator key to find the current route name
                  String? currentRoute;
                  VisiaxApp.navigatorKey.currentState?.popUntil((route) {
                    currentRoute = route.settings.name;
                    return true;
                  });

                  final isOnSplashScreen = AppStatus.isSplashActive;
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
    SnackbarUtils.showNoInternet(context);
  }

  void _showTemporaryOfflineSnackbar(BuildContext context) {
    SnackbarUtils.showError(context, 'Network disconnected');
  }

  void _showConnectedSnackbar(BuildContext context) {
    SnackbarUtils.showSuccess(context, 'Connected to Network');
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
