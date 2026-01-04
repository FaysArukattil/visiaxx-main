/// Pelli-Robson Contrast Sensitivity Scoring Utility
/// Clinical-grade scoring calculation per Pelli-Robson chart specifications
library;

/// Triplet configuration with exact opacity and log CS values
class PelliRobsonTriplet {
  final String code; // e.g., 'VRS'
  final String letters; // Individual letters
  final double logCS; // Log contrast sensitivity value
  final double opacity; // Flutter Opacity widget value
  final int screenIndex; // Which screen this triplet appears on (0-7)

  const PelliRobsonTriplet({
    required this.code,
    required this.letters,
    required this.logCS,
    required this.opacity,
    required this.screenIndex,
  });
}

/// Clinical scoring for Pelli-Robson Contrast Sensitivity Test
class PelliRobsonScoring {
  /// All 17 triplets with clinical contrast values
  /// Opacity values calculated for visual differentiation on digital screens
  /// Using exponential decay for logarithmic contrast sensitivity
  static const List<PelliRobsonTriplet> triplets = [
    // Screen 1: High contrast (easily visible)
    PelliRobsonTriplet(
      code: 'VRS',
      letters: 'VRS',
      logCS: 0.00,
      opacity: 1.00, // 100% - full black
      screenIndex: 0,
    ),
    PelliRobsonTriplet(
      code: 'KDR',
      letters: 'KDR',
      logCS: 0.15,
      opacity: 0.70, // 70%
      screenIndex: 0,
    ),
    // Screen 2: Medium-high contrast
    PelliRobsonTriplet(
      code: 'NHC',
      letters: 'NHC',
      logCS: 0.30,
      opacity: 0.50, // 50%
      screenIndex: 1,
    ),
    PelliRobsonTriplet(
      code: 'SOK',
      letters: 'SOK',
      logCS: 0.45,
      opacity: 0.35, // 35%
      screenIndex: 1,
    ),
    PelliRobsonTriplet(
      code: 'SCN',
      letters: 'SCN',
      logCS: 0.60,
      opacity: 0.25, // 25%
      screenIndex: 1,
    ),
    // Screen 3: Medium contrast
    PelliRobsonTriplet(
      code: 'OZV',
      letters: 'OZV',
      logCS: 0.75,
      opacity: 0.18, // 18%
      screenIndex: 2,
    ),
    PelliRobsonTriplet(
      code: 'CNH',
      letters: 'CNH',
      logCS: 0.90,
      opacity: 0.13, // 13%
      screenIndex: 2,
    ),
    // Screen 4: Medium-low contrast
    PelliRobsonTriplet(
      code: 'ZOK',
      letters: 'ZOK',
      logCS: 1.05,
      opacity: 0.09, // 9%
      screenIndex: 3,
    ),
    PelliRobsonTriplet(
      code: 'NOD',
      letters: 'NOD',
      logCS: 1.20,
      opacity: 0.065, // 6.5%
      screenIndex: 3,
    ),
    // Screen 5: Low contrast
    PelliRobsonTriplet(
      code: 'VHR',
      letters: 'VHR',
      logCS: 1.35,
      opacity: 0.045, // 4.5%
      screenIndex: 4,
    ),
    PelliRobsonTriplet(
      code: 'CDN',
      letters: 'CDN',
      logCS: 1.50,
      opacity: 0.032, // 3.2%
      screenIndex: 4,
    ),
    // Screen 6: Very low contrast
    PelliRobsonTriplet(
      code: 'ZSV',
      letters: 'ZSV',
      logCS: 1.65,
      opacity: 0.022, // 2.2%
      screenIndex: 5,
    ),
    PelliRobsonTriplet(
      code: 'KCH',
      letters: 'KCH',
      logCS: 1.80,
      opacity: 0.016, // 1.6%
      screenIndex: 5,
    ),
    // Screen 7: Minimal contrast
    PelliRobsonTriplet(
      code: 'ODK',
      letters: 'ODK',
      logCS: 1.95,
      opacity: 0.011, // 1.1%
      screenIndex: 6,
    ),
    PelliRobsonTriplet(
      code: 'RSZ',
      letters: 'RSZ',
      logCS: 2.10,
      opacity: 0.008, // 0.8%
      screenIndex: 6,
    ),
    // Screen 8: Threshold contrast
    PelliRobsonTriplet(
      code: 'HVR',
      letters: 'HVR',
      logCS: 2.25,
      opacity: 0.006, // 0.6%
      screenIndex: 7,
    ),
    PelliRobsonTriplet(
      code: 'HSV',
      letters: 'HSV',
      logCS: 2.40,
      opacity: 0.004, // 0.4%
      screenIndex: 7,
    ),
  ];

