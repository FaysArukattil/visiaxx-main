import 'package:flutter/material.dart';
import '../../quick_vision_test/widgets/instruction_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

/// Pelli-Robson Contrast Sensitivity Test Instructions Screen
class PelliRobsonInstructionsScreen extends StatefulWidget {
  final String testMode; // 'short' (40cm) or 'long' (1m)
  final VoidCallback onContinue;

  const PelliRobsonInstructionsScreen({
    super.key,
    required this.testMode,
    required this.onContinue,
  });

  @override
  State<PelliRobsonInstructionsScreen> createState() =>
      _PelliRobsonInstructionsScreenState();
}

class _PelliRobsonInstructionsScreenState
    extends State<PelliRobsonInstructionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'Maximum Brightness',
    'Contrast Sensitivity',
    'Test Distance',
    'Reading Triplets',
    'Declining Contrast',
  ];

  late final List<String> _ttsMessages;

  @override
  void initState() {
    super.initState();
    _ttsMessages = [
      'Please increase your screen brightness to maximum for accurate results. This test measures subtle differences in contrast.',
      'This test measures how well you can distinguish objects from their background. It is crucial for driving, reading, and seeing in low light.',
      widget.testMode == 'short'
          ? 'Hold the device about 40 centimeters away from your face.'
          : 'Place the device exactly 1 meter away from your face.',
      'You will see groups of 3 letters. Only read the letters inside the blue box aloud from left to right.',
      'The letters will become fainter and harder to see. Read as many as you can. If you cannot see any, say "nothing" or "skip".',
    ];
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    // Small delay to ensure service is ready for first load auto-play
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
    widget.onContinue();
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Contrast Test Instructions'),
          backgroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
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
                      Icons.brightness_high_rounded,
                      'Brightness Check',
                      'Turn your screen brightness to maximum for the most accurate contrast measurements.',
                      AppColors.warning,
                      animation: const LightingAnimation(isCompact: true),
                    ),
                    _buildStep(
                      1,
                      Icons.palette_rounded,
                      'What is Contrast?',
                      'Contrast sensitivity is your eye\'s ability to distinguish an object from its background.',
                      AppColors.primary,
                      animation: const AlignmentAnimation(isCompact: true),
                    ),
                    _buildStep(
                      2,
                      Icons.straighten_rounded,
                      'Perfect Distance',
                      widget.testMode == 'short'
                          ? 'Hold the device about 40 centimeters away from your eyes.'
                          : 'Sit exactly 1 meter away from the screen for the long-distance test.',
                      AppColors.success,
                      animation: const DistanceAnimation(isCompact: true),
                    ),
                    _buildStep(
                      3,
                      Icons.record_voice_over_rounded,
                      'Reading Triplets',
                      'You will see several triplets. Read whichever three letters are inside the blue box.',
                      AppColors.info,
                      animation: const ReadingTripletsAnimation(
                        isCompact: true,
                      ),
                    ),
                    _buildStep(
                      4,
                      Icons.gradient_rounded,
                      'Declining Contrast',
                      'The letters will become fainter and harder to see. Read as many as possible until they are no longer visible.',
                      AppColors.error,
                      animation: const FadingTripletsAnimation(isCompact: true),
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
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.05),
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
                                  ? AppColors.primary
                                  : AppColors.border,
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage < _totalPages - 1
                              ? 'Next'
                              : 'Start Test',
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _stepTitles[index],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildModernInstructionItem(icon, description, color),
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stepTitles[index],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildModernInstructionItem(icon, description, color),
                  if (animation != null)
                    Flexible(
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
          child: Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
