import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../home/widgets/app_bar_widget.dart';
import 'patient_results_view_screen.dart';

class DoctorBookingReviewScreen extends StatefulWidget {
  const DoctorBookingReviewScreen({super.key});

  @override
  State<DoctorBookingReviewScreen> createState() =>
      _DoctorBookingReviewScreenState();
}

class _DoctorBookingReviewScreenState extends State<DoctorBookingReviewScreen> {
  final _consultationService = ConsultationService();
  final _authService = AuthService();
  List<ConsultationBookingModel> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final uid = _authService.currentUserId;
    if (uid != null) {
      final allBookings = await _consultationService.getDoctorBookings(uid);
      setState(() {
        _requests = allBookings
            .where((b) => b.status == BookingStatus.requested)
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(
    ConsultationBookingModel booking,
    BookingStatus newStatus,
  ) async {
    String? zoomLink;
    if (newStatus == BookingStatus.confirmed &&
        booking.type == ConsultationType.online) {
      zoomLink = await _showLinkDialog();
      if (zoomLink == null) return; // Cancelled dialog
    }

    final success = await _consultationService.updateBookingStatus(
      booking.id,
      newStatus,
      zoomLink: zoomLink,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking ${newStatus == BookingStatus.confirmed ? 'confirmed' : 'rejected'}.',
          ),
        ),
      );
      _loadRequests();
    }
  }

  Future<String?> _showLinkDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Meeting Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste Zoom/Google Meet link here',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Review Requests'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? _buildEmptyState()
          : _buildRequestsList(),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final booking = _requests[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: context.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            booking.type == ConsultationType.online
                                ? 'Online Consultation'
                                : 'In-Person Visit',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _infoChip(
                      Icons.calendar_today,
                      DateFormat('MMM d, yyyy').format(booking.dateTime),
                    ),
                    const SizedBox(width: 12),
                    _infoChip(Icons.access_time, booking.timeSlot),
                  ],
                ),
                if (booking.attachedResultIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${booking.attachedResultIds.length} Test Results Attached',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientResultsViewScreen(
                                resultIds: booking.attachedResultIds,
                                patientName: booking.patientName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text(
                          'View',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _updateStatus(booking, BookingStatus.cancelled),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _updateStatus(booking, BookingStatus.confirmed),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text('All caught up!'),
          const SizedBox(height: 8),
          Text(
            'No pending consultation requests.',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
