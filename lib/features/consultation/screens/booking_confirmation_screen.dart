import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/services/test_result_service.dart';
import '../../../data/models/test_result_model.dart';
import '../../../core/widgets/eye_loader.dart';
import 'in_person_location_screen.dart';
import 'package:provider/provider.dart';
import '../../../data/models/family_member_model.dart';
import '../../../data/providers/family_member_provider.dart';

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key});

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _consultationService = ConsultationService();
  final _authService = AuthService();
  final _testResultService = TestResultService();

  DoctorModel? _doctor;
  DateTime? _date;
  TimeSlotModel? _slot;
  List<String> _attachedResultIds = [];
  double? _latitude;
  double? _longitude;
  String? _exactAddress;
  String? _flat;
  String? _landmark;
  String? _pincode;
  String? _patientName;
  int? _patientAge;
  String? _patientGender;
  bool _isForSelf = true;
  String? _familyMemberId;
  ConsultationType? _type;
  List<TimeSlotModel> _availableSlots = [];
  List<TestResultModel> _previousResults = [];
  bool _isLoadingSlots = false;
  bool _isLoadingResults = false;
  bool _isSubmitting = false;
  bool _isBooked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_doctor != null) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _doctor = args?['doctor'];
    _date = args?['date'];
    _slot = args?['slot'];
    _attachedResultIds = args?['attachedResultIds'] ?? [];
    _latitude = args?['latitude'];
    _longitude = args?['longitude'];
    _exactAddress = args?['exactAddress'];
    _flat = args?['flat'];
    _landmark = args?['landmark'];
    _pincode = args?['pincode'];
    _patientName = args?['patientName'];
    _patientAge = args?['patientAge'];
    _patientGender = args?['patientGender'];
    _isForSelf = args?['isForSelf'] ?? true;
    _familyMemberId = args?['familyMemberId'];
    _type = args?['type'] is String
        ? (args?['type'] == 'inPerson'
              ? ConsultationType.inPerson
              : ConsultationType.online)
        : args?['type'] ?? ConsultationType.online;
    // Default to online if completely missing, but propagation should prevent this now
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    final user = _authService.currentUser;
    if (user != null) {
      await Provider.of<FamilyMemberProvider>(
        context,
        listen: false,
      ).loadFamilyMembers(user.uid);
    }
  }

  Future<void> _finalizeBooking() async {
    if (_doctor == null || _slot == null || _date == null) return;

    if (_type == ConsultationType.inPerson &&
        (_latitude == null || _longitude == null || _exactAddress == null)) {
      SnackbarUtils.showWarning(
        context,
        'Please select a valid visit location and provide your address.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = _authService.currentUser;
    final userProfile = await _authService.getCurrentUserProfile();

    if (user != null && userProfile != null) {
      final booking = ConsultationBookingModel(
        id: '', // Will be generated
        patientId: user.uid,
        doctorId: _doctor!.id,
        doctorName: _doctor!.fullName,
        doctorPhotoUrl: _doctor!.photoUrl,
        patientName:
            _patientName ?? '${userProfile.firstName} ${userProfile.lastName}',
        patientAge: _patientAge,
        patientGender: _patientGender,
        isForSelf: _isForSelf,
        familyMemberId: _familyMemberId,
        dateTime: _date!,
        timeSlot: _slot!.startTime,
        type: _type ?? ConsultationType.online,
        status: BookingStatus.requested,
        attachedResultIds: _attachedResultIds,
        latitude: _latitude,
        longitude: _longitude,
        exactAddress: _exactAddress,
        clinicAddress: _type == ConsultationType.inPerson
            ? '${_flat ?? ''}, ${_landmark != null && _landmark!.isNotEmpty ? '$_landmark, ' : ''}${_exactAddress ?? ''} - ${_pincode ?? ''}'
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _consultationService.requestBooking(booking, _slot!);

      if (result != null) {
        if (mounted) {
          setState(() => _isBooked = true);
          _showSuccessSheet();
        }
      } else {
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to request booking. Please try again.',
          );
        }
      }
    } else {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to load user profile. Please check your connection.',
        );
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showSuccessSheet() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height *
                  (isLandscape ? 0.7 : 0.8),
            ),
            padding: EdgeInsets.fromLTRB(
              isLandscape ? 40 : 32,
              isLandscape ? 32 : 16,
              isLandscape ? 40 : 32,
              isLandscape ? 32 : 40,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: isLandscape
                ? Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 80,
                                  )
                                  .animate()
                                  .scale(delay: 200.ms)
                                  .rotate(duration: 400.ms),
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Request Sent!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your consultation request has been sent to Dr. ${_doctor?.fullName}. You will be notified once it is confirmed.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context); // Close sheet
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/home',
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Back to Home',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSheetHandle(),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 72,
                                  )
                                  .animate()
                                  .scale(delay: 200.ms)
                                  .rotate(duration: 400.ms),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Request Sent!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your consultation request has been sent to Dr. ${_doctor?.fullName}. You will be notified once it is confirmed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close sheet
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ).animate().slideY(
            begin: 1.0,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text('Data missing')));
    }

    final theme = Theme.of(context);
    final color = context.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Decorative background circles
          Positioned(
            top: -100,
            right: -50,
            child: _buildDecorativeCircle(color, 300, 0.03),
          ),
          Positioned(
            bottom: 150,
            left: -50,
            child: _buildDecorativeCircle(color, 250, 0.02),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Review Booking',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 32),
                        const Text(
                          'Schedule Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryItem(
                          Icons.calendar_today_rounded,
                          'Date',
                          DateFormat('EEEE, dd MMM yyyy').format(_date!),
                          color,
                          onEdit: _showSlotSelectionSheet,
                        ),
                        _buildSummaryItem(
                          Icons.access_time_rounded,
                          'Time',
                          _slot!.startTime,
                          color,
                          onEdit: _showSlotSelectionSheet,
                        ),
                        _buildSummaryItem(
                          Icons.location_on_rounded,
                          'Type',
                          _type == ConsultationType.inPerson
                              ? 'In-Person Visit'
                              : 'Online Consultation',
                          color,
                          onEdit: _showTypeSelectionSheet,
                        ),
                        if (_type == ConsultationType.inPerson)
                          _buildSummaryItem(
                            Icons.home_filled,
                            'Visit Address',
                            _flat != null
                                ? '${_flat ?? ''}, ${_landmark != null && _landmark!.isNotEmpty ? '$_landmark, ' : ''}${_exactAddress ?? ''} - ${_pincode ?? ''}'
                                : (_exactAddress ?? 'Address not selected'),
                            color,
                            onEdit: _pickLocation,
                          ),
                        _buildSummaryItem(
                          Icons.person_outline_rounded,
                          'Patient',
                          '$_patientName ${_isForSelf ? '(Self)' : '(Family)'}',
                          color,
                          onEdit: _showPatientSelectionSheet,
                        ),
                        _buildSummaryItem(
                          Icons.attach_file_rounded,
                          'Attached Results',
                          '${_attachedResultIds.length} items',
                          color,
                          onEdit: _showResultsSelectionSheet,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: color.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: color,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'The consultation will be finalized once the doctor confirms your request.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: color.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action
                _buildBottomAction(),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value,
    Color color, {
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Edit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final color = context.primary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              image: _doctor!.photoUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_doctor!.photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _doctor!.photoUrl.isEmpty
                ? Icon(
                    Icons.person_rounded,
                    color: color.withValues(alpha: 0.5),
                    size: 36,
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. ${_doctor!.fullName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _doctor!.specialty,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, isLandscape ? 16 : 32),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isSubmitting || _isBooked) ? null : _finalizeBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, isLandscape ? 44 : 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const EyeLoader(size: 40, color: Colors.white)
            : Text(
                _isBooked ? 'Request Sent' : 'Confirm & Request',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildDecorativeCircle(Color color, double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  void _showTypeSelectionSheet() {
    ConsultationType localType = _type ?? ConsultationType.online;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final color = context.primary;
            return Container(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHandle(),
                  _buildSheetHeader('Update Consultation Type'),
                  _buildTypeOption(
                    'Online Consultation',
                    'Video Call',
                    'Connect with doctors via high-quality video call.',
                    Icons.video_camera_front_rounded,
                    localType == ConsultationType.online,
                    () => setSheetState(
                      () => localType = ConsultationType.online,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTypeOption(
                    'In-Person Visit',
                    'Home Visit',
                    'Our certified doctors visit your doorstep.',
                    Icons.home_work_rounded,
                    localType == ConsultationType.inPerson,
                    () => setSheetState(
                      () => localType = ConsultationType.inPerson,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _type = localType);
                      Navigator.pop(context);
                    },
                    style: _sheetButtonStyle(color),
                    child: const Text('Confirm Change'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeOption(
    String title,
    String subtitle,
    String desc,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final color = context.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : context.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? color : context.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAvailableSlots(
    DateTime date,
    Function setSheetState,
  ) async {
    setSheetState(() => _isLoadingSlots = true);
    try {
      final bookedSlots = await _consultationService.getAllSlotsForDate(
        _doctor!.id,
        date,
      );
      final generatedSlots = _generateDailySlots(date);
      final finalSlots = generatedSlots.map((gen) {
        final booked = bookedSlots
            .where((b) => b.startTime == gen.startTime)
            .firstOrNull;
        return booked ?? gen;
      }).toList();
      setSheetState(() {
        _availableSlots = finalSlots;
        _isLoadingSlots = false;
      });
    } catch (e) {
      setSheetState(() => _isLoadingSlots = false);
    }
  }

  List<TimeSlotModel> _generateDailySlots(DateTime date) {
    final List<TimeSlotModel> slots = [];
    final startTime = DateTime(date.year, date.month, date.day, 10);
    final endTime = DateTime(date.year, date.month, date.day, 22);
    DateTime current = startTime;
    int index = 0;
    while (current.isBefore(endTime)) {
      final next = current.add(const Duration(minutes: 20));
      slots.add(
        TimeSlotModel(
          id: 'gen_${date.millisecondsSinceEpoch}_$index',
          doctorId: _doctor!.id,
          date: date,
          startTime: DateFormat('h:mm a').format(current),
          endTime: DateFormat('h:mm a').format(next),
          status: SlotStatus.available,
        ),
      );
      current = next;
      index++;
    }
    return slots;
  }

  void _showSlotSelectionSheet() {
    DateTime localDate = _date!;
    String? localSlotId = _slot?.id;
    _availableSlots = []; // Reset to force reload for local date

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final color = context.primary;
          if (_availableSlots.isEmpty && !_isLoadingSlots) {
            _loadAvailableSlots(localDate, setSheetState);
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            decoration: BoxDecoration(
              color: context.scaffoldBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                _buildSheetHandle(),
                _buildSheetHeader('Update Schedule'),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: 14,
                    itemBuilder: (context, index) {
                      final date = DateTime.now().add(Duration(days: index));
                      final isSelected = DateUtils.isSameDay(date, localDate);
                      return _buildDateItem(date, isSelected, color, () {
                        setSheetState(() {
                          localDate = date;
                          localSlotId = null;
                          _availableSlots = [];
                        });
                        _loadAvailableSlots(date, setSheetState);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _isLoadingSlots
                      ? const Center(child: EyeLoader(size: 40))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: _availableSlots.length,
                          itemBuilder: (context, index) {
                            final slot = _availableSlots[index];
                            final isSel = localSlotId == slot.id;
                            final isUn = slot.status != SlotStatus.available;
                            return _buildSlotItem(slot, isSel, isUn, color, () {
                              setSheetState(() => localSlotId = slot.id);
                            });
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ElevatedButton(
                    onPressed: localSlotId == null
                        ? null
                        : () {
                            setState(() {
                              _date = localDate;
                              _slot = _availableSlots.firstWhere(
                                (s) => s.id == localSlotId,
                              );
                            });
                            Navigator.pop(context);
                          },
                    style: _sheetButtonStyle(color),
                    child: const Text('Confirm Appointment'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickLocation() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const InPersonLocationScreen(pickerMode: true),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _exactAddress = result['exactAddress'];
        _flat = result['flat'];
        _landmark = result['landmark'];
        _pincode = result['pincode'];
      });
    }
  }

  void _showResultsSelectionSheet() {
    List<String> localSelections = List.from(_attachedResultIds);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final color = context.primary;
          if (_previousResults.isEmpty && !_isLoadingResults) {
            _loadPreviousResults(setSheetState);
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            decoration: BoxDecoration(
              color: context.scaffoldBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                _buildSheetHandle(),
                _buildSheetHeader(
                  'Attach Results',
                  subtitle: '${localSelections.length}/10 selected',
                ),
                Expanded(
                  child: _isLoadingResults
                      ? const Center(child: EyeLoader(size: 40))
                      : _previousResults.isEmpty
                      ? _buildEmptyResultsState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _previousResults.length,
                          itemBuilder: (context, index) {
                            final res = _previousResults[index];
                            final isSel = localSelections.contains(res.id);
                            return _buildResultItem(res, isSel, color, () {
                              setSheetState(() {
                                if (isSel)
                                  localSelections.remove(res.id);
                                else if (localSelections.length < 10)
                                  localSelections.add(res.id);
                                else
                                  SnackbarUtils.showWarning(
                                    context,
                                    'Limit: 10 results',
                                  );
                              });
                            });
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _attachedResultIds = localSelections);
                      Navigator.pop(context);
                    },
                    style: _sheetButtonStyle(color),
                    child: const Text('Confirm Attachments'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadPreviousResults(Function setSheetState) async {
    setSheetState(() => _isLoadingResults = true);
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final results = await _testResultService.getTestResults(user.uid);
        setSheetState(() {
          _previousResults = results;
          _isLoadingResults = false;
        });
      } catch (e) {
        setSheetState(() => _isLoadingResults = false);
      }
    }
  }

  Widget _buildSheetHandle() => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.dividerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildSheetHeader(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 0, 20, 20),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _buildDateItem(
    DateTime date,
    bool isSelected,
    Color color,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 65,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(date).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : color,
              ),
            ),
            Text(
              DateFormat('d').format(date),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildSlotItem(
    TimeSlotModel slot,
    bool isSel,
    bool isUn,
    Color color,
    VoidCallback onTap,
  ) => InkWell(
    onTap: isUn ? null : onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSel
            ? color
            : isUn
            ? context.dividerColor.withValues(alpha: 0.05)
            : color.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSel
              ? color
              : isUn
              ? Colors.transparent
              : color.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Text(
        slot.startTime,
        style: TextStyle(
          fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
          fontSize: 13,
          color: isSel
              ? Colors.white
              : isUn
              ? context.textTertiary
              : context.textPrimary,
          decoration: isUn ? TextDecoration.lineThrough : null,
        ),
      ),
    ),
  );

  Widget _buildResultItem(
    TestResultModel res,
    bool isSel,
    Color color,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.08) : context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? color : color.withValues(alpha: 0.1),
            width: isSel ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getStatusColor(
                  res.overallStatus,
                ).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(res.overallStatus),
                color: _getStatusColor(res.overallStatus),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.profileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(res.timestamp),
                    style: TextStyle(fontSize: 11, color: context.textTertiary),
                  ),
                ],
              ),
            ),
            if (isSel) Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    ),
  );

  Color _getStatusColor(TestStatus status) {
    switch (status) {
      case TestStatus.normal:
        return context.success;
      case TestStatus.review:
        return context.warning;
      case TestStatus.urgent:
        return context.error;
    }
  }

  IconData _getStatusIcon(TestStatus status) {
    switch (status) {
      case TestStatus.normal:
        return Icons.check_circle_rounded;
      case TestStatus.review:
        return Icons.info_rounded;
      case TestStatus.urgent:
        return Icons.warning_rounded;
    }
  }

  ButtonStyle _sheetButtonStyle(Color color) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: Size(double.infinity, isLandscape ? 44 : 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
    );
  }

  Widget _buildEmptyResultsState() => Center(
    child: Text(
      'No results found.',
      style: TextStyle(color: context.textTertiary),
    ),
  );

  void _showPatientSelectionSheet() {
    bool localIsForSelf = _isForSelf;
    String? localFamilyMemberId = _familyMemberId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final color = context.primary;
          final familyProvider = Provider.of<FamilyMemberProvider>(context);

          return Container(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
            decoration: BoxDecoration(
              color: context.scaffoldBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSheetHandle(),
                _buildSheetHeader('Select Patient'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildPatientTypeCard(
                          'Myself',
                          Icons.person_rounded,
                          localIsForSelf,
                          () => setSheetState(() => localIsForSelf = true),
                          color,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPatientTypeCard(
                          'Family',
                          Icons.family_restroom_rounded,
                          !localIsForSelf,
                          () => setSheetState(() => localIsForSelf = false),
                          color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (localIsForSelf)
                  _buildPatientSelfDetails(color)
                else if (familyProvider.familyMembers.isEmpty)
                  _buildEmptyFamilyState()
                else
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: familyProvider.familyMembers.length,
                      itemBuilder: (context, index) {
                        final member = familyProvider.familyMembers[index];
                        final isSelected = localFamilyMemberId == member.id;
                        return _buildFamilyMemberItem(
                          member,
                          isSelected,
                          color,
                          () {
                            setSheetState(
                              () => localFamilyMemberId = member.id,
                            );
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ElevatedButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      if (localIsForSelf) {
                        final userProfile = await _authService
                            .getCurrentUserProfile();
                        if (userProfile == null) {
                          if (context.mounted) {
                            SnackbarUtils.showError(
                              context,
                              'Failed to load user profile. Please try again.',
                            );
                          }
                          return;
                        }
                        if (mounted) {
                          setState(() {
                            _isForSelf = true;
                            _familyMemberId = null;
                            _patientName =
                                '${userProfile.firstName} ${userProfile.lastName}';
                            _patientAge = userProfile.age;
                            _patientGender = userProfile.sex;
                          });
                        }
                      } else {
                        if (localFamilyMemberId == null) {
                          SnackbarUtils.showWarning(
                            context,
                            'Please select a family member',
                          );
                          return;
                        }
                        final member = familyProvider.familyMembers.firstWhere(
                          (m) => m.id == localFamilyMemberId,
                        );
                        if (mounted) {
                          setState(() {
                            _isForSelf = false;
                            _familyMemberId = localFamilyMemberId;
                            _patientName = member.firstName;
                            _patientAge = member.age;
                            _patientGender = member.sex;
                          });
                        }
                      }
                      nav.pop();
                    },
                    style: _sheetButtonStyle(color),
                    child: const Text('Confirm Patient'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientTypeCard(
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color : context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : context.dividerColor.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : context.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSelfDetails(Color color) {
    return FutureBuilder(
      future: _authService.getCurrentUserProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: EyeLoader(size: 30));
        final user = snapshot.data!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.firstName} ${user.lastName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${user.age} yrs • ${user.sex}',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFamilyMemberItem(
    FamilyMemberModel member,
    bool isSelected,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.05) : context.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? color
                  : context.dividerColor.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isSelected
                    ? color
                    : color.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person_outline,
                  color: isSelected ? Colors.white : color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.firstName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? color : context.textPrimary,
                      ),
                    ),
                    Text(
                      '${member.age} yrs • ${member.sex} • ${member.relationship}',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFamilyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 40, color: context.textTertiary),
          const SizedBox(height: 12),
          Text(
            'No family members found.',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
