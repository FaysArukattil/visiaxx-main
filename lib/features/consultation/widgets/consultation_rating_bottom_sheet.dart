import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/providers/network_connectivity_provider.dart';

class ConsultationRatingBottomSheet extends StatefulWidget {
  final String bookingId;
  final String doctorId;
  final String doctorName;

  const ConsultationRatingBottomSheet({
    super.key,
    required this.bookingId,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<ConsultationRatingBottomSheet> createState() =>
      _ConsultationRatingBottomSheetState();
}

class _ConsultationRatingBottomSheetState
    extends State<ConsultationRatingBottomSheet> {
  final _consultationService = ConsultationService();
  final _feedbackController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      SnackbarUtils.showError(context, 'Please select a star rating');
      return;
    }

    setState(() => _isSubmitting = true);

    final connectivity = Provider.of<NetworkConnectivityProvider>(
      context,
      listen: false,
    );
    if (!connectivity.isOnline) {
      setState(() => _isSubmitting = false);
      SnackbarUtils.showError(
        context,
        'No internet connection. Please try again later.',
      );
      return;
    }

    try {
      final success = await _consultationService.rateDoctor(
        bookingId: widget.bookingId,
        doctorId: widget.doctorId,
        rating: _rating.toDouble(),
        review: _feedbackController.text.trim(),
      );

      if (success && mounted) {
        Navigator.pop(context, true);
        SnackbarUtils.showSuccess(context, 'Thank you for your rating!');
      } else if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to save rating. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Header Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_rounded, color: context.primary, size: 40),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),

            // Title
            Text(
              'How was your session?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rate your consultation with\nDr. ${widget.doctorName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child:
                      Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isSelected
                                  ? Colors.amber
                                  : context.dividerColor.withValues(alpha: 0.3),
                              size: 48,
                            ),
                          )
                          .animate(target: isSelected ? 1 : 0)
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.2, 1.2),
                            duration: 200.ms,
                          )
                          .then()
                          .scale(end: const Offset(1.0, 1.0)),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Feedback field
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Share your experience (optional)...',
                hintStyle: TextStyle(
                  color: context.textSecondary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: context.surface.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: context.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: context.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: context.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const EyeLoader(size: 24, color: Colors.white)
                    : const Text(
                        'SUBMIT RATING',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Skip Button
            if (!_isSubmitting)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
