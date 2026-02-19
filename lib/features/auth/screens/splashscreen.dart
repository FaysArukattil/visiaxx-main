import 'package:flutter/material.dart';
import '../../../core/constants/app_status.dart';
import '../../../core/extensions/theme_extension.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';
import 'dart:async';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/session_monitor_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/navigation_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  UserModel? _cachedUser;

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
        const Duration(seconds: 15), // Increased from 5s
        onTimeout: () async {
          debugPrint('[SplashScreen] ⚠️ Auth check timed out.');
          if (mounted) {
            // If Firebase says we ARE logged in, try to go home anyway instead of forcing login
            if (_authService.isLoggedIn) {
              debugPrint(
                '[SplashScreen] Still logged in via Firebase, attempting Home.',
              );
              // Use cached user role if available to speed up fallback
              await NavigationUtils.navigateHome(
                context,
                preFetchedRole: _cachedUser?.role,
              );
            } else {
              Navigator.pushReplacementNamed(context, '/login');
            }
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

    debugPrint('[SplashScreen] 🚀 Starting Cache-First Auth Check...');
    _cachedUser = await LocalStorageService().getUserProfile();

    if (_cachedUser != null) {
      debugPrint(
        '[SplashScreen] ✅ Cache found: ${_cachedUser!.fullName}. Navigating home IMMEDIATELY.',
      );

      // FIRE-AND-FORGET: Start auth stabilization in background
      unawaited(
        _authService.getInitialUser().then((user) {
          if (user != null) {
            debugPrint(
              '[SplashScreen] 🛡️ Background auth confirmed user: ${user.uid}',
            );
            // Ensure session monitoring is running
            SessionMonitorService().startMonitoring(
              _cachedUser!.identityString,
              context,
              isPractitioner: _cachedUser!.role == UserRole.examiner,
            );
          } else {
            debugPrint(
              '[SplashScreen] ⚠️ Background auth found NO user. Session monitoring will handle fallback.',
            );
          }
        }),
      );

      // Navigate immediately while background check runs
      if (mounted)
        await NavigationUtils.navigateHome(
          context,
          preFetchedRole: _cachedUser!.role,
        );
      return;
    }

    // NO CACHE: Must wait for Firebase (this is a first-time or logged-out start)
    debugPrint(
      '[SplashScreen] 🔍 No cache found. Waiting for Firebase Auth...',
    );
    User? initialUser = await _authService.getInitialUser();

    if (initialUser != null) {
      final userId = initialUser.uid;
      debugPrint('[SplashScreen] ✅ User logged in via Firebase: $userId');

      // Fetch profile from network since we have no cache
      UserModel? user;
      try {
        user = await _authService
            .getUserData(userId)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[SplashScreen] ⚠️ Failed to fetch user data: $e');
      }

      if (user == null) {
        debugPrint(
          '[SplashScreen] 🚨 No profile found even with valid auth. Redirecting to login.',
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Start monitoring
      if (mounted) {
        SessionMonitorService().startMonitoring(
          user.identityString,
          context,
          isPractitioner: user.role == UserRole.examiner,
        );
      }

      debugPrint('[SplashScreen] Navigating home with new session.');
      if (mounted)
        await NavigationUtils.navigateHome(context, preFetchedRole: user.role);
    } else {
      debugPrint('[SplashScreen] 🚫 No user logged in. Redirecting to login.');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
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
                          ? EyeLoader(
                              size: MediaQuery.of(context).size.width >= 600
                                  ? 48
                                  : 24,
                              color: context.primary,
                            )
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
