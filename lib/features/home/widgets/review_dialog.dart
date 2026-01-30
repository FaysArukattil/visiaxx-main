import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/network_connectivity_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/review_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/review_model.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/eye_loader.dart';

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({super.key});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  final TextEditingController _reviewController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      SnackbarUtils.showError(context, 'Please select a rating');
      return;
    }

    if (_reviewController.text.trim().isEmpty) {
      SnackbarUtils.showError(context, 'Please write your review');
      return;
    }

    setState(() => _isSubmitting = true);

    final connectivity = Provider.of<NetworkConnectivityProvider>(
      context,
      listen: false,
    );

    if (!connectivity.isOnline) {
      // Queue the operation
      connectivity.queueOperation(() async {
        debugPrint(
          '[ReviewDialog] 🔄 Processing queued feedback submission...',
        );
        await _submitReviewLogic();
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        SnackbarUtils.showInfo(
          context,
          'No internet. Your feedback will be submitted when you are back online.',
        );
      }
      return;
    }

    try {
      await _submitReviewLogic();
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog on success
        SnackbarUtils.showSuccess(context, 'Thank you for your feedback!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Extracted logic for review submission to reuse in queued operation
  Future<void> _submitReviewLogic() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Get user data
    final userData = await _authService.getUserData(user.uid);
    if (userData == null) {
      throw Exception('User data not found');
    }

    // Create review model
    final review = ReviewModel(
      id: '',
      userId: user.uid,
      userName: userData.fullName,
      userAge: userData.age,
      rating: _rating,
      reviewText: _reviewController.text.trim(),
      timestamp: DateTime.now(),
    );

    // Submit review (Save to Firebase + Open Email)
    final success = await _reviewService.submitReview(review);

    if (success) {
      debugPrint('[ReviewDialog] ✅ Review submitted successfully');
      // If we are currently in the dialog (not a queued op), we pop it.
      // But _submitReview already handles popping for live submissions.
    } else {
      debugPrint('[ReviewDialog] ❌ Failed to submit review');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rate Your Experience',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: context.scaffoldBackground,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.primary,
                            context.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: AppColors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  Center(
                    child: Text(
                      'Your feedback helps us improve Visiaxx',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Star Rating
                  Center(
                    child: Wrap(
                      spacing: 8,
                      children: List.generate(5, (index) {
                        final starNumber = index + 1;
                        final isFilled = starNumber <= _rating;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _rating = starNumber);
                          },
                          child: Icon(
                            isFilled ? Icons.star : Icons.star_border,
                            size: 40,
                            color: isFilled
                                ? AppColors.warning
                                : context.dividerColor,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Review Text Field
                  Text(
                    'Tell us more',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Share your experience with Visiaxx...',
                      hintStyle: TextStyle(color: context.textTertiary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: context.scaffoldBackground,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Privacy Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This review will be sent to vnoptocare@gmail.com for feedback purposes and to improve our product.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: context.dividerColor),
                          ),
                          child: const Text('Maybe Later'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: context.primary,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: EyeLoader(
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
