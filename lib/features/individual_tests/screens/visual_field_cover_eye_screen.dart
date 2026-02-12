import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/visual_field_result.dart';
import 'package:provider/provider.dart';

class VisualFieldCoverEyeScreen extends StatefulWidget {
  final VisualFieldEye eyeToCover;
  final VoidCallback? onContinue;

  const VisualFieldCoverEyeScreen({
    super.key,
    required this.eyeToCover,
    this.onContinue,
  });

  @override
  State<VisualFieldCoverEyeScreen> createState() =>
      _VisualFieldCoverEyeScreenState();
}

class _VisualFieldCoverEyeScreenState extends State<VisualFieldCoverEyeScreen> {
  int _countdown = 4;
  int _totalDuration = 4;
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

    final eyeToCoverLabel = widget.eyeToCover == VisualFieldEye.left
        ? 'left'
        : 'right';
    final eyeBeingTested = widget.eyeToCover == VisualFieldEye.left
        ? 'right'
        : 'left';

    await _ttsService.speak(
      'Cover your $eyeToCoverLabel eye with your palm or a paper. '
      'Keep your $eyeBeingTested eye open. '
      'Focus your gaze on the center dot throughout the test. '
      'Tap anywhere on the screen whenever you see a flickering dot in your peripheral vision.',
      speechRate: 0.5,
    );

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
      const duration = 4;

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

        if (_isAutoScrolling && _scrollController.hasClients) {
          _scrollController.jumpTo(
            maxScroll * (progress * 1.25).clamp(0.0, 1.0),
          );
        }

        if (_scrollController.hasClients &&
            _scrollController.offset >= maxScroll - 5) {
          if (!_reachedBottom) {
            setState(() => _reachedBottom = true);
          }
        }

        if (elapsedMs >= totalMs) {
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
      Navigator.of(context).pop();
    }
  }

  void _showExitConfirmation() {
    setState(() => _isPaused = true);
    _countdownTimer?.cancel();
    _ttsService.stop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          onContinue: () {
            setState(() => _isPaused = false);
            _startCountdown();
          },
          onRestart: () {
            setState(() {
              _isPaused = false;
              _countdown = 4;
            });
            _startCountdown();
            _initializeTts();
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
    final eyeToCoverLabel = widget.eyeToCover == VisualFieldEye.left
        ? 'Left'
        : 'Right';
    final eyeBeingTested = widget.eyeToCover == VisualFieldEye.left
        ? 'Right'
        : 'Left';
    final eyeColor = eyeBeingTested == 'Right' ? context.primary : context.info;

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
            'Test Preparation',
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
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              if (isLandscape) {
                return Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: context.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _EyeIllustration(eyeToCover: widget.eyeToCover),
                              const SizedBox(height: 12),
                              Text(
                                'Cover $eyeToCoverLabel Eye',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: context.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Visual Field Test',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.primary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: context.border.withValues(
                                      alpha: 0.5,
                                    ),
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
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildInstructionItem(
                                          Icons.center_focus_strong_rounded,
                                          'Fixed Gaze',
                                          'Keep your eye focused on the center dot at all times',
                                          context.primary,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Divider(height: 1),
                                        ),
                                        _buildInstructionItem(
                                          Icons.visibility_rounded,
                                          'Peripheral Dot',
                                          'Dots will flicker in your peripheral field',
                                          context.info,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Divider(height: 1),
                                        ),
                                        _buildInstructionItem(
                                          Icons.touch_app_rounded,
                                          'Respond Promptly',
                                          'Tap the screen as soon as you see a flicker',
                                          context.warning,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _handleContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: eyeColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _countdown > 0
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          EyeLoader(
                                            size: 24,
                                            color: Colors.white,
                                            value: _progress,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Starting in $_countdown...',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Start $eyeBeingTested Eye Test',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: context.border.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _EyeIllustration(eyeToCover: widget.eyeToCover),
                          const SizedBox(height: 12),
                          Text(
                            'Cover $eyeToCoverLabel Eye',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: context.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Visual Field Test Preparation',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.primary.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: context.border.withValues(alpha: 0.5),
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
                                  Icons.center_focus_strong_rounded,
                                  'Keep Fixed Gaze',
                                  'Focus on the center dot throughout the entire test',
                                  context.primary,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Divider(height: 1),
                                ),
                                _buildInstructionItem(
                                  Icons.visibility_rounded,
                                  'Watch for Dots',
                                  'Dots will appear in your peripheral field',
                                  context.info,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Divider(height: 1),
                                ),
                                _buildInstructionItem(
                                  Icons.touch_app_rounded,
                                  'Tap the Screen',
                                  'Tap anywhere as soon as you detect a flickering dot',
                                  context.warning,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16.0),
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
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _handleContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: eyeColor,
                          foregroundColor: Colors.white,
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
                                    color: Colors.white,
                                    value: _progress,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Starting in $_countdown...',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Start $eyeBeingTested Eye Test',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
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

class _EyeIllustration extends StatelessWidget {
  final VisualFieldEye eyeToCover;

  const _EyeIllustration({required this.eyeToCover});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  context.primary.withValues(alpha: 0.1),
                  context.primary.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
          Positioned(
            top: 35,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Eye(isActive: eyeToCover == VisualFieldEye.right),
                const SizedBox(width: 25),
                _Eye(isActive: eyeToCover == VisualFieldEye.left),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final isLeft = eyeToCover == VisualFieldEye.left;
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
                      color: context.primary.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isLeft ? 30 : 10),
                        bottomLeft: Radius.circular(isLeft ? 30 : 10),
                        topRight: Radius.circular(isLeft ? 10 : 30),
                        bottomRight: Radius.circular(isLeft ? 10 : 30),
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
    );
  }
}

class _Eye extends StatelessWidget {
  final bool isActive;

  const _Eye({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.primary.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.grey : context.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
