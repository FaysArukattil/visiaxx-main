import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';
import 'dart:async';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/session_monitor_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/constants/app_status.dart';

/// Professional eye care splash screen with elegant animations
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _textFadeAnimation;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    AppStatus.isSplashActive = true;
    _setupAnimations();
    _startAnimationSequence();
  }

  void _setupAnimations() {
    // Faster logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Reduced from 1600
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  Future<void> _startAnimationSequence() async {
    // Reduced initial delay
    await Future.delayed(const Duration(milliseconds: 200)); // Reduced from 500
    if (!mounted) return;

    _logoController.forward();

    // 2. Reduced total time
    await Future.delayed(const Duration(milliseconds: 1500));

    // Add a timeout to the auth check to prevent getting stuck
    try {
      await _checkAuthAndNavigate().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
            '[SplashScreen] ±ï¸ Auth check timed out. Navigating to Login.',
          );
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      );
    } catch (e) {
      debugPrint(
        '[SplashScreen] Œ Error during auth check: $e. Navigating to Login.',
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    if (_authService.isLoggedIn) {
      final userId = _authService.currentUserId;
      if (userId == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // OPTIMIZATION: Try local cache first for instant UI
      UserModel? user = await LocalStorageService().getUserProfile();

      // Verify cached user matches current auth
      if (user != null && user.id != userId) {
        user = null; // Cache is stale
      }

      // OPTIMIZATION: If no valid cache, fetch from network with timeout
      if (user == null) {
        try {
          user = await _authService
              .getUserData(userId)
              .timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('[SplashScreen] ⚠️ Failed to fetch user data: $e');
        }
      }

      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final isPractitioner = user.role == UserRole.examiner;

      // OPTIMIZATION: For practitioners, skip session conflict check (multi-device allowed)
      if (!isPractitioner) {
        final sessionService = SessionMonitorService();
        try {
          final checkResult = await sessionService
              .checkExistingSession(user.identityString)
              .timeout(const Duration(seconds: 2));

          if (checkResult.exists && !checkResult.isOurSession) {
            debugPrint(
              '[SplashScreen] 🚨 Session stolen by another device. Forcing logout.',
            );

            sessionService.markKickedOut();

            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      const Icon(
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
                  content: Text(
                    'Your account is currently active on: ${checkResult.sessionData?.deviceInfo ?? 'Another Device'}.\n\nYou have been logged out on this device.',
                    style: const TextStyle(fontSize: 15),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }

            await _authService.signOut();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }

          // Start monitoring in background
          if (mounted) {
            sessionService.startMonitoring(
              user.identityString,
              context,
              isPractitioner: false,
            );
          }
        } catch (e) {
          debugPrint('[SplashScreen] ⚠️ Session check error: $e');
          // On timeout/error, proceed anyway (better UX than blocking)
        }
      } else {
        // Practitioners: just start monitoring, no conflict check
        if (mounted) {
          SessionMonitorService().startMonitoring(
            user.identityString,
            context,
            isPractitioner: true,
          );
        }
      }

      if (!mounted) return;
      await NavigationUtils.navigateHome(context);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    AppStatus.isSplashActive = false;
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.scaffoldBackgroundColor, colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              // Unified layout for both orientations, but with specific adjustments
              return Stack(
                children: [
                  // Centered logo
                  Center(
                    child: FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: SizedBox(
                          width: isLandscape ? 180 : 240,
                          height: isLandscape ? 180 : 240,
                          child: Image.asset(
                            'assets/images/icons/app_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tagline
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: isLandscape ? 70 : 130,
                    child: FadeTransition(
                      opacity: _textFadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Your Eye Partner',
                            style: TextStyle(
                              fontSize: isLandscape ? 16 : 18,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Professional Eye Care Solutions',
                            style: TextStyle(
                              fontSize: isLandscape ? 10 : 11,
                              fontWeight: FontWeight.w400,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Loading indicator
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: isLandscape ? 20 : 30,
                    child: Center(
                      child: isLandscape
                          ? EyeLoader(size: 24, color: context.primary)
                          : EyeLoader.fullScreen(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
