import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for uploading and managing images in Firebase Storage
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image to Firebase Storage
  /// Returns the download URL
  Future<String?> uploadImage({
    required String userId,
    required String fileName,
    required File imageFile,
    String folder = 'test_results',
  }) async {
    try {
      // Create path: {folder}/{userId}/{fileName}
      final storageRef = _storage.ref().child('$folder/$userId/$fileName');

      // Upload file
      final uploadTask = await storageRef.putFile(imageFile);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      if (e.toString().contains('billing') || e.toString().contains('quota')) {
        print(
          '[FirebaseStorageService] ⚠️ Firebase Storage quota exceeded or billing required. Working in offline mode.',
        );
      } else {
        print('[FirebaseStorageService] Error uploading image: $e');
      }
      return null;
    }
  }

  /// Compatibility method for existing code
  Future<String?> uploadAmslerGridImage({
    required String userId,
    required String testId,
    required String eye,
    required File imageFile,
  }) async {
    return uploadImage(
      userId: userId,
      fileName: 'amsler_${testId}_$eye.png',
      imageFile: imageFile,
      folder: 'amsler_grids',
    );
  }

  /// Download image from Firebase Storage URL to local temp file
  /// Returns the local file path
  Future<File?> downloadImageFromUrl(String firebaseUrl) async {
    try {
      // Create temp file
      final tempDir = Directory.systemTemp;
      final fileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');

      // Get reference from URL
      final ref = _storage.refFromURL(firebaseUrl);

      // Download to temp file
      await ref.writeToFile(tempFile);

      return tempFile;
    } catch (e) {
      print('[FirebaseStorageService] Error downloading image: $e');
      return null;
    }
  }

  /// Delete Amsler grid images for a specific test
  Future<bool> deleteAmslerGridImages({
    required String userId,
    required String testId,
  }) async {
    try {
      final folderRef = _storage.ref().child('amsler_grids/$userId/$testId');

      // List all files in the folder
      final listResult = await folderRef.listAll();

      // Delete each file
      for (final item in listResult.items) {
        await item.delete();
      }

      return true;
    } catch (e) {
      print('[FirebaseStorageService] Error deleting images: $e');
      return false;
    }
  }

  /// Check if user is within storage limits (free tier: 5GB total, 1GB/day downloads)
  /// Note: This is a basic check - actual limits are enforced by Firebase
  Future<bool> canUploadImage(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      // Amsler images should be small (typically < 500KB)
      // Warn if larger than 1MB
      if (fileSize > 1024 * 1024) {
        print('[FirebaseStorageService] Warning: Image larger than 1MB');
      }
      return true;
    } catch (e) {
      print('[FirebaseStorageService] Error checking file size: $e');
      return false;
    }
  }
}
