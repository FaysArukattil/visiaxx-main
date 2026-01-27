import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_monitor_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/user_model.dart';

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
        // Check for email verification
        if (!result.isEmailVerified) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showVerificationDialog(_emailController.text.trim());
          }
          return;
        }

        // 1. Check for existing active session on another device
        final sessionService = SessionMonitorService();
        final isPractitioner = result.user!.role == UserRole.examiner;

        final checkResult = await sessionService.checkExistingSession(
          result.user!.identityString,
        );

        if (checkResult.exists &&
            checkResult.isOnline &&
            !checkResult.isOurSession &&
            !isPractitioner) {
          // Active session elsewhere - Block Login for regular users
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

        // 2. Create/Overwrite session
        final creationResult = await sessionService.createSession(
          result.user!.id,
          result.user!.identityString,
          isPractitioner: isPractitioner,
        );

        if (!creationResult.isSuccess) {
          // Session creation failed
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

        // 3. Start monitoring this session
        if (mounted) {
          sessionService.startMonitoring(
            result.user!.identityString,
            context,
            isPractitioner: isPractitioner,
          );
        }

        // 4. Navigate based on role
        if (!mounted) return;
        // Keep _isLoading = true until navigation starts to prevent the "stop" feeling
        await NavigationUtils.navigateHome(context);

        // At this point we are navigating away, so we don't need to set _isLoading = false
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
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: Text(
          'Your email $email is not verified. Please check your inbox for the verification link.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final resendResult = await _authService.sendEmailVerification();
              if (!context.mounted) return;
              setState(() => _isLoading = false);
              if (resendResult.isSuccess) {
                SnackbarUtils.showSuccess(
                  context,
                  resendResult.message ?? 'Verification email sent',
                );
              } else {
                SnackbarUtils.showError(
                  context,
                  resendResult.message ?? 'Failed to send verification email',
                );
              }
            },
            child: const Text('Resend Email'),
          ),
        ],
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                if (isLandscape) {
                  return Row(
                    children: [
                      // Left Side: Logo & Tagline
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppColors.primaryGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Image.asset(
                                    'assets/images/icons/app_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Visiaxx',
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Premium Digital Eye Care',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Move Sign Up here in landscape to save vertical space on the form
                              Column(
                                children: [
                                  Text(
                                    "Don't have an account?",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      if (!_isLoading) {
                                        Navigator.pushNamed(
                                          context,
                                          '/register',
                                        );
                                      }
                                    },
                                    child: Text(
                                      'Sign Up Now',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right Side: Form
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 16,
                          ),
                          child: Form(key: _formKey, child: _buildLoginForm()),
                        ),
                      ),
                    ],
                  );
                }

                // Portrait layout
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo Section
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: AppColors.primaryGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Image.asset(
                                      'assets/images/icons/app_icon.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Visiaxx',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Premium Digital Eye Care',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          _buildLoginForm(),

                          const SizedBox(height: 32),

                          // Sign Up Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (!_isLoading) {
                                    Navigator.pushNamed(context, '/register');
                                  }
                                },
                                child: Text(
                                  'Sign Up',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please enter your details to sign in',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 32),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Login Button
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.transparent,
                shadowColor: AppColors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const EyeLoader(size: 32, color: AppColors.white)
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
