import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

class ColorVisionCoverEyeScreen extends StatefulWidget {
  final String eyeToCover; // 'left' or 'right'
  final VoidCallback onContinue;

  const ColorVisionCoverEyeScreen({
    super.key,
    required this.eyeToCover,
    required this.onContinue,
  });

  @override
  State<ColorVisionCoverEyeScreen> createState() =>
      _ColorVisionCoverEyeScreenState();
}

class _ColorVisionCoverEyeScreenState extends State<ColorVisionCoverEyeScreen> {
  int _countdown = 3;
  int _totalDuration = 3;
  double _progress = 0.0;
  bool _isAutoScrolling = true;
  bool _isPaused = false;
  bool _reachedBottom = false;
  Timer? _countdownTimer;
  Timer? _resumeTimer;
  final TtsService _ttsService = TtsService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _ttsService.initialize();
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _isPaused) return;

    final eyeBeingTested = widget.eyeToCover == 'left' ? 'right' : 'left';
    await _ttsService.speak(
      'Cover your ${widget.eyeToCover} eye with your palm or a paper. '
      'Keep your $eyeBeingTested eye open. '
      'Stand at 40 centimeters distance from the screen. '
      'You will see colored plates with numbers. '
      'Tap the correct option that matches what you see on the screen.',
      speechRate: 0.5,
    );

    // ✅ FIX: Start countdown only after TTS completes
    if (mounted && !_isPaused) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _resumeTimer?.cancel();
    _isAutoScrolling = true;
    _scrollController.removeListener(_onScroll);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      setState(() => _progress = 0.0);
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      final maxScroll = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      const duration = 3;

      setState(() {
        _countdown = duration;
        _totalDuration = duration;
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

        final currentSec = elapsedMs ~/ 1000;
        final newCountdown = (_totalDuration - currentSec).clamp(
          0,
          _totalDuration,
        );

        if (newCountdown != _countdown) {
          setState(() => _countdown = newCountdown);
        }

        final progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
        setState(() => _progress = progress);

        if (_isAutoScrolling && _scrollController.hasClients && maxScroll > 0) {
          _scrollController.jumpTo(maxScroll * progress);
        }

        // Check if reached bottom
        if (_scrollController.hasClients &&
            (maxScroll == 0 || _scrollController.offset >= maxScroll - 5)) {
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
    widget.onContinue();
  }

  void _showExitConfirmation() {
    setState(() => _isPaused = true);
    _countdownTimer?.cancel();
    _ttsService.stop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TestExitConfirmationDialog(
        onContinue: () {
          setState(() => _isPaused = false);
          _startCountdown();
        },
        onRestart: () {
          setState(() {
            _isPaused = false;
            _countdown = 3;
          });
          _startCountdown();
          _initializeTts();
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final eyeBeingTested = widget.eyeToCover == 'left' ? 'right' : 'left';
    final eyeColor = eyeBeingTested == 'right'
        ? AppColors.rightEye
        : AppColors.leftEye;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Test Instructions'),
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
                                _CircularEye(color: eyeColor),
                                const SizedBox(width: 25),
                                _CircularEye(color: eyeColor),
                              ],
                            ),
                          ),
                          // Semi-circular Hand Cover
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              final isLeft = widget.eyeToCover == 'left';
                              return Positioned(
                                left: isLeft ? 10 + (25 * (1 - value)) : null,
                                right: !isLeft ? 10 + (25 * (1 - value)) : null,
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
                                      borderRadius: BorderRadius.only(
                                        topLeft: isLeft
                                            ? const Radius.circular(30)
                                            : const Radius.circular(10),
                                        bottomLeft: isLeft
                                            ? const Radius.circular(30)
                                            : const Radius.circular(10),
                                        topRight: !isLeft
                                            ? const Radius.circular(30)
                                            : const Radius.circular(10),
                                        bottomRight: !isLeft
                                            ? const Radius.circular(30)
                                            : const Radius.circular(10),
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
                    Text(
                      'COVER YOUR ${widget.eyeToCover.toUpperCase()} EYE',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B3A57),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Focus with your ${eyeBeingTested.toUpperCase()} eye only',
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
                            _buildInstructionItem(
                              Icons.straighten,
                              'Testing Distance',
                              'Stand 40 centimeters from screen',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),
                            _buildInstructionItem(
                              Icons.palette,
                              'Color Plates',
                              'Look at colored plates and identify the number',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),
                            _buildInstructionItem(
                              Icons.touch_app,
                              'Tap to Respond',
                              'Identify the number on the plate and tap the matching button',
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
                      backgroundColor: eyeColor,
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
                            'Start ${eyeBeingTested.toUpperCase()} Eye Test',
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

  Widget _buildInstructionItem(
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircularEye extends StatelessWidget {
  final Color color;
  const _CircularEye({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
