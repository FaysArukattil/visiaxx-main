import 'dart:ui';

/// Amsler grid test result model for a single eye
class AmslerGridResult {
  final String eye; // 'right' or 'left'
  final bool hasDistortions;
  final bool hasMissingAreas;
  final bool hasBlurryAreas;
  final List<DistortionPoint> distortionPoints;
  final String status;
  final String? annotatedImagePath;
  final String? description;

  AmslerGridResult({
    required this.eye,
    required this.hasDistortions,
    required this.hasMissingAreas,
    required this.hasBlurryAreas,
    required this.distortionPoints,
    required this.status,
    this.annotatedImagePath, // This will store the captured image path
    this.description,
  });

  AmslerGridResult copyWith({
    String? eye,
    bool? hasDistortions,
    bool? hasMissingAreas,
    bool? hasBlurryAreas,
    List<DistortionPoint>? distortionPoints,
    String? status,
    String? annotatedImagePath,
    String? description,
  }) {
    return AmslerGridResult(
      eye: eye ?? this.eye,
      hasDistortions: hasDistortions ?? this.hasDistortions,
      hasMissingAreas: hasMissingAreas ?? this.hasMissingAreas,
      hasBlurryAreas: hasBlurryAreas ?? this.hasBlurryAreas,
      distortionPoints: distortionPoints ?? this.distortionPoints,
      status: status ?? this.status,
      annotatedImagePath: annotatedImagePath ?? this.annotatedImagePath,
      description: description ?? this.description,
    );
  }

  factory AmslerGridResult.fromMap(Map<String, dynamic> data) {
    return AmslerGridResult(
      eye: data['eye'] ?? '',
      hasDistortions: data['hasDistortions'] ?? false,
      hasMissingAreas: data['hasMissingAreas'] ?? false,
      hasBlurryAreas: data['hasBlurryAreas'] ?? false,
      distortionPoints:
          (data['distortionPoints'] as List<dynamic>?)
              ?.map((e) => DistortionPoint.fromMap(e))
              .toList() ??
          [],
      status: data['status'] ?? '',
      annotatedImagePath: data['annotatedImagePath'],
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eye': eye,
      'hasDistortions': hasDistortions,
      'hasMissingAreas': hasMissingAreas,
      'hasBlurryAreas': hasBlurryAreas,
      'distortionPoints': distortionPoints.map((e) => e.toMap()).toList(),
      'status': status,
      'annotatedImagePath': annotatedImagePath,
      'description': description,
    };
  }

  bool get isNormal => !hasDistortions && !hasMissingAreas && !hasBlurryAreas;

  bool get needsAttention =>
      hasDistortions || hasMissingAreas || hasBlurryAreas;

  String get resultSummary {
    if (isNormal) {
      return 'No distortions detected';
    }

    List<String> issues = [];
    if (hasDistortions) issues.add('wavy/distorted lines');
    if (hasMissingAreas) issues.add('missing areas');
    if (hasBlurryAreas) issues.add('blurry areas');

    return 'Detected: ${issues.join(', ')}';
  }

  String get clinicalSignificance {
    if (isNormal) {
      return 'The Amsler grid test shows no signs of macular changes.';
    }
    return 'The Amsler grid test detected potential macular changes. '
        'This may indicate conditions such as macular degeneration or other '
        'retinal disorders. A comprehensive eye examination is recommended.';
  }
}

/// Represents a point marked as distortion on the Amsler grid
class DistortionPoint {
  final double x;
  final double y;
  final String type; // 'distortion', 'missing', 'blurry'
  final double radius;
  final bool isStrokeStart;

  DistortionPoint({
    required this.x,
    required this.y,
    required this.type,
    this.radius = 10.0,
    this.isStrokeStart = false,
  });

  factory DistortionPoint.fromMap(Map<String, dynamic> data) {
    return DistortionPoint(
      x: (data['x'] ?? 0.0).toDouble(),
      y: (data['y'] ?? 0.0).toDouble(),
      type: data['type'] ?? 'distortion',
      radius: (data['radius'] ?? 10.0).toDouble(),
      isStrokeStart: data['isStrokeStart'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'type': type,
      'radius': radius,
      'isStrokeStart': isStrokeStart,
    };
  }

  Offset get offset => Offset(x, y);
}
