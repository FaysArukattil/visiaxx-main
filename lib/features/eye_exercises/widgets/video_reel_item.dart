import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../models/exercise_video_model.dart';

/// Individual video reel item - FULL SCREEN Instagram Reels style
class VideoReelItem extends StatefulWidget {
  final ExerciseVideo video;
  final bool isActive;
  final VoidCallback? onVideoEnd;
  final bool initialPauseState;
  final Duration initialPosition;
  final ValueChanged<bool>? onPauseStateChanged;
  final ValueChanged<Duration>? onPositionChanged;

  const VideoReelItem({
    super.key,
    required this.video,
    required this.isActive,
    this.onVideoEnd,
    this.initialPauseState = false,
    this.initialPosition = Duration.zero,
    this.onPauseStateChanged,
    this.onPositionChanged,
  });

  @override
  State<VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<VideoReelItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPaused = false;
  bool _isLongPressing = false;
  bool _showPauseIcon = false;
  Timer? _pauseIconTimer;
  Timer? _positionUpdateTimer;
  bool _hasRestoredPosition = false;

  @override
  void initState() {
    super.initState();
    _isPaused = widget.initialPauseState;
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
        // Restore saved position if it exists
        if (widget.initialPosition > Duration.zero) {
          debugPrint(
            'VideoReelItem(${widget.video.id}): Restoring saved position ${widget.initialPosition.inMilliseconds}ms',
          );
          await _controller!.seekTo(widget.initialPosition);
          _hasRestoredPosition = true;
        }

        setState(() {
          _isInitialized = true;
        });

        _startPositionTracking();

        if (widget.isActive && !_isPaused) {
          debugPrint(
            'VideoReelItem(${widget.video.id}): Auto-playing after init',
          );
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

  void _startPositionTracking() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (_controller != null && _controller!.value.isInitialized && mounted) {
        widget.onPositionChanged?.call(_controller!.value.position);
      }
    });
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

    // Sync external pause state if it changed from parent
    if (widget.initialPauseState != oldWidget.initialPauseState) {
      _isPaused = widget.initialPauseState;
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_isInitialized && !_isLongPressing && !_isPaused) {
          debugPrint(
            'VideoReelItem(${widget.video.id}): Auto-resuming on activation',
          );
          _controller?.play();
        }
      } else {
        debugPrint(
          'VideoReelItem(${widget.video.id}): Pausing on deactivation',
        );
        _controller?.pause();
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        // Video is playing - pause it
        _controller!.pause();
        _isPaused = true;
        widget.onPauseStateChanged?.call(true);
        widget.onPositionChanged?.call(_controller!.value.position);
      } else {
        // Video is paused - check if at end, otherwise just resume
        final isAtEnd =
            _controller!.value.position >=
            _controller!.value.duration - const Duration(milliseconds: 200);

        if (isAtEnd) {
          // Only restart if video has ended
          _controller!.seekTo(Duration.zero);
        }
        // Resume from current position (or from start if we just seeked)
        _controller!.play();
        _isPaused = false;
        widget.onPauseStateChanged?.call(false);
      }
      _showPauseIcon = true;
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
    _positionUpdateTimer?.cancel();
    _controller?.removeListener(_checkVideoStatus);
    // Save final position before disposing
    if (_controller != null && _controller!.value.isInitialized) {
      widget.onPositionChanged?.call(_controller!.value.position);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

        // Bottom gradient overlay for text legibility
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
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
                  _isLongPressing = true;
                  _showPauseIcon = true;
                });
              }
            },
            onLongPressEnd: (_) {
              if (_isLongPressing && !_isPaused) {
                // User was long pressing but hadn't manually paused - resume
                _controller?.play();
                setState(() {
                  _isLongPressing = false;
                  _showPauseIcon = true;
                });
                _startPauseIconTimer();
              } else if (_isLongPressing && _isPaused) {
                // User had paused, then long pressed - just clear long press state
                setState(() {
                  _isLongPressing = false;
                });
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
                  _isPaused || _isLongPressing ? Icons.pause : Icons.play_arrow,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        // Video info overlay - Far bottom like YouTube Shorts
        Positioned(
          left: 16,
          bottom: 40, // Slightly adjusted for gradient
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
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
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
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
