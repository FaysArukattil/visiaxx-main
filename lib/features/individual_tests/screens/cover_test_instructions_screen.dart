import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import 'cover_test_screen.dart';
import '../../../core/constants/app_colors.dart';

class CoverTestInstructionsScreen extends StatefulWidget {
  const CoverTestInstructionsScreen({super.key});

  @override
  State<CoverTestInstructionsScreen> createState() =>
      _CoverTestInstructionsScreenState();
}

class _CoverTestInstructionsScreenState
    extends State<CoverTestInstructionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 2;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'Test Overview & Setup',
    'Clinical Procedure',
  ];

  final List<String> _ttsMessages = [
    'The cover-uncover test assesses eye alignment. Hold the device at eye level and ensure the face is centered.',
    'Follow the prompts to cover and uncover each eye. Observe any eye movement carefully.',
  ];

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    await Future.delayed(const Duration(milliseconds: 500));
    _playCurrentStepTts();
  }

  void _playCurrentStepTts() {
    _ttsService.stop();
    _ttsService.speak(_ttsMessages[_currentPage], speechRate: 0.5);
  }

  void _handleNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _handleContinue();
    }
  }

  void _handleContinue() {
    _ttsService.stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const CoverTestScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _showExitConfirmation() {
    _ttsService.stop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          onContinue: () => _playCurrentStepTts(),
          onRestart: () {
            setState(() => _currentPage = 0);
            _pageController.jumpToPage(0);
            _playCurrentStepTts();
          },
          onExit: () async => await NavigationUtils.navigateHome(context),
          hasCompletedTests: provider.hasAnyCompletedTest,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Cover-Uncover Test'),
          backgroundColor: context.cardColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.close, color: context.textPrimary),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: OrientationBuilder(
                  builder: (context, orientation) {
                    final isLandscape = orientation == Orientation.landscape;
                    return PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        _playCurrentStepTts();
                      },
                      children: [
                        _buildStep(
                          0,
                          Icons.visibility_rounded,
                          'Overview & Setup',
                          'This test detects eye deviations. Hold the device steady at eye level and ensure the patient\'s face is well-lit and centered.',
                          context.primary,
                          animation: _AlignmentAnimation(
                            height: isLandscape ? 170 : 240,
                          ),
                        ),
                        _buildStep(
                          1,
                          Icons.history_edu_rounded,
                          'Procedure Steps',
                          'Follow the recorded prompts to: 1. Cover Right, 2. Uncover Right, 3. Cover Left, 4. Uncover Left. Observe the eyes carefully.',
                          context.warning,
                          animation: _CoverProcedureAnimation(
                            height: isLandscape ? 170 : 240,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        return Container(
          padding: EdgeInsets.all(isLandscape ? 12.0 : 16.0),
          decoration: BoxDecoration(
            color: context.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLandscape) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _totalPages,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? context.primary
                            : context.dividerColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: isLandscape ? 48 : 56,
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage < _totalPages - 1
                        ? 'Next'
                        : 'Start Assessment',
                    style: TextStyle(
                      fontSize: isLandscape ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(
    int index,
    IconData icon,
    String title,
    String description,
    Color color, {
    Widget? animation,
  }) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        return Padding(
          padding: EdgeInsets.all(isLandscape ? 8.0 : 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 16.0 : 20.0,
              vertical: isLandscape ? 12.0 : 16.0,
            ),
            child: isLandscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Step ${index + 1} of $_totalPages',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.primary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _stepTitles[index],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildModernInstructionItem(
                                icon,
                                title,
                                description,
                                color,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (animation != null) ...[
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: Center(child: animation)),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Step ${index + 1} of $_totalPages',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.primary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _stepTitles[index],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildModernInstructionItem(
                                icon,
                                title,
                                description,
                                color,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      if (animation != null)
                        Expanded(child: Center(child: animation)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildModernInstructionItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlignmentAnimation extends StatefulWidget {
  final double height;
  const _AlignmentAnimation({required this.height});

  @override
  State<_AlignmentAnimation> createState() => _AlignmentAnimationState();
}

class _AlignmentAnimationState extends State<_AlignmentAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;

          double leftEyeDeviation = 0;
          double rightEyeOpacity = 0;

          // Phase 1: Normal alignment (0.0 - 0.2)
          if (progress < 0.2) {
            leftEyeDeviation = 0;
            rightEyeOpacity = 0;
          }
          // Phase 2: Left eye deviates OUT (0.2 - 0.4)
          else if (progress < 0.4) {
            double t = (progress - 0.2) / 0.2;
            leftEyeDeviation = t * 15;
            rightEyeOpacity = 0;
          }
          // Phase 3: Cover Right Eye (0.4 - 0.5) -> Left eye moves IN to fixate
          else if (progress < 0.5) {
            double t = (progress - 0.4) / 0.1;
            leftEyeDeviation = 15 - (t * 15); // Move back to center
            rightEyeOpacity = t; // Cover animation
          }
          // Phase 4: Hold with Right covered (0.5 - 0.7)
          else if (progress < 0.7) {
            leftEyeDeviation = 0;
            rightEyeOpacity = 1;
          }
          // Phase 5: Uncover Right Eye (0.7 - 0.8) -> Left eye deviates OUT again
          else if (progress < 0.8) {
            double t = (progress - 0.7) / 0.1;
            leftEyeDeviation = t * 15;
            rightEyeOpacity = 1 - t;
          }
          // Phase 6: Reset (0.8 - 1.0)
          else {
            leftEyeDeviation = 15;
            rightEyeOpacity = 0;
          }

          return CustomPaint(
            painter: _AlignmentPainter(
              deviation: leftEyeDeviation,
              occluderOpacity: rightEyeOpacity,
            ),
          );
        },
      ),
    );
  }
}

class _AlignmentPainter extends CustomPainter {
  final double deviation;
  final double occluderOpacity;

  _AlignmentPainter({required this.deviation, required this.occluderOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eyeSpacing = 70.0;
    final eyeWidth = 70.0;
    final eyeHeight = 35.0;

    // Draw Right Eye (The one being covered)
    _drawRealisticEye(
      canvas,
      center.translate(-eyeSpacing, 0),
      eyeWidth,
      eyeHeight,
      0,
      AppColors.primary,
    );

    // Draw Right Eye Occluder
    if (occluderOpacity > 0) {
      final occluderPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: occluderOpacity * 0.8)
        ..style = PaintingStyle.fill;
      final rect = Rect.fromCenter(
        center: center.translate(-eyeSpacing, -5),
        width: 80,
        height: 100,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        occluderPaint,
      );
    }

    // Draw Left Eye (Deviating/Refixating)
    _drawRealisticEye(
      canvas,
      center.translate(eyeSpacing, 0),
      eyeWidth,
      eyeHeight,
      deviation,
      AppColors.primary,
    );

    // Draw guide lines
    final dashedPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      center.translate(-eyeSpacing, -40),
      center.translate(-eyeSpacing, 40),
      dashedPaint,
    );
    canvas.drawLine(
      center.translate(eyeSpacing, -40),
      center.translate(eyeSpacing, 40),
      dashedPaint,
    );
  }

  void _drawRealisticEye(
    Canvas canvas,
    Offset eyeCenter,
    double width,
    double height,
    double irisXOffset,
    Color themeColor,
  ) {
    final eyePath = Path();
    eyePath.moveTo(eyeCenter.dx - width / 2, eyeCenter.dy);
    eyePath.quadraticBezierTo(
      eyeCenter.dx,
      eyeCenter.dy - height,
      eyeCenter.dx + width / 2,
      eyeCenter.dy,
    );
    eyePath.quadraticBezierTo(
      eyeCenter.dx,
      eyeCenter.dy + height,
      eyeCenter.dx - width / 2,
      eyeCenter.dy,
    );
    eyePath.close();

    // Sclera
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = themeColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.save();
    canvas.clipPath(eyePath);

    // Iris (The black/colored part that moves)
    final irisCenter = eyeCenter + Offset(irisXOffset * 0.5, 0);
    final irisRadius = height * 0.6;
    canvas.drawCircle(irisCenter, irisRadius, Paint()..color = themeColor);

    // Pupil
    canvas.drawCircle(
      irisCenter,
      irisRadius * 0.45,
      Paint()..color = Colors.black,
    );

    // Reflection
    canvas.drawCircle(
      irisCenter + Offset(irisRadius * 0.3, -irisRadius * 0.3),
      irisRadius * 0.15,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AlignmentPainter oldDelegate) =>
      oldDelegate.deviation != deviation ||
      oldDelegate.occluderOpacity != occluderOpacity;
}

class _CoverProcedureAnimation extends StatefulWidget {
  final double height;
  const _CoverProcedureAnimation({required this.height});

  @override
  State<_CoverProcedureAnimation> createState() =>
      _CoverProcedureAnimationState();
}

class _CoverProcedureAnimationState extends State<_CoverProcedureAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;

          double rightIrisOffset = 0;
          double leftIrisOffset = 0;
          double occluderX = 0;
          double occluderOpacity = 0;

          // Clinical Logic in Animation:
          // 0.0 - 0.2: Cover Right -> Watch Left for movement
          if (progress < 0.2) {
            occluderX = -70.0;
            occluderOpacity = (progress / 0.2);
            leftIrisOffset = -(occluderOpacity * 8); // Subtle refixation IN
          }
          // 0.2 - 0.4: Uncover Right -> Watch Right for recovery
          else if (progress < 0.4) {
            occluderX = -70.0;
            double t = (progress - 0.2) / 0.2;
            occluderOpacity = 1 - t;
            rightIrisOffset = (1 - t) * 10; // Moves back as uncovered
            leftIrisOffset = -8 + (t * 8); // Left returns
          }
          // 0.4 - 0.6: Cover Left -> Watch Right for movement
          else if (progress < 0.6) {
            occluderX = 70.0;
            double t = (progress - 0.4) / 0.2;
            occluderOpacity = t;
            rightIrisOffset = -(t * 8); // Subtle refixation IN
          }
          // 0.6 - 0.8: Uncover Left -> Watch Left for recovery
          else if (progress < 0.8) {
            occluderX = 70.0;
            double t = (progress - 0.6) / 0.2;
            occluderOpacity = 1 - t;
            leftIrisOffset = (1 - t) * 10; // Moves back as uncovered
            rightIrisOffset = -8 + (t * 8); // Right returns
          }
          // 0.8 - 1.0: Reset
          else {
            occluderOpacity = 0;
          }

          return CustomPaint(
            painter: _CoverProcedurePainter(
              progress: progress,
              leftIrisOffset: leftIrisOffset,
              rightIrisOffset: rightIrisOffset,
              occluderX: occluderX,
              occluderOpacity: occluderOpacity,
            ),
          );
        },
      ),
    );
  }
}

