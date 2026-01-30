import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/extensions/theme_extension.dart';

/// User home screen with navigation grid and carousel
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentCarouselIndex = 0;
  final _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isConsultationLoading = false;
  String _selectedLanguage = 'English';

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'or', 'name': 'Odia', 'native': 'ଓଡ଼ିଆ'},
  ];

  final List<Map<String, dynamic>> _carouselSlides = [
    {
      'heading': 'Who We Are',
      'content':
          'Vision Optocare reshapes eye care with mobile-first technology and optometric precision.',
      'supportText': 'Built by professionals',
      'hasImages': true,
    },
    {
      'heading': 'Our Product',
      'content':
          'Visiaxx Digital Eye Clinic App conducts clinically approved vision screenings from your smartphone.',
      'supportText': 'Smart. Clinical. Mobile-first.',
      'hasImages': false,
    },
    {
      'heading': 'Our Mission',
      'content':
          'Deliver high-quality, validated eye-care solutions through intuitive digital platforms.',
      'supportText': 'Accessible eye care everywhere.',
      'hasImages': false,
    },
    {
      'heading': 'Our Vision',
      'content':
          'Create a future where comprehensive eye care is universally accessible and technology-driven.',
      'supportText': 'Redefining digital eye health.',
      'hasImages': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (_authService.currentUserId != null) {
        final user = await _authService.getUserData(
          _authService.currentUserId!,
        );
        if (mounted && user != null) {
          setState(() {
            _user = user;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[HomeScreen] ❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final language = _languages[index];
                  final isSelected = language['name'] == _selectedLanguage;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.primary.withValues(alpha: 0.1)
                            : context.scaffoldBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          language['code']!.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? context.primary
                                : context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      language['name']!,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? context.primary : null,
                      ),
                    ),
                    subtitle: Text(
                      language['native']!,
                      style: TextStyle(color: context.textSecondary),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: context.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedLanguage = language['name']!);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? const Center(child: EyeLoader.fullScreen())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(constraints),
                            SizedBox(height: constraints.maxHeight * 0.015),
                            _buildCarousel(constraints),
                            SizedBox(height: constraints.maxHeight * 0.012),
                            _buildCarouselIndicators(),
                            SizedBox(height: constraints.maxHeight * 0.02),
                            _buildServicesGrid(constraints),
                            SizedBox(height: constraints.maxHeight * 0.02),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isConsultationLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.1),
                child: const Center(child: EyeLoader.fullScreen()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BoxConstraints constraints) {
    final selectedLang = _languages.firstWhere(
      (l) => l['name'] == _selectedLanguage,
      orElse: () => _languages.first,
    );

    final horizontalPadding = constraints.maxWidth * 0.045;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Dynamic logo sizing based on screen dimensions
    final logoWidth = (screenWidth * 0.28).clamp(100.0, 140.0);
    final logoHeight = (screenHeight * 0.06).clamp(48.0, 65.0);

    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: logoWidth,
                height: logoHeight,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/icons/app_logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.remove_red_eye, color: context.primary);
                    },
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showLanguageSelector,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.025,
                    vertical: screenHeight * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: (screenWidth * 0.04).clamp(14.0, 18.0),
                        color: context.textSecondary,
                      ),
                      SizedBox(width: screenWidth * 0.012),
                      Text(
                        selectedLang['code']!.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: (screenWidth * 0.03).clamp(11.0, 13.0),
                          color: context.onSurface,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: (screenWidth * 0.04).clamp(14.0, 18.0),
                        color: context.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_user?.firstName ?? 'User'} 👋',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: (screenWidth * 0.055).clamp(18.0, 24.0),
                        color: context.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Container(
                      width: double.infinity, // Takes full width
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.035,
                        vertical: screenHeight * 0.01,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.primary.withValues(alpha: 0.08),
                            context.primary.withValues(alpha: 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          20,
                        ), // Already matches the grid cards
                        border: Border.all(
                          color: context.primary.withValues(alpha: 0.15),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.primary.withValues(alpha: 0.05),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Keep content centered
                        children: [
                          Icon(
                            Icons.remove_red_eye,
                            color: context.primary,
                            size: (screenWidth * 0.04).clamp(14.0, 18.0),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Flexible(
                            // Changed from no wrapper to Flexible for better text handling
                            child: Text(
                              'Your Vision, Our Priority',
                              style: TextStyle(
                                fontSize: (screenWidth * 0.035).clamp(
                                  12.0,
                                  14.5,
                                ),
                                fontWeight: FontWeight.w600,
                                color: context.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel(BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // More adaptive height calculation - Reduced max clamps to avoid excessive height
    final double carouselHeight;
    if (isLandscape) {
      carouselHeight = (screenHeight * 0.45).clamp(180.0, 240.0);
    } else {
      carouselHeight = (screenHeight * 0.22).clamp(160.0, 210.0);
    }

    return SizedBox(
      width: screenWidth,
      height: carouselHeight,
      child: CarouselSlider(
        options: CarouselOptions(
          height: carouselHeight,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 5),
          enlargeCenterPage: true,
          enlargeFactor: 0.1, // Increased slightly for better focus
          viewportFraction:
              0.91, // Precisely aligns with 0.045 horizontal padding
          padEnds: true,
          onPageChanged: (index, reason) =>
              setState(() => _currentCarouselIndex = index),
        ),
        items: _carouselSlides.map((slide) {
          return Builder(
            builder: (BuildContext context) {
              return Container(
                width: screenWidth * 0.91,
                margin: const EdgeInsets.symmetric(
                  horizontal: 0,
                ), // Removed margin for perfect alignment
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: .08),
                      AppColors.primaryLight.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Decorative circles
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.12),
                                AppColors.primary.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -25,
                        bottom: -25,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primaryLight.withOpacity(0.1),
                                AppColors.primaryLight.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: (screenWidth * 0.04).clamp(16.0, 24.0),
                          vertical: (screenWidth * 0.02).clamp(
                            8.0,
                            12.0,
                          ), // Reduced vertical padding
                        ),
                        child: slide['hasImages'] as bool
                            ? _buildSlideWithImages(
                                slide,
                                screenWidth,
                                carouselHeight,
                              )
                            : _buildSlideWithoutImages(
                                slide,
                                screenWidth,
                                carouselHeight,
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSlideWithImages(
    Map<String, dynamic> slide,
    double screenWidth,
    double carouselHeight,
  ) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final availableHeight = cardConstraints.maxHeight;
        final availableWidth = cardConstraints.maxWidth;
        final isBroad = availableWidth > 450;

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: availableWidth,
            height: availableHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isBroad ? 70 : 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize
                        .min, // Added to prevent unnecessary vertical expansion
                    children: [
                      Text(
                        slide['heading'] as String,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: (availableWidth * 0.06).clamp(
                            15.0,
                            20.0,
                          ), // Reduced max font size
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: (availableHeight * 0.04).clamp(4.0, 8.0),
                      ), // Reduced spacing
                      Text(
                        slide['content'] as String,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: (availableWidth * 0.035).clamp(
                            11.0,
                            13.5,
                          ), // Reduced max font size
                          height: 1.2, // Tighter height
                        ),
                        maxLines: isBroad
                            ? 3
                            : 2, // Fewer lines if height is constrained
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: (availableHeight * 0.04).clamp(6.0, 10.0),
                      ), // Reduced spacing
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, // Reduced padding
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slide['supportText'] as String,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: (availableWidth * 0.028).clamp(
                              9.0,
                              11.0,
                            ), // Reduced max font size
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: availableWidth * 0.02),
                Flexible(
                  flex: isBroad ? 30 : 36,
                  child: Center(
                    child: SizedBox(
                      height:
                          availableHeight *
                          0.85, // Slightly reduced to avoid overflow
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circular background for images
                          Container(
                            width: (availableWidth * 0.22).clamp(70.0, 110.0),
                            height: (availableWidth * 0.22).clamp(70.0, 110.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.04),
                            ),
                          ),
                          // Dynamic positioning to prevent overlap on small screens
                          Positioned(
                            top: 0,
                            left: isBroad ? 0 : -5,
                            child: _buildFounderImage(
                              'assets/images/founder_image_1.png',
                              availableWidth,
                              availableHeight,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: isBroad ? 0 : -5,
                            child: _buildFounderImage(
                              'assets/images/founder_image_2.png',
                              availableWidth,
                              availableHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFounderImage(String imagePath, double width, double height) {
    final imageWidth = (width * 0.15).clamp(38.0, 58.0); // Reduced size
    final imageHeight = (height * 0.42).clamp(70.0, 95.0); // Reduced size

    return Container(
      width: imageWidth,
      height: imageHeight,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person,
                color: AppColors.primary.withValues(alpha: 0.6),
                size: imageWidth * 0.4,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlideWithoutImages(
    Map<String, dynamic> slide,
    double screenWidth,
    double carouselHeight,
  ) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final availableWidth = cardConstraints.maxWidth;
        final availableHeight = cardConstraints.maxHeight;

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: availableWidth,
            height: availableHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slide['heading'] as String,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: (availableWidth * 0.06).clamp(16.0, 24.0),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: (availableHeight * 0.05).clamp(6.0, 12.0)),
                Text(
                  slide['content'] as String,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: (availableWidth * 0.04).clamp(12.0, 16.0),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: (availableHeight * 0.06).clamp(8.0, 16.0)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    slide['supportText'] as String,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: (availableWidth * 0.035).clamp(10.0, 13.5),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarouselIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _carouselSlides.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentCarouselIndex == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: _currentCarouselIndex == index
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesGrid(BoxConstraints constraints) {
    final horizontalPadding = constraints.maxWidth * 0.045;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate available height for grid
    final usedHeight =
        (screenHeight * 0.06) + // Header logo height
        (screenHeight * 0.015) + // Spacing after header
        (screenHeight * 0.015) + // Greeting height estimate
        (screenHeight * 0.22).clamp(160.0, 220.0) + // Carousel height
        (screenHeight * 0.012) + // Spacing after carousel
        (screenHeight * 0.015) + // Indicators
        (screenHeight * 0.02) + // Spacing before grid
        (screenHeight * 0.02); // Spacing after grid

    final availableGridHeight = (screenHeight - usedHeight).clamp(280.0, 500.0);

    // Dynamic spacing and heights based on available grid space
    final cardSpacing = (availableGridHeight * 0.035).clamp(6.0, 12.0);
    final compactCardHeight = (availableGridHeight * 0.32).clamp(85.0, 115.0);
    final wideCardHeight = (availableGridHeight * 0.2).clamp(55.0, 72.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _CompactServiceCard(
                  icon: Icons.timer_outlined,
                  title: 'Quick Test',
                  subtitle: 'rapid tests',
                  onTap: () => Navigator.pushNamed(context, '/quick-test'),
                  height: compactCardHeight,
                  screenWidth: screenWidth,
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _CompactServiceCard(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Full Eye Exam',
                  subtitle: 'Comprehensive',
                  onTap: () =>
                      Navigator.pushNamed(context, '/comprehensive-test'),
                  height: compactCardHeight,
                  screenWidth: screenWidth,
                ),
              ),
            ],
          ),
          SizedBox(height: cardSpacing),
          _WideServiceCard(
            icon: Icons.assessment_outlined,
            title: 'My Results',
            subtitle: 'View & download reports',
            onTap: () => Navigator.pushNamed(context, '/my-results'),
            height: wideCardHeight,
            screenWidth: screenWidth,
          ),
          SizedBox(height: cardSpacing),
          Row(
            children: [
              Expanded(
                child: _CompactServiceCard(
                  icon: Icons.video_call_outlined,
                  title: 'Consultation',
                  subtitle: 'Talk to doctor',
                  onTap: () async {
                    setState(() => _isConsultationLoading = true);
                    await Future.delayed(const Duration(seconds: 4));
                    if (mounted) {
                      setState(() => _isConsultationLoading = false);
                      SnackbarUtils.showInfo(
                        context,
                        'Consultation feature coming soon!',
                      );
                    }
                  },
                  height: compactCardHeight,
                  screenWidth: screenWidth,
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _CompactServiceCard(
                  icon: Icons.tips_and_updates_outlined,
                  title: 'Eye Care Tips',
                  subtitle: 'Daily care guide',
                  onTap: () => Navigator.pushNamed(context, '/eye-care-tips'),
                  height: compactCardHeight,
                  screenWidth: screenWidth,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double height;
  final double screenWidth;

  const _CompactServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.height,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final availableWidth = cardConstraints.maxWidth;
        final iconSize = (availableWidth * 0.18).clamp(
          28.0,
          36.0,
        ); // Increased icon size
        final titleFontSize = (availableWidth * 0.08).clamp(13.0, 16.0);
        final subtitleFontSize = (availableWidth * 0.058).clamp(9.5, 12.0);
        final cardPadding = (availableWidth * 0.065).clamp(10.0, 14.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            highlightColor: Theme.of(
              context,
            ).primaryColor.withValues(alpha: 0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withValues(alpha: 0.08),
                    Theme.of(context).primaryColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.05),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: iconSize + 14,
                      height: iconSize + 14,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).primaryColor,
                        size: iconSize,
                      ),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: titleFontSize,
                              color: Theme.of(context).primaryColor,
                              height: 1.1,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: subtitleFontSize,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WideServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double height;
  final double screenWidth;

  const _WideServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.height,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final iconSize = (cardConstraints.maxWidth * 0.055).clamp(24.0, 30.0);
        final titleFontSize = (cardConstraints.maxWidth * 0.042).clamp(
          14.0,
          17.0,
        );
        final subtitleFontSize = (cardConstraints.maxWidth * 0.032).clamp(
          10.0,
          12.0,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            highlightColor: Theme.of(
              context,
            ).primaryColor.withValues(alpha: 0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withValues(alpha: 0.08),
                    Theme.of(context).primaryColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.05),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.symmetric(
                  horizontal: (cardConstraints.maxWidth * 0.04).clamp(
                    12.0,
                    18.0,
                  ),
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: iconSize + 14,
                      height: iconSize + 14,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).primaryColor,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(
                      width: (cardConstraints.maxWidth * 0.03).clamp(8.0, 14.0),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: titleFontSize,
                              color: Theme.of(context).primaryColor,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: subtitleFontSize,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: (cardConstraints.maxWidth * 0.038).clamp(
                          16.0,
                          20.0,
                        ),
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
