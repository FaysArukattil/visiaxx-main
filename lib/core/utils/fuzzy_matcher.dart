import 'package:string_similarity/string_similarity.dart';

class FuzzyMatcher {
  /// Match two strings with similarity threshold
  /// Returns similarity percentage (0-100)
  static double getSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    // Normalize: lowercase, remove punctuation, trim
    final normalized1 = _normalize(text1);
    final normalized2 = _normalize(text2);

    // Calculate similarity using Jaro-Winkler distance
    final similarity = normalized1.similarityTo(normalized2);

    return similarity * 100; // Convert to percentage
  }

  /// Check if similarity meets threshold (default 70%)
  static bool matches(String text1, String text2, {double threshold = 70.0}) {
    final similarity = getSimilarity(text1, text2);
    return similarity >= threshold;
  }

  /// Normalize text for comparison
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .trim();
  }

  /// Remove common instruction phrases from speech recognition result
  static String removeInstructions(String text) {
    if (text.isEmpty) return text;

    // Pattern to match "Level X. Read this sentence aloud" or similar
    // Longest/most specific first to avoid partial matches leaving scraps
    final instructionPatterns = [
      RegExp(r'please\s+read\s+this\s+sentence\s+aloud', caseSensitive: false),
      RegExp(r'please\s+read\s+the\s+sentence\s+aloud', caseSensitive: false),
      RegExp(r'read\s+this\s+sentence\s+aloud', caseSensitive: false),
      RegExp(r'read\s+the\s+sentence\s+aloud', caseSensitive: false),
      RegExp(r'please\s+read\s+this\s+sentence', caseSensitive: false),
      RegExp(r'read\s+this\s+sentence', caseSensitive: false),
      RegExp(r'please\s+read\s+this', caseSensitive: false),
      RegExp(r'read\s+this\s+aloud', caseSensitive: false),
      RegExp(r'sentence\s+aloud', caseSensitive: false),
      RegExp(r'read\s+aloud', caseSensitive: false),
      RegExp(r'level\s+\d+', caseSensitive: false),
    ];

    String cleanedText = text;
    for (final pattern in instructionPatterns) {
      cleanedText = cleanedText.replaceAll(pattern, '');
    }

    // Also remove leading/trailing noise and extra whitespace
    return cleanedText
        .replaceAll(RegExp(r'^\s*[\.,!?;:]+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// … NEW: Check if speech contains most/all important words of the target
  /// Useful for "Short Distance Reading" where users say extra words.
  static bool containsKeywords(
    String target,
    String actual, {
    double keywordThreshold = 0.7,
  }) {
    final targetWords = _normalize(
      target,
    ).split(' ').where((w) => w.length > 2).toSet();
    if (targetWords.isEmpty) return false;

    final actualWords = _normalize(actual).split(' ').toSet();

    int matchesCount = 0;
    for (final tWord in targetWords) {
      if (actualWords.contains(tWord)) {
        matchesCount++;
      } else {
        // Soft match for minor typos (e.g. "vision" vs "missions")
        for (final aWord in actualWords) {
          double similarity = aWord.similarityTo(tWord);

          // … SPECIAL CASE: "green" & "grass" often misheard
          if (tWord == 'green') {
            final greenVariants = [
              'grin',
              'grain',
              'grand',
              'great',
              'greene',
              'grim',
            ];
            if (greenVariants.contains(aWord)) similarity = 0.9;
          } else if (tWord == 'grass') {
            final grassVariants = ['glass', 'gras', 'gross', 'crass', 'grace'];
            if (grassVariants.contains(aWord)) similarity = 0.9;
          }

          if (similarity > 0.8) {
            matchesCount++;
            break;
          }
        }
      }
    }

    return (matchesCount / targetWords.length) >= keywordThreshold;
  }

  /// Convert spoken number words to digit strings (e.g., "eight" -> "8")
  static String? parseSpokenNumber(String text) {
    if (text.isEmpty) return null;
    final normalized = text.toLowerCase().trim();

    // Direct mapping for common numbers in Ishihara plates
    final numberMap = {
      'zero': '0',
      'nothing': 'nothing',
      'none': 'nothing',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'twelve': '12',
      'fifteen': '15',
      'sixteen': '16',
      'twenty': '20',
      'twenty six': '26',
      'twenty nine': '29',
      'thirty': '30',
      'thirty five': '35',
      'forty': '40',
      'forty two': '42',
      'forty five': '45',
      'fifty': '50',
      'fifty seven': '57',
      'seventy': '70',
      'seventy three': '73',
      'seventy four': '74',
      'ninety': '90',
      'ninety six': '96',
      'ninety seven': '97',
    };

    // Check for exact word match
    if (numberMap.containsKey(normalized)) {
      return numberMap[normalized];
    }

    // Check if the text contains any of these words
    for (final entry in numberMap.entries) {
      if (normalized == entry.key ||
          normalized.contains(' ${entry.key}') ||
          normalized.contains('${entry.key} ')) {
        return entry.value;
      }
    }

    // Fallback to digit regex if no word match
    final digitMatch = RegExp(r'\d+').firstMatch(normalized);
    if (digitMatch != null) {
      return digitMatch.group(0);
    }

    return null;
  }

  /// Get match result with details
  static MatchResult getMatchResult(
    String expected,
    String actual, {
    double threshold = 70.0,
  }) {
    final similarity = getSimilarity(expected, actual);
    final passed = similarity >= threshold;

    return MatchResult(
      expected: expected,
      actual: actual,
      similarity: similarity,
      passed: passed,
      threshold: threshold,
    );
  }
}

/// Match result details
class MatchResult {
  final String expected;
  final String actual;
  final double similarity;
  final bool passed;
  final double threshold;

  MatchResult({
    required this.expected,
    required this.actual,
    required this.similarity,
    required this.passed,
    required this.threshold,
  });

  @override
  String toString() {
    return 'Expected: "$expected" | Actual: "$actual" | '
        'Similarity: ${similarity.toStringAsFixed(1)}% | '
        'Passed: $passed (threshold: $threshold%)';
  }
}
