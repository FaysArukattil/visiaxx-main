import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../data/providers/visual_field_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/visual_field_result.dart';
import 'visual_field_cover_eye_screen.dart';

class VisualFieldScreen extends StatefulWidget {
  final VisualFieldEye? eye;
  const VisualFieldScreen({super.key, this.eye});

  @override
  State<VisualFieldScreen> createState() => _VisualFieldScreenState();
}

class _VisualFieldScreenState extends State<VisualFieldScreen> {
  bool _isHandlingCompletion = false;

  @override
  void initState() {
    super.initState();
    // Synchronously reset provider state to avoid seeing completion from previous phases
    context.read<VisualFieldProvider>().reset();

    // Start test immediately when screen is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VisualFieldProvider>().startTest(eye: widget.eye);
    });
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final sessionProvider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          onContinue: () {},
          onRestart: () {
            final sessionProvider = context.read<TestSessionProvider>();
            sessionProvider.resetKeepProfile();
            context.read<VisualFieldProvider>().reset();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/visual-field-test-intro',
              (route) => false,
            );
          },
          onExit: () async {
            await NavigationUtils.navigateHome(context);
          },
          hasCompletedTests: sessionProvider.hasAnyCompletedTest,
          onSaveAndExit: sessionProvider.hasAnyCompletedTest
              ? () {
                  Navigator.pushReplacementNamed(context, '/quick-test-result');
                }
              : null,
        );
      },
    );
  }

  void _handleTestComplete(VisualFieldProvider provider) {
    if (_isHandlingCompletion) return;
    setState(() => _isHandlingCompletion = true);

    final sessionProvider = context.read<TestSessionProvider>();
    final result = provider.createResult();
    sessionProvider.setVisualFieldResult(result);

    // Reset provider state immediately to stop isComplete from triggering again
    provider.reset();

    // Smooth transition
    Future.delayed(500.ms, () {
      if (!mounted) return;

      if (result.eye == VisualFieldEye.right) {
        // If Right Eye finished, prepare to test Left Eye
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VisualFieldCoverEyeScreen(
              eyeToCover: VisualFieldEye.right,
              onContinue: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const VisualFieldScreen(eye: VisualFieldEye.left),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // If Left Eye finished, go to results
        if (sessionProvider.isMultiTest) {
          Navigator.pushReplacementNamed(
            context,
            sessionProvider.getNextTestRoute(),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/quick-test-result');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VisualFieldProvider>(
      builder: (context, provider, child) {
        if (provider.isComplete && !_isHandlingCompletion) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _handleTestComplete(provider),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _showExitConfirmation(context);
          },
          child: Scaffold(
            backgroundColor: Colors.black, // Dark theme for better contrast
            appBar: AppBar(
              backgroundColor: Colors.grey.shade900,
              elevation: 0,
              title: const Text(
                'Visual Field Test',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => _showExitConfirmation(context),
              ),
            ),
            body: Column(
              children: [
                LinearProgressIndicator(
                  value: provider.progress,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.visualFieldColor,
                  ),
                ),
                Expanded(flex: 3, child: _buildStimulusGrid(context, provider)),
                _buildResponseArea(context, provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStimulusGrid(
    BuildContext context,
    VisualFieldProvider provider,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // Grid lines
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              // Center crosshair
              Center(
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
              // Active Stimulus
              if (provider.activeStimulus != null)
                _buildStimulus(provider.activeStimulus!, constraints),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStimulus(Stimulus stimulus, BoxConstraints constraints) {
    // Reduced size (8) and adjusted intensity
    return Positioned(
      left: stimulus.position.dx * constraints.maxWidth - 4,
      top: stimulus.position.dy * constraints.maxHeight - 4,
      child:
          Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: stimulus.intensity * 0.9,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: stimulus.intensity * 0.4,
                      ),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 100.ms)
              .fadeOut(delay: 400.ms, duration: 200.ms),
    );
  }

  Widget _buildResponseArea(
    BuildContext context,
    VisualFieldProvider provider,
  ) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        provider.recordDetection();
      },
      child: AnimatedContainer(
        duration: 100.ms,
        width: double.infinity,
        height: 120,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: provider.hasFeedback
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: provider.hasFeedback
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app, size: 40, color: AppColors.primary),
            const SizedBox(height: 8),
            const Text(
              'TAP HERE WHEN YOU SEE A DOT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      double dx = size.width * (i / 4);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      double dy = size.height * (i / 4);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
