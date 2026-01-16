import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/individual_test_result_model.dart';
import '../../../data/models/color_vision_result.dart';
import '../../../core/services/individual_test_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

class IndividualColorVisionResultScreen extends StatefulWidget {
  final ColorVisionResult result;

  const IndividualColorVisionResultScreen({required this.result, super.key});

  @override
  State<IndividualColorVisionResultScreen> createState() =>
      _IndividualColorVisionResultScreenState();
}

class _IndividualColorVisionResultScreenState
    extends State<IndividualColorVisionResultScreen> {
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
        testType: 'color_vision',
        testData: widget.result.toMap(),
      );

      await _testService.saveIndividualTest(result);
      if (mounted) {
        setState(() => _isSaving = false);
        SnackbarUtils.showSuccess(context, 'Results saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        SnackbarUtils.showError(context, 'Failed to save results');
      }
    }
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
                '/color-vision-test',
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
          title: const Text('Color Vision Results'),
          backgroundColor: const Color(0xFFE91E63),
          foregroundColor: AppColors.white,
          actions: [
            if (!_isSaving)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () {
                  SnackbarUtils.showInfo(
                    context,
                    'PDF generation coming in next update!',
                  );
                },
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
                    _buildScoreCard(),
                    const SizedBox(height: 16),
                    _buildDetailsCard(),
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
            AppColors.success.withOpacity(0.1),
            AppColors.success.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
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

  Widget _buildScoreCard() {
    final successRate =
        (widget.result.correctAnswers / widget.result.totalPlates * 100);
    final color = successRate >= 90
        ? AppColors.success
        : successRate >= 70
        ? AppColors.warning
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.palette, color: color, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${successRate.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Success Rate',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Correct Answers',
            '${widget.result.correctAnswers}',
            Icons.check_circle,
            AppColors.success,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Incorrect Answers',
            '${widget.result.totalPlates - widget.result.correctAnswers}',
            Icons.cancel,
            AppColors.error,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Total Plates',
            '${widget.result.totalPlates}',
            Icons.filter_none,
            AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInterpretation() {
    final successRate =
        (widget.result.correctAnswers / widget.result.totalPlates * 100);
    String interpretation;
    IconData icon;
    Color color;

    if (successRate >= 90) {
      interpretation =
          'Excellent! Your color vision appears normal. You correctly identified most color plates.';
      icon = Icons.check_circle;
      color = AppColors.success;
    } else if (successRate >= 70) {
      interpretation =
          'Good performance, but some difficulty detected. Consider a comprehensive eye exam.';
      icon = Icons.info;
      color = AppColors.warning;
    } else {
      interpretation =
          'Color vision deficiency detected. Please consult an eye care professional for detailed evaluation.';
      icon = Icons.warning_amber;
      color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          },
          icon: const Icon(Icons.home),
          label: const Text('Back to Home'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/comprehensive-test',
              (route) => false,
            );
          },
          icon: const Icon(Icons.assessment_rounded),
          label: const Text('Start Full Eye Exam'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE91E63),
            minimumSize: const Size(double.infinity, 54),
            side: const BorderSide(color: Color(0xFFE91E63), width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
