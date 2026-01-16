import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/snackbar_utils.dart';
import 'profile_screen.dart';

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
  bool _isConsultationLoading = false; // For demonstration
  String _selectedLanguage = 'English';

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'à¤¹à¤¿à¤¨à¥à¤¦à¥€'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'à¤®à¤°à¤¾à¤ à¥€'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'à´®à´²à´¯à´¾à´³à´‚'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'à®¤à®®à®¿à®´à¯'},
    {'code': 'te', 'name': 'Telugu', 'native': 'à°¤à±†à°²à±à°—à±'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'à²•à²¨à³à²¨à²¡'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'à¦¬à¦¾à¦‚à¦²à¦¾'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'àª—à«àªœàª°àª¾àª¤à«€'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'à¨ªà©°à¨œà¨¾à¨¬à©€'},
    {'code': 'or', 'name': 'Odia', 'native': 'à¬“à¬¡à¬¼à¬¿à¬†'},
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
        // Now returns from local cache instantly or refreshes from server
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
      debugPrint('[HomeScreen] âŒ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
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
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          language['code']!.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
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
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    subtitle: Text(
                      language['native']!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          )
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
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildTagline(),
                        const SizedBox(height: 16),
                        _buildCarousel(),
                        const SizedBox(height: 16),
                        _buildCarouselIndicators(),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Services'),
                        const SizedBox(height: 16),
                        _buildServicesGrid(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Individual Tests'),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Take tests individually with instant results',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildIndividualTestsGrid(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
          if (_isConsultationLoading)
            Positioned.fill(
              child: Container(
                color: AppColors.black.withValues(alpha: 0.1),
                child: const Center(child: EyeLoader.fullScreen()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final selectedLang = _languages.firstWhere(
      (l) => l['name'] == _selectedLanguage,
      orElse: () => _languages.first,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 120,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/images/icons/app_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showLanguageSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedLang['code']!.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (_user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: _user!),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _user?.firstName.isNotEmpty == true
                          ? _user!.firstName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Hello, ${_user?.firstName ?? 'User'} ðŸ‘‹',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How can we help you today?',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_red_eye, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Your Vision, Our Priority',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight =
        screenHeight * 0.22; // Approximately 22% of screen height

    return CarouselSlider(
      options: CarouselOptions(
        height: carouselHeight > 220
            ? 220
            : (carouselHeight < 180 ? 180 : carouselHeight),
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        enlargeCenterPage: true,
        enlargeFactor: 0.1,
        viewportFraction: 0.92,
        onPageChanged: (index, reason) =>
            setState(() => _currentCarouselIndex = index),
      ),
      items: _carouselSlides.map((slide) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: slide['hasImages'] as bool
                      ? _buildSlideWithImages(slide)
                      : _buildSlideWithoutImages(slide),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSlideWithImages(Map<String, dynamic> slide) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Text content (left side)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                slide['heading'] as String,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slide['content'] as String,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                slide['supportText'] as String,
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Founder images (right side) - staggered diagonally
        SizedBox(
          width: 70,
          height: 150, // Reduced from 190
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: _buildFounderImage('assets/images/founder_image_1.png'),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: _buildFounderImage('assets/images/founder_image_2.png'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFounderImage(String imagePath) {
    return Container(
      width: 45, // Reduced from 50
      height: 85, // Reduced from 100
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.white.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                color: AppColors.white.withValues(alpha: 0.6),
                size: 28,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlideWithoutImages(Map<String, dynamic> slide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          slide['heading'] as String,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide['content'] as String,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            slide['supportText'] as String,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _carouselSlides.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentCarouselIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentCarouselIndex == index
                ? AppColors.primary
                : AppColors.divider,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildServicesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  icon: Icons.speed_rounded,
                  title: 'Quick Test',
                  onTap: () => Navigator.pushNamed(context, '/quick-test'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceCard(
                  icon: Icons.assessment_rounded,
                  title: 'Full Eye Exam',
                  onTap: () =>
                      Navigator.pushNamed(context, '/comprehensive-test'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  icon: Icons.history_rounded,
                  title: 'My Results',
                  onTap: () => Navigator.pushNamed(context, '/my-results'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'Consultation',
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  icon: Icons.remove_red_eye_rounded,
                  title: 'Visiaxx TV',
                  onTap: () => Navigator.pushNamed(context, '/eye-exercises'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Eye Care Tips',
                  onTap: () => Navigator.pushNamed(context, '/eye-care-tips'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualTestsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/individual-tests'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'View All Individual Tests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '6 tests available â€¢ Tap to explore',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