  /// Map of triplet codes to their log CS values
  static const Map<String, double> tripletValues = {
    'VRS': 1.10,
    'KDR': 1.15,
    'NHC': 1.20,
    'SOK': 1.25,
    'SCN': 1.30,
    'OZV': 1.35,
    'CNH': 1.40,
    'ZOK': 1.45,
    'NOD': 1.50,
    'VHR': 1.55,
    'CDN': 1.60,
    'ZSV': 1.65,
    'KCH': 1.70,
    'ODK': 1.75,
    'RSZ': 1.80,
    'HVR': 1.85,
    'HSV': 2.00,
  };

  /// Get triplets for a specific screen
  static List<PelliRobsonTriplet> getTripletsForScreen(int screenIndex) {
    return triplets.where((t) => t.screenIndex == screenIndex).toList();
  }

  /// Total number of screens
  static const int totalScreens = 8;

  /// Calculate the final score
  /// Step 1: Find last triplet where all 3 letters correct
  /// Step 2: Count correct letters in next triplet (0-3)
  /// Step 3: Uncorrected score = lastTripletValue + (correctInNext * 0.05)
  /// Step 4: If short distance (40cm): Adjusted = Uncorrected - 0.15
  static double calculateScore({
    required String? lastFullTriplet,
    required int correctInNextTriplet,
    required bool isShortDistance,
  }) {
    if (lastFullTriplet == null || lastFullTriplet.isEmpty) {
      // If no triplet was fully correct, use minimum score
      return isShortDistance ? 0.95 : 1.10; // Worst possible
    }

    final baseValue = tripletValues[lastFullTriplet] ?? 1.10;
    final bonus = correctInNextTriplet * 0.05;
    final uncorrected = baseValue + bonus;

    if (isShortDistance) {
      return uncorrected - 0.15;
    }
    return uncorrected;
  }

  /// Get clinical category for a score
  static String getCategory(double score) {
    if (score >= 1.85) return 'Excellent';
    if (score >= 1.65) return 'Normal';
    if (score >= 1.40) return 'Borderline';
    return 'Reduced';
  }

  /// Get category description for users
  static String getCategoryDescription(String category) {
    switch (category) {
      case 'Excellent':
        return 'Your ability to distinguish subtle contrast differences is excellent. '
            'This indicates healthy contrast sensitivity.';
      case 'Normal':
        return 'Your contrast sensitivity is within the normal range. '
            'You can see well in various lighting conditions.';
      case 'Borderline':
        return 'Your contrast sensitivity shows early signs of impairment. '
            'This may affect vision in low light or foggy conditions.';
      case 'Reduced':
      default:
        return 'Your contrast sensitivity is reduced. '
            'This may impact activities like reading and driving. '
            'Please consult an eye care professional.';
    }
  }

  /// Get short professional interpretation
  static String getClinicalInterpretation(double score, String category) {
    return 'Log CS: ${score.toStringAsFixed(2)} - $category contrast sensitivity. '
        '${category == 'Excellent' || category == 'Normal' ? 'Within normal limits.' : 'Further evaluation recommended.'}';
  }

  /// Find the last fully correct triplet and count correct in next
  static ({String? lastFull, int correctInNext}) analyzeResponses(
    List<({String code, int correctLetters})> responses,
  ) {
    String? lastFullTriplet;
    int correctInNext = 0;
    bool foundNextAfterLast = false;

    for (final response in responses) {
      if (response.correctLetters == 3) {
        lastFullTriplet = response.code;
        foundNextAfterLast = false;
        correctInNext = 0;
      } else if (lastFullTriplet != null && !foundNextAfterLast) {
        correctInNext = response.correctLetters;
        foundNextAfterLast = true;
      }
    }

    return (lastFull: lastFullTriplet, correctInNext: correctInNext);
  }
}
