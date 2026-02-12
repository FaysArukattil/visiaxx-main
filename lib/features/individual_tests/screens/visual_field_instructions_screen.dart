import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/visual_field_result.dart';
import '../../quick_vision_test/widgets/instruction_animations.dart';
import 'visual_field_cover_eye_screen.dart';
import 'visual_field_test_screen.dart';

class VisualFieldInstructionsScreen extends StatefulWidget {
  const VisualFieldInstructionsScreen({super.key});

  @override
  State<VisualFieldInstructionsScreen> createState() =>
      _VisualFieldInstructionsScreenState();
}

class _VisualFieldInstructionsScreenState
    extends State<VisualFieldInstructionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 2;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = ['Fixed Gaze', 'Response Method'];

  final List<String> _ttsMessages = [
    'Keep your gaze fixed on the center white plus icon throughout the test. Do not look directly at the appearing dots.',
    'Dots will appear in your peripheral vision. Tap the bottom area immediately when you see one. Let\'s practice.',
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
    // Start session once at the beginning of the sequential test
    context.read<TestSessionProvider>().startIndividualTest('visual_field');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VisualFieldCoverEyeScreen(
          eyeToCover: VisualFieldEye.left, // Cover left to test right
          onContinue: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const VisualFieldScreen(eye: VisualFieldEye.right),
              ),
            );
          },
        ),
      ),
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
          title: const Text('Visual Field Prep'),
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
                      Icons.center_focus_strong_rounded,
                      'Fixed Gaze',
                      'Keep your eyes fixed on the center white plus icon throughout the test.',
                      context.primary,
                      animation: const PulsatingFixationAnimation(
                        isCompact: true,
                      ),
                    ),
                    _buildStep(
                      1,
                      Icons.track_changes_rounded,
                      'Detect Dots',
                      'Tap the bottom area as soon as you see a faint dot in your peripheral vision.',
                      context.success,
                      animation: const VisualFieldProcedureAnimation(
                        isCompact: true,
                      ),
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
