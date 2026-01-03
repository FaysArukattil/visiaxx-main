import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/eye_exercise_provider.dart';
import '../widgets/video_reel_item.dart';
import '../widgets/youtube_popup_dialog.dart';

class EyeExerciseReelsScreen extends StatefulWidget {
  const EyeExerciseReelsScreen({super.key});

  @override
  State<EyeExerciseReelsScreen> createState() => _EyeExerciseReelsScreenState();
}

class _EyeExerciseReelsScreenState extends State<EyeExerciseReelsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Initialize provider data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EyeExerciseProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<EyeExerciseProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
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
                },
                itemCount: provider.videos.length,
                itemBuilder: (context, index) {
                  final video = provider.videos[index];
                  return VideoReelItem(
                    key: ValueKey(video.id),
                    video: video,
                    isActive: index == provider.currentIndex,
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
                          color: Colors.white,
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black26,
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
                      color: Colors.white12,
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
                            color: Colors.white,
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

  Widget _buildYouTubeButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (_) => const YouTubePopupDialog(),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/1024px-YouTube_full-color_icon_%282017%29.svg.png',
                height: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Visiaxx TV',
                style: TextStyle(
                  color: Colors.white,
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
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            'No exercises available',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
