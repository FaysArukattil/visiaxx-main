import 'package:flutter/material.dart';
import 'dart:async';

/// Countdown timer widget for test timing
class CountdownTimer extends StatefulWidget {
  final int seconds;
  final VoidCallback onComplete;
  final bool autoStart;

  const CountdownTimer({
    super.key,
    required this.seconds,
    required this.onComplete,
    this.autoStart = true,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.seconds;
    if (widget.autoStart) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _isRunning = false;
        widget.onComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.seconds;
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isRunning && _remainingSeconds > 0)
              IconButton(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Start',
              ),
            if (_isRunning)
              IconButton(
                onPressed: _pauseTimer,
                icon: const Icon(Icons.pause),
                tooltip: 'Pause',
              ),
            IconButton(
              onPressed: _resetTimer,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
            ),
          ],
        ),
      ],
    );
  }
}
