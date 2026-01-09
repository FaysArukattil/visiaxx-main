import 'package:flutter/material.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';
import 'dart:async';
import '../../../core/services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
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

    // Reduced total time
    await Future.delayed(
      const Duration(milliseconds: 1500),
    ); // Reduced from 2800
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    if (_authService.isLoggedIn) {
      final userId = _authService.currentUserId;
      UserModel? user;
      if (userId != null) {
        // 1. Fetch user data to get identityString
        user = await _authService.getUserData(userId);

        if (user != null && mounted) {
          // 2. STRICTOR CHECK: Verify if we still own the active session
          final sessionService = SessionMonitorService();
          final checkResult = await sessionService.checkExistingSession(
            user.identityString,
          );

          if (checkResult.exists && !checkResult.isOurSession) {
            debugPrint(
              '[SplashScreen] 🚨 Session stolen by another device. Forcing logout.',
            );

            // FLAG as kicked out so removeSession doesn't delete the new remote session!
            sessionService.markKickedOut();

            // Show alert before navigating
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
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
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

            // Perform cleanup
            await _authService.signOut();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }

          // 3. Start monitoring if session is valid
          sessionService.startMonitoring(user.identityString, context);
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
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Centered logo
              Center(
                child: FadeTransition(
                  opacity: _logoFadeAnimation,
                  child: ScaleTransition(
                    scale: _logoScaleAnimation,
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: Image.asset(
                        'assets/images/icons/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // Tagline at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 100,
                child: FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Your Eye Partner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Professional Eye Care Solutions',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Loading indicator at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Center(child: EyeLoader.fullScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
