import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/pelli_robson_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

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
      builder: (dialogContext) => TestExitConfirmationDialog(
        onContinue: () {
          _resumeFromDialog();
        },
        onRestart: () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/pelli-robson-test',
            (route) => false,
          );
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
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

    final isPositive =
        result.overallCategory == 'Normal' ||
        result.overallCategory == 'Excellent';
    final statusColor = isPositive ? AppColors.success : AppColors.warning;

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
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(), // Minimal scroll if any
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      // Header Section (Ultra Compact)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 32,
                              color: statusColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Test Completed',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              result.overallCategory,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Eye Results Grid
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (result.rightEye != null)
                            Expanded(
                              child: _buildCompactEyeColumn(
                                'Right Eye',
                                result.rightEye!,
                              ),
                            ),
                          if (result.leftEye != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCompactEyeColumn(
                                'Left Eye',
                                result.leftEye!,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),
                      // Summary Insight
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          result.userSummary,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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
                        'Continue Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
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

  Widget _buildCompactEyeColumn(String title, PelliRobsonEyeResult eye) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyeTitle(title),
        const SizedBox(height: 6),
        if (eye.shortDistance != null)
          _buildCompactMetricCard(
            'Near (40cm)',
            eye.shortDistance!,
            Icons.short_text_rounded,
          ),
        if (eye.longDistance != null) ...[
          const SizedBox(height: 6),
          _buildCompactMetricCard(
            'Distance (1m)',
            eye.longDistance!,
            Icons.visibility_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildEyeTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildCompactMetricCard(
    String label,
    PelliRobsonSingleResult metric,
    IconData icon,
  ) {
    final color = _getCategoryColor(metric.category);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${metric.adjustedScore.toStringAsFixed(2)} log CS',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.category,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
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

