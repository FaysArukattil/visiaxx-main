import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/exercise_video_model.dart';
import 'dart:async';

class VideoReelItem extends StatefulWidget {
  final ExerciseVideo video;
  final bool isActive;

  const VideoReelItem({super.key, required this.video, required this.isActive});

  @override
  State<VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<VideoReelItem>
    with AutomaticKeepAliveClientMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showPlayIcon = false;
  bool _isManuallyPaused = false;
  Timer? _iconTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    debugPrint('🎬 Initializing video: ${widget.video.id}');
    if (widget.video.isAssetVideo) {
      _controller = VideoPlayerController.asset(widget.video.videoPath);
    } else {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoPath),
      );
    }

    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (mounted) {
        setState(() => _isInitialized = true);
        debugPrint('✅ Video initialized: ${widget.video.id}');
        if (widget.isActive && !_isManuallyPaused) {
          debugPrint('▶️ Auto-playing active video: ${widget.video.id}');
          _controller.play();
        }
      }
    } catch (e) {
      debugPrint('❌ Error initializing video ${widget.video.id}: $e');
    }
  }

  @override
  void didUpdateWidget(VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isActive && !oldWidget.isActive) {
        if (!_isManuallyPaused) {
          debugPrint('▶️ Resuming active video: ${widget.video.id}');
          _controller.play();
        }
      } else if (!widget.isActive && oldWidget.isActive) {
        debugPrint('⏸ Pausing inactive video: ${widget.video.id}');
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (!_isInitialized) return;

    if (_controller.value.isPlaying) {
      debugPrint('⏸ User pausing video: ${widget.video.id}');
      await _controller.pause();
      _isManuallyPaused = true;
    } else {
      debugPrint('▶️ User resuming video: ${widget.video.id}');
      await _controller.play();
      _isManuallyPaused = false;

      // Verify playback started
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_controller.value.isPlaying && !_isManuallyPaused) {
          debugPrint(
            '⚠️ Playback failed to start, retrying...: ${widget.video.id}',
          );
          _controller.play();
        }
      });
    }

    if (mounted) {
      setState(() {
        _showPlayIcon = true;
      });
    }

    _iconTimer?.cancel();
    _iconTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showPlayIcon = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),

          // Bottom Gradient
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
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Play/Pause Icon Overlay
          if (_showPlayIcon)
            Center(
              child: AnimatedOpacity(
                opacity: _showPlayIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.play_arrow
                        : Icons.pause,
                    size: 48,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),

          // Video Meta Information
          Positioned(
            left: 20,
            bottom: 60,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'EYE EXERCISE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black87,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (widget.video.description != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.video.description!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black45,
                          offset: Offset(0, 1),
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
        ],
      ),
    );
  }
}
