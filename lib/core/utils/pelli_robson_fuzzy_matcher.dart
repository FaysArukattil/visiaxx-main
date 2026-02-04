/// Pelli-Robson Speech Recognition Fuzzy Matcher
/// Handles phonetic alternatives and adaptive learning for reliable letter recognition
library;

import 'dart:math';

/// Fuzzy matching utility for Pelli-Robson letter recognition
class PelliRobsonFuzzyMatcher {
  /// Phonetic alternatives for each letter in the test
  /// Maps letter to list of acceptable pronunciations/mishearings
  static const Map<String, List<String>> phoneticAlternatives = {
    'V': ['V', 'B', 'P', 'BEE', 'VEE', 'PEE', 'BE', 'WE', 'VE'],
    'R': ['R', 'AR', 'ARE', 'ARR', 'OR', 'ER', 'AH'],
    'S': ['S', 'ES', 'ESS', 'C', 'SEE', 'ASS', 'AS'],
    'K': ['K', 'KAY', 'C', 'CAY', 'KEY', 'KE', 'CA'],
    'D': ['D', 'DEE', 'T', 'B', 'TE', 'DE', 'DI', 'TI'],
    'N': ['N', 'EN', 'M', 'EM', 'AN', 'NE', 'IN', 'AND'],
    'H': ['H', 'AITCH', 'EIGHT', 'A', 'AGE', 'AH', 'HE', 'HA', 'ACH'],
    'C': ['C', 'SEE', 'K', 'S', 'SI', 'KE', 'CE'],
    'O': ['O', 'OH', 'ZERO', '0', 'OW', 'AW', 'OU'],
    'Z': ['Z', 'ZED', 'ZEE', 'S', 'ZE', 'SET', 'ZEA'],
  };

  /// User-learned patterns during the test
  /// Maps what user says to which letter they mean
  final Map<String, String> learnedPatterns = {};

  /// Record what the user said for a letter and update patterns
  void recordPattern(String heardWord, String expectedLetter) {
    final normalized = _normalize(heardWord);
    if (normalized.isNotEmpty && expectedLetter.isNotEmpty) {
      learnedPatterns[normalized] = expectedLetter.toUpperCase();
    }
  }

  /// Check if a heard word matches a target letter
  bool matchesLetter(String heardWord, String targetLetter) {
    final normalized = _normalize(heardWord);
    final target = targetLetter.toUpperCase();

    // 1. Check exact match
    if (normalized == target) return true;

    // 2. Check learned patterns
    if (learnedPatterns[normalized] == target) return true;

    // 3. Check phonetic alternatives
    final alternatives = phoneticAlternatives[target];
    if (alternatives != null) {
      for (final alt in alternatives) {
        if (normalized == alt) {
          return true;
        }
      }
    }

    // 4. Check Levenshtein distance (‰¤ 2 is acceptable for longer words)
    if (normalized.length > 1 && target.length > 1) {
      final distance = _levenshteinDistance(normalized, target);
      if (distance <= 2) return true;
    }

    return false;
  }

  /// Count how many letters in a triplet were correctly identified
  /// Returns (correctCount, matchesLetters)
  ({int count, List<bool> matches}) matchTriplet(
    String heardPhrase,
    String expectedTriplet,
  ) {
    final normalized = _normalize(heardPhrase);
    final letters = expectedTriplet.toUpperCase().split('');
    final matches = <bool>[false, false, false];

    // 1. HOLISTIC MATCH: Check if the entire normalized phrase matches the triplet
    if (normalized == expectedTriplet.toUpperCase()) {
      return (count: 3, matches: [true, true, true]);
    }

    // 2. PARTIAL EXTRACTION: Try to extract individual words/letters from the heard phrase
    final heardParts = _extractLettersFromPhrase(normalized);

    // Match each expected letter
    for (int i = 0; i < letters.length && i < 3; i++) {
      final expectedLetter = letters[i];

      // Check if any heard part matches this letter
      for (final part in heardParts) {
        if (matchesLetter(part, expectedLetter)) {
          matches[i] = true;
          // Record successful pattern for learning
          recordPattern(part, expectedLetter);
          break;
        }
      }
    }

    return (count: matches.where((m) => m).length, matches: matches);
  }

  /// Check if triplet is accepted (at least 2 of 3 letters correct)
  bool acceptTriplet(String heardPhrase, String expectedTriplet) {
    final result = matchTriplet(heardPhrase, expectedTriplet);
    return result.count >= 2;
  }

  /// Extract individual letter sounds from a phrase
  List<String> _extractLettersFromPhrase(String phrase) {
    // Split by spaces and common separators
    final parts = phrase
        .replaceAll(RegExp(r'[,.\-!?]'), ' ')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    // For Pelli-Robson, we always want to check individual letters
    // especially for combined speech like "VRS"
    if (phrase.length <= 10) {
      final chars = phrase.split('').where((c) => c.trim().isNotEmpty).toList();
      parts.addAll(chars);
    }

    return parts;
  }

  /// Normalize input for comparison
  String _normalize(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Reset learned patterns (call when starting new test)
  void reset() {
    learnedPatterns.clear();
  }

  /// Get debug info about current learned patterns
  String get debugInfo =>
      'Learned patterns: ${learnedPatterns.entries.map((e) => '${e.key}†’${e.value}').join(', ')}';
}
