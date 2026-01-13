import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/navigation_utils.dart';
import '../../../../data/models/mobile_refractometry_result.dart';
import '../../../../data/providers/test_session_provider.dart';

class MobileRefractometryQuickResultScreen extends StatelessWidget {
  const MobileRefractometryQuickResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    final result = provider.mobileRefractometry;

    if (result == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('No result data found'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => NavigationUtils.navigateHome(context),
                child: const Text('Return Home'),
              ),
            ],
          ),
        ),
      );
    }

    final overallStatus = _getOverallStatus(result);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Refractometry Results'),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => NavigationUtils.navigateHome(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildStatusHeader(overallStatus),
            const SizedBox(height: 32),

            if (result.rightEye != null)
              _buildEyeCard('Right Eye', result.rightEye!, AppColors.primary),

            if (result.leftEye != null) ...[
              const SizedBox(height: 24),
              _buildEyeCard('Left Eye', result.leftEye!, AppColors.secondary),
            ],

            const SizedBox(height: 32),
            _buildClinicalInsights(result),
            const SizedBox(height: 48),

            _buildActionButtons(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(Map<String, dynamic> statusInfo) {
    final Color color = statusInfo['color'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(statusInfo['icon'], size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            statusInfo['label'],
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Refraction Screening Complete',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeCard(
    String side,
    MobileRefractometryEyeResult res,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEyeLabel(side, accentColor),
              _buildAccuracyBadge(res.accuracy, accentColor),
            ],
          ),
          const SizedBox(height: 24),
          _buildRefractionGrid(res),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          _buildInterpretation(res, accentColor),
        ],
      ),
    );
  }

  Widget _buildEyeLabel(String side, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_red_eye_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            side.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyBadge(String accuracy, Color color) {
    final double accValue = double.tryParse(accuracy) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${accValue.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          'CONSISTENCY',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRefractionGrid(MobileRefractometryEyeResult res) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildValueItem('SPHERE', res.sphere, 'Distance'),
        _buildValueItem('CYLINDER', res.cylinder, 'Focus'),
        _buildValueItem('AXIS', '${res.axis}°', 'Angle'),
        if (double.tryParse(res.addPower) != null &&
            double.parse(res.addPower) > 0)
          _buildValueItem('READING', '+${res.addPower}', 'Add Power'),
      ],
    );
  }

  Widget _buildValueItem(String label, String value, String subLabel) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subLabel,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretation(MobileRefractometryEyeResult res, Color color) {
    final interpretation = _getInterpretationDetails(res);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(interpretation['icon'], size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              interpretation['condition'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          interpretation['description'],
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalInsights(MobileRefractometryResult result) {
    if (result.healthWarnings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Professional Insights',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.warningDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.healthWarnings.join('. '),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/quick-test-result'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.transparent,
              shadowColor: AppColors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'View Detailed Results',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => NavigationUtils.navigateHome(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          ),
          child: Text(
            'Done',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getOverallStatus(MobileRefractometryResult result) {
    if (result.criticalAlert) {
      return {
        'label': 'Urgent Care',
        'color': AppColors.error,
        'icon': Icons.emergency_rounded,
      };
    }

    final rSph = double.tryParse(result.rightEye?.sphere ?? '0') ?? 0;
    final lSph = double.tryParse(result.leftEye?.sphere ?? '0') ?? 0;

    if (rSph.abs() > 3.0 || lSph.abs() > 3.0) {
      return {
        'label': 'Review Needed',
        'color': AppColors.warning,
        'icon': Icons.warning_amber_rounded,
      };
    }

    return {
      'label': 'Normal Vision',
      'color': AppColors.success,
      'icon': Icons.check_circle_rounded,
    };
  }

  Map<String, dynamic> _getInterpretationDetails(
    MobileRefractometryEyeResult res,
  ) {
    final sph = double.tryParse(res.sphere) ?? 0.0;
    final cyl = double.tryParse(res.cylinder) ?? 0.0;

    if (sph < -0.25) {
      return {
        'condition': 'Myopia (Nearsighted)',
        'description':
            'Distance objects may appear blurry. Reading and close work are usually clear.',
        'icon': Icons.remove_red_eye_outlined,
      };
    } else if (sph > 0.25) {
      return {
        'condition': 'Hyperopia (Farsighted)',
        'description':
            'Close objects may cause strain or appear blurry. Distance vision is usually better.',
        'icon': Icons.visibility_outlined,
      };
    } else if (cyl.abs() > 0.5) {
      return {
        'condition': 'Astigmatism',
        'description':
            'Vision may be distorted or blurred at all distances due to irregular eye shape.',
        'icon': Icons.blur_on_rounded,
      };
    }

    return {
      'condition': 'Healthy Refraction',
      'description':
          'No significant refractive issues detected. Light focuses correctly on your retina.',
      'icon': Icons.check_circle_outline_rounded,
    };
  }
}
