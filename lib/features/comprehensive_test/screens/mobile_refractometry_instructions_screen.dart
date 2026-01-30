import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../results/widgets/how_to_respond_animation.dart';
import '../../quick_vision_test/widgets/instruction_animations.dart';
import '../../quick_vision_test/widgets/glasses_removal_animation.dart';
import '../widgets/blur_awareness_animation.dart';

class MobileRefractometryInstructionsScreen extends StatefulWidget {
  final VoidCallback? onContinue;

  const MobileRefractometryInstructionsScreen({super.key, this.onContinue});

  @override
  State<MobileRefractometryInstructionsScreen> createState() =>
      _MobileRefractometryInstructionsScreenState();
}

class _MobileRefractometryInstructionsScreenState
    extends State<MobileRefractometryInstructionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'No Eyewear',
    'Lighting Check',
    'Dual Distance Focus',
    'Blur Awareness',
    'How to Respond',
  ];

  final List<String> _ttsMessages = [
    'Please remove your glasses or contact lenses for this test.',
    'First, find a quiet, well-lit room for the best results.',
    'This test checks your vision at two distances: arm\'s length and closer.',
    'During the test, the E may become smaller and blurry. If you can barely make it out, say blurry or select Can\'t See.',
    'Speak the direction of the letter "E". If it looks blurry, just say "blurry".',
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
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      Navigator.pushReplacementNamed(context, '/mobile-refractometry-test');
    }
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
      builder: (context) => TestExitConfirmationDialog(
        onContinue: () {
          _playCurrentStepTts();
        },
        onRestart: () {
          setState(() {
            _currentPage = 0;
          });
          _pageController.jumpToPage(0);
          _playCurrentStepTts();
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
      ),
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
          title: const Text('Mobile Refractometry'),
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
              // PageView Content
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
                      Icons.visibility_off_rounded,
                      'No Eyewear',
                      'Remove glasses or contact lenses. This test measures your natural vision.',
                      context.error,
                      animation: const RemoveGlassesAnimation(),
                    ),
                    _buildStep(
                      1,
                      Icons.wb_sunny_rounded,
                      'Well-lit Room',
                      'Ensure your room is well-lit and quiet for the most accurate results.',
                      context.warning,
                      animation: const LightingAnimation(),
                    ),
                    _buildStep(
                      2,
                      Icons.straighten_rounded,
                      'Multi-Distance',
                      'You will be asked to hold the device at 100cm (distance) and 40cm (near).',
                      context.primary,
                      animation: const DistanceAnimation(),
                    ),
                    _buildStep(
                      3,
                      Icons.blur_on_rounded,
                      'Blur Awareness',
                      'During the test, the E may become smaller and blurry. If you can barely make it out, say "Blurry" or select "Can\'t See".',
                      context.warning,
                      animation: const BlurAwarenessAnimation(),
                    ),
                    _buildStep(
                      4,
                      Icons.mic_rounded,
                      'Voice & Blurry',
                      'Say the direction clearly. If the letter "E" is out of focus, say "Blurry".',
                      context.success,
                      animation: const HowToRespondAnimation(),
                    ),
                  ],
                ),
              ),

              // Bottom Navigation Section
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).orientation == Orientation.landscape
                      ? 12.0
                      : 16.0,
                ),
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
                    if (MediaQuery.of(context).orientation !=
                        Orientation.landscape) ...[
                      // Dot Indicator (only in portrait)
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
                      height:
                          MediaQuery.of(context).orientation ==
                              Orientation.landscape
                          ? 48
                          : 60,
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
                              : 'Start Preparation',
                          style: TextStyle(
                            fontSize:
                                MediaQuery.of(context).orientation ==
                                    Orientation.landscape
                                ? 16
                                : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
                  _buildModernInstructionItem(icon, title, description, color),
                  if (animation != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Center(child: animation),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildModernInstructionItem(
    IconData icon,
    String title,
    String description,
    Color accentColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: 24),
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
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
