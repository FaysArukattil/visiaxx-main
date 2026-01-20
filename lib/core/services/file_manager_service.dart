import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

// Only import android_intent_plus on Android
import 'package:device_info_plus/device_info_plus.dart';

// Conditional import for Android
import 'package:android_intent_plus/android_intent.dart' as android_intent;
import 'package:android_intent_plus/flag.dart';

class FileManagerService {
  /// Opens the folder in the native file manager
  /// Returns true if successful, false otherwise
  static Future<bool> openFolder(String folderPath) async {
    try {
      if (Platform.isAndroid) {
        return await _openFolderAndroid(folderPath);
      } else if (Platform.isIOS) {
        return await _openFolderIOS(folderPath);
      }
      return false;
    } catch (e) {
      debugPrint('[FileManagerService] Error opening folder: $e');
      return false;
    }
  }

  /// Android-specific folder opening with multiple fallback strategies
  /// Android-specific folder opening with multiple fallback strategies
  static Future<bool> _openFolderAndroid(String folderPath) async {
    if (!Platform.isAndroid) return false;

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      debugPrint('[FileManagerService] Android SDK: $sdkInt');
      debugPrint('[FileManagerService] Opening folder: $folderPath');

      // Extract the folder name from the full path
      // e.g., /storage/emulated/0/Download/Visiaxx_Reports/All_Reports
      // We want to navigate to Download/Visiaxx_Reports/All_Reports
      String relativePath = '';
      if (folderPath.contains('/Download/')) {
        final parts = folderPath.split('/Download/');
        if (parts.length > 1) {
          relativePath = parts[1];
        }
      } else if (folderPath.contains('/Downloads/')) {
        final parts = folderPath.split('/Downloads/');
        if (parts.length > 1) {
          relativePath = parts[1];
        }
      }

      debugPrint('[FileManagerService] Relative path: $relativePath');

      // Strategy 1: Try to open the specific folder using DocumentsUI (Android 10+)
      if (sdkInt >= 29) {
        try {
          // Encode the full path for the URI
          final encodedPath = Uri.encodeComponent(
            relativePath.isNotEmpty ? relativePath : 'Visiaxx_Reports',
          );

          final intent = android_intent.AndroidIntent(
            action: 'android.intent.action.VIEW',
            data:
                'content://com.android.externalstorage.documents/document/primary:Download%2F$encodedPath',
            type: 'vnd.android.document/directory',
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_GRANT_READ_URI_PERMISSION,
            ],
          );

          await intent.launch();
          debugPrint(
            '[FileManagerService] Opened specific folder (DocumentsUI)',
          );
          return true;
        } catch (e) {
          debugPrint('[FileManagerService] DocumentsUI strategy failed: $e');
        }
      }

