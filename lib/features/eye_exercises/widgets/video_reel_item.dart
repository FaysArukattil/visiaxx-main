import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/exercise_video_model.dart';
import 'video_progress_indicator.dart';

/// Individual video reel item
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

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Initialize based on video type
      if (widget.video.isAssetVideo) {
        _controller = VideoPlayerController.asset(widget.video.videoPath);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.video.videoPath),
        );
      }

      await _controller!.initialize();
      _controller!.setLooping(false);

      // Listen for video completion
      _controller!.addListener(_videoListener);

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

  void _videoListener() {
    if (_controller != null) {
      // Check if video ended
      if (_controller!.value.position >= _controller!.value.duration) {
        widget.onVideoEnd?.call();
      }
    }
  }

  @override
  void didUpdateWidget(VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Play/pause based on active state
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPaused = true;
      } else {
        _controller!.play();
        _isPaused = false;
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
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

    return GestureDetector(
      onLongPressStart: (_) {
        if (_controller?.value.isPlaying == true) {
          _controller?.pause();
          setState(() => _isPaused = true);
        }
      },
      onLongPressEnd: (_) {
        if (_isPaused) {
          _controller?.play();
          setState(() => _isPaused = false);
        }
      },
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video player
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

            // Pause indicator
            if (_isPaused)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pause, size: 50, color: Colors.white),
                ),
              ),

            // Video info overlay
            Positioned(
              left: 16,
              bottom: 80,
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
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                  if (widget.video.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.video.description!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Progress bar at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: CustomVideoProgressBar(
                  controller: _controller!,
                  progressColor: Colors.white,
                  backgroundColor: Colors.white24,
                  height: 3,
                ),
              ),
            ),
          ],
        ),
      ),
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
