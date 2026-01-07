import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'selected_language';

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मರಾଠી'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'or', 'name': 'Odia', 'native': 'ଓଡ଼ିଆ'},
  ];

  String _selectedLanguage = 'English';

  LocaleProvider() {
    _loadFromPrefs();
  }

  List<Map<String, String>> get languages => _languages;
  String get selectedLanguage => _selectedLanguage;

  Map<String, String> get currentLanguageData => _languages.firstWhere(
    (l) => l['name'] == _selectedLanguage,
    orElse: () => _languages.first,
  );

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLanguage = prefs.getString(_prefKey) ?? 'English';
    notifyListeners();
  }

  Future<void> setLanguage(String languageName) async {
    if (_selectedLanguage == languageName) return;

    _selectedLanguage = languageName;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageName);
  }
}
