import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/extensions/theme_extension.dart';
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        appBar: isLandscape
            ? null
            : AppBar(
                title: Text(widget.title),
                backgroundColor: context.surface,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: Icon(Icons.close, color: context.textPrimary),
                  onPressed: _showExitConfirmation,
                ),
              ),
        body: SafeArea(
          child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Hero Animation Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _buildHeroSection(),
        ),

        // Instruction Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildInstructionSection(),
          ),
        ),

        // Action Button
        _buildActionButtonContainer(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Hero Animation
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildHeroSection(),
                ),
              ),
              // Right: Instructions
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: _buildInstructionSection(isLandscape: true),
                ),
              ),
            ],
          ),
        ),
        _buildActionButtonContainer(isLandscape: true),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.2 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(child: DistanceAnimation(isCompact: true)),
    );
  }

  Widget _buildInstructionSection({bool isLandscape = false}) {
    return Container(
      padding: EdgeInsets.all(isLandscape ? 16 : 24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLandscape)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _showExitConfirmation,
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance close button
                ],
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_overscan_rounded,
                color: context.primary,
                size: isLandscape ? 30 : 40,
              ),
            ),
            SizedBox(height: isLandscape ? 12 : 24),
            Text(
              widget.headline ?? 'Switching Distance',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLandscape ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 16),
            Text(
              widget.instruction,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLandscape ? 14 : 16,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: isLandscape ? 16 : 32),
            // Distance Indicators
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDistanceInfo(
                    'Current',
                    widget.currentDistance,
                    Icons.near_me_disabled_rounded,
                    context.error,
                    small: isLandscape,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: context.primary,
                        size: isLandscape ? 16 : 20,
                      ),
                    ),
                  ),
                  _buildDistanceInfo(
                    'Target',
                    widget.targetDistance,
                    Icons.straighten_rounded,
                    context.success,
                    small: isLandscape,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonContainer({bool isLandscape = false}) {
    return Container(
      padding: EdgeInsets.all(isLandscape ? 12 : 16),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.2 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: isLandscape ? 50 : 60,
        child: ElevatedButton(
          onPressed: _secondsRemaining == 0 ? _handleContinue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: context.border.withValues(alpha: 0.5),
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
                      size: isLandscape ? 24 : 30,
                      color: context.primary,
                      value: _progress,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Wait ($_secondsRemaining)',
                      style: TextStyle(
                        fontSize: isLandscape ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Continue to Calibration',
                  style: TextStyle(
                    fontSize: isLandscape ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDistanceInfo(
    String label,
    String distance,
    IconData icon,
    Color color, {
    bool small = false,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(small ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: small ? 20 : 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: small ? 10 : 12,
            color: context.textSecondary,
          ),
        ),
        Text(
          distance,
          style: TextStyle(
            fontSize: small ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
