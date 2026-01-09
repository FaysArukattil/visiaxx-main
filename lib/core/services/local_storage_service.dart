import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';

/// Service to handle local persistence for offline-first resilience
class LocalStorageService {
  static const String _userKey = 'current_user_profile';
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
}
