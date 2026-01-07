import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/data_cleanup_service.dart';
import '../../../core/services/session_monitor_service.dart';

class PractitionerHomeScreen extends StatefulWidget {
  const PractitionerHomeScreen({super.key});

  @override
  State<PractitionerHomeScreen> createState() => _PractitionerHomeScreenState();
}

class _PractitionerHomeScreenState extends State<PractitionerHomeScreen> {
  int _currentCarouselIndex = 0;
  final _authService = AuthService();
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
    if (_authService.currentUserId != null) {
      final user = await _authService.getUserData(_authService.currentUserId!);
      if (mounted && user != null) {
        setState(() {
          _userName = user.firstName;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. Stop session monitoring
      SessionMonitorService().stopMonitoring();

      // 2. Comprehensive cleanup and logout
      if (mounted) {
        await DataCleanupService.cleanupAllData(context);

        // 3. Navigate to login
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
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
              // Practitioner badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Practitioner',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'logout') _handleLogout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 12),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: AppColors.error),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: Colors.white,
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
            'Hello, $_userName 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ready to help your patients today?',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
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
            Icon(Icons.medical_services, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Professional Eye Care Platform',
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
    final carouselHeight = screenHeight * 0.22;

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
                style: TextStyle(
                  color: Colors.grey[800],
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
          height: 150,
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
      width: 45,
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                color: Colors.white.withValues(alpha: 0.6),
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
          style: TextStyle(
            color: Colors.grey[800],
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
                : Colors.grey[300],
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
          color: Colors.grey[900],
        ),
      ),
    );
  }

  Widget _buildServicesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // First row: Add Patient and Full Eye Exam
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  icon: Icons.speed_rounded,
                  title: 'Quick Test',
                  subtitle: 'Immediate vision check',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/practitioner-profile-selection',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceCard(
                  icon: Icons.assessment_rounded,
                  title: 'Full Eye Exam',
                  subtitle: 'Comprehensive analysis',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/practitioner-profile-selection',
                    arguments: {'comprehensive': true},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row: My Results spans full width (no Consultation)
          _WideServiceCard(
            icon: Icons.history_rounded,
            title: 'Patient Results',
            subtitle: 'View all patient test results, organized by date',
            onTap: () => Navigator.pushNamed(context, '/practitioner-results'),
          ),
          const SizedBox(height: 16),
          // Third row: Eye Exercises and Eye Care Tips
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  icon: Icons.self_improvement_rounded,
                  title: 'Eye Exercises',
                  subtitle: 'For patients',
                  onTap: () => Navigator.pushNamed(context, '/eye-exercises'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Eye Care Tips',
                  subtitle: 'Patient education',
                  onTap: () => Navigator.pushNamed(context, '/eye-care-tips'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    this.subtitle,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wide service card spanning full width - used for My Results in practitioner mode
class _WideServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WideServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
}
