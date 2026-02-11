import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import 'aws_credentials_manager.dart';

/// AWS S3 Storage Service for uploading and downloading test results
/// Uses Minio client which is S3-compatible
class AWSS3StorageService {
  Minio? _client;

  /// Check if AWS S3 is available
  bool get isAvailable {
    _initializeClient(); // Attempt to initialize if not already
    final configured = AWSCredentials.isConfigured;
    if (!configured) {
      debugPrint(
        '[AWS S3]  ï¸ isAvailable: FALSE (Credentials not configured)',
      );
    }
    // Removed: if (_client == null) { debugPrint('[AWS S3] Œ isAvailable: FALSE (Client is NULL)'); }
    return _client != null && configured;
  }

  /// Initialize S3 client
  void _initializeClient() {
    // If client exists AND bucket is current, return
    if (_client != null) return;

    if (!AWSCredentials.isConfigured) {
      debugPrint('[AWS S3] ”„ Waiting for credentials to initialize Minio...');
      return;
    }

    try {
      debugPrint('[AWS S3] ™ï¸ Configuring Minio with credentials...');
      _client = Minio(
        endPoint: 's3.${AWSCredentials.region}.amazonaws.com',
        accessKey: AWSCredentials.accessKeyId,
        secretKey: AWSCredentials.secretAccessKey,
        useSSL: true,
        region: AWSCredentials.region,
      );
      debugPrint('[AWS S3] … Minio client initialized');
    } catch (e) {
      debugPrint('[AWS S3] Œ Minio initialization error: $e');
      _client = null;
    }
  }

