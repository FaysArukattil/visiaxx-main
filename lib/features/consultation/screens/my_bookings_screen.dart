import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../home/widgets/app_bar_widget.dart';
import 'patient_video_call_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _consultationService = ConsultationService();
  final _authService = AuthService();
  List<ConsultationBookingModel> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    if (user != null) {
      print('[MyBookingsScreen] Loading bookings for UID: ${user.uid}');
      final bookings = await _consultationService.getPatientBookings(user.uid);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'My Bookings'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              color: context.primary,
              child: _bookings.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        return _BookingListTile(
                              booking: _bookings[index],
                              onCancel: () =>
                                  _cancelBooking(_bookings[index].id),
                              onDelete: () =>
                                  _deleteBooking(_bookings[index].id),
                            )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: (index * 50).ms)
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              duration: 400.ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.calendar_today_outlined,
              size: 64,
              color: context.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Keep Track of Your Health',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your upcoming and past consultations will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/consultation-type'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Book Now',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Cancel Request?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Are you sure you want to cancel this consultation request?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No, Keep It',
              style: TextStyle(color: context.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _consultationService.updateBookingStatus(
          bookingId,
          BookingStatus.cancelled,
        );
        await _loadBookings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: $e')),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Record?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This will permanently remove the record from your bookings history. This cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _consultationService.deleteBooking(bookingId);
        await _loadBookings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete booking: $e')),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }
}

class _BookingListTile extends StatelessWidget {
  final ConsultationBookingModel booking;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  const _BookingListTile({required this.booking, this.onCancel, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(booking.status);
    final color = context.primary;

    return GestureDetector(
      onLongPress:
          (booking.status == BookingStatus.cancelled ||
              booking.status == BookingStatus.completed)
          ? onDelete
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: context.dividerColor.withValues(alpha: 0.05),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        image:
                            (booking.doctorPhotoUrl != null &&
                                booking.doctorPhotoUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(booking.doctorPhotoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child:
                          (booking.doctorPhotoUrl == null ||
                              booking.doctorPhotoUrl!.isEmpty)
                          ? Icon(Icons.person, color: color, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  booking.doctorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(booking.status, statusColor),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.type == ConsultationType.online
                                ? 'Online Consultation'
                                : 'In-Person Visit',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Patient: ${booking.patientName}${booking.isForSelf ? ' (Self)' : ''}',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: context.dividerColor.withValues(alpha: 0.05),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInfoChip(
                          Icons.calendar_month_rounded,
                          DateFormat('dd MMM yyyy').format(booking.dateTime),
                          context,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.access_time_filled_rounded,
                          booking.timeSlot,
                          context,
                        ),
                      ],
                    ),
                    if (booking.status == BookingStatus.requested)
                      TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded, size: 14),
                        label: const Text('Cancel Request'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (booking.status == BookingStatus.confirmed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: ElevatedButton(
                    onPressed: _isSlotActive(booking)
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PatientVideoCallScreen(booking: booking),
                            ),
                          )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSlotActive(booking)
                          ? context.primary
                          : context.dividerColor.withValues(alpha: 0.1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_rounded),
                        const SizedBox(width: 12),
                        Text(
                          _isSlotActive(booking)
                              ? 'Join Video Consultation'
                              : 'Starts at ${booking.timeSlot}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BookingStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textTertiary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSlotActive(ConsultationBookingModel booking) {
    // Basic implementation: Allow joining 5 mins before and during the 20-min slot
    final now = DateTime.now();
    final slotDate = booking.dateTime;

    // Parse timeSlot string "10:00 AM"
    try {
      final timeParts = booking.timeSlot.split(' ');
      final hms = timeParts[0].split(':');
      int hour = int.parse(hms[0]);
      int minute = int.parse(hms[1]);

      if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'PM' &&
          hour < 12) {
        hour += 12;
      } else if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }

      final slotStartTime = DateTime(
        slotDate.year,
        slotDate.month,
        slotDate.day,
        hour,
        minute,
      );

      final slotEndTime = slotStartTime.add(const Duration(minutes: 20));
      final earlyJoinTime = slotStartTime.subtract(const Duration(minutes: 5));

      return now.isAfter(earlyJoinTime) && now.isBefore(slotEndTime);
    } catch (e) {
      return false;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.requested:
        return 'REQUEST SENT';
      case BookingStatus.confirmed:
        return 'CONFIRMED';
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.cancelled:
        return 'CANCELLED';
      case BookingStatus.noShow:
        return 'NO SHOW';
    }
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.requested:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.completed:
        return Colors.blue;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.noShow:
        return Colors.grey;
    }
  }
}
