import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';

/// Service to handle local persistence for offline-first resilience
class LocalStorageService {
  static const String _userKey = 'current_user_profile';
  static const String _metadataPrefix = 'user_metadata_';
  static const String _awsKey = 'aws_credentials';
  static final LocalStorageService _instance = LocalStorageService._internal();

  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  /// Save user profile to local storage as JSON
  Future<void> saveUserProfile(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(user.toJson());
    await prefs.setString(_userKey, jsonString);
  }

  /// Get user profile from local storage
  Future<UserModel?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userKey);
    if (jsonString == null) return null;

    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return UserModel.fromJson(data);
    } catch (e) {
      debugPrint('[LocalStorage] Error decoding user: $e');
      return null;
    }
  }

  /// Clear local user data
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  /// Save user metadata (identityString and collection) for faster login lookup
  Future<void> saveUserMetadata(
    String uid,
    Map<String, String> metadata,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_metadataPrefix$uid', jsonEncode(metadata));
  }

  /// Get user metadata if it exists
  Future<Map<String, String>?> getUserMetadata(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_metadataPrefix$uid');
    if (jsonString == null) return null;
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return data.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return null;
    }
  }

  /// Save AWS credentials to local storage
  Future<void> saveAWSCredentials(Map<String, String> creds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_awsKey, jsonEncode(creds));
  }

  /// Get AWS credentials from local storage
  Future<Map<String, String>?> getAWSCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_awsKey);
    if (jsonString == null) return null;

    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      return data.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return null;
    }
  }

  // ─── Secure Credential Storage (for silent Firebase re-auth) ───

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _emailKey = 'visiaxx_auth_email';
  static const String _passwordKey = 'visiaxx_auth_password';

  /// Save login credentials securely for auto-login
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      debugPrint('[LocalStorage] ✅ Credentials saved securely');
    } catch (e) {
      debugPrint('[LocalStorage] ⚠️ Failed to save credentials: $e');
    }
  }

  /// Get stored credentials for silent re-authentication
  Future<Map<String, String>?> getCredentials() async {
    try {
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
      return null;
    } catch (e) {
      debugPrint('[LocalStorage] ⚠️ Failed to read credentials: $e');
      return null;
    }
  }

  /// Clear stored credentials (on logout or invalid credentials)
  Future<void> clearCredentials() async {
    try {
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _passwordKey);
      debugPrint('[LocalStorage] ✅ Credentials cleared');
    } catch (e) {
      debugPrint('[LocalStorage] ⚠️ Failed to clear credentials: $e');
    }
  }
}
