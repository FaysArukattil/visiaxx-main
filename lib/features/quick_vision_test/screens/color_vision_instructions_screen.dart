import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/color_vision_response_animation.dart';
import '../../results/widgets/wear_specs_animation.dart';
import '../widgets/instruction_animations.dart';

class ColorVisionInstructionsScreen extends StatefulWidget {
  final VoidCallback? onContinue;

  const ColorVisionInstructionsScreen({super.key, this.onContinue});

  @override
  State<ColorVisionInstructionsScreen> createState() =>
      _ColorVisionInstructionsScreenState();
}

class _ColorVisionInstructionsScreenState
    extends State<ColorVisionInstructionsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  final TtsService _ttsService = TtsService();

  final List<String> _stepTitles = [
    'Ishihara Plates',
    'Identifying Numbers',
    'Optimal Position',
    'Vision Correction',
  ];

  final List<String> _ttsMessages = [
    'Identify the number on each plate and select the matching option.',
    'Hold the device at a normal reading distance, about 40 centimeters.',
    'If you wear glasses for distance, please keep them on during the test.',
  ];

  @override
  void initState() {
    super.initState();
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
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      Navigator.pushReplacementNamed(context, '/color-vision-test');
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
      builder: (context) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
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
          hasCompletedTests: provider.hasAnyCompletedTest,
          onSaveAndExit: provider.hasAnyCompletedTest
              ? () {
                  Navigator.pushReplacementNamed(context, '/quick-test-result');
                }
              : null,
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
          title: Text(
            'Color Vision Instructions',
            style: TextStyle(color: context.textPrimary),
          ),
          backgroundColor: context.scaffoldBackground,
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
                      Icons.palette_rounded,
                      'Ishihara Plates',
                      'This test uses circular plates with dots of different colors and sizes.',
                      context.primary,
                      animation: const IshiharaIntroAnimation(),
                    ),
                    _buildStep(
                      1,
                      Icons.touch_app_rounded,
                      'Identifying Numbers',
                      'Each plate contains a number. Select the option that matches what you see.',
                      context.success,
                      animation: const ColorVisionResponseAnimation(),
                    ),
                    _buildStep(
                      2,
                      Icons.visibility_rounded,
                      'Optimal Position',
                      'Hold the device at comfortable reading distance and keep your head steady.',
                      context.warning,
                      animation: const SteadyReadingAnimation(isCompact: true),
                    ),
                    _buildStep(
                      3,
                      Icons.visibility_rounded,
                      'Wear Your Glasses',
                      'If you wear distance correction glasses, please keep them on.',
                      context.info,
                      animation: const WearSpecsAnimation(),
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
                  color: context.surface,
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
                      // Dot Indicator
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
                              : 'Start Color Test',
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
          color: context.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
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

class _AnimatedProfessionalEye extends StatefulWidget {
  const _AnimatedProfessionalEye();

  @override
  __AnimatedProfessionalEyeState createState() =>
      __AnimatedProfessionalEyeState();
}

class __AnimatedProfessionalEyeState extends State<_AnimatedProfessionalEye>
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
    return SizedBox(
      width: 34,
      height: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _EyeInstructionPainter(
              progress: _controller.value,
              color: context.primary,
              scleraColor: Colors.white,
              pupilColor: Colors.black,
            ),
          );
        },
      ),
    );
  }
}

class _EyeInstructionPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color scleraColor;
  final Color pupilColor;

  _EyeInstructionPainter({
    required this.progress,
    required this.color,
    required this.scleraColor,
    required this.pupilColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eyeWidth = size.width * 0.95;
    double baseEyeHeight = size.height * 0.52;

    double irisXOffset = 0;
    double blinkFactor = 1.0;

    const curve = Curves.easeInOutCubic;
    if (progress < 0.15) {
      irisXOffset = 0;
    } else if (progress < 0.35) {
      double t = curve.transform((progress - 0.15) / 0.2);
      irisXOffset = -t * (eyeWidth * 0.28);
    } else if (progress < 0.65) {
      double t = curve.transform((progress - 0.35) / 0.3);
      irisXOffset = -(eyeWidth * 0.28) + (t * eyeWidth * 0.56);
    } else if (progress < 0.85) {
      double t = curve.transform((progress - 0.65) / 0.2);
      irisXOffset = (eyeWidth * 0.28) - (t * eyeWidth * 0.28);
    }

    double pulseScale = 1.0;
    if (progress < 0.15) {
      final t = progress / 0.15;
      pulseScale = 1.4 - (Curves.easeOutExpo.transform(t) * 0.4);
    }

    final blinkMarkers = [0.2, 0.5, 0.8];
    const blinkHalfWindow = 0.07;
    for (final marker in blinkMarkers) {
      if (progress > marker - blinkHalfWindow &&
          progress < marker + blinkHalfWindow) {
        final t =
            (progress - (marker - blinkHalfWindow)) / (blinkHalfWindow * 2);
        final easedT = math.sin(t * math.pi);
        blinkFactor = 1.0 - easedT;
        break;
      }
    }

    final currentHeight = baseEyeHeight * blinkFactor;
    final scleraCenter = center + Offset(irisXOffset * 0.22, 0);

    final eyePath = Path();
    eyePath.moveTo(scleraCenter.dx - eyeWidth / 2, scleraCenter.dy);
    eyePath.quadraticBezierTo(
      scleraCenter.dx,
      scleraCenter.dy - currentHeight,
      scleraCenter.dx + eyeWidth / 2,
      scleraCenter.dy,
    );
    eyePath.quadraticBezierTo(
      scleraCenter.dx,
      scleraCenter.dy + currentHeight,
      scleraCenter.dx - eyeWidth / 2,
      scleraCenter.dy,
    );
    eyePath.close();

    canvas.drawPath(
      eyePath,
      Paint()
        ..color = scleraColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      eyePath,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (blinkFactor > 0.1) {
      canvas.save();
      canvas.clipPath(eyePath);

      final irisCenter = center + Offset(irisXOffset, 0);
      final irisRadius = (size.width / 2) * 0.5;

      canvas.drawCircle(irisCenter, irisRadius, Paint()..color = color);

      canvas.drawCircle(
        irisCenter,
        irisRadius * 0.48 * pulseScale,
        Paint()..color = pupilColor,
      );

      final reflectionOffset =
          Offset(irisRadius * 0.25, -irisRadius * 0.25) +
          Offset(irisXOffset * 0.14, 0);

      canvas.drawCircle(
        irisCenter + reflectionOffset,
        irisRadius * 0.15,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _EyeInstructionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
