enum PlateCategory {
  demo, // Plate 1 - not scored
  transformation, // Plates 2-9 - show different numbers
  vanishing, // Plates 10-17 - normal sees, deficient doesn't
  hidden, // Plates 18-21 - deficient sees, normal doesn't
  classification, // Plates 22-25 - distinguish Protan vs Deutan
}

class IshiharaPlateConfig {
  final int plateNumber; // 1-25
  final String svgPath; // 'assets/ishihara_plates/1.svg'
  final PlateCategory category;
  final String normalAnswer; // What normal vision sees
  final String? deficientAnswer; // What red-green deficient sees (null = X)
  final String? protanStrongAnswer; // For classification plates
  final String? protanMildAnswer; // For classification plates
  final String? deutanStrongAnswer; // For classification plates
  final String? deutanMildAnswer; // For classification plates
  final bool isDemo; // true only for plate 1
  final bool isUsedInTest; // true for the 14 plates we use

  const IshiharaPlateConfig({
    required this.plateNumber,
    required this.svgPath,
    required this.category,
    required this.normalAnswer,
    this.deficientAnswer,
    this.protanStrongAnswer,
    this.protanMildAnswer,
    this.deutanStrongAnswer,
    this.deutanMildAnswer,
    this.isDemo = false,
    this.isUsedInTest = false,
  });
}

class IshiharaPlateData {
  /// The 14 plates used in test (excluding demo from scoring)
  static const List<int> testPlateNumbers = [
    1, // Demo
    2, 3, 4, 5, // Transformation (4)
    10, 9, 12, 13, // Vanishing (3) + 1 Trans (9)
    18, 19, // Hidden (2)
    22, 23, 24, // Classification (3)
  ];

  /// All 25 available plates
  static final List<IshiharaPlateConfig> allPlates = [
    // Plate 1 - DEMO (everyone should see 12)
    IshiharaPlateConfig(
      plateNumber: 1,
      svgPath: 'assets/ishihara_plates/Demo/1.svg',
      category: PlateCategory.demo,
      normalAnswer: '12',
      deficientAnswer: '12',
      isDemo: true,
      isUsedInTest: true,
    ),

    // Plates 2-9 - TRANSFORMATION
    IshiharaPlateConfig(
      plateNumber: 2,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/2.svg',
      category: PlateCategory.transformation,
      normalAnswer: '8',
      deficientAnswer: '3',
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 3,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/3.svg',
      category: PlateCategory.transformation,
      normalAnswer: '6',
      deficientAnswer: '5',
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 4,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/4.svg',
      category: PlateCategory.transformation,
      normalAnswer: '29',
      deficientAnswer: '70',
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 5,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/5.svg',
      category: PlateCategory.transformation,
      normalAnswer: '57',
      deficientAnswer: '35',
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 6,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/6.svg',
      category: PlateCategory.transformation,
      normalAnswer: '5',
      deficientAnswer: '2',
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 7,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/7.svg',
      category: PlateCategory.transformation,
      normalAnswer: '3',
      deficientAnswer: '5',
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 8,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/8.svg',
      category: PlateCategory.transformation,
      normalAnswer: '15',
      deficientAnswer: '17',
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 9,
      svgPath: 'assets/ishihara_plates/Diagnostic/Transformation plates/9.svg',
      category: PlateCategory.transformation,
      normalAnswer: '74',
      deficientAnswer: '21',
      isUsedInTest: true,
    ),

    // Plates 10-11 - VANISHING (only 2 used, rest skipped)
    IshiharaPlateConfig(
      plateNumber: 10,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0010.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '2',
      deficientAnswer: null, // Cannot see
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 11,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0011.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '6',
      deficientAnswer: null, // Cannot see
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 12,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0012.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '97',
      deficientAnswer: null,
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 13,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0013.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '45',
      deficientAnswer: null,
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 14,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0014.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '5',
      deficientAnswer: null,
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 15,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0015.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '7',
      deficientAnswer: null,
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 16,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0016.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '16',
      deficientAnswer: null,
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 17,
      svgPath: 'assets/ishihara_plates/Diagnostic/Vanishing plates/0017.svg',
      category: PlateCategory.vanishing,
      normalAnswer: '73',
      deficientAnswer: null,
      isUsedInTest: false,
    ),

    // Plates 18-19 - HIDDEN (only 2 used)
    IshiharaPlateConfig(
      plateNumber: 18,
      svgPath: 'assets/ishihara_plates/Diagnostic/Hidden plates/18.svg',
      category: PlateCategory.hidden,
      normalAnswer: 'X', // Cannot see
      deficientAnswer: '5',
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 19,
      svgPath: 'assets/ishihara_plates/Diagnostic/Hidden plates/19.svg',
      category: PlateCategory.hidden,
      normalAnswer: 'X', // Cannot see
      deficientAnswer: '2',
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 20,
      svgPath: 'assets/ishihara_plates/Diagnostic/Hidden plates/20.svg',
      category: PlateCategory.hidden,
      normalAnswer: 'X',
      deficientAnswer: '45',
      isUsedInTest: false,
    ),
    IshiharaPlateConfig(
      plateNumber: 21,
      svgPath: 'assets/ishihara_plates/Diagnostic/Hidden plates/21.svg',
      category: PlateCategory.hidden,
      normalAnswer: 'X',
      deficientAnswer: '73',
      isUsedInTest: false,
    ),

    // Plates 22-23 - CLASSIFICATION (only 2 used)
    IshiharaPlateConfig(
      plateNumber: 22,
      svgPath: 'assets/ishihara_plates/Classification/22.svg',
      category: PlateCategory.classification,
      normalAnswer: '26',
      protanStrongAnswer: '6',
      protanMildAnswer: '26', // Can see both, but 2 is faint
      deutanStrongAnswer: '2',
      deutanMildAnswer: '26', // Can see both, but 6 is faint
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 23,
      svgPath: 'assets/ishihara_plates/Classification/23.svg',
      category: PlateCategory.classification,
      normalAnswer: '42',
      protanStrongAnswer: '2',
      protanMildAnswer: '42', // Can see both, but 4 is faint
      deutanStrongAnswer: '4',
      deutanMildAnswer: '42', // Can see both, but 2 is faint
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 24,
      svgPath: 'assets/ishihara_plates/Classification/24.svg',
      category: PlateCategory.classification,
      normalAnswer: '35',
      protanStrongAnswer: '5',
      protanMildAnswer: '35',
      deutanStrongAnswer: '3',
      deutanMildAnswer: '35',
      isUsedInTest: true,
    ),
    IshiharaPlateConfig(
      plateNumber: 25,
      svgPath: 'assets/ishihara_plates/Classification/25.svg',
      category: PlateCategory.classification,
      normalAnswer: '96',
      protanStrongAnswer: '6',
      protanMildAnswer: '96',
      deutanStrongAnswer: '9',
      deutanMildAnswer: '96',
      isUsedInTest: false,
    ),
  ];

  /// Get only the plates used in testing
  static List<IshiharaPlateConfig> getTestPlates() {
    return allPlates.where((plate) => plate.isUsedInTest).toList();
  }

  /// Get a specific plate by number
  static IshiharaPlateConfig? getPlate(int plateNumber) {
    try {
      return allPlates.firstWhere((p) => p.plateNumber == plateNumber);
    } catch (e) {
      return null;
    }
  }
}
