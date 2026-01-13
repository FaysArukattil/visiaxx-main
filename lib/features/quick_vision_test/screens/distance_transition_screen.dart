import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../widgets/instruction_animations.dart';
import '../../../core/widgets/eye_loader.dart';

class DistanceTransitionScreen extends StatefulWidget {
  final String title;
  final String currentDistance;
  final String targetDistance;
  final String instruction;
  final String? headline;
  final VoidCallback onContinue;

  const DistanceTransitionScreen({
    super.key,
    required this.title,
    required this.currentDistance,
    required this.targetDistance,
    required this.instruction,
    this.headline,
    required this.onContinue,
  });

  @override
  State<DistanceTransitionScreen> createState() =>
      _DistanceTransitionScreenState();
}

class _DistanceTransitionScreenState extends State<DistanceTransitionScreen> {
  final TtsService _ttsService = TtsService();
  int _secondsRemaining = 4;
  final int _totalSeconds = 4;
  double _progress = 0.0;
  Timer? _timer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _startTimer();
  }

  Future<void> _initTts() async {
    await _ttsService.initialize();
    _ttsService.speak(widget.instruction, speechRate: 0.5);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isPaused) return;

      final elapsedMs = timer.tick * 16;
      final totalMs = _totalSeconds * 1000;

      setState(() {
        _progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
        _secondsRemaining = (_totalSeconds - (elapsedMs ~/ 1000)).clamp(
          0,
          _totalSeconds,
        );
      });

      if (elapsedMs >= totalMs) {
        timer.cancel();
        _handleContinue();
      }
    });
  }

  void _handleContinue() {
    _timer?.cancel();
    _ttsService.stop();
    widget.onContinue();
  }

  void _showExitConfirmation() {
    _ttsService.stop();
    setState(() => _isPaused = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TestExitConfirmationDialog(
        onContinue: () {
          setState(() => _isPaused = false);
        },
        onRestart: () {
          setState(() {
            _isPaused = false;
            _progress = 0.0;
            _secondsRemaining = _totalSeconds;
          });
          _startTimer();
          _ttsService.speak(widget.instruction, speechRate: 0.5);
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ttsService.dispose();
    super.dispose();
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
              // Hero Animation Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const DistanceAnimation(isCompact: true),
                ),
              ),

              // Instruction Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.settings_overscan_rounded,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.headline ?? 'Switching Distance',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.instruction,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Distance Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDistanceInfo(
                                'Current',
                                widget.currentDistance,
                                Icons.near_me_disabled_rounded,
                                AppColors.error,
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              _buildDistanceInfo(
                                'Target',
                                widget.targetDistance,
                                Icons.straighten_rounded,
                                AppColors.success,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action Button
              Container(
                padding: const EdgeInsets.all(16.0),
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
                    onPressed: _secondsRemaining == 0 ? _handleContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.border.withValues(
                        alpha: 0.5,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _secondsRemaining > 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              EyeLoader(
                                size: 30,
                                color: AppColors.primary,
                                value: _progress,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Wait ($_secondsRemaining)',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Continue to Calibration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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

  Widget _buildDistanceInfo(
    String label,
    String distance,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          distance,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
