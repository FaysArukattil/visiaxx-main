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
        title: 'Eye Relaxation Exercise',
        description: 'Reduce eye strain with simple relaxation techniques',
        videoPath: 'assets/exercise_videos/exercise_1.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_2',
        title: 'Focus Shifting Exercise',
        description: 'Improve focus flexibility',
        videoPath: 'assets/exercise_videos/exercise_2.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_3',
        title: 'Eye Rotation Exercise',
        description: 'Strengthen eye muscles',
        videoPath: 'assets/exercise_videos/exercise_3.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_4',
        title: 'Blinking Exercise',
        description: 'Keep your eyes moisturized',
        videoPath: 'assets/exercise_videos/exercise_4.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_5',
        title: 'Near and Far Focus',
        description: 'Improve accommodation flexibility',
        videoPath: 'assets/exercise_videos/exercise_5.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_6',
        title: 'Figure 8 Exercise',
        description: 'Enhance eye muscle coordination',
        videoPath: 'assets/exercise_videos/exercise_6.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_7',
        title: 'Palming Exercise',
        description: 'Relax and soothe tired eyes',
        videoPath: 'assets/exercise_videos/exercise_7.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_8',
        title: 'Eye Rolling Exercise',
        description: 'Improve blood circulation',
        videoPath: 'assets/exercise_videos/exercise_8.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_9',
        title: 'Zooming Exercise',
        description: 'Strengthen focusing muscles',
        videoPath: 'assets/exercise_videos/exercise_9.mp4',
        isAsset: true,
      ),
      ExerciseVideo(
        id: 'ex_10',
        title: '20-20-20 Rule Exercise',
        description: 'Prevent digital eye strain',
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
