import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../home/widgets/app_bar_widget.dart';

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key});

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _consultationService = ConsultationService();
  final _authService = AuthService();

  DoctorModel? _doctor;
  DateTime? _date;
  TimeSlotModel? _slot;
  List<String> _attachedResultIds = [];
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _doctor = args?['doctor'];
    _date = args?['date'];
    _slot = args?['slot'];
    _attachedResultIds = args?['attachedResultIds'] ?? [];
  }

  Future<void> _finalizeBooking() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (_doctor == null || _slot == null || _date == null) return;

    setState(() => _isSubmitting = true);

    final user = _authService.currentUser;
    final userProfile = await _authService.getCurrentUserProfile();

    if (user != null && userProfile != null) {
      final booking = ConsultationBookingModel(
        id: '', // Will be generated
        patientId: user.uid,
        doctorId: _doctor!.id,
        doctorName: _doctor!.fullName,
        patientName: '${userProfile.firstName} ${userProfile.lastName}',
        dateTime: _date!,
        timeSlot: _slot!.startTime,
        type: args?['type'] == 'inPerson'
            ? ConsultationType.inPerson
            : ConsultationType.online,
        status: BookingStatus.requested,
        attachedResultIds: _attachedResultIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _consultationService.requestBooking(
        booking,
        _slot!.id,
      );

      if (result != null) {
        if (mounted) {
          _showSuccessSheet();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to request booking. Please try again.'),
            ),
          );
        }
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Request Sent!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Your consultation request has been sent to the doctor. You will be notified once it is confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close sheet
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Back to Home',
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_doctor == null)
      return const Scaffold(body: Center(child: Text('Data missing')));

    return Scaffold(
      appBar: const AppBarWidget(title: 'Confirm Booking'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildSummaryRow('Date', DateFormat('dd MMM yyyy').format(_date!)),
            _buildSummaryRow('Time', _slot!.startTime),
            _buildSummaryRow(
              'Type',
              _slot!.status == SlotStatus.booked
                  ? 'Online Consultation'
                  : 'In-Person Visit',
            ),
            _buildSummaryRow(
              'Results',
              '${_attachedResultIds.length} attached',
            ),
            const SizedBox(height: 40),
            const Text(
              'Important Note',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The consultation will be booked after the doctor confirms your request. Please check "My Bookings" for status updates.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _finalizeBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.primary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: AppColors.white)
              : const Text(
                  'Confirm & Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: context.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dr. ${_doctor!.fullName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _doctor!.specialty,
                style: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
