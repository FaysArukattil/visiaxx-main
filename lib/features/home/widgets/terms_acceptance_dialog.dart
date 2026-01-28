import 'package:flutter/material.dart';
import 'package:visiaxx/core/constants/app_colors.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import 'package:visiaxx/core/utils/snackbar_utils.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';

class TermsAcceptanceDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onAccepted;

  const TermsAcceptanceDialog({
    super.key,
    required this.userId,
    required this.onAccepted,
  });

  @override
  State<TermsAcceptanceDialog> createState() => _TermsAcceptanceDialogState();
}

class _TermsAcceptanceDialogState extends State<TermsAcceptanceDialog> {
  final AuthService _authService = AuthService();
  bool _isSubmitting = false;
  bool _isExpanded = false;

  Future<void> _handleAccept() async {
    setState(() => _isSubmitting = true);
    final success = await _authService.updateAgreementStatus(
      widget.userId,
      true,
    );
    setState(() => _isSubmitting = false);

    if (success) {
      widget.onAccepted();
    } else {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to save your agreement. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return PopScope(
      canPop: false, // Mandatory
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: AppColors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 100 : 20,
          vertical: 24,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Terms & Conditions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please review and agree to our terms to continue using Visiaxx Digital Eye Clinic.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  // Expandable Section
                  AnimatedCrossFade(
                    firstChild: const SizedBox(height: 20),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TermsPoint(
                                title: '1. Vision Screening Only',
                                content:
                                    'Visiaxx is for screening and monitoring only. It is NOT a diagnostic tool and does not provide medical diagnosis.',
                              ),
                              _TermsPoint(
                                title: '2. Potential for Errors',
                                content:
                                    'Results may vary due to lighting, device calibration, or user error. AI analysis provides clinical standards but is not infallible.',
                              ),
                              _TermsPoint(
                                title: '3. No Medical Liability',
                                content:
                                    'Vision Optocare is not responsible for health outcomes. Results are not a substitute for professional medical advice.',
                              ),
                              _TermsPoint(
                                title: '4. Data Collection',
                                content:
                                    'We collect vision scores, age, and feedback to improve our AI and services. Technical reports are stored securely in Firebase.',
                              ),
                              _TermsPoint(
                                title: '5. Privacy Policy',
                                content:
                                    'Your data is protected and handled in accordance with our strict confidentiality notice and data policy.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),

                  const SizedBox(height: 16),

                  if (!_isExpanded)
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = true),
                      child: Text(
                        'View Full Terms & Conditions',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  const Text(
                    'By clicking "I Agree", you acknowledge that you have read and accepted all policies and terms.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: !_isSubmitting ? _handleAccept : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.3,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: EyeLoader(
                                size: 24,
                                color: AppColors.white,
                              ),
                            )
                          : const Text(
                              'I Agree & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  if (!_isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'You must review the policy before agreeing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
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

class _TermsPoint extends StatelessWidget {
  final String title;
  final String content;

  const _TermsPoint({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
