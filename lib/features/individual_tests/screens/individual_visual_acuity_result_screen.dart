import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/individual_test_result_model.dart';
import '../../../data/models/visiual_acuity_result.dart';
import '../../../core/services/individual_test_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

class IndividualVisualAcuityResultScreen extends StatefulWidget {
  final VisualAcuityResult rightEye;
  final VisualAcuityResult leftEye;

  const IndividualVisualAcuityResultScreen({
    required this.rightEye,
    required this.leftEye,
    super.key,
  });

  @override
  State<IndividualVisualAcuityResultScreen> createState() =>
      _IndividualVisualAcuityResultScreenState();
}

class _IndividualVisualAcuityResultScreenState
    extends State<IndividualVisualAcuityResultScreen> {
  final _testService = IndividualTestService();
  final _authService = AuthService();
  bool _isSaving = true;

  @override
  void initState() {
    super.initState();
    _saveResult();
  }

  Future<void> _saveResult() async {
    try {
      final user = await _authService.getUserData(_authService.currentUserId!);
      if (user == null) return;

      final result = IndividualTestResult(
        id: '',
        userId: user.id,
        profileId: user.id,
        profileName: '${user.firstName} ${user.lastName}',
        profileAge: user.age,
        profileSex: user.sex,
        timestamp: DateTime.now(),
        testType: 'visual_acuity',
        testData: {
          'rightEye': widget.rightEye.toMap(),
          'leftEye': widget.leftEye.toMap(),
        },
      );

      await _testService.saveIndividualTest(result);
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        SnackbarUtils.showSuccess(context, 'Results saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        SnackbarUtils.showError(context, 'Failed to save results');
      }
    }
  }

  Future<void> _generatePdf() async {
    SnackbarUtils.showInfo(context, 'PDF generation coming in next update!');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => TestExitConfirmationDialog(
            onContinue: () {
              // Just close the dialog
            },
            onRestart: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/visual-acuity-test',
                (route) => false,
              );
            },
            onExit: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visual Acuity Results'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          actions: [
            if (!_isSaving)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _generatePdf,
                tooltip: 'Download PDF',
              ),
          ],
        ),
        body: _isSaving
            ? const Center(child: EyeLoader())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSuccessBanner(),
                    const SizedBox(height: 24),
                    _buildEyeCard(
                      'Right Eye',
                      widget.rightEye,
                      Colors.blue,
                      Icons.visibility,
                    ),
                    const SizedBox(height: 16),
                    _buildEyeCard(
                      'Left Eye',
                      widget.leftEye,
                      Colors.teal,
                      Icons.visibility,
                    ),
                    const SizedBox(height: 24),
                    _buildInterpretation(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.1),
            AppColors.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test Complete!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your results have been saved securely',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeCard(
    String title,
    VisualAcuityResult result,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildResultRow('Snellen Score', result.snellenScore, color),
          const SizedBox(height: 12),
          _buildResultRow('LogMAR', result.logMAR.toStringAsFixed(2), color),
          const SizedBox(height: 12),
          _buildResultRow(
            'Status',
            result.logMAR <= 0.1
                ? 'Excellent'
                : result.logMAR <= 0.3
                ? 'Good'
                : 'Needs Review',
            result.logMAR <= 0.1
                ? AppColors.success
                : result.logMAR <= 0.3
                ? AppColors.warning
                : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInterpretation() {
    final avgLogMAR = (widget.rightEye.logMAR + widget.leftEye.logMAR) / 2;
    String interpretation;
    IconData icon;
    Color color;

    if (avgLogMAR <= 0.1) {
      interpretation =
          'Excellent vision! Your distance vision is very good in both eyes.';
      icon = Icons.check_circle;
      color = AppColors.success;
    } else if (avgLogMAR <= 0.3) {
      interpretation =
          'Good vision overall. Minor correction may improve clarity.';
      icon = Icons.info;
      color = AppColors.warning;
    } else {
      interpretation =
          'Consider a comprehensive eye exam for detailed assessment.';
      icon = Icons.warning_amber;
      color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              interpretation,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Continue / Start Full Eye Exam (Primary action)
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/comprehensive-test',
              (route) => false,
            );
          },
          icon: const Icon(Icons.assessment_rounded),
          label: const Text('Start Full Eye Exam'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Restart Current Test
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/visual-acuity-test',
              (route) => false,
            );
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Restart Test'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.warning,
            minimumSize: const Size(double.infinity, 54),
            side: const BorderSide(color: AppColors.warning, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Exit to Home
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          },
          icon: const Icon(Icons.home_rounded),
          label: const Text('Back to Home'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.grey.withValues(alpha: 0.1),
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

