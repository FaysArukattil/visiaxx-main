/// Asset path constants for the Vision Testing App
class AppAssets {
  AppAssets._();

  // Base paths
  static const String _imagesPath = 'assets/images';
  static const String _iconsPath = 'assets/images/icons';
  static const String _ishiharaPath = 'assets/ishihara_plates';
  static const String _amslerPath = 'assets/amsler_grid';
  static const String _animationsPath = 'assets/animations';

  // App Logo & Branding
  static const String appLogo = '$_iconsPath/app_logo.png';
  static const String appIcon = '$_iconsPath/app_icon.png';

  // Carousel Images
  static const String carousel1 = '$_imagesPath/carousel 1.png';
  static const String carousel2 = '$_imagesPath/carousel 2.png';
  static const String carousel3 = '$_imagesPath/carousel 3.png';
  
  static const List<String> carouselImages = [
    carousel1,
    carousel2,
    carousel3,
  ];

  // Relaxation Image (for 10-second eye rest)
  static const String relaxationImage = '$_imagesPath/releaxing image.png';

  // Ishihara Plates for Color Vision Test
  static const String ishiharaPlate1 = '$_ishiharaPath/ishihara_plate 1.png';
  static const String ishiharaPlate2 = '$_ishiharaPath/ishihara_plate 2.png';
  static const String ishiharaPlate3 = '$_ishiharaPath/ishihara_plate 3.png';
  static const String ishiharaPlate4 = '$_ishiharaPath/ishihara_plate 4.png';

  static const List<String> ishiharaPlates = [
    ishiharaPlate1,
    ishiharaPlate2,
    ishiharaPlate3,
    ishiharaPlate4,
  ];

  // Expected answers for Ishihara plates (in order) - Visiaxx specification
  static const List<String> ishiharaExpectedAnswers = [
    '74',  // Plate 1
    '12',  // Plate 2
    '6',   // Plate 3
    '42',  // Plate 4
  ];

  // Amsler Grid
  static const String amslerGrid = '$_amslerPath/amsler_grid.png';

  // Navigation Icons
  static const String quickTestIcon = '$_iconsPath/quick_test.png';
  static const String comprehensiveTestIcon = '$_iconsPath/comprehensive_test.png';
  static const String resultsIcon = '$_iconsPath/results.png';
  static const String consultationIcon = '$_iconsPath/consultation.png';
  static const String videosIcon = '$_iconsPath/videos.png';

  // Animations
  static const String loadingAnimation = '$_animationsPath/loading.json';
  static const String successAnimation = '$_animationsPath/success.json';
  static const String eyeAnimation = '$_animationsPath/eye.json';
}
