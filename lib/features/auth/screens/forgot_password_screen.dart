import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/verification_dialog.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Timer States
  int _resendCountdown = 0;
  Timer? _timer;
  bool _isLinkSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLinkSent && mounted) {
      _showSuccessConfirmationDialog();
    }
  }

  void _showSuccessConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VerificationDialog(
        title: 'Password Reset',
        message:
            'Have you successfully reset your password in your email?\n\nWould you like to continue to the login page?',
        confirmLabel: 'Yes, Continue',
        cancelLabel: 'Not Yet',
        onConfirm: () {
          Navigator.pop(context);
          Navigator.pop(
            context,
            'Password reset link sent. Please log in with your new password.',
          );
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _startTimer() {
    setState(() {
      _resendCountdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _authService.sendPasswordResetEmail(
        _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.isSuccess) {
            _successMessage =
                "Verification link has been sent to your email. Check your inbox to reset your password.";
            _isLinkSent = true;
            _startTimer();
            showDialog(
              context: context,
              builder: (context) => VerificationDialog(
                isSuccess: true,
                title: 'Link Sent!',
                message:
                    'A password reset link has been sent to ${_emailController.text}. Please check your inbox.',
                confirmLabel: 'OK',
                onConfirm: () => Navigator.pop(context),
              ),
            );
          } else {
            _errorMessage =
                result.message?.contains('network-request-failed') == true
                ? 'No internet connection. Please check your network and try again.'
                : result.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Layering
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
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
          ).animate().fadeIn(duration: 800.ms),
          Positioned(
            bottom: -50,
            left: -50,
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
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildHeader(isLandscape: true),
                                  const SizedBox(height: 48),
                                  _buildBackToLogin(),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 24,
                              ),
                              child: Form(
                                key: _formKey,
                                child: _buildResetForm(isLandscape: true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.05),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 32,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(isLandscape: false),
                            const SizedBox(height: 48),
                            _buildResetForm(isLandscape: false),
                            const SizedBox(height: 32),
                            _buildBackToLogin(),
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

  Widget _buildHeader({required bool isLandscape}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: context.primary.withValues(alpha: 0.1)),
          ),
          child: Icon(
            Icons.lock_reset_rounded,
            size: 40,
            color: context.primary,
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text(
          'Reset Password',
          style:
              (isLandscape
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: context.primary,
                    fontSize: isLandscape ? 32 : 26,
                    letterSpacing: -0.5,
                  ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "Enter your email address and we'll send you a link to reset your password",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBackToLogin() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            "Remember your password? ",
            style: TextStyle(color: context.textSecondary),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Sign In',
              style: TextStyle(
                color: context.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetForm({required bool isLandscape}) {
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
          if (_errorMessage != null || _successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_isLinkSent ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_isLinkSent ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isLinkSent
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: _isLinkSent ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (_successMessage ?? _errorMessage)!,
                      style: TextStyle(
                        color: _isLinkSent
                            ? AppColors.success
                            : AppColors.error,
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
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleResetPassword(),
            style: const TextStyle(fontWeight: FontWeight.w600),
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
          const SizedBox(height: 32),

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
            child: ElevatedButton(
              onPressed: (_isLoading || _resendCountdown > 0)
                  ? null
                  : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.transparent,
                shadowColor: AppColors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const EyeLoader(size: 32, color: AppColors.white)
                  : Text(
                      _resendCountdown > 0
                          ? 'RESEND IN ${_resendCountdown}S'
                          : (_isLinkSent ? 'RESEND LINK' : 'SEND RESET LINK'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
