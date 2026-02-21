import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/widgets/eye_loader.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _currentCarouselIndex = 0;
  final _authService = AuthService();
  final _consultationService = ConsultationService();
  UserModel? _user;
  bool _isLoading = true;
  int _totalPatients = 0;
  int _todaysSlots = 0;
  int _completedConsultations = 0;
  List<ConsultationBookingModel> _upcomingBookings = [];

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
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUserProfile();
    if (user != null) {
      final patients = await _consultationService.getDoctorPatients(user.id);
      final bookings = await _consultationService.getDoctorBookings(user.id);
      final todaySlots = await _consultationService.getAvailableSlots(
        user.id,
        DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _user = user;
          _totalPatients = patients.length;
          _todaysSlots = todaySlots.length;
          _completedConsultations = bookings
              .where((b) => b.status == BookingStatus.completed)
              .length;
          _upcomingBookings = bookings
              .where((b) => b.status == BookingStatus.confirmed)
              .take(5)
              .toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: EyeLoader(size: 40));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Decorations
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.primary.withValues(alpha: 0.08),
                    context.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.05),
                    AppColors.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(constraints)),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth * 0.045,
                        vertical: 16,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCarousel(constraints),
                            const SizedBox(height: 12),
                            _buildCarouselIndicators(),
                            const SizedBox(height: 32),
                            _buildSectionTitle(
                              'Live Analytics',
                              Icons.insights_rounded,
                            ),
                            _buildStatsRow(constraints),
                            const SizedBox(height: 32),
                            _buildSectionTitle(
                              'Quick Actions',
                              Icons.bolt_rounded,
                            ),
                            _buildQuickActionsGrid(constraints),
                            const SizedBox(height: 32),
                            _buildSectionTitle(
                              'Upcoming Consultations',
                              Icons.event_note_rounded,
                            ),
                            _buildUpcomingConsultations(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BoxConstraints constraints) {
    final horizontalPadding = constraints.maxWidth * 0.045;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final logoWidth = (screenWidth * 0.25).clamp(110.0, 150.0);
    final logoHeight = (screenHeight * 0.06).clamp(50.0, 65.0);

    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (constraints.maxWidth <= 800)
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
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.remove_red_eye, color: context.primary),
                    ),
                  ),
                ),
              const Spacer(),
              _buildHeaderAction(Icons.notifications_none_rounded, () {}),
              if (constraints.maxWidth <= 800)
                _buildHeaderAction(Icons.logout_rounded, () async {
                  final nav = Navigator.of(context);
                  await _authService.signOut();
                  nav.pushReplacementNamed('/login');
                }),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Hello, Dr. ${_user?.fullName ?? ''} 👋',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: (screenWidth * 0.055).clamp(18.0, 24.0),
              color: context.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primary.withValues(alpha: 0.08),
                  context.primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.primary.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.primary.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.remove_red_eye, color: context.primary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Vision, Our Priority',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: context.surface,
        shape: BoxShape.circle,
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.05)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: context.onSurface),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: context.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(color: context.dividerColor.withValues(alpha: 0.05)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingConsultations() {
    if (_upcomingBookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: context.dividerColor.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 40,
                color: context.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Consultations Today',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your schedule is clear for now.',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _upcomingBookings.length,
      itemBuilder: (context, index) {
        final booking = _upcomingBookings[index];
        return _BookingTile(booking: booking);
      },
    );
  }

  Widget _buildCarousel(BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Adaptive height calculation
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
          enlargeFactor: 0.1,
          viewportFraction: 0.92,
          padEnds: true,
          onPageChanged: (index, reason) =>
              setState(() => _currentCarouselIndex = index),
        ),
        items: _carouselSlides.map((slide) {
          return Builder(
            builder: (BuildContext context) {
              return Container(
                width: screenWidth * 0.92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.primary.withValues(alpha: 0.08),
                      context.primary.withValues(alpha: 0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: context.primary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.primary.withValues(alpha: 0.08),
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
                                context.primary.withValues(alpha: 0.12),
                                context.primary.withValues(alpha: 0.02),
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
                                context.primary.withValues(alpha: 0.1),
                                context.primary.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: (screenWidth * 0.04).clamp(16.0, 24.0),
                          vertical: (screenWidth * 0.02).clamp(8.0, 12.0),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slide['heading'] as String,
                        style: TextStyle(
                          color: context.primary,
                          fontSize: (availableWidth * 0.06).clamp(15.0, 20.0),
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: (availableHeight * 0.04).clamp(4.0, 8.0),
                      ),
                      Text(
                        slide['content'] as String,
                        style: TextStyle(
                          color: context.onSurface.withValues(alpha: 0.6),
                          fontSize: (availableWidth * 0.035).clamp(11.0, 13.5),
                          height: 1.2,
                        ),
                        maxLines: isBroad ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: (availableHeight * 0.04).clamp(6.0, 10.0),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slide['supportText'] as String,
                          style: TextStyle(
                            color: context.primary,
                            fontSize: (availableWidth * 0.028).clamp(9.0, 11.0),
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
                      height: availableHeight * 0.85,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: (availableWidth * 0.22).clamp(70.0, 110.0),
                            height: (availableWidth * 0.22).clamp(70.0, 110.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.primary.withValues(alpha: 0.04),
                            ),
                          ),
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
    final imageWidth = (width * 0.15).clamp(38.0, 58.0);
    final imageHeight = (height * 0.42).clamp(70.0, 95.0);

    return Container(
      width: imageWidth,
      height: imageHeight,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: context.primary.withValues(alpha: 0.1),
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
              color: context.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person,
                color: context.primary.withValues(alpha: 0.6),
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
                    color: context.primary,
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
                    color: context.onSurface.withValues(alpha: 0.6),
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
                    color: context.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    slide['supportText'] as String,
                    style: TextStyle(
                      color: context.primary,
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
                  ? context.primary
                  : context.dividerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BoxConstraints constraints) {
    final isWide = constraints.maxWidth > 800;
    final content = [
      _statCard(
        'PATIENTS',
        _totalPatients.toString(),
        Icons.people_rounded,
        Colors.blue,
      ),
      const SizedBox(width: 12),
      _statCard(
        'TODAY SLOTS',
        _todaysSlots.toString(),
        Icons.schedule_rounded,
        Colors.orange,
      ),
      const SizedBox(width: 12),
      _statCard(
        'COMPLETED',
        _completedConsultations.toString(),
        Icons.verified_rounded,
        Colors.green,
      ),
    ];

    if (isWide) {
      return Row(
        children: [Expanded(child: Row(children: content))],
      );
    }
    return Row(children: content);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.onSurface,
                letterSpacing: -1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: context.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(delay: 100.ms);
  }

  Widget _buildQuickActionsGrid(BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = constraints.maxWidth > 800;
    final cardSpacing = 16.0;
    final compactCardHeight = 100.0;
    final wideCardHeight = 70.0;

    if (isWide) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: cardSpacing,
        crossAxisSpacing: cardSpacing,
        childAspectRatio: 3.5,
        children: [
          _CompactServiceCard(
            icon: Icons.pending_actions_rounded,
            title: 'Review Requests',
            subtitle: 'Pending bookings',
            onTap: () => Navigator.pushNamed(context, '/doctor-booking-review'),
            height: compactCardHeight,
            screenWidth: screenWidth,
          ),
          _CompactServiceCard(
            icon: Icons.calendar_view_day_rounded,
            title: 'Manage Slots',
            subtitle: 'Daily availability',
            onTap: () => Navigator.pushNamed(context, '/doctor-slots'),
            height: compactCardHeight,
            screenWidth: screenWidth,
          ),
          _WideServiceCard(
            icon: Icons.videocam_rounded,
            title: 'Tele-Health Consultation',
            subtitle: 'Start a video session',
            onTap: () {},
            height: wideCardHeight,
            screenWidth: screenWidth,
          ),
          _WideServiceCard(
            icon: Icons.storage_rounded,
            title: 'Patient Vault',
            subtitle: 'Access patient records',
            onTap: () {},
            height: wideCardHeight,
            screenWidth: screenWidth,
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CompactServiceCard(
                icon: Icons.pending_actions_rounded,
                title: 'Review Requests',
                subtitle: 'Pending bookings',
                onTap: () =>
                    Navigator.pushNamed(context, '/doctor-booking-review'),
                height: compactCardHeight,
                screenWidth: screenWidth,
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _CompactServiceCard(
                icon: Icons.calendar_view_day_rounded,
                title: 'Manage Slots',
                subtitle: 'Daily availability',
                onTap: () => Navigator.pushNamed(context, '/doctor-slots'),
                height: compactCardHeight,
                screenWidth: screenWidth,
              ),
            ),
          ],
        ),
        SizedBox(height: cardSpacing),
        _WideServiceCard(
          icon: Icons.videocam_rounded,
          title: 'Tele-Health Consultation',
          subtitle: 'Start a video session',
          onTap: () {},
          height: wideCardHeight,
          screenWidth: screenWidth,
        ),
        SizedBox(height: cardSpacing),
        _WideServiceCard(
          icon: Icons.storage_rounded,
          title: 'Patient Vault',
          subtitle: 'Access patient records',
          onTap: () {},
          height: wideCardHeight,
          screenWidth: screenWidth,
        ),
      ],
    );
  }
}

class _BookingTile extends StatelessWidget {
  final ConsultationBookingModel booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person_rounded,
                color: context.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.patientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildMiniInfoChip(
                        Icons.schedule_rounded,
                        booking.timeSlot,
                        context,
                      ),
                      const SizedBox(width: 8),
                      _buildMiniInfoChip(
                        booking.type == ConsultationType.online
                            ? Icons.videocam_rounded
                            : Icons.home_rounded,
                        booking.type == ConsultationType.online
                            ? 'Online'
                            : 'In-Person',
                        context,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfoChip(IconData icon, String text, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 10, color: context.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
      ],
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
    final Color activeColor = context.primary;
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
            splashColor: activeColor.withValues(alpha: 0.1),
            highlightColor: activeColor.withValues(alpha: 0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor.withValues(alpha: 0.08),
                    activeColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                constraints: BoxConstraints(minHeight: height),
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (height > 60) ...[
                      Container(
                        width: iconSize + 14,
                        height: iconSize + 14,
                        decoration: BoxDecoration(
                          color: context.scaffoldBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: activeColor, size: iconSize),
                      ),
                      SizedBox(height: cardPadding * 0.8),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: titleFontSize,
                            color: activeColor,
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
                            color: context.textSecondary,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
    final Color activeColor = context.primary;
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
            splashColor: activeColor.withValues(alpha: 0.1),
            highlightColor: activeColor.withValues(alpha: 0.05),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor.withValues(alpha: 0.08),
                    activeColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.15),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                constraints: BoxConstraints(minHeight: height),
                padding: EdgeInsets.symmetric(
                  horizontal: (cardConstraints.maxWidth * 0.04).clamp(
                    12.0,
                    18.0,
                  ),
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (height > 40) ...[
                      Container(
                        width: iconSize + 14,
                        height: iconSize + 14,
                        decoration: BoxDecoration(
                          color: context.scaffoldBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: activeColor, size: iconSize),
                      ),
                      SizedBox(
                        width: (cardConstraints.maxWidth * 0.03).clamp(
                          8.0,
                          14.0,
                        ),
                      ),
                    ],
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
                              color: activeColor,
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
                              color: context.textSecondary,
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
                        color: context.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: (cardConstraints.maxWidth * 0.038).clamp(
                          16.0,
                          20.0,
                        ),
                        color: context.primary,
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
