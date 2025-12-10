import 'package:flutter/material.dart';

/// Language selector widget
class LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final Function(String) onLanguageChanged;

  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'hi', 'name': 'हिन्दी'},
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedLanguage,
      icon: const Icon(Icons.language),
      underline: Container(),
      items: languages.map((lang) {
        return DropdownMenuItem<String>(
          value: lang['code'],
          child: Row(
            children: [
              const Icon(Icons.language, size: 20),
              const SizedBox(width: 8),
              Text(lang['name']!),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onLanguageChanged(value);
        }
      },
    );
  }
}
