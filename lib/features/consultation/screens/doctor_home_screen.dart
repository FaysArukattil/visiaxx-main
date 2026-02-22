import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/ui_utils.dart';

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
  DoctorModel? _doctor;
  bool _isLoading = true;
  int _totalPatients = 0;
  int _todaysSlots = 0;
  int _completedConsultations = 0;
  int _pendingRequests = 0;
  List<ConsultationBookingModel> _upcomingBookings = [];
  List<ConsultationBookingModel> _pendingBookings = [];
  StreamSubscription<List<ConsultationBookingModel>>? _bookingsSubscription;

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
    // Proactively check if user is already in cache to avoid full-screen loader flicker
    final cachedUser = _authService.cachedUser;
    if (cachedUser != null) {
      _user = cachedUser;
      _isLoading = false;
    }
    _loadData();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // If we don't have a user yet, try to get it
    final user = _user ?? await _authService.getCurrentUserProfile();

    if (user != null) {
      // Auto-expire past-due pending bookings first
      await _consultationService.autoExpireBookings(user.id);

      // Parallel fetch for non-booking stats
      final results = await Future.wait([
        _consultationService.getDoctorPatients(user.id),
        _consultationService.getAvailableSlots(user.id, DateTime.now()),
      ]);

      final patients = results[0] as List;
      final todaySlots = results[1] as List;
      final doctor = await _consultationService.getDoctorById(user.id);

      if (mounted) {
        setState(() {
          _user = user;
          _doctor = doctor;
          _totalPatients = patients.length;
          _todaysSlots = todaySlots.length;
          _isLoading = false;
        });
      }

      // Subscribe to real-time bookings stream for instant updates
      _bookingsSubscription?.cancel();
      _bookingsSubscription = _consultationService
          .getDoctorBookingsStream(user.id)
          .listen((bookings) {
            if (mounted) {
              setState(() {
                _completedConsultations = bookings
                    .where((b) => b.status == BookingStatus.completed)
                    .length;
                _pendingRequests = bookings
                    .where((b) => b.status == BookingStatus.requested)
                    .length;
                _pendingBookings = bookings
                    .where((b) => b.status == BookingStatus.requested)
                    .take(5)
                    .toList();
                _upcomingBookings = bookings
                    .where((b) => b.status == BookingStatus.confirmed)
                    .take(5)
                    .toList();
              });
            }
          });
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: EyeLoader(
            size: 60,
          ), // Increased base size, will scale to 120 on laptop
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 900;
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: isWeb
                        ? _buildWebLayout(constraints)
                        : _buildMobileLayout(constraints),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
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
                _buildSectionTitle('Live Analytics', Icons.insights_rounded),
                _buildStatsRow(constraints),
                const SizedBox(height: 32),
                _buildSectionTitle('Quick Actions', Icons.bolt_rounded),
                _buildQuickActionsGrid(constraints),
                if (_pendingBookings.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    'Pending Requests ($_pendingRequests)',
                    Icons.pending_actions_rounded,
                  ),
                  _buildPendingRequestsList(),
                ],
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
  }

  Widget _buildWebLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Web Hero Section
          _buildWebHero(),
          const SizedBox(height: 40),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Stats & Patients
              Expanded(
                flex: 65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      'Live Analytics',
                      Icons.insights_rounded,
                    ),
                    _buildWebStatsGrid(),
                    const SizedBox(height: 48),
                    _buildSectionTitle('Patient Hub', Icons.people_rounded),
                    _buildWebPatientHub(),
                  ],
                ),
              ),
              const SizedBox(width: 40),

              // Right Column: Tools & Analytics
              Expanded(
                flex: 35,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Command Center', Icons.bolt_rounded),
                    _buildWebActionPalette(),
                    const SizedBox(height: 48),
                    _buildSectionTitle(
                      'Performance brief',
                      Icons.analytics_rounded,
                    ),
                    _buildWebAnalyticsBrief(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildWebHero() {
    return _WebGlassCard(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Home,',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _doctor?.specialty.isNotEmpty == true
                      ? _doctor!.specialty.toUpperCase()
                      : 'CERTIFIED DOCTOR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dr. ${_user?.fullName ?? ""}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: context.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: context.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Visiaxx Doctor Portal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Featured Portrait Image in Hero for Web
          if (_doctor?.photoUrl != null && _doctor!.photoUrl.isNotEmpty)
            Container(
              width: 200,
              height: 200,
              margin: const EdgeInsets.only(left: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: context.primary.withValues(alpha: 0.2),
                  width: 4,
                ),
                image: DecorationImage(
                  image: NetworkImage(_doctor!.photoUrl),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
            )
          else
            SizedBox(width: 400, child: _buildCarousel(const BoxConstraints())),
        ],
      ),
    );
  }

  Widget _buildWebStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _WebGlassCard(
            child: _statCard(
              'TOTAL PATIENTS',
              _totalPatients.toString(),
              Icons.people_rounded,
              Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _WebGlassCard(
            child: _statCard(
              'TODAY SLOTS',
              _todaysSlots.toString(),
              Icons.schedule_rounded,
              Colors.orange,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _WebGlassCard(
            child: _statCard(
              'COMPLETED',
              _completedConsultations.toString(),
              Icons.verified_rounded,
              Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebPatientHub() {
    return _WebGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Today\'s Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.onSurface,
                ),
              ),
              const Spacer(),
              _buildHeaderAction(Icons.filter_list_rounded, () {}),
              _buildHeaderAction(Icons.search_rounded, () {}),
            ],
          ),
          const SizedBox(height: 24),
          if (_upcomingBookings.isEmpty)
            _buildUpcomingConsultations()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingBookings.length,
              itemBuilder: (context, index) {
                final booking = _upcomingBookings[index];
                return _BookingTile(booking: booking, isWeb: true);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWebActionPalette() {
    return _WebGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _WebActionTile(
            icon: Icons.pending_actions_rounded,
            title: 'Review Requests',
            subtitle: '$_pendingRequests pending',
            color: Colors.orange,
            onTap: () => Navigator.pushNamed(context, '/doctor-booking-review'),
          ),
          const SizedBox(height: 16),
          _WebActionTile(
            icon: Icons.calendar_today_rounded,
            title: 'Manage Slots',
            subtitle: 'Update schedule',
            color: context.primary,
            onTap: () => Navigator.pushNamed(context, '/doctor-slots'),
          ),
          const SizedBox(height: 16),
          _WebActionTile(
            icon: Icons.videocam_rounded,
            title: 'Virtual Clinic',
            subtitle: 'Start tele-health',
            color: Colors.blue,
            onTap: () {},
          ),
          const SizedBox(height: 16),
          _WebActionTile(
            icon: Icons.folder_shared_rounded,
            title: 'Patient Vault',
            subtitle: 'Medical records',
            color: Colors.teal,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildWebAnalyticsBrief() {
    return _WebGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Response Rate',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '98% positive feedback',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(
            value: 0.98,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(Colors.green),
            borderRadius: BorderRadius.all(Radius.circular(10)),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BoxConstraints constraints) {
    final horizontalPadding = constraints.maxWidth * 0.045;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final logoWidth = (screenWidth * 0.3).clamp(120.0, 160.0);
    final logoHeight = (screenHeight * 0.07).clamp(60.0, 75.0);

    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (screenWidth <= 900)
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
              if (_doctor?.photoUrl != null && _doctor!.photoUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.primary.withValues(alpha: 0.15),
                        width: 2,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(_doctor!.photoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              _buildHeaderAction(Icons.notifications_none_rounded, () {}),
              if (constraints.maxWidth <= 900)
                _buildHeaderAction(Icons.logout_rounded, () async {
                  final confirm = await UIUtils.showLogoutConfirmation(context);
                  if (confirm == true) {
                    final nav = Navigator.of(context);
                    await _authService.signOut();
                    nav.pushReplacementNamed('/login');
                  }
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

  Widget _buildPendingRequestsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingBookings.length,
      itemBuilder: (context, index) {
        final booking = _pendingBookings[index];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/doctor-booking-review'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.06),
                  blurRadius: 12,
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.timeSlot} · ${booking.type == ConsultationType.online ? 'Online' : 'In-Person'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'REVIEW',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.person, color: context.primary, size: 20),
        ),
      ),
    );
  }

  Widget _buildSlideWithoutImages(
    Map<String, dynamic> slide,
    double screenWidth,
    double carouselHeight,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slide['heading'] as String,
          style: TextStyle(
            color: context.primary,
            fontSize: (screenWidth * 0.05).clamp(16.0, 22.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide['content'] as String,
          style: TextStyle(
            color: context.onSurface.withValues(alpha: 0.7),
            fontSize: (screenWidth * 0.032).clamp(11.0, 14.0),
            height: 1.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Text(
          slide['supportText'] as String,
          style: TextStyle(
            color: context.primary.withValues(alpha: 0.6),
            fontSize: (screenWidth * 0.028).clamp(10.0, 12.0),
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _carouselSlides.asMap().entries.map((entry) {
        return Container(
          width: _currentCarouselIndex == entry.key ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: context.primary.withValues(
              alpha: _currentCarouselIndex == entry.key ? 0.8 : 0.2,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsRow(BoxConstraints constraints) {
    final isWide = constraints.maxWidth > 600;
    final content = [
      Expanded(
        child: _statCard(
          'TOTAL PATIENTS',
          _totalPatients.toString(),
          Icons.people_rounded,
          Colors.blue,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _statCard(
          'TODAY SLOTS',
          _todaysSlots.toString(),
          Icons.schedule_rounded,
          Colors.orange,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _statCard(
          'COMPLETED',
          _completedConsultations.toString(),
          Icons.verified_rounded,
          Colors.green,
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
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
    ).animate().fadeIn(duration: 500.ms).scale(delay: 100.ms);
  }

  Widget _buildQuickActionsGrid(BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = constraints.maxWidth > 900;
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
  final bool isWeb;
  const _BookingTile({required this.booking, this.isWeb = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: isWeb ? 0.5 : 1.0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWeb
              ? context.primary.withValues(alpha: 0.1)
              : context.dividerColor.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (!isWeb)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        child: Row(
          children: [
            Container(
              width: isWeb ? 64 : 56,
              height: isWeb ? 64 : 56,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
              ),
              child: Icon(
                Icons.person_rounded,
                color: context.primary,
                size: isWeb ? 32 : 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.patientName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isWeb ? 18 : 15,
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
                      if (isWeb) ...[
                        const SizedBox(width: 8),
                        _buildMiniInfoChip(
                          Icons.contact_support_rounded,
                          'Initial Consult',
                          context,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: isWeb ? 12 : 10,
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

class _WebGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _WebGlassCard({required this.child, this.padding});

  @override
  State<_WebGlassCard> createState() => _WebGlassCardState();
}

class _WebGlassCardState extends State<_WebGlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: context.primary.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: context.surface.withValues(
                    alpha: _isHovered ? 0.6 : 0.4,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isHovered
                        ? context.primary.withValues(alpha: 0.3)
                        : context.primary.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _WebActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_WebActionTile> createState() => _WebActionTileState();
}

class _WebActionTileState extends State<_WebActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isHovered ? widget.color : context.onSurface,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _isHovered
                    ? widget.color
                    : context.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
