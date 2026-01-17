import 'dart:math';
import 'package:flutter/material.dart';

/// … GLOBAL Reusable Speech Waveform Animation
/// Shows animated bars when listening or talking
class SpeechWaveform extends StatefulWidget {
  final bool isListening;
  final bool isTalking;
  final Color color;
  final double size;
  final int barCount;

  const SpeechWaveform({
    super.key,
    required this.isListening,
    this.isTalking = false,
    required this.color,
    this.size = 14.0,
    this.barCount = 5,
  });

  @override
  State<SpeechWaveform> createState() => _SpeechWaveformState();
}

class _SpeechWaveformState extends State<SpeechWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.barCount, (index) {
            final double baseHeight = widget.size * 0.35;
            final double activeHeight = widget.isTalking
                ? widget.size * 1.3
                : widget.size * 0.85;

            // … Animate IF listening OR talking
            final bool shouldAnimate = widget.isListening || widget.isTalking;

            final double height = shouldAnimate
                ? baseHeight +
                      activeHeight *
                          sin(
                            (_controller.value * 2 * pi) + (index * 0.8),
                          ).abs()
                : baseHeight;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 2.5,
              height: height,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: shouldAnimate ? 0.8 : 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}


