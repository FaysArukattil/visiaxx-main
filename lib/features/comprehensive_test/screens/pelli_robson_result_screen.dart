import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/pelli_robson_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/utils/navigation_utils.dart';

class PelliRobsonResultScreen extends StatefulWidget {
  const PelliRobsonResultScreen({super.key});

  @override
  State<PelliRobsonResultScreen> createState() =>
      _PelliRobsonResultScreenState();
}

class _PelliRobsonResultScreenState extends State<PelliRobsonResultScreen> {
  Timer? _autoContinueTimer;
  int _secondsRemaining = 5;
  bool _isNavigating = false;
  bool _isPausedForExit = false;

  @override
  void initState() {
    super.initState();
    _startAutoContinueTimer();
  }

  void _startAutoContinueTimer() {
    _autoContinueTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _autoContinueTimer?.cancel();
          _navigateToSummary();
        }
      });
    });
  }

  void _navigateToSummary() {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.pushReplacementNamed(context, '/mobile-refractometry-test');
  }

  void _showPauseDialog() {
    _autoContinueTimer?.cancel();
    setState(() => _isPausedForExit = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.pause_circle_outline,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Test Paused',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'What would you like to do?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _resumeFromDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue to Mobile Refractometry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await NavigationUtils.navigateHome(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Exit and Lose Progress',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    ).then((_) {
      if (mounted && _isPausedForExit) {
        _resumeFromDialog();
      }
    });
  }

  void _resumeFromDialog() {
    if (!mounted) return;
    setState(() => _isPausedForExit = false);
    _startAutoContinueTimer();
  }

  @override
  void dispose() {
    _autoContinueTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    final result = provider.pelliRobson;

    if (result == null) {
      return const Scaffold(body: Center(child: Text('No results found')));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showPauseDialog();
      },
      child: Scaffold(
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          title: const Text('Contrast Sensitivity Result'),
          backgroundColor: AppColors.testBackground,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              (result.overallCategory == 'Normal' ||
                                          result.overallCategory == 'Excellent'
                                      ? AppColors.success
                                      : AppColors.warning)
                                  .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                (result.overallCategory == 'Normal' ||
                                            result.overallCategory ==
                                                'Excellent'
                                        ? AppColors.success
                                        : AppColors.warning)
                                    .withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    (result.overallCategory == 'Normal' ||
                                                result.overallCategory ==
                                                    'Excellent'
                                            ? AppColors.success
                                            : AppColors.warning)
                                        .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                (result.overallCategory == 'Normal' ||
                                        result.overallCategory == 'Excellent'
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded),
                                size: 40,
                                color:
                                    (result.overallCategory == 'Normal' ||
                                        result.overallCategory == 'Excellent'
                                    ? AppColors.success
                                    : AppColors.warning),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Contrast Sensitivity Test Completed',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              result.overallCategory,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    (result.overallCategory == 'Normal' ||
                                        result.overallCategory == 'Excellent'
                                    ? AppColors.success
                                    : AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Right Eye
                      if (result.rightEye != null) ...[
                        _buildEyeTitle('Right Eye'),
                        const SizedBox(height: 8),
                        if (result.rightEye!.shortDistance != null)
                          _buildDistanceResultCard(
                            'Near Vision (40cm)',
                            result.rightEye!.shortDistance!,
                            Icons.short_text,
                          ),
                        const SizedBox(height: 12),
                        if (result.rightEye!.longDistance != null)
                          _buildDistanceResultCard(
                            'Distance Vision (1m)',
                            result.rightEye!.longDistance!,
                            Icons.visibility,
                          ),
                        const SizedBox(height: 20),
                      ],

                      // Left Eye
                      if (result.leftEye != null) ...[
                        _buildEyeTitle('Left Eye'),
                        const SizedBox(height: 8),
                        if (result.leftEye!.shortDistance != null)
                          _buildDistanceResultCard(
                            'Near Vision (40cm)',
                            result.leftEye!.shortDistance!,
                            Icons.short_text,
                          ),
                        const SizedBox(height: 12),
                        if (result.leftEye!.longDistance != null)
                          _buildDistanceResultCard(
                            'Distance Vision (1m)',
                            result.leftEye!.longDistance!,
                            Icons.visibility,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Sticky Bottom Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Continue to Refractometry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_secondsRemaining}s',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildDistanceResultCard(
    String title,
    PelliRobsonSingleResult result,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.adjustedScore.toStringAsFixed(2)} log CS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getCategoryColor(result.category).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.category,
              style: TextStyle(
                color: _getCategoryColor(result.category),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Excellent':
      case 'Normal':
        return AppColors.success;
      case 'Borderline':
        return AppColors.warning;
      case 'Reduced':
      default:
        return AppColors.error;
    }
  }
}