  /// Upload PDF report to S3
  /// Returns the public URL or null if failed
  Future<String?> uploadPdfReport({
    required String userId,
    required String identityString,
    required String roleCollection,
    required String testCategory,
    required String testId,
    required File pdfFile,
    String? memberIdentityString, // Optional for family members
  }) async {
    if (!isAvailable) {
      debugPrint('[AWS S3] Service not available, skipping upload');
      return null;
    }

    try {
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final fileName = pdfFile.path.split(Platform.pathSeparator).last;

      // New organized path: Role/IdentityString/[members/MemberIdentity/]?Date/Category/Reports/FileName
      String basePath = '$roleCollection/$identityString';
      if (memberIdentityString != null && memberIdentityString.isNotEmpty) {
        basePath += '/members/$memberIdentityString';
      }

      final objectName = '$basePath/$dateStr/$testCategory/reports/$fileName';
      final bucket = AWSCredentials.bucketName;

      debugPrint('[AWS S3] “„ PDF UPLOAD START:');
      debugPrint('   Bucket: $bucket');
      debugPrint('   Path: $objectName');
      debugPrint('   File: ${pdfFile.path}');

      if (!await pdfFile.exists()) {
        debugPrint('[AWS S3] Œ ERROR: PDF File does not exist at path');
        return null;
      }

      // Read file bytes
      final bytes = await pdfFile.readAsBytes();
      debugPrint('   Size: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        debugPrint('[AWS S3] Œ ERROR: PDF File is empty');
        return null;
      }

      final stream = Stream.value(bytes);

      // Upload to S3 with timeout
      await _client!
          .putObject(
            bucket,
            objectName,
            stream,
            size: bytes.length,
            metadata: {
              'Content-Type': 'application/pdf',
              'user-id': userId,
              'test-id': testId,
              'upload-date': DateTime.now().toIso8601String(),
            },
          )
          .timeout(const Duration(seconds: 15));

      // Generate public URL
      final url = await getPresignedUrl(objectName);

      debugPrint('[AWS S3] … PDF UPLOAD SUCCESS: $url');
      return url;
    } on SocketException {
      debugPrint('[AWS S3] Œ Network error: No internet connection');
      return null;
    } on TimeoutException {
      debugPrint('[AWS S3] Œ Network timeout during PDF upload');
      return null;
    } catch (e) {
      if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection')) {
        debugPrint('[AWS S3] Œ Network-related error during PDF upload: $e');
      } else {
        debugPrint('[AWS S3] Œ PDF Upload failed: $e');
      }
      return null;
    }
  }

  /// Upload Amsler Grid image to S3
  /// Returns the public URL or null if failed
  Future<String?> uploadAmslerGridImage({
    required String userId,
    required String identityString,
    required String roleCollection,
    required String testCategory,
    required String testId,
    required String eye, // 'right' or 'left'
    required File imageFile,
    String? memberIdentityString, // Optional for family members
  }) async {
    if (!isAvailable) {
      debugPrint('[AWS S3] Service not available, skipping upload');
      return null;
    }

    try {
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'amsler_${testId}_$eye.png';

      // New organized path: Role/IdentityString/[members/MemberIdentity/]?Date/Category/Images/FileName
      String basePath = '$roleCollection/$identityString';
      if (memberIdentityString != null && memberIdentityString.isNotEmpty) {
        basePath += '/members/$memberIdentityString';
      }

      final objectName = '$basePath/$dateStr/$testCategory/images/$fileName';
      final bucket = AWSCredentials.bucketName;

      debugPrint('[AWS S3] –¼ï¸ IMAGE UPLOAD START:');
      debugPrint('   Bucket: $bucket');
      debugPrint('   Path: $objectName');
      debugPrint('   File: ${imageFile.path}');

      if (!await imageFile.exists()) {
        debugPrint('[AWS S3] Œ ERROR: Image file missing');
        return null;
      }

      // Read file bytes
      final bytes = await imageFile.readAsBytes();
      debugPrint('   Size: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        debugPrint('[AWS S3] Œ ERROR: Image file is empty');
        return null;
      }

      final stream = Stream.value(bytes);

      // Upload to S3 with timeout
      await _client!
          .putObject(
            bucket,
            objectName,
            stream,
            size: bytes.length,
            metadata: {
              'Content-Type': 'image/png',
              'user-id': userId,
              'test-id': testId,
              'eye': eye,
              'upload-date': DateTime.now().toIso8601String(),
            },
          )
          .timeout(const Duration(seconds: 10));

      // Generate public URL (with presigned URL for private buckets)
      final url = await getPresignedUrl(objectName);

      debugPrint('[AWS S3] … IMAGE UPLOAD SUCCESS: $url');
      return url;
    } on SocketException {
      debugPrint('[AWS S3] Œ Network error: No internet connection');
      return null;
    } on TimeoutException {
      debugPrint('[AWS S3] Œ Network timeout during image upload');
      return null;
    } catch (e) {
      if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection')) {
        debugPrint('[AWS S3] Œ Network-related error during image upload: $e');
      } else {
        debugPrint('[AWS S3] Œ Upload failed: $e');
      }
      return null;
    }
  }

  /// Upload Shadow Test image to S3
  Future<String?> uploadShadowTestImage({
    required String userId,
    required String identityString,
    required String roleCollection,
    required String testCategory,
    required String testId,
    required String eye, // 'right' or 'left'
    required File imageFile,
    String? memberIdentityString, // Optional for family members
  }) async {
    if (!isAvailable) {
      debugPrint('[AWS S3] Service not available, skipping upload');
      return null;
    }

    try {
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'shadow_${testId}_$eye.png';

      String basePath = '$roleCollection/$identityString';
      if (memberIdentityString != null && memberIdentityString.isNotEmpty) {
        basePath += '/members/$memberIdentityString';
      }

      final objectName = '$basePath/$dateStr/$testCategory/images/$fileName';
      final bucket = AWSCredentials.bucketName;

      debugPrint('[AWS S3] –¼ï¸  SHADOW IMAGE UPLOAD START:');
      if (!await imageFile.exists()) {
        debugPrint('[AWS S3]  Œ ERROR: Image file missing');
        return null;
      }

      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('[AWS S3]  Œ ERROR: Image file is empty');
        return null;
      }

      final stream = Stream.value(bytes);

      await _client!
          .putObject(
            bucket,
            objectName,
            stream,
            size: bytes.length,
            metadata: {
              'Content-Type': 'image/png',
              'user-id': userId,
              'test-id': testId,
              'eye': eye,
              'test-type': 'shadow_test',
              'upload-date': DateTime.now().toIso8601String(),
            },
          )
          .timeout(const Duration(seconds: 10));

      final url = await getPresignedUrl(objectName);
      debugPrint('[AWS S3] … SHADOW IMAGE UPLOAD SUCCESS: $url');
      return url;
    } catch (e) {
      debugPrint('[AWS S3]  Œ Shadow Image Upload failed: $e');
      return null;
    }
  }

  /// Upload Cover Test Video to S3
  Future<String?> uploadCoverTestVideo({
    required String userId,
    required String identityString,
    required String roleCollection,
    required String testCategory,
    required String testId,
    required String phase, // e.g. 'cover_right'
    required File videoFile,
    String? memberIdentityString,
  }) async {
    if (!isAvailable) {
      debugPrint('[AWS S3] Service not available, skipping upload');
      return null;
    }

    try {
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'cover_${testId}_$phase.mp4';

      String basePath = '$roleCollection/$identityString';
      if (memberIdentityString != null && memberIdentityString.isNotEmpty) {
        basePath += '/members/$memberIdentityString';
      }

      final objectName = '$basePath/$dateStr/$testCategory/videos/$fileName';
      final bucket = AWSCredentials.bucketName;

      debugPrint('[AWS S3] 🎥 VIDEO UPLOAD START:');
      if (!await videoFile.exists()) {
        debugPrint('[AWS S3] ❌ ERROR: Video file missing at ${videoFile.path}');
        return null;
      }

      final bytes = await videoFile.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('[AWS S3] ❌ ERROR: Video file is empty');
        return null;
      }

      final stream = Stream.value(bytes);

      await _client!
          .putObject(
            bucket,
            objectName,
            stream,
            size: bytes.length,
            metadata: {
              'Content-Type': 'video/mp4',
              'user-id': userId,
              'test-id': testId,
              'phase': phase,
              'test-type': 'cover_test',
              'upload-date': DateTime.now().toIso8601String(),
            },
          )
          .timeout(const Duration(seconds: 30)); // Longer timeout for video

      final url = await getPresignedUrl(objectName);
      debugPrint('[AWS S3] ✅ VIDEO UPLOAD SUCCESS: $url');
      return url;
    } catch (e) {
      debugPrint('[AWS S3] ❌ Video Upload failed: $e');
      return null;
    }
  }

  /// Upload general test result image
  Future<String?> uploadTestImage({
    required String userId,
    required String identityString,
    required String roleCollection,
    required String fileName,
    required File imageFile,
    Map<String, String>? metadata,
  }) async {
    if (!isAvailable) {
      debugPrint('[AWS S3] Service not available, skipping upload');
      return null;
    }

    try {
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final objectName =
          '$roleCollection/$identityString/$dateStr/images/$fileName';

      debugPrint('[AWS S3] Uploading to: $objectName');

      final bytes = await imageFile.readAsBytes();
      final stream = Stream.value(bytes);

      await _client!.putObject(
        AWSCredentials.bucketName,
        objectName,
        stream,
        size: bytes.length,
        metadata: {
          'Content-Type': 'image/png',
          'user-id': userId,
          ...?metadata,
        },
      );

      final url = await getPresignedUrl(objectName);

      debugPrint('[AWS S3] … Upload successful: $url');
      return url;
    } catch (e) {
      debugPrint('[AWS S3] Œ Upload failed: $e');
      return null;
    }
  }

  /// Download image from S3 to local file
  /// Returns the local file or null if failed
  Future<File?> downloadImage({
    required String s3Url,
    required String localFileName,
  }) async {
    if (!isAvailable) {
      debugPrint('[AWS S3] Service not available, skipping download');
      return null;
    }

    try {
      // Extract object name from URL
      final uri = Uri.parse(s3Url);
      final objectName = uri.path.substring(1); // Remove leading '/'

      debugPrint('[AWS S3] Downloading: $objectName');

      // Create temp file
      final tempDir = Directory.systemTemp;
      final localFile = File('${tempDir.path}/$localFileName');

      // Download from S3
      final stream = await _client!.getObject(
        AWSCredentials.bucketName,
        objectName,
      );

      // Write to local file
      final bytes = await stream.toList();
      final allBytes = bytes.expand((x) => x).toList();
      await localFile.writeAsBytes(allBytes);

      debugPrint('[AWS S3] … Download successful: ${localFile.path}');
      return localFile;
    } on SocketException {
      debugPrint('[AWS S3] Œ Network error: No internet connection');
      return null;
    } on TimeoutException {
      debugPrint('[AWS S3] Œ Network timeout during download');
      return null;
    } catch (e) {
      if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection')) {
        debugPrint('[AWS S3] Œ Network-related error during download: $e');
      } else {
        debugPrint('[AWS S3] Œ Download failed: $e');
      }
      return null;
    }
  }

  /// Generate a presigned URL for accessing private objects
  /// Valid for 7 days by default
  Future<String> getPresignedUrl(
    String objectName, {
    int expirySeconds = 604800, // 7 days
  }) async {
    try {
      final url = await _client!.presignedGetObject(
        AWSCredentials.bucketName,
        objectName,
        expires: expirySeconds,
      );
      return url;
    } catch (e) {
      debugPrint('[AWS S3] Œ Failed to generate presigned URL: $e');
      // Fallback to direct URL (works only if bucket is public)
      return '${AWSCredentials.bucketUrl}/$objectName';
    }
  }

  /// Delete an image from S3
  Future<bool> deleteImage(String objectName) async {
    if (!isAvailable) return false;

    try {
      await _client!.removeObject(AWSCredentials.bucketName, objectName);
      debugPrint('[AWS S3] … Deleted: $objectName');
      return true;
    } catch (e) {
      debugPrint('[AWS S3] Œ Delete failed: $e');
      return false;
    }
  }

  /// Delete all a Amsler grid images for a specific test
  Future<bool> deleteAmslerGridImages({
    required String identityString,
    required String roleCollection,
    required String testId,
  }) async {
    if (!isAvailable) return false;

    try {
      // Objects are stored under roleCollection/identityString/
      // We search recursively for any files matching the testId
      final prefix = '$roleCollection/$identityString/';

      final results = await _client!
          .listObjects(
            AWSCredentials.bucketName,
            prefix: prefix,
            recursive: true,
          )
          .toList();

      for (final result in results) {
        for (final obj in result.objects) {
          if (obj.key != null && obj.key!.contains(testId)) {
            await deleteImage(obj.key!);
          }
        }
      }

      debugPrint('[AWS S3] … Deleted all images for test: $testId');
      return true;
    } catch (e) {
      debugPrint('[AWS S3] Œ Batch delete failed: $e');
      return false;
    }
  }

  /// Check if image exists in S3
  Future<bool> imageExists(String objectName) async {
    if (!isAvailable) return false;

    try {
      await _client!.statObject(AWSCredentials.bucketName, objectName);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get image metadata
  Future<Map<String, String>?> getImageMetadata(String objectName) async {
    if (!isAvailable) return null;

    try {
      final stat = await _client!.statObject(
        AWSCredentials.bucketName,
        objectName,
      );
      // Convert Map<String, String?> to Map<String, String>
      final Map<String, String> metadata = {};
      stat.metaData?.forEach((key, value) {
        if (value != null) metadata[key] = value;
      });
      return metadata.isEmpty ? null : metadata;
    } catch (e) {
      debugPrint('[AWS S3] Œ Failed to get metadata: $e');
      return null;
    }
  }

  /// Test connection to S3
  Future<bool> testConnection() async {
    if (!isAvailable) return false;

    try {
      await _client!
          .bucketExists(AWSCredentials.bucketName)
          .timeout(const Duration(seconds: 5));
      debugPrint('[AWS S3] … Connection test successful');
      return true;
    } catch (e) {
      debugPrint('[AWS S3] Œ Connection test failed: $e');
      return false;
    }
  }
}
