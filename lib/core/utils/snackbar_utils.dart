import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Centralized utility for showing professional, consistent snackbars throughout the app.
/// These snackbars use Overlay to show on top of everything, including modal bottom sheets.
class SnackbarUtils {
  static String? _lastMessage;
  static DateTime? _lastShownTime;
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  /// Show a success snackbar with premium styling
  static void showSuccess(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      backgroundColor: AppColors.success,
    );
  }

  /// Show an error snackbar with premium styling
  static void showError(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppColors.error,
    );
  }

  /// Show a warning snackbar with premium styling
  static void showWarning(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: AppColors.warning,
    );
  }

  /// Show a standardized no internet warning
  static void showNoInternet(BuildContext context, {String? customMessage}) {
    _showSnackbar(
      context,
      message:
          customMessage ?? 'No internet connection. Please check your network.',
      icon: Icons.wifi_off_rounded,
      backgroundColor: AppColors.error,
    );
  }

  /// Show an info snackbar with premium styling
  static void showInfo(BuildContext context, String message) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AppColors.info,
    );
  }

  /// Private method to show a professional, overlay-based floating snackbar
  static void _showSnackbar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final now = DateTime.now();

    // Anti-ghosting: If it's the same message triggered within 1 second,
    // don't re-trigger a new animation to avoid flickering.
    if (_lastMessage == message &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!) < const Duration(milliseconds: 1000)) {
      _lastShownTime = now;
      // Reset the timer even if we don't show a new one
      _dismissTimer?.cancel();
      _dismissTimer = Timer(duration, () => _removeCurrentSnackbar());
      return;
    }

    _lastMessage = message;
    _lastShownTime = now;

    _removeCurrentSnackbar();

    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _SnackbarWidget(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        onDismissed: () => _removeCurrentSnackbar(),
      ),
    );

    overlay.insert(_currentOverlay!);

    _dismissTimer = Timer(duration, () {
      _removeCurrentSnackbar();
    });
  }

  static void _removeCurrentSnackbar() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
  }
}

class _SnackbarWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onDismissed;

  const _SnackbarWidget({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.onDismissed,
  });

  @override
  State<_SnackbarWidget> createState() => _SnackbarWidgetState();
}

class _SnackbarWidgetState extends State<_SnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.backgroundColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
