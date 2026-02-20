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
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    if (!mounted) return;

    _logoController.forward();

    // Start auth check in parallel with animation - NO pre-delay
    final authFuture = _checkAuthAndNavigate();

    // Minimum splash display time (reduced for snappier feel)
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await authFuture.timeout(
        const Duration(seconds: 8),
        onTimeout: () async {
          debugPrint('[SplashScreen] ⚠️ Auth check timed out.');
          if (mounted) {
            if (_cachedUser != null) {
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
      debugPrint('[SplashScreen] Error during auth check: $e');
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
        '[SplashScreen] ✅ Cache found: ${_cachedUser!.fullName}. Skipping Firebase wait.',
      );
      await _initializeSessionAndNavigate(_cachedUser!);
      return;
    }

    // No cache: wait for Firebase (first launch or logged out)
    debugPrint('[SplashScreen] 🔍 No cache. Waiting for Firebase Auth...');
    final initialUser = await _authService.getInitialUser();

    if (initialUser == null) {
      debugPrint('[SplashScreen] 🚫 No user logged in. Going to login.');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    debugPrint('[SplashScreen] ✅ Firebase user: ${initialUser.uid}');

    UserModel? user;
    try {
      user = await _authService
          .getUserData(initialUser.uid)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[SplashScreen] ⚠️ Failed to fetch user data: $e');
    }

    if (user == null) {
      debugPrint('[SplashScreen] 🚨 No profile found. Going to login.');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    await _initializeSessionAndNavigate(user);
  }

  Future<void> _initializeSessionAndNavigate(UserModel user) async {
    final sessionService = SessionMonitorService();
    final isPractitioner = user.role == UserRole.examiner;
    final identityString = user.identityString;

    debugPrint('[SplashScreen] Starting session initialization...');

    // STEP 1: Quick check if Firebase Auth is already available
    var firebaseUser = _authService.currentUser;

    // If not immediately available, wait briefly for restoration
    if (firebaseUser == null) {
      firebaseUser = await AuthService().waitForAuth(
        timeout: const Duration(seconds: 2),
      );
    }

    // STEP 1b: If Firebase session didn't restore, try silent re-auth
    if (firebaseUser == null) {
      debugPrint(
        '[SplashScreen] ⚠️ Firebase session not restored. Trying silent re-auth...',
      );
      firebaseUser = await AuthService().signInSilently();
    }

    if (firebaseUser == null) {
      debugPrint(
        '[SplashScreen] 🚫 Firebase Auth failed completely. Clearing stale cache.',
      );
      await LocalStorageService().clearUserData();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Best-effort token refresh (non-blocking, fire-and-forget)
    firebaseUser
        .getIdToken(true)
        .then((_) {
          debugPrint('[SplashScreen] ✅ Firebase ID token refreshed.');
        })
        .catchError((e) {
          debugPrint(
            '[SplashScreen] ⚠️ Token refresh failed (non-blocking): $e',
          );
        });

    // STEP 2: Check for session conflicts (regular users only)
    if (!isPractitioner) {
      debugPrint('[SplashScreen] Checking session conflict...');
      final checkResult = await sessionService.checkExistingSession(
        identityString,
      );
      debugPrint(
        '[SplashScreen] Check: exists=${checkResult.exists} ours=${checkResult.isOurSession} online=${checkResult.isOnline}',
      );

      if (checkResult.exists &&
          checkResult.isOnline &&
          !checkResult.isOurSession) {
        debugPrint('[SplashScreen] 🚫 Conflict detected. Going to login.');
        await LocalStorageService().clearUserData();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
    }

    // STEP 3: Create/Update session (must await so _currentSessionId is set before monitoring starts)
    debugPrint('[SplashScreen] Creating session...');
    final result = await sessionService.createSession(
      firebaseUser.uid,
      identityString,
      isPractitioner: isPractitioner,
    );

    if (result.error != null) {
      debugPrint(
        '[SplashScreen] ⚠️ Session creation error: ${result.error}. Proceeding anyway.',
      );
    }

    sessionService.startMonitoring(
      identityString,
      context,
      isPractitioner: isPractitioner,
    );

    // STEP 4: Navigate Home immediately
    if (mounted) {
      debugPrint('[SplashScreen] 🏠 Navigating home...');
      await NavigationUtils.navigateHome(context, preFetchedRole: user.role);
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
