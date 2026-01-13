import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/tts_service.dart';

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initTts();
    _startTimer();
  }

  Future<void> _initTts() async {
    await _ttsService.initialize();
    _ttsService.speak(widget.instruction);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          // Auto-continue to the next screen
          widget.onContinue();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Instruction Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
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
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.headline ?? 'Switching Distance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.instruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                          Icons.near_me_disabled,
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                        ),
                        _buildDistanceInfo(
                          'Target',
                          widget.targetDistance,
                          Icons.straighten_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Action Button
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: _secondsRemaining == 0 ? widget.onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _secondsRemaining > 0
                        ? 'Wait ($_secondsRemaining)'
                        : 'Continue to Calibration',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  Widget _buildDistanceInfo(String label, String distance, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary.withValues(alpha: 0.5), size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          distance,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
