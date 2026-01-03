/// Model for eye exercise videos
class ExerciseVideo {
  final String id;
  final String title;
  final String? description;
  final String videoPath; // Can be asset path or network URL
  final bool isAsset;
  final String? thumbnailPath;
  final Duration? duration;

  ExerciseVideo({
    required this.id,
    required this.title,
    this.description,
    required this.videoPath,
    this.isAsset = true,
    this.thumbnailPath,
    this.duration,
  });

  /// Check if video is from network
  bool get isNetworkVideo => !isAsset && videoPath.startsWith('http');

  /// Check if video is from assets
  bool get isAssetVideo => isAsset;

  factory ExerciseVideo.fromJson(Map<String, dynamic> json) {
    return ExerciseVideo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoPath: json['videoPath'] as String,
      isAsset: json['isAsset'] as bool? ?? true,
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'videoPath': videoPath,
      'isAsset': isAsset,
      'thumbnailPath': thumbnailPath,
      'duration': duration?.inSeconds,
    };
  }

  ExerciseVideo copyWith({
    String? id,
    String? title,
    String? description,
    String? videoPath,
    bool? isAsset,
    String? thumbnailPath,
    Duration? duration,
  }) {
    return ExerciseVideo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      videoPath: videoPath ?? this.videoPath,
      isAsset: isAsset ?? this.isAsset,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
    );
  }
}
