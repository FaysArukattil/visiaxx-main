import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

/// Custom video progress bar - Instagram Reels style with PROPER SEEKING
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
  bool _isDragging = false;
  double _dragValue = 0.0; // 0.0 to 1.0
  bool _wasPlayingBeforeDrag = false;
  DateTime? _lastSeekTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _updateDragPosition(double dx, double width) async {
    final duration = widget.controller.value.duration;
    if (duration == Duration.zero || width == 0) return;

    final progress = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = progress);

    // Optional: throttled seek for visual feedback while dragging
    final now = DateTime.now();
    if (_lastSeekTime == null ||
        now.difference(_lastSeekTime!) > const Duration(milliseconds: 200)) {
      _lastSeekTime = now;
      widget.controller.seekTo(duration * progress);
    }
  }

  Future<void> _onDragStart(Offset globalPosition) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(globalPosition);
    final duration = widget.controller.value.duration;

    _wasPlayingBeforeDrag = widget.controller.value.isPlaying;
    if (_wasPlayingBeforeDrag) {
      await widget.controller.pause();
    }

    setState(() {
      _isDragging = true;
      _dragValue = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
    });

    if (duration != Duration.zero) {
      widget.controller.seekTo(duration * _dragValue);
    }
  }

  Future<void> _onDragEnd() async {
    if (!_isDragging) return;

    final duration = widget.controller.value.duration;
    if (duration != Duration.zero) {
      await widget.controller.seekTo(duration * _dragValue);
    }

    if (_wasPlayingBeforeDrag) {
      await widget.controller.play();
    }

    if (mounted) {
      setState(() => _isDragging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, VideoPlayerValue value, child) {
        final duration = value.duration;
        final position = value.position;

        if (duration == Duration.zero) {
          return child!;
        }

        final currentProgress = _isDragging
            ? _dragValue
            : (duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              _onDragStart(details.globalPosition),
          onHorizontalDragUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            _updateDragPosition(localPosition.dx, box.size.width);
          },
          onHorizontalDragEnd: (details) => _onDragEnd(),
          onHorizontalDragCancel: () => _onDragEnd(),
          onTapDown: (details) => _onDragStart(details.globalPosition),
          onTapUp: (details) => _onDragEnd(),
          onTapCancel: () => _onDragEnd(),
          child: Container(
            height: 40, // Large touch area
            alignment: Alignment.center,
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isDragging ? widget.height * 2.5 : widget.height,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(widget.height),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Progress fill
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * currentProgress,
                          height: _isDragging
                              ? widget.height * 2.5
                              : widget.height,
                          decoration: BoxDecoration(
                            color: widget.progressColor,
                            borderRadius: BorderRadius.circular(widget.height),
                          ),
                        ),
                      ),

                      // Dragging thumb indicator
                      if (_isDragging)
                        Positioned(
                          left: (constraints.maxWidth * currentProgress - 8)
                              .clamp(-8.0, constraints.maxWidth - 8),
                          top: -6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
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
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
        ),
      ),
    );
  }
}
