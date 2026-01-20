import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/widgets/eye_loader.dart';

class PractitionerHomeScreen extends StatefulWidget {
  const PractitionerHomeScreen({super.key});

  @override
  State<PractitionerHomeScreen> createState() => _PractitionerHomeScreenState();
}

class _PractitionerHomeScreenState extends State<PractitionerHomeScreen> {
  int _currentCarouselIndex = 0;
  final _authService = AuthService();
  UserModel? _user;
  String _userName = 'Practitioner';
  bool _isLoading = true;

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
            _userName = user.firstName;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[PractitionerHomeScreen] ❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
    );
  }

  Widget _buildHeader(BoxConstraints constraints) {
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
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.06),
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
                      return const Icon(
                        Icons.remove_red_eye,
                        color: AppColors.primary,
                      );
                    },
                  ),
                ),
              ),
              const Spacer(),
              // Practitioner badge replacing language selector
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.025,
                  vertical: screenHeight * 0.008,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: (screenWidth * 0.04).clamp(14.0, 18.0),
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: screenWidth * 0.012),
                    Text(
                      'PRACTITIONER',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: (screenWidth * 0.03).clamp(11.0, 13.0),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
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
                      'Hello, $_userName 👋',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: (screenWidth * 0.055).clamp(18.0, 24.0),
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.035,
                        vertical: screenHeight * 0.01,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            AppColors.primaryLight.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.15),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.05),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_red_eye,
                            color: AppColors.primary,
                            size: (screenWidth * 0.04).clamp(14.0, 18.0),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Flexible(
                            child: Text(
                              'Your Vision, Our Priority',
                              style: TextStyle(
                                fontSize: (screenWidth * 0.035).clamp(
                                  12.0,
                                  14.5,
                                ),
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
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
    final carouselHeight = (screenHeight * 0.22).clamp(160.0, 220.0);

    return SizedBox(
      width: screenWidth,
      height: carouselHeight,
      child: CarouselSlider(
        options: CarouselOptions(
          height: carouselHeight,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 5),
          enlargeCenterPage: true,
          enlargeFactor: 0.08,
          viewportFraction: 0.88,
          padEnds: true,
          onPageChanged: (index, reason) =>
              setState(() => _currentCarouselIndex = index),
        ),
        items: _carouselSlides.map((slide) {
          return Builder(
            builder: (BuildContext context) {
              return Container(
                width: screenWidth * 0.88,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: .08),
                      AppColors.primaryLight.withOpacity(0.05),
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
                        padding: EdgeInsets.all(
                          (screenWidth * 0.035).clamp(12.0, 18.0),
                        ),
                        child: slide['hasImages'] as bool
                            ? _buildSlideWithImages(
                                slide,
                                screenWidth,
                                screenHeight,
                              )
                            : _buildSlideWithoutImages(
                                slide,
                                screenWidth,
                                screenHeight,
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
    double screenHeight,
  ) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final availableHeight = cardConstraints.maxHeight;
        final availableWidth = cardConstraints.maxWidth;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slide['heading'] as String,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: (availableWidth * 0.055).clamp(13.0, 17.0),
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: availableHeight * 0.04),
                  Text(
                    slide['content'] as String,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: (availableWidth * 0.032).clamp(9.0, 11.5),
                      height: 1.35,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: availableHeight * 0.035),
                  Text(
                    slide['supportText'] as String,
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      fontSize: (availableWidth * 0.028).clamp(8.0, 10.0),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: availableWidth * 0.02),
            Flexible(
              flex: 35,
              child: Center(
                child: SizedBox(
                  height: availableHeight * 0.85,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _buildFounderImage(
                          'assets/images/founder_image_1.png',
                          availableWidth,
                          availableHeight,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
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
        );
      },
    );
  }

  Widget _buildFounderImage(String imagePath, double width, double height) {
    return Container(
      width: (width * 0.13).clamp(38.0, 52.0),
      height: (height * 0.42).clamp(65.0, 90.0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person,
                color: AppColors.primary.withValues(alpha: 0.6),
                size: 20,
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
    double screenHeight,
  ) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final availableWidth = cardConstraints.maxWidth;
        final availableHeight = cardConstraints.maxHeight;

        return Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slide['heading'] as String,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: (availableWidth * 0.055).clamp(14.0, 18.0),
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: availableHeight * 0.05),
              Text(
                slide['content'] as String,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: (availableWidth * 0.038).clamp(10.5, 13.0),
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: availableHeight * 0.05),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: availableWidth * 0.03,
                  vertical: availableHeight * 0.025,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  slide['supportText'] as String,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: (availableWidth * 0.032).clamp(9.0, 11.0),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
                  ? AppColors.primary
                  : AppColors.divider,
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
          // Row 1: Quick Test and Full Eye Exam
          Row(
            children: [
              Expanded(
                child: _CompactServiceCard(
                  icon: Icons.timer_outlined,
                  title: 'Quick Test',
                  subtitle: 'rapid tests',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/practitioner-profile-selection',
                  ),
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
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/practitioner-profile-selection',
                    arguments: {'comprehensive': true},
                  ),
                  height: compactCardHeight,
                  screenWidth: screenWidth,
                ),
              ),
            ],
          ),
          SizedBox(height: cardSpacing),
          // Row 2: Patient Results (wide card)
          _WideServiceCard(
            icon: Icons.assessment_outlined,
            title: 'Patient Results',
            subtitle: 'View & download reports',
            onTap: () => Navigator.pushNamed(context, '/practitioner-results'),
            height: wideCardHeight,
            screenWidth: screenWidth,
          ),
          SizedBox(height: cardSpacing),
          // Row 3: Individual Tests and Visiaxx TV
          Row(
            children: [
              Expanded(
                child: _CompactServiceCard(
                  icon: Icons.list_alt_outlined,
                  title: 'Individual Tests',
                  subtitle: 'Quick standalone tests',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/practitioner-individual-tests',
                  ),
                  height: compactCardHeight,
                  screenWidth: screenWidth,
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                child: _CompactServiceCard(
                  icon: Icons.video_library_outlined,
                  title: 'Visiaxx TV',
                  subtitle: 'Eye exercises',
                  onTap: () => Navigator.pushNamed(context, '/eye-exercises'),
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
        final iconSize = (availableWidth * 0.18).clamp(28.0, 36.0);
        final titleFontSize = (availableWidth * 0.08).clamp(13.0, 16.0);
        final subtitleFontSize = (availableWidth * 0.058).clamp(9.5, 12.0);
        final cardPadding = (availableWidth * 0.065).clamp(10.0, 14.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: AppColors.primary.withOpacity(0.1),
            highlightColor: AppColors.primary.withOpacity(0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primaryLight.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
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
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primary,
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
                              color: AppColors.primary,
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
                              color: AppColors.textSecondary,
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
            splashColor: AppColors.primary.withOpacity(0.1),
            highlightColor: AppColors.primary.withOpacity(0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primaryLight.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
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
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primary,
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
                              color: AppColors.primary,
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
                              color: AppColors.textSecondary,
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
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: (cardConstraints.maxWidth * 0.038).clamp(
                          16.0,
                          20.0,
                        ),
                        color: AppColors.primary,
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
