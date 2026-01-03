import '../../../features/eye_exercises/models/exercise_video_model.dart';

/// Exercise video constants and data
class ExerciseVideos {
  ExerciseVideos._();

  /// YouTube channel URL
  static const String youtubeChannelUrl =
      'https://youtube.com/@nurturingvision?si=ZWkbxSVXpAunss7w';

  /// List of exercise videos (ASSET VIDEOS)
  /// Replace these paths with your actual video file names
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
      // Add more videos as needed
    ];
  }

  /// Example: Network videos from Firebase Storage or any CDN
  /// You can use this in the future
  static List<ExerciseVideo> getNetworkVideos() {
    return [
      ExerciseVideo(
        id: 'net_1',
        title: 'Advanced Eye Exercise',
        description: 'Advanced techniques for eye health',
        videoPath: 'https://your-storage-url.com/video1.mp4',
        isAsset: false,
        thumbnailPath: 'https://your-storage-url.com/thumbnail1.jpg',
      ),
      // Add network videos when ready
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
