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

  /// ✅ NEW: Check if speech contains most/all important words of the target
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

    int matches = 0;
    for (final tWord in targetWords) {
      if (actualWords.contains(tWord)) {
        matches++;
      } else {
        // Soft match for minor typos (e.g. "vision" vs "missions")
        for (final aWord in actualWords) {
          if (aWord.similarityTo(tWord) > 0.8) {
            matches++;
            break;
          }
        }
      }
    }

    return (matches / targetWords.length) >= keywordThreshold;
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
