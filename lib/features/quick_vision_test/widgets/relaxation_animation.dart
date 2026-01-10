import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Relaxation animation widget to show between tests
class RelaxationAnimation extends StatefulWidget {
  final int durationSeconds;
  final VoidCallback onComplete;

  const RelaxationAnimation({
    super.key,
    this.durationSeconds = 10,
    required this.onComplete,
  });

  @override
  State<RelaxationAnimation> createState() => _RelaxationAnimationState();
}

class _RelaxationAnimationState extends State<RelaxationAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: widget.durationSeconds),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.remove_red_eye, size: 80, color: AppColors.primary),
          const SizedBox(height: 32),
          Text(
            'Relax Your Eyes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'Look at a distant object for a few seconds',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          LinearProgressIndicator(
            value: _animation.value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.durationSeconds - (_animation.value * widget.durationSeconds).round()}s',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
