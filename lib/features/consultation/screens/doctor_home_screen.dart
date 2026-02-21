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
      'heading': 'Professional Care',
      'content':
          'Connect with patients globally and provide premium eye diagnostics.',
      'supportText': 'DIGITAL CLINIC',
      'icon': Icons.medical_services_rounded,
    },
    {
      'heading': 'Advanced Insights',
      'content':
          'Analyze comprehensive test results with our AI-driven diagnostic tools.',
      'supportText': 'DATA INSIGHTS',
      'icon': Icons.analytics_rounded,
    },
    {
      'heading': 'Seamless Workflow',
      'content':
          'Manage your slots and consultation records in one consolidated dashboard.',
      'supportText': 'EFFICIENCY',
      'icon': Icons.auto_graph_rounded,
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

    final theme = Theme.of(context);

    return Stack(
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

        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              floating: true,
              centerTitle: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Dr. ${_user?.firstName ?? ''}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: context.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                _buildHeaderAction(Icons.notifications_none_rounded, () {}),
                _buildHeaderAction(Icons.logout_rounded, () async {
                  final nav = Navigator.of(context);
                  await _authService.signOut();
                  nav.pushReplacementNamed('/login');
                }),
                const SizedBox(width: 16),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCarousel(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Live Analytics',
                      Icons.insights_rounded,
                    ),
                    _buildStatsRow(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Quick Actions', Icons.bolt_rounded),
                    _buildQuickActionsGrid(),
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
        ),
      ],
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

  Widget _buildCarousel() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 180,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.92,
            onPageChanged: (index, reason) =>
                setState(() => _currentCarouselIndex = index),
          ),
          items: _carouselSlides
              .map((slide) => _CarouselSlide(slide: slide))
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _carouselSlides.asMap().entries.map((entry) {
            final isSelected = _currentCarouselIndex == entry.key;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: context.primary.withValues(
                  alpha: isSelected ? 0.8 : 0.2,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
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
      ],
    );
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

  Widget _buildQuickActionsGrid() {
    final isWide = MediaQuery.of(context).size.width > 800;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isWide ? 4 : 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _actionCard(
          'Review Requests',
          Icons.pending_actions_rounded,
          Colors.orange,
          () => Navigator.pushNamed(context, '/doctor-booking-review'),
        ),
        _actionCard(
          'Manage Slots',
          Icons.calendar_view_day_rounded,
          Colors.blue,
          () => Navigator.pushNamed(context, '/doctor-slots'),
        ),
        _actionCard('Tele-Health', Icons.videocam_rounded, Colors.green, () {}),
        _actionCard(
          'Patient Vault',
          Icons.storage_rounded,
          Colors.purple,
          () {},
        ),
      ],
    );
  }

  Widget _actionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.dividerColor.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: context.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselSlide extends StatelessWidget {
  final Map<String, dynamic> slide;
  const _CarouselSlide({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.primary, context.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    slide['supportText'],
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide['heading'],
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  slide['content'],
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(slide['icon'], size: 40, color: AppColors.white),
          ),
        ],
      ),
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
