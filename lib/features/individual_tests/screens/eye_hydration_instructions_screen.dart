import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../quick_vision_test/widgets/instruction_animations.dart';

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
    'Position Face',
    'Ensure Good Lighting',
    'Read Naturally',
  ];

  final List<String> _ttsMessages = [
    'Hold your device at about 40 centimeters from your eyes. Keep both eyes open.',
    'Make sure you are in a well-lit environment. We will monitor your blink rate automatically.',
    'Read the text on the screen at your normal pace. No need to blink forcefully.',
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
          title: const Text('Eye Hydration Instructions'),
          backgroundColor: context.surface,
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
                      Icons.face_rounded,
                      'Position Face',
                      'Hold your device at a comfortable reading distance (40cm). Ensure your entire face is visible.',
                      context.primary,
                      animation: const DistanceAnimation(
                        distanceText: '40 cm',
                        isCompact: false,
                      ),
                    ),
                    _buildStep(
                      1,
                      Icons.light_mode_rounded,
                      'Ensure Good Lighting',
                      'Perform this test in a well-lit environment. We will accurately calculate your blink rate.',
                      context.warning,
                      animation: const LightingAnimation(),
                    ),
                    _buildStep(
                      2,
                      Icons.auto_stories_rounded,
                      'Read Naturally',
                      'A short article will appear. Simply read it at your normal pace. No need to stare or blink forcefully.',
                      context.success,
                      animation: _ReadingAnimation(),
                    ),
                  ],
                ),
              ),
              _buildModernBottomBar(),
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
          color: context.surface,
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

  Widget _buildModernBottomBar() {
    return Container(
      padding: EdgeInsets.all(
        MediaQuery.of(context).orientation == Orientation.landscape
            ? 12.0
            : 16.0,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.of(context).orientation != Orientation.landscape) ...[
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
            height: MediaQuery.of(context).orientation == Orientation.landscape
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
                _currentPage < _totalPages - 1 ? 'Next' : 'Begin Reading',
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
