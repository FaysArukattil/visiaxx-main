import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Custom video progress bar with seek functionality
class CustomVideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final Color progressColor;
  final Color backgroundColor;
  final double height;

  const CustomVideoProgressBar({
    super.key,
    required this.controller,
    this.progressColor = Colors.white,
    this.backgroundColor = Colors.white24,
    this.height = 4.0,
  });

  @override
  State<CustomVideoProgressBar> createState() => _CustomVideoProgressBarState();
}

class _CustomVideoProgressBarState extends State<CustomVideoProgressBar> {
  void _seekToRelativePosition(
    Offset globalPosition,
    BoxConstraints constraints,
  ) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(globalPosition);
    final percentage = localPosition.dx / constraints.maxWidth;
    final duration = widget.controller.value.duration;

    if (duration != Duration.zero) {
      final newPosition = duration * percentage.clamp(0.0, 1.0);
      widget.controller.seekTo(newPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            _seekToRelativePosition(details.globalPosition, constraints);
          },
          onHorizontalDragUpdate: (details) {
            _seekToRelativePosition(details.globalPosition, constraints);
          },
          child: Container(
            height: widget.height + 20, // Extra touch area
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, child) {
                final duration = widget.controller.value.duration;
                final position = widget.controller.value.position;

                double progress = 0.0;
                if (duration != Duration.zero) {
                  progress = (position.inMilliseconds / duration.inMilliseconds)
                      .clamp(0.0, 1.0);
                }

                return Stack(
                  children: [
                    // Background
                    Container(
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.circular(widget.height / 2),
                      ),
                    ),

                    // Progress
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: widget.height,
                        decoration: BoxDecoration(
                          color: widget.progressColor,
                          borderRadius: BorderRadius.circular(
                            widget.height / 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
