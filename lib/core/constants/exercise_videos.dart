import '../../../features/eye_exercises/models/exercise_video_model.dart';

/// Exercise video constants and data
class ExerciseVideos {
  ExerciseVideos._();

  /// YouTube channel URL
  static const String youtubeChannelUrl =
      'https://youtube.com/@nurturingvision?si=ZWkbxSVXpAunss7w';

  /// List of ALL 10 exercise videos (ASSET VIDEOS)
  /// Make sure these file names match your actual video files in assets/exercise_videos/
  static List<ExerciseVideo> getAssetVideos() {
    return [
      ExerciseVideo(
        id: 'ex_1',
        title: '7 Eye Disease Signs You Might Be Missing',
        description:
            "Don't ignore these! Learn the subtle signs that could save your vision.",
        videoPath: 'assets/exercise_videos/exercise_1.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_2',
        title: '5 Eye Disease Symptoms to Watch For',
        description:
            'Are you noticing these changes? 5 symptoms you should never ignore.',
        videoPath: 'assets/exercise_videos/exercise_2.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_3',
        title: 'Improve Your Eyesight Naturally',
        description:
            'Want better vision? 5 simple, effective tips to boost eye health from home.',
        videoPath: 'assets/exercise_videos/exercise_3.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_4',
        title: 'Near-Sighted or Far-Sighted?',
        description:
            "Can't see far or near? Learn the quick difference between the two.",
        videoPath: 'assets/exercise_videos/exercise_4.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_5',
        title: 'The Ultimate Eye Health Diet',
        description:
            'Fuel your sight! Eat these nutrient-rich superfoods for peak vision.',
        videoPath: 'assets/exercise_videos/exercise_5.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_6',
        title: 'Avoid These 3 Contact Lens Mistakes',
        description:
            'Protect your eyes from damage by avoiding these common lens errors.',
        videoPath: 'assets/exercise_videos/exercise_6.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_7',
        title: 'Quick Eye Relief Exercises',
        description:
            'Feeling digital eye strain? Try these instant relief hacks for tired eyes.',
        videoPath: 'assets/exercise_videos/exercise_7.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_8',
        title: 'Snack Your Way to Better Vision',
        description:
            'Boost your eye health with these simple and vision-friendly snack ideas.',
        videoPath: 'assets/exercise_videos/exercise_8.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_9',
        title: 'The Digital Warrior\'s Blue Light Guide',
        description:
            'Scrolling all day? Here is how to protect your eyes from harmful blue light.',
        videoPath: 'assets/exercise_videos/exercise_9.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_10',
        title: 'Simple Habits for Healthy Eyes',
        description:
            'It\'s easy to stay proactive! Follow these tips for lifelong healthy vision.',
        videoPath: 'assets/exercise_videos/exercise_10.mp4',
        isAsset: true,
      ),
    ];
  }

  /// Example: Network videos from Firebase Storage or any CDN
  /// You can use this in the future
  static List<ExerciseVideo> getNetworkVideos() {
    return [
      // Uncomment and add network videos when ready
      // ExerciseVideo(
      //   id: 'net_1',
      //   title: 'Advanced Eye Exercise',
      //   description: 'Advanced techniques for eye health',
      //   videoPath: 'https://your-storage-url.com/video1.mp4',
      //   isAsset: false,
      //   thumbnailPath: 'https://your-storage-url.com/thumbnail1.jpg',
      // ),
    ];
  }

  /// Get all videos (can mix asset and network)
  static List<ExerciseVideo> getAllVideos() {
    final videos = <ExerciseVideo>[];
    videos.addAll(getAssetVideos());
    // videos.addAll(getNetworkVideos()); // Uncomment when using network videos
    return videos;
  }

  /// Get shuffled videos for random order
  static List<ExerciseVideo> getShuffledVideos() {
    final videos = getAllVideos();
    videos.shuffle();
    return videos;
  }
}
