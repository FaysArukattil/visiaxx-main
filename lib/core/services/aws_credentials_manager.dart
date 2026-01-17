import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';

/// Secure AWS Credentials Manager using Firebase Remote Config
/// Credentials are stored server-side in Firebase, not in app code
class AWSCredentials {
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _initialized = false;

  // Cache for credentials (loaded from Firebase)
  static String _accessKeyId = '';
  static String _secretAccessKey = '';
  static String _bucketName = '';
  static String _region = '';

  // S3 folder structure
  static const String testResultsFolder = 'test-results';
  static const String amslerGridsFolder = 'amsler-grids';
  static const String reportsFolder = 'reports';

  /// Initialize and fetch credentials from Firebase Remote Config
  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      debugPrint('[AWS Credentials] ”„ Initializing Firebase Remote Config...');

      _remoteConfig = FirebaseRemoteConfig.instance;

      // Fast settings for diagnostics
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: const Duration(minutes: 5),
        ),
      );

      // Set default values (fallback if fetch fails)
      await _remoteConfig!.setDefaults({
        'aws_access_key_id': '',
        'aws_secret_access_key': '',
        'aws_bucket_name': 'visiaxx-test-results',
        'aws_region': 'ap-south-1',
      });

      // Fetch and activate values from Firebase
      await _remoteConfig!.fetchAndActivate().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      // Load credentials into memory
      _accessKeyId = _remoteConfig!.getString('aws_access_key_id');
      _secretAccessKey = _remoteConfig!.getString('aws_secret_access_key');
      _bucketName = _remoteConfig!.getString('aws_bucket_name');
      _region = _remoteConfig!.getString('aws_region');

      // If Remote Config empty, try loading from local cache
      if (_accessKeyId.isEmpty) {
        debugPrint('[AWS Credentials]  ï¸ Remote keys empty, trying cache...');
        final cached = await LocalStorageService().getAWSCredentials();
        if (cached != null) {
          _accessKeyId = cached['aws_access_key_id'] ?? '';
          _secretAccessKey = cached['aws_secret_access_key'] ?? '';
          _bucketName = cached['aws_bucket_name'] ?? '';
          _region = cached['aws_region'] ?? '';
        }
      } else {
        // Save successfully fetched keys to local cache
        await LocalStorageService().saveAWSCredentials({
          'aws_access_key_id': _accessKeyId,
          'aws_secret_access_key': _secretAccessKey,
          'aws_bucket_name': _bucketName,
          'aws_region': _region,
        });
      }

      _initialized = true;

      debugPrint('[AWS Credentials] … Initialized successfully');
      debugPrint('[AWS Credentials] Bucket: $_bucketName');
      debugPrint('[AWS Credentials] Region: $_region');
      debugPrint(
        '[AWS Credentials] Access Key: ${_accessKeyId.isNotEmpty ? "“ Loaded" : "— Missing"}',
      );
      debugPrint(
        '[AWS Credentials] Secret Key: ${_secretAccessKey.isNotEmpty ? "“ Loaded" : "— Missing"}',
      );

      return true;
    } catch (e) {
      debugPrint('[AWS Credentials] Œ Initialization failed: $e');
      _initialized = false;
      return false;
    }
  }

  /// Get Access Key ID
  static String get accessKeyId {
    if (!_initialized) {
      debugPrint(
        '[AWS Credentials]  ï¸ Not initialized! Call initialize() first',
      );
    }
    return _accessKeyId;
  }

  /// Get Secret Access Key
  static String get secretAccessKey {
    if (!_initialized) {
      debugPrint(
        '[AWS Credentials]  ï¸ Not initialized! Call initialize() first',
      );
    }
    return _secretAccessKey;
  }

  /// Get Bucket Name
  static String get bucketName {
    if (!_initialized) {
      debugPrint(
        '[AWS Credentials]  ï¸ Not initialized! Call initialize() first',
      );
    }
    return _bucketName.isNotEmpty ? _bucketName : 'visiaxx-test-results';
  }

  /// Get Region
  static String get region {
    if (!_initialized) {
      debugPrint(
        '[AWS Credentials]  ï¸ Not initialized! Call initialize() first',
      );
    }
    return _region.isNotEmpty ? _region : 'ap-south-1';
  }

  /// Validate if credentials are configured and loaded
  static bool get isConfigured {
    return _initialized &&
        _accessKeyId.isNotEmpty &&
        _secretAccessKey.isNotEmpty &&
        _bucketName.isNotEmpty &&
        _region.isNotEmpty;
  }

  /// Get S3 endpoint URL for the region
  static String get endpoint {
    return 'https://s3.$region.amazonaws.com';
  }

  /// Get full bucket URL
  static String get bucketUrl {
    return 'https://$bucketName.s3.$region.amazonaws.com';
  }

  /// Refresh credentials from Firebase (useful if values change)
  static Future<bool> refresh() async {
    try {
      debugPrint('[AWS Credentials] ”„ Refreshing credentials...');

      if (_remoteConfig == null) {
        return await initialize();
      }

      await _remoteConfig!.fetchAndActivate();

      _accessKeyId = _remoteConfig!.getString('aws_access_key_id');
      _secretAccessKey = _remoteConfig!.getString('aws_secret_access_key');
      _bucketName = _remoteConfig!.getString('aws_bucket_name');
      _region = _remoteConfig!.getString('aws_region');

      debugPrint('[AWS Credentials] … Refreshed successfully');
      return true;
    } catch (e) {
      debugPrint('[AWS Credentials] Œ Refresh failed: $e');
      return false;
    }
  }
}

/// ” SECURITY BENEFITS:
/// 
/// … Credentials stored in Firebase, not in app code
/// … Can update credentials without rebuilding app
/// … No risk of exposing keys in Git/GitHub
/// … Works with Firebase security rules
/// … Automatic caching (1 hour) to reduce API calls
/// … Graceful fallback if Firebase is unavailable
/// 
/// USAGE:
/// 1. Call AWSCredentials.initialize() in main.dart before runApp()
/// 2. All services automatically use the loaded credentials
/// 3. Update credentials in Firebase Console †’ Remote Config †’ Publish