      // Strategy 2: Try opening Visiaxx_Reports parent folder
      if (sdkInt >= 29) {
        try {
          final intent = android_intent.AndroidIntent(
            action: 'android.intent.action.VIEW',
            data:
                'content://com.android.externalstorage.documents/document/primary:Download%2FVisiaxx_Reports',
            type: 'vnd.android.document/directory',
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_GRANT_READ_URI_PERMISSION,
            ],
          );

          await intent.launch();
          debugPrint('[FileManagerService] Opened Visiaxx_Reports folder');
          return true;
        } catch (e) {
          debugPrint(
            '[FileManagerService] Visiaxx_Reports folder open failed: $e',
          );
        }
      }

      // Strategy 3: Use file:// URI for Android 10+ with SAF (Storage Access Framework)
      if (sdkInt >= 29) {
        try {
          final intent = android_intent.AndroidIntent(
            action: 'android.intent.action.VIEW',
            data:
                'content://com.android.externalstorage.documents/tree/primary:Download%2FVisiaxx_Reports',
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_GRANT_READ_URI_PERMISSION,
              Flag.FLAG_GRANT_WRITE_URI_PERMISSION,
            ],
          );

          await intent.launch();
          debugPrint('[FileManagerService] Opened with tree URI');
          return true;
        } catch (e) {
          debugPrint('[FileManagerService] Tree URI strategy failed: $e');
        }
      }

      // Strategy 4: Open Downloads folder (fallback)
      if (sdkInt >= 29) {
        try {
          final intent = android_intent.AndroidIntent(
            action: 'android.intent.action.VIEW',
            data:
                'content://com.android.externalstorage.documents/document/primary:Download',
            type: 'vnd.android.document/directory',
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_GRANT_READ_URI_PERMISSION,
            ],
          );

          await intent.launch();
          debugPrint('[FileManagerService] Opened Downloads folder (fallback)');
          return true;
        } catch (e) {
          debugPrint('[FileManagerService] Downloads folder open failed: $e');
        }
      }

      // Strategy 5: Open Files app
      try {
        final intent = android_intent.AndroidIntent(
          action: 'android.intent.action.VIEW',
          type: 'resource/folder',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint('[FileManagerService] Opened Files app');
        return true;
      } catch (e) {
        debugPrint('[FileManagerService] Files app open failed: $e');
      }

      // Strategy 6: Launch DocumentsUI directly
      try {
        final intent = android_intent.AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'com.android.documentsui',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint('[FileManagerService] Launched DocumentsUI');
        return true;
      } catch (e) {
        debugPrint('[FileManagerService] DocumentsUI launch failed: $e');
      }

      // Strategy 7: Try Google Files app
      try {
        final intent = android_intent.AndroidIntent(
          action: 'android.intent.action.VIEW',
          package: 'com.google.android.apps.nbu.files',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint('[FileManagerService] Launched Google Files');
        return true;
      } catch (e) {
        debugPrint('[FileManagerService] Google Files launch failed: $e');
      }

      debugPrint('[FileManagerService] All strategies failed');
      return false;
    } catch (e) {
      debugPrint('[FileManagerService] Android folder open error: $e');
      return false;
    }
  }

  /// iOS-specific folder opening
  static Future<bool> _openFolderIOS(String folderPath) async {
    if (!Platform.isIOS) return false;

    try {
      // iOS doesn't support direct folder opening
      // Extract relative path for better user guidance
      String relativePath = 'visiaxx';
      if (folderPath.contains('Documents')) {
        final parts = folderPath.split('/');
        final docsIndex = parts.indexOf('Documents');
        if (docsIndex >= 0 && docsIndex < parts.length - 1) {
          relativePath = parts.sublist(docsIndex + 1).join('/');
        }
      }

      await Share.share(
        '📁 Visiaxx Reports Saved\n\n'
        '✅ $relativePath\n\n'
        'To view your reports:\n'
        '1. Open the Files app\n'
        '2. Tap "On My iPhone"\n'
        '3. Navigate to: $relativePath\n\n'
        'Full path:\n$folderPath',
        subject: 'Visiaxx Reports Location',
      );

      debugPrint('[FileManagerService] iOS share succeeded');
      return true;
    } catch (e) {
      debugPrint('[FileManagerService] iOS folder open failed: $e');
      return false;
    }
  }

  /// Gets the appropriate download directory based on platform
  static Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      try {
        // Try standard Download directory
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          debugPrint('[FileManagerService] Using Download directory');
          return dir;
        }

        // Fallback to Downloads (some devices use this)
        final altDir = Directory('/storage/emulated/0/Downloads');
        if (await altDir.exists()) {
          debugPrint('[FileManagerService] Using Downloads directory');
          return altDir;
        }
      } catch (e) {
        debugPrint('[FileManagerService] Error accessing Downloads: $e');
      }

      // Last resort for Android: external storage directory
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          debugPrint('[FileManagerService] Using external storage');
          return externalDir;
        }
      } catch (e) {
        debugPrint('[FileManagerService] Error accessing external storage: $e');
      }

      // Absolute last resort
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      // iOS uses app documents directory
      debugPrint('[FileManagerService] Using iOS documents directory');
      return await getApplicationDocumentsDirectory();
    }

    return await getApplicationDocumentsDirectory();
  }

  /// Shows a user-friendly dialog with folder location
  static Future<void> showFolderPathDialog(
    BuildContext context,
    String folderPath,
    int fileCount,
  ) async {
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Platform.isIOS ? Icons.folder_outlined : Icons.folder_open,
              color: theme.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Files Saved', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$fileCount PDF${fileCount > 1 ? 's' : ''} saved!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Saved Location:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.folder, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        folderPath,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (Platform.isAndroid) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Open Files app → Downloads → Visiaxx_Reports',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Files app → On My iPhone → visiaxx',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              if (Platform.isAndroid) {
                final success = await openFolder(folderPath);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please open Files app → Downloads → Visiaxx_Reports',
                      ),
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              } else {
                await Share.share(
                  'Visiaxx Reports:\n$folderPath\n\n'
                  'Open Files app → On My iPhone → visiaxx',
                );
              }
            },
            icon: Icon(
              Platform.isIOS ? Icons.share : Icons.folder_open,
              size: 18,
            ),
            label: Text(Platform.isIOS ? 'Share' : 'Open'),
          ),
        ],
      ),
    );
  }
}
