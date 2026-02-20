import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/consultation_booking_model.dart';
import 'patient_results_view_screen.dart';
import 'doctor_video_call_screen.dart';
import '../../home/widgets/app_bar_widget.dart';

class DoctorSlotManagementScreen extends StatefulWidget {
  const DoctorSlotManagementScreen({super.key});

  @override
  State<DoctorSlotManagementScreen> createState() =>
      _DoctorSlotManagementScreenState();
}

class _DoctorSlotManagementScreenState
    extends State<DoctorSlotManagementScreen> {
  final _consultationService = ConsultationService();
  final _authService = AuthService();
  DateTime _selectedDate = DateTime.now();
  List<ConsultationBookingModel> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final uid = _authService.currentUserId;
    if (uid != null) {
      await _consultationService.getAllSlotsForDate(uid, _selectedDate);
      final bookings = await _consultationService.getDoctorBookings(uid);
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    }
  }

  List<String> _generateTimeIntervals() {
    List<String> intervals = [];
    for (int hour = 10; hour < 22; hour++) {
      for (int min = 0; min < 60; min += 20) {
        final time = DateTime(2024, 1, 1, hour, min);
        intervals.add(DateFormat('h:mm a').format(time));
      }
    }
    return intervals;
  }

  ConsultationBookingModel? _getBookingForSlot(String time) {
    try {
      return _bookings.firstWhere(
        (b) =>
            DateUtils.isSameDay(b.dateTime, _selectedDate) &&
            b.timeSlot.toUpperCase() == time.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateBookingStatus(
    ConsultationBookingModel booking,
    BookingStatus status,
  ) async {
    final success = await _consultationService.updateBookingStatus(
      booking.id,
      status,
    );
    if (success) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Manage Slots'),
      body: Column(
        children: [
          _buildDatePicker(),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildSlotsGrid(),
          ),
        ],
      ),
      floatingActionButton: null, // Removed as we use the full 10-10 grid
    );
  }

  Widget _buildSlotsGrid() {
    final intervals = _generateTimeIntervals();
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
        mainAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: intervals.length,
      itemBuilder: (context, index) {
        final time = intervals[index];
        final booking = _getBookingForSlot(time);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: booking != null
                  ? _getStatusColor(booking.status).withValues(alpha: 0.2)
                  : context.dividerColor.withValues(alpha: 0.1),
              width: booking != null ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (booking != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            booking.status,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          booking.status.name.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(booking.status),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Text(
                        'AVAILABLE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (booking != null) ...[
                  Text(
                    booking.patientName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (booking.status == BookingStatus.requested)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _updateBookingStatus(
                              booking,
                              BookingStatus.cancelled,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateBookingStatus(
                              booking,
                              BookingStatus.confirmed,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (booking.status == BookingStatus.confirmed)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DoctorVideoCallScreen(booking: booking),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.videocam,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Start Call',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primary,
                        minimumSize: const Size(double.infinity, 36),
                      ),
                    ),
                  if (booking.attachedResultIds.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientResultsViewScreen(
                            resultIds: booking.attachedResultIds,
                            patientName: booking.patientName,
                          ),
                        ),
                      ),
                      child: const Text(
                        'View Results',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ] else ...[
                  const Text(
                    'No booking yet',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
      default:
        return Colors.grey;
    }
  }

  Widget _buildDatePicker() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 30, // Next 30 days
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() => _selectedDate = date);
                _loadData();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: isSelected ? context.primary : context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? context.primary
                        : context.dividerColor.withValues(alpha: 0.1),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: context.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