class _CoverProcedurePainter extends CustomPainter {
  final double progress;
  final double leftIrisOffset;
  final double rightIrisOffset;
  final double occluderX;
  final double occluderOpacity;

  _CoverProcedurePainter({
    required this.progress,
    required this.leftIrisOffset,
    required this.rightIrisOffset,
    required this.occluderX,
    required this.occluderOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eyeSpacing = 70.0;
    final eyeWidth = 70.0;
    final eyeHeight = 35.0;

    // Draw Eyes
    _drawRealisticEye(
      canvas,
      center.translate(-eyeSpacing, 0),
      eyeWidth,
      eyeHeight,
      rightIrisOffset,
      AppColors.primary,
    );

    _drawRealisticEye(
      canvas,
      center.translate(eyeSpacing, 0),
      eyeWidth,
      eyeHeight,
      leftIrisOffset,
      AppColors.primary,
    );

    // Draw Occluder
    if (occluderOpacity > 0) {
      final occluderPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: occluderOpacity * 0.8)
        ..style = PaintingStyle.fill;

      final occluderRect = Rect.fromCenter(
        center: center.translate(occluderX, -5),
        width: 80,
        height: 100,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(occluderRect, const Radius.circular(12)),
        occluderPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(occluderRect, const Radius.circular(12)),
        Paint()
          ..color = Colors.white.withValues(alpha: occluderOpacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawRealisticEye(
    Canvas canvas,
    Offset eyeCenter,
    double width,
    double height,
    double irisXOffset,
    Color themeColor,
  ) {
    final eyePath = Path();
    eyePath.moveTo(eyeCenter.dx - width / 2, eyeCenter.dy);
    eyePath.quadraticBezierTo(
      eyeCenter.dx,
      eyeCenter.dy - height,
      eyeCenter.dx + width / 2,
      eyeCenter.dy,
    );
    eyePath.quadraticBezierTo(
      eyeCenter.dx,
      eyeCenter.dy + height,
      eyeCenter.dx - width / 2,
      eyeCenter.dy,
    );
    eyePath.close();

    // Sclera
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawPath(
      eyePath,
      Paint()
        ..color = themeColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.save();
    canvas.clipPath(eyePath);

    // Iris (The moving part)
    final irisCenter = eyeCenter + Offset(irisXOffset, 0);
    final irisRadius = height * 0.6;
    canvas.drawCircle(irisCenter, irisRadius, Paint()..color = themeColor);

    // Pupil
    canvas.drawCircle(
      irisCenter,
      irisRadius * 0.45,
      Paint()..color = Colors.black,
    );

    // Reflection
    canvas.drawCircle(
      irisCenter + Offset(irisRadius * 0.3, -irisRadius * 0.3),
      irisRadius * 0.15,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoverProcedurePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.leftIrisOffset != leftIrisOffset ||
      oldDelegate.rightIrisOffset != rightIrisOffset ||
      oldDelegate.occluderOpacity != occluderOpacity;
}
