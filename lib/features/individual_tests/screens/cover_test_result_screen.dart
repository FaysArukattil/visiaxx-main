import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/cover_test_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/utils/navigation_utils.dart';

class CoverTestResultScreen extends StatelessWidget {
  final CoverTestResult result;

  const CoverTestResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Cover Test Results',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildOverallStatusCard(context),
              const SizedBox(height: 20),
              _buildEyeStatusCards(context),
              const SizedBox(height: 20),
              _buildObservationsCard(context),
              const SizedBox(height: 20),
              _buildRecommendationCard(context),
              const SizedBox(height: 32),
              _buildActionButtons(context),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
        ),
      ),
    );
  }

  Widget _buildOverallStatusCard(BuildContext context) {
    final hasDeviation = result.hasDeviation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasDeviation
              ? [context.warning, context.warning.withValues(alpha: 0.8)]
              : [context.success, context.success.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (hasDeviation ? context.warning : context.success)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            hasDeviation
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            hasDeviation ? 'Eye Deviation Detected' : 'Normal Alignment',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            result.overallInterpretation,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEyeStatusCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildEyeCard(
            context,
            'Right Eye',
            result.rightEyeStatus,
            Icons.visibility_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEyeCard(
            context,
            'Left Eye',
            result.leftEyeStatus,
            Icons.visibility_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildEyeCard(
    BuildContext context,
    String title,
    AlignmentStatus status,
    IconData icon,
  ) {
    final isNormal = status == AlignmentStatus.normal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNormal
              ? context.success.withValues(alpha: 0.3)
              : context.warning.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isNormal ? context.success : context.warning).withValues(
                alpha: 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isNormal ? context.success : context.warning,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.label,
            style: TextStyle(
              color: isNormal ? context.success : context.warning,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_outlined, color: context.primary),
              const SizedBox(width: 12),
              Text(
                'Observations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...result.observations.map(
            (obs) => _buildObservationItem(context, obs),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationItem(BuildContext context, CoverTestObservation obs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    obs.phase,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Eye observed: ${obs.eye}',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  obs.movement.label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: context.info),
              const SizedBox(width: 12),
              Text(
                'Recommendation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.recommendation,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () async {
              // Save result to session provider
              final sessionProvider = Provider.of<TestSessionProvider>(
                context,
                listen: false,
              );
              sessionProvider.setCoverTestResult(result);

              // Navigate to home
              await NavigationUtils.navigateHome(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Complete Test',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              // Show more info or navigate to learn more
              showDialog(
                context: context,
                builder: (context) => _buildInfoDialog(context),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: context.primary,
              side: BorderSide(color: context.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Learn More',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoDialog(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'About Cover-Uncover Test',
        style: TextStyle(color: context.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The cover-uncover test is a clinical assessment used to detect ocular misalignment (strabismus).',
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Types of Deviations:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _infoItem(context, 'Esotropia', 'Inward eye turning'),
            _infoItem(context, 'Exotropia', 'Outward eye turning'),
            _infoItem(context, 'Hypertropia', 'Upward eye deviation'),
            _infoItem(context, 'Hypotropia', 'Downward eye deviation'),
            _infoItem(context, 'Esophoria', 'Latent inward deviation'),
            _infoItem(context, 'Exophoria', 'Latent outward deviation'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: context.primary)),
        ),
      ],
    );
  }

  Widget _infoItem(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: context.primary, fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: context.textSecondary, fontSize: 14),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
