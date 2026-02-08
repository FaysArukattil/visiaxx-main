import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../quick_vision_test/widgets/instruction_animations.dart';
import '../widgets/eye_blink_animation.dart';

class EyeHydrationInstructionsScreen extends StatefulWidget {
  const EyeHydrationInstructionsScreen({super.key});

  @override
  State<EyeHydrationInstructionsScreen> createState() =>
      _EyeHydrationInstructionsScreenState();
}

class _EyeHydrationInstructionsScreenState
    extends State<EyeHydrationInstructionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'Position Your Face',
    'Ensure Good Lighting',
    'Read Naturally',
  ];

  final List<String> _ttsMessages = [
    'Position your face clearly in front of the front camera.',
    'Make sure you are in a well-lit area for accurate tracking.',
    'Read the text at your normal pace. We will monitor your eye health automatically.',
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
    Navigator.pushReplacementNamed(context, '/eye-hydration-test');
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
          title: const Text('Eye Hydration Test'),
          backgroundColor: context.cardColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.close, color: context.textPrimary),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.landscape) {
                return Row(
                  children: [
                    Expanded(flex: 1, child: _buildCurrentAnimation()),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: _buildStepContent(_currentPage),
                            ),
                          ),
                          _buildBottomBar(),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        _playCurrentStepTts();
                      },
                      children: [_buildStep(0), _buildStep(1), _buildStep(2)],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentAnimation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: switch (_currentPage) {
          0 => const DistanceAnimation(distanceText: '40 cm', isCompact: true),
          1 => const EyeBlinkAnimation(autoBlink: true, size: 100),
          _ => _ReadingAnimation(),
        },
      ),
    );
  }

  Widget _buildStep(int index) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(child: _buildStepContent(index)),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildCurrentAnimation()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(int index) {
    final titles = ['Position Face', 'Ensure Good Lighting', 'Read Naturally'];
    final descriptions = [
      'Hold your device at a comfortable reading distance (40cm). Ensure your entire face is visible.',
      'Perform this test in a well-lit environment. We will accurately calculate your blink rate.',
      'A short article will appear. Simply read it at your normal pace. No need to stare or blink forcefully.',
    ];
    final icons = [
      Icons.face_rounded,
      Icons.light_mode_rounded,
      Icons.auto_stories_rounded,
    ];
    final colors = [context.primary, context.warning, context.success];

    return Column(
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
        _buildInstructionItem(
          icons[index],
          titles[index],
          descriptions[index],
          colors[index],
        ),
      ],
    );
  }

  Widget _buildInstructionItem(
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
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
          SizedBox(
            width: double.infinity,
            height: 56,
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
                _currentPage < _totalPages - 1 ? 'Next' : 'Begin Reading',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkCalculationAnimation extends StatefulWidget {
  const _BlinkCalculationAnimation();

  @override
  State<_BlinkCalculationAnimation> createState() =>
      _BlinkCalculationAnimationState();
}

class _BlinkCalculationAnimationState extends State<_BlinkCalculationAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
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
        final t = _controller.value;
        // Blink happens at t=0.5
        double blinkFactor = 1.0;
        if (t > 0.45 && t < 0.55) {
          blinkFactor = 0.0;
        }

        return Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Eye shape
              Container(
                width: 100,
                height: 60 * blinkFactor.clamp(0.2, 1.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(50, 30 * blinkFactor.clamp(0.2, 1.0)),
                  ),
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30 * blinkFactor.clamp(0.2, 1.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // "Scanning" line
              Positioned(
                left: 20 + (t * 160),
                top: 20,
                bottom: 20,
                child: Container(
                  width: 2,
                  color: context.success.withValues(alpha: 0.5),
                ),
              ),
              // Counter label
              Positioned(
                bottom: 10,
                child: Text(
                  'Blinks Detected: ${t > 0.5 ? 1 : 0}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReadingAnimation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (int i = 0; i < 4; i++)
            Container(
              height: 8,
              color: Theme.of(context).dividerColor,
              margin: const EdgeInsets.only(bottom: 8),
              width: 140.0 + (i % 2 == 0 ? 20 : -20),
            ),
          const Spacer(),
          const Icon(
            Icons.remove_red_eye_rounded,
            size: 32,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
}
