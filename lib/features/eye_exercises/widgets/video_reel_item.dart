import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../models/exercise_video_model.dart';
import '../../../core/widgets/eye_loader.dart';
import 'dart:async';

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
    debugPrint('ðŸŽ¬ Initializing video: ${widget.video.id}');
    if (widget.video.isAssetVideo) {
      _controller = VideoPlayerController.asset(widget.video.videoPath);
    } else {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoPath),
      );
    }

    try {
      await _controller.initialize();
      _controller.setLooping(false); // Changed to false to detect end
      _controller.addListener(_videoListener);
      if (mounted) {
        setState(() => _isInitialized = true);
        debugPrint('âœ… Video initialized: ${widget.video.id}');
        if (widget.isActive && !_isManuallyPaused) {
          debugPrint('â–¶ï¸ Auto-playing active video: ${widget.video.id}');
          _controller.play();

          // Verify playback started (some devices need a small kick)
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted &&
                !_controller.value.isPlaying &&
                widget.isActive &&
                !_isManuallyPaused) {
              debugPrint('âš ï¸ Initial autoplay failed, retrying...');
              _controller.play();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('âŒ Error initializing video ${widget.video.id}: $e');
    }
  }

  @override
  void didUpdateWidget(VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isActive && !oldWidget.isActive) {
        if (!_isManuallyPaused) {
          debugPrint('â–¶ï¸ Resuming active video: ${widget.video.id}');
          _controller.play();
        }
      } else if (!widget.isActive && oldWidget.isActive) {
        debugPrint('â¸ Pausing inactive video: ${widget.video.id}');
        _controller.pause();
      }
    }
  }

  void _videoListener() {
    if (_isInitialized &&
        _controller.value.position >= _controller.value.duration &&
        !_controller.value.isPlaying) {
      debugPrint('ðŸ Video finished: ${widget.video.id}');
      widget.onVideoEnd?.call();

      if (widget.isActive && !_isManuallyPaused) {
        _controller.seekTo(Duration.zero);
        _controller.play();
      }
    }
  }

  @override
  void dispose() {
    _iconTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (!_isInitialized) return;

    if (_controller.value.isPlaying) {
      debugPrint('â¸ User pausing video: ${widget.video.id}');
      await _controller.pause();
      _isManuallyPaused = true;
    } else {
      debugPrint('â–¶ï¸ User resuming video: ${widget.video.id}');
      await _controller.play();
      _isManuallyPaused = false;

      // Verify playback started
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_controller.value.isPlaying && !_isManuallyPaused) {
          debugPrint(
            'âš ï¸ Playback failed to start, retrying...: ${widget.video.id}',
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
      return Container(
        color: AppColors.black,
        child: const Center(child: EyeLoader.fullScreen()),
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
                    AppColors.black.withValues(alpha: 0.7),
                    AppColors.black.withValues(alpha: 0.3),
                    AppColors.transparent,
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
                    color: AppColors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.play_arrow
                        : Icons.pause,
                    size: 48,
                    color: AppColors.white70,
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
                    color: AppColors.error.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VISIAXX TV',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.video.title,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: AppColors.black87,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (widget.video.description != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.video.description!,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: AppColors.black45,
                          offset: const Offset(0, 1),
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

