import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';

class StereopsisTestInstructionsScreen extends StatefulWidget {
  const StereopsisTestInstructionsScreen({super.key});

  @override
  State<StereopsisTestInstructionsScreen> createState() =>
      _StereopsisTestInstructionsScreenState();
}

class _StereopsisTestInstructionsScreenState
    extends State<StereopsisTestInstructionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'Special Glasses',
    'Viewing Distance',
    'Both Eyes Open',
    'Identify 3D Circle',
  ];

  final List<String> _ttsMessages = [
    'Please wear the special red and cyan anaglyph glasses for this test.',
    'Position yourself at arm\'s length, about 40 centimeters from the screen.',
    'Keep both eyes open and relaxed throughout the test.',
    'You will see 4 circles. Tap on the one that appears to pop out in 3D.',
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
    Navigator.pushReplacementNamed(context, '/stereopsis-test');
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
          title: const Text('Stereopsis Test'),
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
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                    _playCurrentStepTts();
                  },
                  children: [
                    _buildStep(
                      0,
                      Icons.threed_rotation_rounded,
                      'Wear 3D Glasses',
                      'Put on the special red-cyan (anaglyph) glasses. The red lens goes over your LEFT eye, cyan over your RIGHT eye.',
                      context.primary,
                      animation: const _RedCyanGlassesAnimation(),
                    ),
                    _buildStep(
                      1,
                      Icons.straighten_rounded,
                      'Maintain Distance',
                      'Position yourself about 40cm (arm\'s length) from the screen for optimal 3D effect.',
                      context.warning,
                      animation: const _DistanceAnimation(),
                    ),
                    _buildStep(
                      2,
                      Icons.visibility_rounded,
                      'Both Eyes Open',
                      'Keep both eyes open and relaxed. Do not squint or close one eye.',
                      context.info,
                      animation: const _BothEyesAnimation(),
                    ),
                    _buildStep(
                      3,
                      Icons.touch_app_rounded,
                      'Tap the 3D Circle',
                      'You will see 4 circles. ONE will appear to "pop out" with visible red and cyan separation. Tap that circle.',
                      context.success,
                      animation: const _CircleSelectionAnimation(),
                    ),
                  ],
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
                    _currentPage < _totalPages - 1 ? 'Next' : 'Start Test',
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

// Animation for red-cyan glasses
class _RedCyanGlassesAnimation extends StatefulWidget {
  const _RedCyanGlassesAnimation();

  @override
  State<_RedCyanGlassesAnimation> createState() =>
      _RedCyanGlassesAnimationState();
}

class _RedCyanGlassesAnimationState extends State<_RedCyanGlassesAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 120),
          painter: _GlassesPainter(_controller.value),
        );
      },
    );
  }
}

class _GlassesPainter extends CustomPainter {
  final double progress;
  _GlassesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final glassRadius = size.width * 0.2;

    // Left lens (RED)
    final leftCenter = Offset(size.width * 0.3, centerY);
    final redPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6 + progress * 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(leftCenter, glassRadius, redPaint);
    canvas.drawCircle(
      leftCenter,
      glassRadius,
      Paint()
        ..color = Colors.red.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Right lens (CYAN)
    final rightCenter = Offset(size.width * 0.7, centerY);
    final cyanPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.6 + progress * 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rightCenter, glassRadius, cyanPaint);
    canvas.drawCircle(
      rightCenter,
      glassRadius,
      Paint()
        ..color = Colors.cyan.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Bridge
    final bridgePaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(leftCenter.dx + glassRadius, centerY),
      Offset(rightCenter.dx - glassRadius, centerY),
      bridgePaint,
    );

    // Temple arms
    canvas.drawLine(
      Offset(leftCenter.dx - glassRadius, centerY),
      Offset(0, centerY - 10),
      bridgePaint,
    );
    canvas.drawLine(
      Offset(rightCenter.dx + glassRadius, centerY),
      Offset(size.width, centerY - 10),
      bridgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Distance animation
class _DistanceAnimation extends StatelessWidget {
  const _DistanceAnimation();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.phone_android, size: 60, color: context.primary),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 2, color: context.primary),
            const SizedBox(width: 8),
            Text(
              '40cm',
              style: TextStyle(
                color: context.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 80, height: 2, color: context.primary),
          ],
        ),
        const SizedBox(height: 8),
        Icon(Icons.person, size: 60, color: context.textSecondary),
      ],
    );
  }
}

// Both eyes animation
class _BothEyesAnimation extends StatelessWidget {
  const _BothEyesAnimation();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildEye(context, 'L'),
        const SizedBox(width: 40),
        _buildEye(context, 'R'),
      ],
    );
  }

  Widget _buildEye(BuildContext context, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: context.primary, width: 3),
          ),
          child: Center(
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: context.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Circle selection animation
class _CircleSelectionAnimation extends StatefulWidget {
  const _CircleSelectionAnimation();

  @override
  State<_CircleSelectionAnimation> createState() =>
      _CircleSelectionAnimationState();
}

class _CircleSelectionAnimationState extends State<_CircleSelectionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            _buildCircle(context, false, 0),
            _buildCircle(context, true, _controller.value), // This one pops out
            _buildCircle(context, false, 0),
            _buildCircle(context, false, 0),
          ],
        );
      },
    );
  }

  Widget _buildCircle(BuildContext context, bool hasDepth, double progress) {
    final separation = hasDepth ? 4.0 + progress * 4 : 0.0;

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cyan layer
          Transform.translate(
            offset: Offset(-separation, 0),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyan.withValues(alpha: hasDepth ? 0.6 : 0.2),
              ),
            ),
          ),
          // Red layer
          Transform.translate(
            offset: Offset(separation, 0),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: hasDepth ? 0.6 : 0.2),
              ),
            ),
          ),
          // Main circle
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade700,
              border: hasDepth
                  ? Border.all(color: context.primary, width: 2)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
