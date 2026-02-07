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
    'Select 3D Ball',
  ];

  final List<String> _ttsMessages = [
    'Please wear the special red and blue anaglyph glasses for this test.',
    'Position yourself at arm\'s length, about 40 centimeters from the screen.',
    'You will see 4 balls. Select the one you can see in 3D.',
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
                          'Select the one you can see in 3D',
                          'You will see 4 balls. ONE will appear to "pop out" in 3D. Tap that ball to respond.',
                          context.success,
                          animation: _Grid3DBallAnimation(
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
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final redLensPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final blueLensPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Left lens (RED)
    final leftLens = Rect.fromLTWH(10, 5, 35, 30);
    canvas.drawRect(leftLens, redLensPaint);
    canvas.drawRect(leftLens, framePaint);

    // Right lens (BLUE)
    final rightLens = Rect.fromLTWH(75, 5, 35, 30);
    canvas.drawRect(rightLens, blueLensPaint);
    canvas.drawRect(rightLens, framePaint);

    // Bridge
    canvas.drawLine(const Offset(45, 20), const Offset(75, 20), framePaint);

    // Arms
    canvas.drawLine(const Offset(10, 20), const Offset(0, 15), framePaint);
    canvas.drawLine(const Offset(110, 20), const Offset(120, 15), framePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 2x2 Grid of Balls with 3D Effect and Tap Interaction
class _Grid3DBallAnimation extends StatefulWidget {
  final double height;
  const _Grid3DBallAnimation({this.height = 240});

  @override
  State<_Grid3DBallAnimation> createState() => _Grid3DBallAnimationState();
}

class _Grid3DBallAnimationState extends State<_Grid3DBallAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _targetIndex = 0;
  bool _isTapping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _controller.addListener(() {
      final progress = _controller.value;
      // Cycle target index every 1s
      final newIndex = (progress * 4).floor();
      if (newIndex != _targetIndex) {
        setState(() {
          _targetIndex = newIndex;
          _isTapping = false;
        });
      }

      // Trigger tap effect in the second half of each second
      final subProgress = (progress * 4) % 1.0;
      if (subProgress > 0.5 && !_isTapping) {
        setState(() => _isTapping = true);
      }
    });
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
        final ballSize = h * 0.3; // Responsive ball size
        final spacing = h * 0.1; // Responsive spacing

        return Container(
          width: double.infinity,
          height: widget.height,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBall(0, ballSize),
                      SizedBox(width: spacing),
                      _buildBall(1, ballSize),
                    ],
                  ),
                  SizedBox(height: spacing),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBall(2, ballSize),
                      SizedBox(width: spacing),
                      _buildBall(3, ballSize),
                    ],
                  ),
                ],
              ),
              // Finger animation
              _buildFinger(ballSize, spacing, constraints),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBall(int index, double size) {
    final isTarget = index == _targetIndex;
    final subProgress = (_controller.value * 4) % 1.0;

    final oscillation = (1.0 - (subProgress - 0.5).abs() * 2);
    final scale = isTarget ? 1.0 + 0.15 * oscillation : 1.0;
    final depth = isTarget ? (size * 0.08) * oscillation : 0.0;
    final shadowBlur = isTarget ? (size * 0.15) * oscillation : 0.0;

    final innerSize = size * 0.6;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.2),
          border: Border.all(
            color: isTarget && _isTapping
                ? AppColors.success
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isTarget)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2 * oscillation),
                blurRadius: shadowBlur,
                offset: Offset(0, depth),
              ),
          ],
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Blue layer
              Transform.translate(
                offset: Offset(-depth, 0),
                child: Container(
                  width: innerSize * 1.1,
                  height: innerSize * 1.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: isTarget ? 0.4 : 0.1),
                  ),
                ),
              ),
              // Red layer
              Transform.translate(
                offset: Offset(depth, 0),
                child: Container(
                  width: innerSize * 1.1,
                  height: innerSize * 1.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: isTarget ? 0.4 : 0.1),
                  ),
                ),
              ),
              // Main ball
              Container(
                width: innerSize,
                height: innerSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.grey, Colors.black],
                    center: Alignment(-0.3, -0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinger(
    double ballSize,
    double spacing,
    BoxConstraints constraints,
  ) {
    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;

    final row = _targetIndex ~/ 2;
    final col = _targetIndex % 2;

    // Calculate ball center positions relative to container center
    final ballTotalSize = ballSize + spacing;
    final targetX =
        centerX + (col == 0 ? -ballTotalSize / 2 : ballTotalSize / 2);
    final targetY =
        centerY + (row == 0 ? -ballTotalSize / 2 : ballTotalSize / 2);

    final subProgress = (_controller.value * 4) % 1.0;
    final slideDistance = constraints.maxHeight * 0.4;
    final currentY = subProgress < 0.5
        ? targetY + slideDistance * (1.0 - subProgress * 2)
        : targetY + slideDistance * (subProgress - 0.5) * 2;

    return Positioned(
      left: targetX + (ballSize * 0.2),
      top: currentY,
      child: Transform.rotate(
        angle: -0.3,
        child: Icon(
          Icons.touch_app,
          size: ballSize * 0.6,
          color: _isTapping ? AppColors.success : Colors.grey,
        ),
      ),
    );
  }
}
