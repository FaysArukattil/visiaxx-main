import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/services/consultation_service.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final _authService = AuthService();
  final _consultationService = ConsultationService();
  UserModel? _user;
  bool _isLoading = true;
  int _totalPatients = 0;
  int _todaysSlots = 0;
  int _completedConsultations = 0;

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
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text('Welcome, Dr. ${_user?.firstName ?? ''}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _authService.signOut().then(
                (_) => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                // TODO: Add list of today's bookings
                const SizedBox(height: 100),
              ],
            ),
          ),
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
