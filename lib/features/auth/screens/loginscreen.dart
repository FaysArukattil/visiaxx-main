import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/session_monitor_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/user_model.dart';
import '../../../core/widgets/verification_dialog.dart';

/// Login screen with Firebase authentication
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result.isSuccess && result.user != null) {
        if (!result.isEmailVerified) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showVerificationDialog(_emailController.text.trim());
          }
          return;
        }

        final sessionService = SessionMonitorService();
        final isPractitioner = result.user!.role == UserRole.examiner;
        final identityString = result.user!.identityString;

        await LocalStorageService().saveCredentials(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (!isPractitioner) {
          final checkResult = await sessionService.checkExistingSession(
            identityString,
          );

          if (checkResult.exists &&
              checkResult.isOnline &&
              !checkResult.isOurSession) {
            await _authService.signOut();
            if (mounted) {
              setState(() {
                _errorMessage =
                    'Account is currently active on another device. Please logout there first.';
                _isLoading = false;
              });
            }
            return;
          }
        }

        final creationFuture = sessionService.createSession(
          result.user!.id,
          identityString,
          isPractitioner: isPractitioner,
        );

        final creationResult = await creationFuture.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('[Login] Session creation timed out but proceeding...');
            return SessionCreationResult(sessionId: 'pending');
          },
        );

        if (creationResult.error != null) {
          await _authService.signOut();
          if (mounted) {
            setState(() {
              _errorMessage =
                  creationResult.error ??
                  'Could not create session. Please try again.';
              _isLoading = false;
            });
          }
          return;
        }

        if (mounted) {
          sessionService.startMonitoring(
            identityString,
            context,
            isPractitioner: isPractitioner,
          );
        }

        if (!mounted) return;
        await NavigationUtils.navigateHome(context);
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                result.message?.contains('network-request-failed') == true
                ? 'No internet connection. Please check your network and try again.'
                : result.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VerificationDialog(
        title: 'Verify Your Email',
        message:
            'Your email $email is not verified. Please check your inbox for the verification link.',
        confirmLabel: 'Resend Email',
        cancelLabel: 'Cancel',
        onConfirm: () async {
          Navigator.pop(context);
          setState(() => _isLoading = true);
          final resendResult = await _authService.sendEmailVerification();
          if (!context.mounted) return;
          setState(() => _isLoading = false);
          if (resendResult.isSuccess) {
            showDialog(
              context: context,
              builder: (context) => VerificationDialog(
                isSuccess: true,
                title: 'Email Sent!',
                message:
                    resendResult.message ??
                    'A new verification link has been sent to your inbox.',
                confirmLabel: 'Got it',
                onConfirm: () => Navigator.pop(context),
              ),
            );
          } else {
            SnackbarUtils.showError(
              context,
              resendResult.message ?? 'Failed to send verification email',
            );
          }
        },
      ),
    );
  }

  void _handleForgotPassword() async {
    final result = await Navigator.pushNamed(context, '/forgot-password');
    if (result != null && result is String && mounted) {
      SnackbarUtils.showInfo(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Layering (Subtle Spheres)
          Positioned(
                top: -120,
                right: -120,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.primary.withValues(alpha: 0.1),
                        context.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 800.ms)
              .scale(begin: const Offset(0.8, 0.8)),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.08),
                    AppColors.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 800.ms, delay: 200.ms),

          SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                if (isLandscape) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Row(
                        children: [
                          // Left Side: Premium Branding
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBranding(isLandscape: true),
                                  const SizedBox(height: 48),
                                  _buildSignUpToggle(),
                                ],
                              ),
                            ),
                          ),
                          // Right Side: Luxury Form
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 24,
                              ),
                              child: Form(
                                key: _formKey,
                                child: _buildLoginForm(isLandscape: true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.05),
                  );
                }

                // Portrait layout
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBranding(isLandscape: false),
                            const SizedBox(height: 24),
                            _buildLoginForm(isLandscape: false),
                            const SizedBox(height: 24),
                            _buildSignUpToggle(),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding({required bool isLandscape}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: isLandscape ? 100 : 70,
          height: isLandscape ? 100 : 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.primary, context.primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isLandscape ? 28 : 20),
            boxShadow: [
              BoxShadow(
                color: context.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isLandscape ? 28 : 20),
            child: Image.asset(
              'assets/images/icons/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ).animate().scale(
          delay: 300.ms,
          duration: 500.ms,
          curve: Curves.easeOutBack,
        ),
        const SizedBox(height: 16),
        Text(
          'Visiaxx',
          style:
              (isLandscape
                      ? theme.textTheme.headlineLarge
                      : theme.textTheme.displaySmall)
                  ?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: context.primary,
                    letterSpacing: -1.2,
                  ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.primary.withValues(alpha: 0.1)),
          ),
          child: Text(
            'PREMIUM DIGITAL EYE CARE',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpToggle() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          "Don't have an account?",
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (!_isLoading) {
                Navigator.pushNamed(context, '/register');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Create New Account',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm({required bool isLandscape}) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isLandscape ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.primary.withValues(alpha: 0.08),
            context.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: context.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to your professional account',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.lock_person_rounded,
                color: context.primary.withValues(alpha: 0.2),
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              filled: true,
              fillColor: context.surface.withValues(alpha: 0.5),
            ),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
                return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              filled: true,
              fillColor: context.surface.withValues(alpha: 0.5),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Please enter your password';
              return null;
            },
          ),
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: context.primary,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Forgot Password?'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primary,
                  context.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: context.primary.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.transparent,
                  shadowColor: AppColors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isLoading
                    ? const EyeLoader(size: 32, color: AppColors.white)
                    : const Text(
                        'SIGN IN',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'By signing in, you agree to our Terms of Service\nand Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
