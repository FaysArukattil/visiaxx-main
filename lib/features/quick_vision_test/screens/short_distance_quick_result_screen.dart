import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/short_distance_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/widgets/eye_loader.dart';

class ShortDistanceQuickResultScreen extends StatefulWidget {
  const ShortDistanceQuickResultScreen({super.key});

  @override
  State<ShortDistanceQuickResultScreen> createState() =>
      _ShortDistanceQuickResultScreenState();
}

class _ShortDistanceQuickResultScreenState
    extends State<ShortDistanceQuickResultScreen> {
  int _countdown = 4;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _navigateNext();
      }
    });
  }

  void _navigateNext() {
    if (!mounted) return;
    final provider = context.read<TestSessionProvider>();

    if (provider.isIndividualTest) {
      Navigator.pushReplacementNamed(context, '/quick-test-result');
    } else {
      Navigator.pushReplacementNamed(context, '/color-vision-test');
    }
  }

  void _showExitConfirmation() {
    _countdownTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          title: 'Exit Reading Test Results?',
          onContinue: () {
            _startCountdown();
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.pushReplacementNamed(context, '/short-distance-test');
          },
          onExit: () {
            Navigator.of(context).pop();
            Navigator.pushReplacementNamed(context, '/home');
          },
          hasCompletedTests: provider.hasAnyCompletedTest,
          onSaveAndExit: provider.hasAnyCompletedTest
              ? () {
                  Navigator.pushReplacementNamed(context, '/quick-test-result');
                }
              : null,
        );
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    final result = provider.shortDistance;

    if (result == null) {
      return const Scaffold(body: Center(child: EyeLoader(size: 48)));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        'Reading Test Result',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Status Card
                      _buildStatusCard(),
                      const SizedBox(height: 24),

                      // Performance Metrics
                      _buildPerformanceMetrics(result),
                      const SizedBox(height: 24),

                      // Info Card
                      _buildInfoCard(),
                    ],
                  ),
                ),
              ),

              // Bottom Button
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.warning.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_rounded, size: 40, color: context.warning),
          ),
          const SizedBox(height: 16),
          Text(
            'Reading Test Completed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(ShortDistanceResult result) {
    final statusInfo = _getStatusInfo(result);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE METRICS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: context.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),

          // Sentences Mastered
          _buildMetricRow(
            icon: Icons.format_quote_rounded,
            iconColor: context.primary,
            label: 'Sentences Mastered',
            value: '${result.correctSentences}/${result.totalSentences}',
            status: statusInfo['label']!,
            statusColor: statusInfo['color'] as Color,
          ),

          Divider(height: 32, color: context.dividerColor),

          // Average Match
          _buildMetricRow(
            icon: Icons.analytics_rounded,
            iconColor: context.success,
            label: 'Average Match',
            value: '${result.averageSimilarity.toStringAsFixed(1)}%',
            status: _getMatchStatus(result.averageSimilarity),
            statusColor: _getMatchColor(result.averageSimilarity),
          ),

          Divider(height: 32, color: context.dividerColor),

          // Best Clarity
          _buildMetricRow(
            icon: Icons.visibility_rounded,
            iconColor: context.warning,
            label: 'Best Clarity',
            value: result.bestAcuity,
            status: 'Snellen Eq.',
            statusColor: context.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: context.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Near vision reading at 40cm is within healthy limits for standard print sizes.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              _countdownTimer?.cancel();
              _navigateNext();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue Test',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_countdown}s',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(ShortDistanceResult result) {
    if (result.correctSentences >= 6) {
      return {'label': 'Excellent', 'color': context.success};
    } else if (result.correctSentences >= 4) {
      return {'label': 'Good', 'color': context.primary};
    } else if (result.correctSentences >= 2) {
      return {'label': 'Needs Review', 'color': context.warning};
    } else {
      return {'label': 'Poor', 'color': context.error};
    }
  }

  String _getMatchStatus(double similarity) {
    if (similarity >= 85.0) return 'Excellent';
    if (similarity >= 70.0) return 'Good';
    if (similarity >= 50.0) return 'Moderate';
    return 'Poor';
  }

  Color _getMatchColor(double similarity) {
    if (similarity >= 85.0) return context.success;
    if (similarity >= 70.0) return context.primary;
    if (similarity >= 50.0) return context.warning;
    return context.error;
  }
}
