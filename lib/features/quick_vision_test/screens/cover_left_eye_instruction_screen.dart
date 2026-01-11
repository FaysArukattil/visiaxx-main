import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

class CoverLeftEyeInstructionScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String ttsMessage;
  final double targetDistance;
  final String startButtonText;
  final String instructionTitle;
  final String instructionDescription;
  final IconData instructionIcon;
  final VoidCallback? onContinue;

  const CoverLeftEyeInstructionScreen({
    super.key,
    this.title = 'Visual Acuity Test',
    this.subtitle = 'Focus with your RIGHT eye only',
    this.ttsMessage =
        'Cover your left eye with your palm or a paper. Keep your right eye open. Stand at one meter distance from the screen. You will see the letter E pointing in different directions. Say up, upward, or upper, down, downward, or bottom, left, or right to indicate the direction. If you cannot see clearly, say blurry or nothing.',
    this.targetDistance = 100.0,
    this.startButtonText = 'Start Right Eye Test',
    this.instructionTitle = 'Voice Commands',
    this.instructionDescription =
        'Say the direction the E is pointing:\nUP / UPWARD / UPPER,\nDOWN / DOWNWARD / BOTTOM,\nLEFT, RIGHT\n\nOr say BLURRY / NOTHING if you can\'t see clearly',
    this.instructionIcon = Icons.mic,
    this.onContinue,
  });

  @override
  State<CoverLeftEyeInstructionScreen> createState() =>
      _CoverLeftEyeInstructionScreenState();
}

class _CoverLeftEyeInstructionScreenState
    extends State<CoverLeftEyeInstructionScreen> {
  int _countdown = 3;
  int _totalDuration = 3;
  double _progress = 0.0;
  bool _isAutoScrolling = true;
  final TtsService _ttsService = TtsService();
  final ScrollController _scrollController = ScrollController();
  Timer? _countdownTimer;
  Timer? _resumeTimer;
  bool _isPaused = false;
  bool _reachedBottom = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _startCountdown();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _ttsService.speak(widget.ttsMessage, speechRate: 0.5);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _resumeTimer?.cancel();
    _isAutoScrolling = true;
    _scrollController.removeListener(_onScroll);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Step 1: Eye covering animation delay (1s)
      setState(() => _progress = 0.0);
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final calculatedDuration = (maxScroll / 150).ceil().clamp(3, 10);

      setState(() {
        _countdown = calculatedDuration;
        _totalDuration = calculatedDuration;
      });

      _countdownTimer = Timer.periodic(const Duration(milliseconds: 16), (
        timer,
      ) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_isPaused) return;

        final elapsedMs = timer.tick * 16;
        final totalMs = _totalDuration * 1000;

        // Update countdown text every second
        final currentSec = elapsedMs ~/ 1000;
        final newCountdown = (_totalDuration - currentSec).clamp(
          0,
          _totalDuration,
        );

        if (newCountdown != _countdown) {
          setState(() => _countdown = newCountdown);
        }

        // Update progress for EyeLoader (always syncs with timer)
        final progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
        setState(() => _progress = progress);

        // Auto-scroll only if active
        if (_isAutoScrolling && _scrollController.hasClients) {
          _scrollController.jumpTo(maxScroll * progress);
        }

        // Check if reached bottom
        if (_scrollController.hasClients &&
            _scrollController.offset >= maxScroll - 5) {
          if (!_reachedBottom) {
            setState(() => _reachedBottom = true);
          }
        }

        // Auto-continue only if timer finished AND scrolled to bottom
        if (elapsedMs >= totalMs && _reachedBottom) {
          timer.cancel();
          _handleContinue();
        }
      });
    });
  }

  void _handleContinue() {
    _countdownTimer?.cancel();
    _ttsService.stop();
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      _navigateToTest();
    }
  }

  void _navigateToTest() {
    Navigator.pushReplacementNamed(context, '/visual-acuity-test');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resumeTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      if (_isAutoScrolling) {
        setState(() => _isAutoScrolling = false);
      }
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_isPaused) {
          setState(() => _isAutoScrolling = true);
        }
      });
    }
  }

  void _showExitConfirmation() {
    _ttsService.stop();
    _countdownTimer?.cancel();
    setState(() => _isPaused = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TestExitConfirmationDialog(
        onContinue: () {
          setState(() => _isPaused = false);
          _startCountdown();
        },
        onRestart: () {
          // Restarting the instruction screen is just resuming it or reset countdown
          setState(() {
            _isPaused = false;
            _countdown = 3;
          });
          _startCountdown();
          _ttsService.speak(widget.ttsMessage, speechRate: 0.5);
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
          title: Text(widget.title),
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
              // Fixed Illustration Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Illustration Scale Reduced to minimize white space
                    SizedBox(
                      width: 120,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circular Face Silhouette
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.1),
                                  AppColors.primary.withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                          ),
                          // Eyes
                          Positioned(
                            top: 35,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _AnimatedProfessionalEye(),
                                const SizedBox(width: 25),
                                const _AnimatedProfessionalEye(),
                              ],
                            ),
                          ),
                          // Semi-circular Hand Cover (Sliding Left)
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Positioned(
                                left: 10 + (25 * (1 - value)),
                                top: 15 + (10 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: Container(
                                    width: 45,
                                    height: 55,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(30),
                                        bottomLeft: Radius.circular(30),
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.pan_tool_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cover Left Eye',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B3A57),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A90E2),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Fixed Instruction Window
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Listener(
                      onPointerDown: (_) {
                        if (_isAutoScrolling) {
                          setState(() => _isAutoScrolling = false);
                        }
                        _resumeTimer?.cancel();
                      },
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModernInstructionItem(
                              Icons.straighten_rounded,
                              'Testing Distance',
                              'Stand ${widget.targetDistance >= 100 ? 1 : 0.4} meter (${widget.targetDistance.toInt()}cm) from screen',
                              AppColors.primary,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),
                            _buildModernInstructionItem(
                              widget.instructionIcon,
                              widget.instructionTitle,
                              widget.instructionDescription,
                              AppColors.success,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),
                            _buildModernInstructionItem(
                              Icons.record_voice_over_rounded,
                              'Voice Recognition',
                              'Listen for the beep and speak clearly',
                              AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Button Section
              Container(
                padding: const EdgeInsets.all(24.0),
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
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _countdown > 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              EyeLoader(
                                size: 32,
                                color: AppColors.white,
                                value: _progress,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Starting in $_countdown...',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            widget.startButtonText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
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
              color: const Color(0xFF4A90E2),
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
