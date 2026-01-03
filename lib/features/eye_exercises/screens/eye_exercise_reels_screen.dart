import 'package:flutter/material.dart';
import '../../../core/constants/exercise_videos.dart';
import '../models/exercise_video_model.dart';
import '../widgets/video_reel_item.dart';
import '../widgets/youtube_popup_dialog.dart';

/// Instagram/TikTok-like reels screen for eye exercises
class EyeExerciseReelsScreen extends StatefulWidget {
  const EyeExerciseReelsScreen({super.key});

  @override
  State<EyeExerciseReelsScreen> createState() => _EyeExerciseReelsScreenState();
}

class _EyeExerciseReelsScreenState extends State<EyeExerciseReelsScreen> {
  late PageController _pageController;
  late List<ExerciseVideo> _videos;
  int _currentIndex = 0;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadVideos();
  }

  void _loadVideos() {
    // Get shuffled videos for random order each time
    _videos = ExerciseVideos.getShuffledVideos();

    if (_videos.isEmpty) {
      debugPrint('Warning: No exercise videos found!');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isScrolling = false;
    });
  }

  void _onVideoEnd() {
    // Auto-advance to next video when current video ends
    if (_currentIndex < _videos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showYouTubePopup() {
    showDialog(
      context: context,
      builder: (context) => const YouTubePopupDialog(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.video_library_outlined,
                  size: 80,
                  color: Colors.white54,
                ),
                const SizedBox(height: 24),
                const Text(
                  'No exercise videos available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check back soon for eye exercises!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Video reels
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              return VideoReelItem(
                video: _videos[index],
                isActive: index == _currentIndex && !_isScrolling,
                onVideoEnd: _onVideoEnd,
              );
            },
          ),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top bar with back button and YouTube button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),

                  // YouTube button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showYouTubePopup,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF0000),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'YouTube',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Video counter indicator
          Positioned(
            top: 80,
            right: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_videos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
