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
          title: const Text('Contrast Sensitivity Results'),
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Overall Status Card
                _buildCategoryCard(result.overallCategory, result.averageScore),
                const SizedBox(height: 24),

                // Breakdown section
                const Text(
                  'Test Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Right Eye
                if (result.rightEye != null) ...[
                  _buildEyeTitle('Right Eye'),
                  if (result.rightEye!.shortDistance != null)
                    _buildDistanceResultCard(
                      'Near Vision (40cm)',
                      result.rightEye!.shortDistance!,
                      Icons.short_text,
                    ),
                  const SizedBox(height: 8),
                  if (result.rightEye!.longDistance != null)
                    _buildDistanceResultCard(
                      'Distance Vision (1m)',
                      result.rightEye!.longDistance!,
                      Icons.visibility,
                    ),
                  const SizedBox(height: 16),
                ],

                // Left Eye
                if (result.leftEye != null) ...[
                  _buildEyeTitle('Left Eye'),
                  if (result.leftEye!.shortDistance != null)
                    _buildDistanceResultCard(
                      'Near Vision (40cm)',
                      result.leftEye!.shortDistance!,
                      Icons.short_text,
                    ),
                  const SizedBox(height: 8),
                  if (result.leftEye!.longDistance != null)
                    _buildDistanceResultCard(
                      'Distance Vision (1m)',
                      result.leftEye!.longDistance!,
                      Icons.visibility,
                    ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 32),

                // Summary Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        result.userSummary,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Bottom Actions
                ElevatedButton(
                  onPressed: _navigateToSummary,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($_secondsRemaining)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: AppColors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildCategoryCard(String category, double score) {
    Color color;
    IconData icon;

    switch (category) {
      case 'Excellent':
      case 'Normal':
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case 'Borderline':
        color = AppColors.warning;
        icon = Icons.warning;
        break;
      case 'Reduced':
      default:
        color = AppColors.error;
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            category.toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Average: ${score.toStringAsFixed(2)} log CS',
            style: TextStyle(
              fontSize: 16,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
