import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../constants/app_colors.dart';
import '../utils/distance_helper.dart';
import '../services/distance_detection_service.dart';
import 'eye_loader.dart';

/// A universal overlay that provides visual feedback and instructions
/// when the user's distance from the device is incorrect.
class DistanceWarningOverlay extends StatelessWidget {
  final DistanceStatus status;
  final double currentDistance;
  final double targetDistance;
  final VoidCallback onSkip;
  final bool isVisible;
  final String? testType;

  const DistanceWarningOverlay({
    super.key,
    required this.status,
    required this.currentDistance,
    required this.targetDistance,
    required this.onSkip,
    this.isVisible = true,
    this.testType,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final screenHeight = mediaQuery.size.height;
    final isSmallHeight = screenHeight < 500;

    final pauseReason = DistanceHelper.getPauseReason(status, targetDistance);
    final instruction = DistanceHelper.getDetailedInstruction(targetDistance);

    IconData icon;
    final Color iconColor = DistanceHelper.getDistanceColor(
      currentDistance,
      targetDistance,
      testType: testType,
    );

    switch (status) {
      case DistanceStatus.noFaceDetected:
        icon = Icons.person_off_rounded;
        break;
      case DistanceStatus.tooClose:
        icon = Icons.zoom_out_rounded;
        break;
      case DistanceStatus.tooFar:
        icon = Icons.zoom_in_rounded;
        break;
      default:
        icon = Icons.warning_rounded;
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          // 1. Full-Screen Glass Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: AppColors.black.withValues(alpha: 0.4)),
            ),
          ),

          // 2. High-Fidelity Content Card
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: isSmallHeight ? 12 : 24),
              child: Container(
                constraints: BoxConstraints(maxWidth: isLandscape ? 500 : 400),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(isSmallHeight ? 12 : 24),
                decoration: ShapeDecoration(
                  color: AppColors.white.withValues(alpha: 0.95),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      isSmallHeight ? 24 : 32,
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSmallHeight) ...[
                      // Premium Badge - Only show if not very small height
                      Container(
                        width: isLandscape ? 50 : 70,
                        height: isLandscape ? 50 : 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: iconColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withValues(alpha: 0.12),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: isLandscape ? 40 : 54,
                            height: isLandscape ? 40 : 54,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: iconColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: isLandscape ? 22 : 28,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isLandscape ? 12 : 20),
                    ],

                    // Typography
                    Text(
                      pauseReason.toUpperCase(),
                      style: TextStyle(
                        fontSize: isSmallHeight ? 16 : (isLandscape ? 18 : 20),
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallHeight ? 6 : 12),
                    Text(
                      instruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallHeight ? 11 : 14,
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    SizedBox(
                      height: isSmallHeight ? 12 : (isLandscape ? 16 : 24),
                    ),

                    // LIVE DISTANCE GAUGE
                    if (DistanceHelper.isFaceDetected(status)) ...[
                      _buildPremiumDistanceGauge(
                        targetDistance,
                        iconColor,
                        isSmallHeight: isSmallHeight,
                        isLandscape: isLandscape,
                      ),
                    ] else
                      _buildSearchingIndicator(isSmallHeight: isSmallHeight),

                    SizedBox(
                      height: isSmallHeight ? 16 : (isLandscape ? 20 : 40),
                    ),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onSkip,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallHeight ? 10 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'SKIP DISTANCE CHECK',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontSize: 11,
                          ),
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
    );
  }

  Widget _buildPremiumDistanceGauge(
    double target,
    Color statusColor, {
    bool isSmallHeight = false,
    bool isLandscape = false,
  }) {
    final isTooClose = status == DistanceStatus.tooClose;
    final isTooFar = status == DistanceStatus.tooFar;
    final isOptimal = status == DistanceStatus.optimal;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(
                  'CURRENT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentDistance.toStringAsFixed(0)} cm',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 32),
            Container(
              height: 30,
              width: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 32),
            Column(
              children: [
                Text(
                  'TARGET',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${target.toInt()} cm',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Gauge bar
        Container(
          height: 8,
          width: 200,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Optimal zone (Center)
              Center(
                child: Container(
                  width: 40,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: AppColors.success.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // Current pointer
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                left: _getPointerPosition(200, target),
                child: Container(
                  width: 4,
                  height: 12,
                  transform: Matrix4.translationValues(0, -2, 0),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildActionHint(isOptimal, isTooClose, isTooFar),
      ],
    );
  }

  double _getPointerPosition(double width, double target) {
    if (currentDistance <= 0) return 0;
    // Map distance to position (Center = target)
    // Range: target - 20 to target + 20
    final relative = currentDistance - (target - 20);
    final percent = (relative / 40).clamp(0.0, 1.0);
    return percent * (width - 4);
  }

  Widget _buildSearchingIndicator({bool isSmallHeight = false}) {
    return Column(
      children: [
        const EyeLoader(size: 40),
        const SizedBox(height: 24),
        Text(
          'SEARCHING FOR FACE...',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.error.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionHint(bool isOptimal, bool isTooClose, bool isTooFar) {
    if (status == DistanceStatus.noFaceDetected) return const SizedBox.shrink();

    final text = isOptimal
        ? 'DISTANCE OPTIMAL'
        : (isTooClose ? 'MOVE BACK SLOWLY' : 'MOVE CLOSER SLOWLY');
    final icon = isOptimal
        ? Icons.check_circle_rounded
        : (isTooClose ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded);
    final color = isOptimal ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
