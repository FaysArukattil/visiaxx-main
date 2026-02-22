import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/widgets/eye_loader.dart';
import 'doctor_video_call_screen.dart';

class VirtualClinicScreen extends StatefulWidget {
  final String doctorId;

  const VirtualClinicScreen({super.key, required this.doctorId});

  @override
  State<VirtualClinicScreen> createState() => _VirtualClinicScreenState();
}

class _VirtualClinicScreenState extends State<VirtualClinicScreen> {
  final _consultationService = ConsultationService();
  bool _isLoading = true;
  List<ConsultationBookingModel> _queue = [];

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  void _loadQueue() {
    setState(() => _isLoading = true);
    // Listen to today's confirmed bookings for this doctor
    _consultationService.getDoctorBookingsStream(widget.doctorId).listen((
      bookings,
    ) {
      if (mounted) {
        final today = DateTime.now();
        final todayQueue = bookings.where((b) {
          final isToday =
              b.dateTime.year == today.year &&
              b.dateTime.month == today.month &&
              b.dateTime.day == today.day;
          return isToday && b.status == BookingStatus.confirmed;
        }).toList();

        // Sort by timeSlot if possible
        todayQueue.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));

        setState(() {
          _queue = todayQueue;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stack(
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

              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      'Virtual Clinic',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // Header Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildWelcomeCard(),
                    ),
                  ),

                  // Queue Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LIVE QUEUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: context.primary,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_queue.length} Patients Waiting',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isLoading)
                    const SliverFillRemaining(
                      child: Center(child: EyeLoader(size: 40)),
                    )
                  else if (_queue.isEmpty)
                    SliverFillRemaining(child: _buildEmptyQueue())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final booking = _queue[index];
                          return _buildQueueCard(booking, index);
                        }, childCount: _queue.length),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.primary, context.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Start Consultation",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      "Your virtual waiting room is active",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildQueueCard(ConsultationBookingModel booking, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  "#${index + 1}",
                  style: TextStyle(
                    color: context.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
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
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    booking.timeSlot,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DoctorVideoCallScreen(booking: booking),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'START',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
  }

  Widget _buildEmptyQueue() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 80,
              color: context.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Queue is Empty',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'No patients are waiting today.',
            style: TextStyle(color: context.textSecondary),
          ),
        ],
      ).animate().fadeIn(),
    );
  }
}
