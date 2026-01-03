import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../models/exercise_video_model.dart';
import 'video_progress_indicator.dart';

/// Individual video reel item - FULL SCREEN Instagram Reels style
class VideoReelItem extends StatefulWidget {
  final ExerciseVideo video;
  final bool isActive;
  final VoidCallback? onVideoEnd;

  const VideoReelItem({
    super.key,
    required this.video,
    required this.isActive,
    this.onVideoEnd,
  });

  @override
  State<VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<VideoReelItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPaused = false;
  bool _isLongPressing = false;
  bool _showPauseIcon = false;
  Timer? _pauseIconTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.video.isAssetVideo) {
        _controller = VideoPlayerController.asset(widget.video.videoPath);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.video.videoPath),
        );
      }

      await _controller!.initialize();
      _controller!.setLooping(false);
      _controller!.addListener(_checkVideoStatus);

      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.isActive) {
          _controller!.play();
        }
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _checkVideoStatus() {
    if (_controller == null || !mounted) return;

    final value = _controller!.value;
    if (value.isInitialized) {
      // Check for completion
      if (value.position >= value.duration &&
          !value.isPlaying &&
          !value.isLooping) {
        widget.onVideoEnd?.call();
      }
    }
  }

  @override
  void didUpdateWidget(VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Re-initialize if video ID or path changed (due to PageView widget reuse)
    if (widget.video.id != oldWidget.video.id ||
        widget.video.videoPath != oldWidget.video.videoPath) {
      _reinitializeVideo();
      return;
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive && !_isLongPressing) {
        _controller?.play();
        setState(() => _isPaused = false);
      } else if (!widget.isActive) {
        _controller?.pause();
      }
    }
  }

  Future<void> _reinitializeVideo() async {
    // Stop and dispose current
    _controller?.pause();
    _controller?.removeListener(_checkVideoStatus);
    _controller?.dispose();

    // Reset state
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _hasError = false;
        _isPaused = false;
      });
    }

    // Start over
    await _initializeVideo();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPaused = true;
        _showPauseIcon = true;
      } else {
        _controller!.play();
        _isPaused = false;
        _showPauseIcon = true;
      }
    });

    _startPauseIconTimer();
  }

  void _startPauseIconTimer() {
    _pauseIconTimer?.cancel();
    _pauseIconTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showPauseIcon = false);
      }
    });
  }

  @override
  void dispose() {
    _pauseIconTimer?.cancel();
    _controller?.removeListener(_checkVideoStatus);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player - FULL SCREEN with proper cover fit
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
        ),

        // Tap area for play/pause (excluding progress bar area at bottom)
        Positioned.fill(
          bottom: 60, // Leave space for progress bar
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (_) {
              if (_controller?.value.isPlaying == true) {
                _controller?.pause();
                setState(() {
                  _isPaused = true;
                  _isLongPressing = true;
                  _showPauseIcon = true;
                });
              }
            },
            onLongPressEnd: (_) {
              if (_isLongPressing) {
                _controller?.play();
                setState(() {
                  _isPaused = false;
                  _isLongPressing = false;
                  _showPauseIcon = true;
                });
                _startPauseIconTimer();
              }
            },
            onTap: _togglePlayPause,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Pause icon with fade animation
        if (_showPauseIcon)
          AnimatedOpacity(
            opacity: _showPauseIcon ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPaused ? Icons.pause : Icons.play_arrow,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        // Video info overlay
        Positioned(
          left: 16,
          bottom: 100,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (widget.video.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.video.description!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Progress bar at bottom - isolated from other gestures
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: CustomVideoProgressBar(
              controller: _controller!,
              progressColor: Colors.white,
              backgroundColor: Colors.white24,
              height: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.video.title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
