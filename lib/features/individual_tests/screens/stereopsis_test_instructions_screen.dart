import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../quick_vision_test/widgets/instruction_animations.dart';
import '../../../core/constants/app_colors.dart';

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
  final int _totalPages = 3;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'Wear 3D Glasses',
    'Maintain Distance',
    'Identify 3D Image',
  ];

  final List<String> _ttsMessages = [
    'Please wear the special red and blue anaglyph glasses for this test.',
    'Position yourself at arm\'s length, about 40 centimeters from the screen.',
    'You will see an image. Select if you see it in 3D or if it looks flat.',
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
                          Icons.threed_rotation_rounded,
                          '3D Glasses',
                          'Put on the special red-blue anaglyph glasses. The red lens goes over your LEFT eye, blue over your RIGHT eye.',
                          context.primary,
                          animation: _Wear3DGlassesAnimation(
                            height: isLandscape ? 170 : 240,
                          ),
                        ),
                        _buildStep(
                          1,
                          Icons.straighten_rounded,
                          '40cm Distance',
                          'Position yourself about 40cm (arm\'s length) from the screen for optimal 3D effect.',
                          context.warning,
                          animation: DistanceAnimation(
                            isCompact: isLandscape,
                            distanceText: '40 cm',
                          ),
                        ),
                        _buildStep(
                          2,
                          Icons.touch_app_rounded,
                          '3D or Flat?',
                          'You will see 5 different images. For each one, tap "3D" if you perceive depth, or "FLAT" if it looks like a normal 2D image.',
                          context.success,
                          animation: _StereoImageAnimation(
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

// Animation showing user wearing 3D glasses (Red/Blue)
class _Wear3DGlassesAnimation extends StatefulWidget {
  final double height;
  const _Wear3DGlassesAnimation({this.height = 240});

  @override
  State<_Wear3DGlassesAnimation> createState() =>
      _Wear3DGlassesAnimationState();
}

class _Wear3DGlassesAnimationState extends State<_Wear3DGlassesAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _slideAnimation = Tween<double>(begin: widget.height * 0.4, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _controller.repeat(reverse: false);
  }

  @override
  void didUpdateWidget(_Wear3DGlassesAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.height != widget.height) {
      _slideAnimation = Tween<double>(begin: widget.height * 0.4, end: 0)
          .animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
            ),
          );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final faceSize = h * 0.45;
        final eyeSize = faceSize * 0.15;

        return Container(
          width: double.infinity,
          height: widget.height,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Face
                  Container(
                    width: faceSize,
                    height: faceSize,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.warning, width: 3),
                    ),
                    child: Stack(
                      children: [
                        // Left Eye
                        Positioned(
                          top: faceSize * 0.35,
                          left: faceSize * 0.25,
                          child: Container(
                            width: eyeSize,
                            height: eyeSize,
                            decoration: const BoxDecoration(
                              color: AppColors.textPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Right Eye
                        Positioned(
                          top: faceSize * 0.35,
                          right: faceSize * 0.25,
                          child: Container(
                            width: eyeSize,
                            height: eyeSize,
                            decoration: const BoxDecoration(
                              color: AppColors.textPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Smile
                        Positioned(
                          bottom: faceSize * 0.25,
                          left: faceSize * 0.30,
                          child: Container(
                            width: faceSize * 0.40,
                            height: faceSize * 0.20,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.textPrimary,
                                  width: 3,
                                ),
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3D Glasses sliding in
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value - 10),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: CustomPaint(
                        size: Size(faceSize * 1.2, faceSize * 0.4),
                        painter: _RedBlueGlassesPainter(),
                      ),
                    ),
                  ),

                  // Checkmark when done
                  if (_controller.value > 0.8)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _RedBlueGlassesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = size.height * 0.08
      ..style = PaintingStyle.stroke;

    final redLensPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final blueLensPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    const double lensWidthFactor = 0.35;
    const double lensHeightFactor = 0.8;
    final double lensW = size.width * lensWidthFactor;
    final double lensH = size.height * lensHeightFactor;

    // Left lens (RED) - Center at ~29.2% of width (aligned with 0.25 face offset)
    final leftLens = Rect.fromCenter(
      center: Offset(size.width * 0.2916, size.height * 0.5),
      width: lensW,
      height: lensH,
    );
    canvas.drawRect(leftLens, redLensPaint);
    canvas.drawRect(leftLens, framePaint);

    // Right lens (BLUE) - Center at ~70.8% of width (aligned with 0.75 face offset)
    final rightLens = Rect.fromCenter(
      center: Offset(size.width * 0.7083, size.height * 0.5),
      width: lensW,
      height: lensH,
    );
    canvas.drawRect(rightLens, blueLensPaint);
    canvas.drawRect(rightLens, framePaint);

    // Bridge
    canvas.drawLine(
      Offset(size.width * 0.475, size.height * 0.5),
      Offset(size.width * 0.525, size.height * 0.5),
      framePaint,
    );

    // Arms
    canvas.drawLine(
      Offset(leftLens.left, size.height * 0.5),
      Offset(0, size.height * 0.4),
      framePaint,
    );
    canvas.drawLine(
      Offset(rightLens.right, size.height * 0.5),
      Offset(size.width, size.height * 0.4),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Animation showing a 3D image selection effect
class _StereoImageAnimation extends StatefulWidget {
  final double height;
  const _StereoImageAnimation({this.height = 240});

  @override
  State<_StereoImageAnimation> createState() => _StereoImageAnimationState();
}

class _StereoImageAnimationState extends State<_StereoImageAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _depthAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _depthAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final depth = _depthAnimation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // "Image" container
              Container(
                width: widget.height * 0.8,
                height: widget.height * 0.6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10 * depth,
                      offset: Offset(0, 5 * depth),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Red shift
                      Positioned(
                        left: 2 - (4 * depth),
                        top: 0,
                        right: 2 + (4 * depth),
                        bottom: 0,
                        child: Container(
                          color: Colors.red.withValues(alpha: 0.3 * depth),
                        ),
                      ),
                      // Cyan shift
                      Positioned(
                        left: 2 + (4 * depth),
                        top: 0,
                        right: 2 - (4 * depth),
                        bottom: 0,
                        child: Container(
                          color: Colors.cyan.withValues(alpha: 0.3 * depth),
                        ),
                      ),
                      // "3D" content placeholder (a star)
                      Center(
                        child: Icon(
                          Icons.star_rounded,
                          size: 60,
                          color: Colors.amber.withValues(
                            alpha: 0.5 + (0.5 * depth),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Buttons indicator
              Positioned(
                bottom: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: depth < 0.5
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'FLAT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: depth >= 0.5
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '3D',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
