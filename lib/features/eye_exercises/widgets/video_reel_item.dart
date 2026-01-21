import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../models/exercise_video_model.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../data/providers/eye_exercise_provider.dart';
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
  bool _wasPausedByNavigation = false;

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
      _controller.setLooping(false);
      _controller.addListener(_videoListener);
      if (mounted) {
        setState(() => _isInitialized = true);
        debugPrint('✅ Video initialized: ${widget.video.id}');

        // Check if we should pause (user might have navigated away before init)
        final provider = Provider.of<EyeExerciseProvider>(
          context,
          listen: false,
        );
        if (widget.isActive &&
            !_isManuallyPaused &&
            !provider.shouldPauseVideos) {
          debugPrint('▶️ Auto-playing active video: ${widget.video.id}');
          _controller.play();

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted &&
                !_controller.value.isPlaying &&
                widget.isActive &&
                !_isManuallyPaused &&
                !provider.shouldPauseVideos) {
              debugPrint('⚠️ Initial autoplay failed, retrying...');
              _controller.play();
            }
          });
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
        final provider = Provider.of<EyeExerciseProvider>(
          context,
          listen: false,
        );
        if (!_isManuallyPaused && !provider.shouldPauseVideos) {
          debugPrint('▶️ Resuming active video: ${widget.video.id}');
          _controller.play();
        }
      } else if (!widget.isActive && oldWidget.isActive) {
        debugPrint('⏸ Pausing inactive video: ${widget.video.id}');
        _controller.pause();
      }
    }
  }

  void _videoListener() {
    if (_isInitialized &&
        _controller.value.position >= _controller.value.duration &&
        !_controller.value.isPlaying) {
      debugPrint('🏁 Video finished: ${widget.video.id}');
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
      debugPrint('⏸ User pausing video: ${widget.video.id}');
      await _controller.pause();
      _isManuallyPaused = true;
    } else {
      debugPrint('▶️ User resuming video: ${widget.video.id}');
      await _controller.play();
      _isManuallyPaused = false;

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

  void _handleProviderPauseState(bool shouldPause) {
    if (!_isInitialized) return;

    if (shouldPause) {
      // Navigation pause - pause video if playing
      if (_controller.value.isPlaying) {
        debugPrint('🚫 Pausing video due to navigation: ${widget.video.id}');
        _controller.pause();
        _wasPausedByNavigation = true;
      }
    } else {
      // Navigation resume - only resume if it was paused by navigation and not manually paused
      if (_wasPausedByNavigation && !_isManuallyPaused && widget.isActive) {
        debugPrint('✅ Resuming video after navigation: ${widget.video.id}');
        _controller.play();
        _wasPausedByNavigation = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isInitialized) {
      return Container(
        color: AppColors.black,
        child: const Center(child: EyeLoader.fullScreen()),
      );
    }

    return Consumer<EyeExerciseProvider>(
      builder: (context, provider, child) {
        // Handle pause state from provider
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleProviderPauseState(provider.shouldPauseVideos);
        });

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth > 600 ||
                constraints.maxWidth > constraints.maxHeight;

            return GestureDetector(
              onTap: _togglePlay,
              child: Container(
                color: AppColors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Video Player
                    if (!isWide)
                      // Portrait: Full Screen Cover
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    else
                      // Landscape/Tablet: Centered AspectRatio
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),

                    // 2. Bottom Gradient
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

                    // 3. Play/Pause Icon Overlay
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

                    // 4. Video Meta Information
                    Positioned(
                      left: isWide ? 0 : 20,
                      right: isWide ? 0 : 80,
                      bottom: 60,
                      child: isWide
                          ? Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 600,
                                ),
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 80,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: _buildMetaContent(),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: _buildMetaContent(),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildMetaContent() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    ];
  }
}
