import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/providers/eye_exercise_provider.dart';
import '../../../core/providers/network_connectivity_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../widgets/video_reel_item.dart';
import '../widgets/youtube_popup_dialog.dart';
import '../../../core/widgets/eye_loader.dart';

class EyeExerciseReelsScreen extends StatefulWidget {
  const EyeExerciseReelsScreen({super.key});

  @override
  State<EyeExerciseReelsScreen> createState() => _EyeExerciseReelsScreenState();
}

class _EyeExerciseReelsScreenState extends State<EyeExerciseReelsScreen> {
  late PageController _pageController;
  int _videosWatched = 0;
  bool _isPopupShowing = false;
  bool _wasPopupDismissedManually = false;
  bool _showYouTubeHint = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Initialize provider data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EyeExerciseProvider>().initialize();

      // Check connectivity for Visiaxx TV
      final isOnline = Provider.of<NetworkConnectivityProvider>(
        context,
        listen: false,
      ).isOnline;
      if (!isOnline && mounted) {
        SnackbarUtils.showNoInternet(
          context,
          customMessage:
              'You are offline. Some features like Visiaxx TV (YouTube link) may not work.',
        );
      }
      _checkYouTubeHint();
    });
  }

  Future<void> _checkYouTubeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownHint = prefs.getBool('has_shown_youtube_hint') ?? false;
    if (!hasShownHint && mounted) {
      setState(() {
        _showYouTubeHint = true;
      });
      // Automatically hide after 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _showYouTubeHint) {
          _dismissHint();
        }
      });
    }
  }

  Future<void> _dismissHint() async {
    if (!_showYouTubeHint) return;
    if (mounted) {
      setState(() {
        _showYouTubeHint = false;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_shown_youtube_hint', true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Consumer<EyeExerciseProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return Container(
              color: AppColors.black,
              child: const Center(child: EyeLoader.fullScreen()),
            );
          }

          if (provider.videos.isEmpty) {
            return _buildEmptyState();
          }

          return Stack(
            children: [
              // PageView with videos
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: (index) {
                  provider.setCurrentIndex(index);
                  _onPageChanged(index);
                },
                itemCount: provider.videos.length,
                itemBuilder: (context, index) {
                  final video = provider.videos[index];
                  return VideoReelItem(
                    key: ValueKey(video.id),
                    video: video,
                    isActive: index == provider.currentIndex,
                    onVideoEnd: () => _handleVideoEnd(index),
                  );
                },
              ),

              // Top Controls Overlay
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.white,
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.black26,
                        ),
                      ),
                      _buildYouTubeButton(),
                    ],
                  ),
                ),
              ),

              // Progress Indicator (Reels style vertical indicator or page count)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 2,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.white12,
                      borderRadius: BorderRadius.circular(1),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          top:
                              (provider.currentIndex / provider.videos.length) *
                              100,
                          child: Container(
                            width: 2,
                            height: 100 / provider.videos.length,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onPageChanged(int index) {
    _videosWatched++;
    // Show popup every 5 videos watched if not dismissed manually
    if (_videosWatched % 5 == 0 && !_wasPopupDismissedManually) {
      _showYouTubePopup();
    }
  }

  void _handleVideoEnd(int index) {
    final provider = context.read<EyeExerciseProvider>();
    // Check if it's the last video
    if (index == provider.videos.length - 1) {
      _showYouTubePopup();
    }
  }

  void _showYouTubePopup() {
    if (_isPopupShowing || !mounted) return;

    _isPopupShowing = true;
    showDialog(
      context: context,
      builder: (_) => const YouTubePopupDialog(),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isPopupShowing = false;
          _wasPopupDismissedManually = true;
        });
      }
    });
  }

  Widget _buildYouTubeButton() {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          _dismissHint();
          showDialog(
            context: context,
            builder: (_) => const YouTubePopupDialog(),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.black26,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/1024px-YouTube_full-color_icon_%282017%29.svg.png',
                height: 16,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.play_circle_fill,
                    color: AppColors.error,
                    size: 16,
                  );
                },
              ),
              const SizedBox(width: 8),
              if (_showYouTubeHint)
                const Text(
                  'Click Me!',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                )
              else
                const Text(
                  'Visiaxx TV',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 64,
            color: AppColors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            'No exercises available',
            style: TextStyle(color: AppColors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Go Back',
              style: TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}
