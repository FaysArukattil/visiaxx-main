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
    'Identify 3D Ball',
  ];

  final List<String> _ttsMessages = [
    'Please wear the special red and blue anaglyph glasses for this test.',
    'Position yourself at arm\'s length, about 40 centimeters from the screen.',
    'You will see 4 balls. Tap on the one that appears to pop out in 3D.',
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
                      '3D Glasses',
                      'Put on the special red-blue anaglyph glasses. The red lens goes over your LEFT eye, blue over your RIGHT eye.',
                      context.primary,
                      animation: const _Wear3DGlassesAnimation(),
                    ),
                    _buildStep(
                      1,
                      Icons.straighten_rounded,
                      '40cm Distance',
                      'Position yourself about 40cm (arm\'s length) from the screen for optimal 3D effect.',
                      context.warning,
                      animation: const DistanceAnimation(isCompact: false),
                    ),
                    _buildStep(
                      2,
                      Icons.touch_app_rounded,
                      '3D Effect',
                      'You will see 4 balls. ONE will appear to "pop out" in 3D. Tap that ball to respond.',
                      context.success,
                      animation: const _Grid3DBallAnimation(),
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

// Animation showing user wearing 3D glasses (Red/Blue)
class _Wear3DGlassesAnimation extends StatefulWidget {
  const _Wear3DGlassesAnimation();

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

    _slideAnimation = Tween<double>(begin: 100, end: 0).animate(
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const faceSize = 100.0;
    const eyeSize = 15.0;

    return Center(
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
                  ],
                ),
              ),

              // 3D Glasses sliding in
              Transform.translate(
                offset: Offset(0, _slideAnimation.value - 10),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: CustomPaint(
                    size: const Size(120, 40),
                    painter: _RedBlueGlassesPainter(),
                  ),
                ),
              ),

              // Checkmark when done
              if (_controller.value > 0.8)
                Positioned(
                  top: -10,
                  right: -10,
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
  const _Grid3DBallAnimation();

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
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBall(0),
                    const SizedBox(width: 20),
                    _buildBall(1),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBall(2),
                    const SizedBox(width: 20),
                    _buildBall(3),
                  ],
                ),
              ],
            ),
            // Finger animation
            _buildFinger(),
          ],
        ),
      ),
    );
  }

  Widget _buildBall(int index) {
    final isTarget = index == _targetIndex;
    final subProgress = (_controller.value * 4) % 1.0;
    // Oscillate depth for the target ball
    final depth = isTarget
        ? 4.0 + 4.0 * (1.0 - (subProgress - 0.5).abs() * 2)
        : 0.0;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTarget && _isTapping
              ? AppColors.success
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Blue layer (shifted left)
            Transform.translate(
              offset: Offset(-depth, 0),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: isTarget ? 0.4 : 0.1),
                ),
              ),
            ),
            // Red layer (shifted right)
            Transform.translate(
              offset: Offset(depth, 0),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: isTarget ? 0.4 : 0.1),
                ),
              ),
            ),
            // Main ball
            Container(
              width: 36,
              height: 36,
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
    );
  }

  Widget _buildFinger() {
    // Calculate ball position for finger to target
    final row = _targetIndex ~/ 2;
    final col = _targetIndex % 2;
    final targetPos = Offset(30.0 + col * 80.0, 30.0 + row * 80.0);

    final subProgress = (_controller.value * 4) % 1.0;
    // Finger moves from bottom to ball and back
    final fingerOffset = subProgress < 0.5
        ? targetPos + Offset(20, 100 * (1.0 - subProgress * 2))
        : targetPos + Offset(20, 100 * (subProgress - 0.5) * 2);

    return Positioned(
      left: fingerOffset.dx,
      top: fingerOffset.dy,
      child: Transform.rotate(
        angle: -0.3,
        child: Icon(
          Icons.touch_app,
          size: 40,
          color: _isTapping ? AppColors.success : Colors.grey,
        ),
      ),
    );
  }
}
