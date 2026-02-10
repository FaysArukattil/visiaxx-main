import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import 'cover_test_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../quick_vision_test/widgets/instruction_animations.dart';

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
  final int _totalPages = 3;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'Binocular Vision',
    'Clinical Procedure',
    'Positioning',
  ];

  final List<String> _ttsMessages = [
    'The cover-uncover test assesses eye alignment to detect strabismus or latent deviations.',
    'You will observe the patient\'s eyes through the camera as you cover and uncover each eye in four distinct steps.',
    'Ensure the patient is comfortably positioned and the face is clearly visible in the camera frame.',
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
                          'Eye Alignment',
                          'This test detects manifest (tropia) and latent (phoria) deviations by observing eye movement during the cover/uncover process.',
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
                        _buildStep(
                          2,
                          Icons.camera_front_rounded,
                          'Camera Positioning',
                          'Hold the device steady at eye level. Ensure the patient\'s face is well-lit and centered within the guide markers.',
                          context.success,
                          animation: DistanceAnimation(
                            isCompact: isLandscape,
                            distanceText: 'Eye Level',
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
          // Animate eye deviation
          double deviation = 0;
          if (progress < 0.5) {
            deviation = (progress * 2) * 15; // Move out
          } else {
            deviation = 15 - (progress - 0.5) * 2 * 15; // Move back
          }

          return CustomPaint(painter: _AlignmentPainter(deviation: deviation));
        },
      ),
    );
  }
}

class _AlignmentPainter extends CustomPainter {
  final double deviation;

  _AlignmentPainter({required this.deviation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eyeSpacing = 60.0;
    final eyeSize = 25.0;
    final pupilSize = 10.0;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pupilPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill;

    // Draw Right Eye (Normal)
    canvas.drawCircle(center.translate(-eyeSpacing, 0), eyeSize, paint);
    canvas.drawCircle(center.translate(-eyeSpacing, 0), eyeSize, borderPaint);
    canvas.drawCircle(center.translate(-eyeSpacing, 0), pupilSize, pupilPaint);

    // Draw Left Eye (Deviating)
    canvas.drawCircle(center.translate(eyeSpacing, 0), eyeSize, paint);
    canvas.drawCircle(center.translate(eyeSpacing, 0), eyeSize, borderPaint);
    canvas.drawCircle(
      center.translate(eyeSpacing + deviation, 0),
      pupilSize,
      pupilPaint,
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
      duration: const Duration(milliseconds: 4000),
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

          return CustomPaint(
            painter: _CoverProcedurePainter(progress: progress),
          );
        },
      ),
    );
  }
}

class _CoverProcedurePainter extends CustomPainter {
  final double progress;

  _CoverProcedurePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eyeSpacing = 60.0;
    final eyeSize = 25.0;
    final pupilSize = 10.0;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pupilPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill;

    // Draw Eyes
    canvas.drawCircle(center.translate(-eyeSpacing, 0), eyeSize, paint);
    canvas.drawCircle(center.translate(-eyeSpacing, 0), eyeSize, borderPaint);
    canvas.drawCircle(center.translate(-eyeSpacing, 0), pupilSize, pupilPaint);

    canvas.drawCircle(center.translate(eyeSpacing, 0), eyeSize, paint);
    canvas.drawCircle(center.translate(eyeSpacing, 0), eyeSize, borderPaint);
    canvas.drawCircle(center.translate(eyeSpacing, 0), pupilSize, pupilPaint);

    // Draw Occluder (Hand or card)
    final occluderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    double occluderX = 0;
    double opacity = 0;

    // Cycle through cover/uncover on each eye
    if (progress < 0.25) {
      // Cover Right Eye
      occluderX = -eyeSpacing;
      opacity = (progress / 0.25);
    } else if (progress < 0.5) {
      // Uncover Right Eye
      occluderX = -eyeSpacing;
      opacity = 1 - ((progress - 0.25) / 0.25);
    } else if (progress < 0.75) {
      // Cover Left Eye
      occluderX = eyeSpacing;
      opacity = ((progress - 0.5) / 0.25);
    } else {
      // Uncover Left Eye
      occluderX = eyeSpacing;
      opacity = 1 - ((progress - 0.75) / 0.25);
    }

    final occluderRect = Rect.fromCenter(
      center: center.translate(occluderX, -10),
      width: 60,
      height: 80,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(occluderRect, const Radius.circular(10)),
      occluderPaint..color = occluderPaint.color.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
