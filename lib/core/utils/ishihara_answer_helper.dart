/// Helper class to provide expected answers for Ishihara plates
/// Based on RESULT.txt in assets/ishihara_plates/
class IshiharaAnswerHelper {
  /// Get expected answers for a specific plate number
  static PlateAnswers? getExpectedAnswers(int plateNumber) {
    final answers = _plateAnswersMap[plateNumber];
    return answers;
  }

  /// Map of plate numbers to expected answers
  /// Data from RESULT.txt
  static final Map<int, PlateAnswers> _plateAnswersMap = {
    1: PlateAnswers(normal: '12', colorBlind: '12', totalBlind: '12'),
    2: PlateAnswers(normal: '8', colorBlind: '3', totalBlind: null),
    3: PlateAnswers(normal: '6', colorBlind: '5', totalBlind: null),
    4: PlateAnswers(normal: '29', colorBlind: '70', totalBlind: null),
    5: PlateAnswers(normal: '57', colorBlind: '35', totalBlind: null),
    6: PlateAnswers(normal: '5', colorBlind: '2', totalBlind: null),
    7: PlateAnswers(normal: '3', colorBlind: '5', totalBlind: null),
    8: PlateAnswers(normal: '15', colorBlind: '17', totalBlind: null),
    9: PlateAnswers(normal: '74', colorBlind: '21', totalBlind: null),
    10: PlateAnswers(normal: '2', colorBlind: null, totalBlind: null),
    11: PlateAnswers(normal: '6', colorBlind: null, totalBlind: null),
    12: PlateAnswers(normal: '97', colorBlind: null, totalBlind: null),
    13: PlateAnswers(normal: '45', colorBlind: null, totalBlind: null),
    14: PlateAnswers(normal: '5', colorBlind: null, totalBlind: null),
    15: PlateAnswers(normal: '7', colorBlind: null, totalBlind: null),
    16: PlateAnswers(normal: '16', colorBlind: null, totalBlind: null),
    17: PlateAnswers(normal: '73', colorBlind: null, totalBlind: null),
    18: PlateAnswers(normal: null, colorBlind: '5', totalBlind: null),
    19: PlateAnswers(normal: null, colorBlind: '2', totalBlind: null),
    20: PlateAnswers(normal: null, colorBlind: '45', totalBlind: null),
    21: PlateAnswers(normal: null, colorBlind: '73', totalBlind: null),
  };
}

/// Expected answers for a single Ishihara plate
class PlateAnswers {
  final String? normal;
  final String? colorBlind;
  final String? totalBlind;

  const PlateAnswers({this.normal, this.colorBlind, this.totalBlind});

  /// Get the primary answer (normal vision if available, otherwise color blind)
  String? get primaryAnswer => normal ?? colorBlind;

  /// Get the secondary answer (color blind if different from normal)
  String? get secondaryAnswer {
    if (colorBlind != null && colorBlind != normal) {
      return colorBlind;
    }
    return null;
  }

  /// Check if this plate has both normal and color blind answers
  bool get hasBothAnswers =>
      normal != null && colorBlind != null && normal != colorBlind;
}
