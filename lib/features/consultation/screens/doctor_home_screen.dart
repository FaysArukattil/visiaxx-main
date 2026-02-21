import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/extensions/theme_extension.dart';

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
      'heading': 'Manage Consultations',
      'content':
          'Seamlessly connect with patients and manage your daily schedule.',
      'supportText': 'Digital Healthcare',
      'icon': Icons.video_call,
    },
    {
      'heading': 'Patient Records',
      'content':
          'Access patient histories and test results instantly during calls.',
      'supportText': 'Data-Driven Care',
      'icon': Icons.folder_shared,
    },
    {
      'heading': 'Global Reach',
      'content': 'Consult with patients from Mumbai and beyond with Visiaxx.',
      'supportText': 'Expanding Access',
      'icon': Icons.public,
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
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text('Welcome, Dr. ${_user?.firstName ?? ''}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final nav = Navigator.of(context);
                await _authService.signOut();
                nav.pushReplacementNamed('/login');
              },
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCarousel(),
                const SizedBox(height: 32),
                _buildStatsRow(),
                const SizedBox(height: 32),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildQuickActionsGrid(),
                const SizedBox(height: 32),
                const Text(
                  'Upcoming Consultations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildUpcomingConsultations(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingConsultations() {
    if (_upcomingBookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No confirmed bookings for today.',
              style: TextStyle(color: AppColors.textSecondary),
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
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: context.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.person),
            ),
            title: Text(
              booking.patientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${booking.timeSlot} • ${booking.type == ConsultationType.online ? 'Online' : 'In-Person'}',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Confirmed',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarousel() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 160,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.95,
            onPageChanged: (index, reason) =>
                setState(() => _currentCarouselIndex = index),
          ),
          items: _carouselSlides
              .map((slide) => _CarouselSlide(slide: slide))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _carouselSlides.asMap().entries.map((entry) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primary.withValues(
                  alpha: _currentCarouselIndex == entry.key ? 0.8 : 0.2,
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
          'Total Patients',
          _totalPatients.toString(),
          Icons.people,
          Colors.blue,
        ),
        const SizedBox(width: 16),
        _statCard(
          'Today\'s Slots',
          _todaysSlots.toString(),
          Icons.timer,
          Colors.orange,
        ),
        const SizedBox(width: 16),
        _statCard(
          'Completed',
          _completedConsultations.toString(),
          Icons.check_circle,
          Colors.green,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _actionCard(
          'Review Requests',
          Icons.pending_actions,
          Colors.orange,
          () => Navigator.pushNamed(context, '/doctor-booking-review'),
        ),
        _actionCard(
          'Set Availability',
          Icons.edit_calendar,
          Colors.blue,
          () => Navigator.pushNamed(context, '/doctor-slots'),
        ),
        _actionCard('Start Meeting', Icons.video_call, Colors.green, () {}),
        _actionCard(
          'Patient Records',
          Icons.folder_shared,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
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
          colors: [context.primary.withValues(alpha: 0.8), context.primary],
        ),
        borderRadius: BorderRadius.circular(24),
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    slide['supportText'],
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide['heading'],
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slide['content'],
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            slide['icon'],
            size: 64,
            color: AppColors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}
