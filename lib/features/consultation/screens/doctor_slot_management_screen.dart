import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/widgets/eye_loader.dart';
import 'patient_results_view_screen.dart';
import 'doctor_video_call_screen.dart';

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
      // Auto-expire past-due pending bookings
      await _consultationService.autoExpireBookings(uid);

      final bookings = await _consultationService.getDoctorBookings(uid);
      if (mounted) {
        setState(() {
          // Only show bookings for the selected date
          _bookings = bookings
              .where((b) => DateUtils.isSameDay(b.dateTime, _selectedDate))
              .toList();
          _isLoading = false;
        });
      }
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Decorations
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
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

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomScrollView(
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
                        'Manage Slots',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: (constraints.maxWidth * 0.045).clamp(
                            16.0,
                            40.0,
                          ),
                        ),
                        child: _buildDatePicker(),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (constraints.maxWidth * 0.045).clamp(
                          16.0,
                          40.0,
                        ),
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _buildSectionHeader('Availability Timeline'),
                      ),
                    ),
                    if (_isLoading)
                      const SliverFillRemaining(
                        child: Center(child: EyeLoader(size: 40)),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: (constraints.maxWidth * 0.045).clamp(
                            16.0,
                            40.0,
                          ),
                          vertical: 24,
                        ),
                        sliver: _buildSlotsGrid(constraints),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
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

  Widget _buildSlotsGrid(BoxConstraints constraints) {
    final intervals = _generateTimeIntervals();
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: constraints.maxWidth > 900 ? 3 : 1,
        mainAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final time = intervals[index];
        final booking = _getBookingForSlot(time);
        return _buildSlotCard(time, booking, index);
      }, childCount: intervals.length),
    );
  }

  Widget _buildSlotCard(
    String time,
    ConsultationBookingModel? booking,
    int index,
  ) {
    final slotTime = DateFormat('h:mm a').parse(time);
    final fullSlotDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slotTime.hour,
      slotTime.minute,
    );
    final isPast = fullSlotDateTime.isBefore(DateTime.now());
    final isAvailable = booking == null && !isPast;
    final isLocked = booking == null && isPast;
    final statusColor = booking != null
        ? _getStatusColor(booking.status)
        : Colors.green;

    return Container(
          decoration: BoxDecoration(
            color: isLocked
                ? context.surface.withValues(alpha: 0.5)
                : context.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isAvailable
                  ? context.dividerColor.withValues(alpha: 0.05)
                  : isLocked
                  ? context.dividerColor.withValues(alpha: 0.1)
                  : statusColor.withValues(alpha: 0.2),
              width: isAvailable ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isAvailable ? Colors.black : statusColor).withValues(
                  alpha: 0.03,
                ),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: context.primary,
                        ),
                      ),
                    ),
                    _buildStatusBadge(
                      isAvailable
                          ? 'AVAILABLE'
                          : isLocked
                          ? 'EXPIRED'
                          : booking?.status.name.toUpperCase() ?? '',
                      isLocked ? Colors.grey : statusColor,
                    ),
                  ],
                ),
                const Spacer(),
                if (booking != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: context.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Patient',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (booking.status == BookingStatus.requested)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallActionButton(
                            'Reject',
                            AppColors.error,
                            false,
                            () => _updateBookingStatus(
                              booking,
                              BookingStatus.cancelled,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallActionButton(
                            'Accept',
                            Colors.green,
                            true,
                            () => _updateBookingStatus(
                              booking,
                              BookingStatus.confirmed,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (booking.status == BookingStatus.confirmed)
                    _buildSmallActionButton(
                      'START MEETING',
                      context.primary,
                      true,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DoctorVideoCallScreen(booking: booking),
                          ),
                        );
                      },
                      icon: Icons.videocam_rounded,
                    )
                  else if (booking.attachedResultIds.isNotEmpty)
                    _buildSmallActionButton(
                      'VIEW RESULTS',
                      context.primary,
                      false,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientResultsViewScreen(
                              resultIds: booking.attachedResultIds,
                              patientName: booking.patientName,
                              patientId: booking.patientId,
                            ),
                          ),
                        );
                      },
                      icon: Icons.visibility_rounded,
                    ),
                ] else
                  Text(
                    isLocked
                        ? 'This time slot has passed and is no longer available for booking.'
                        : 'No current appointments scheduled for this time slot.',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index % 10 * 50).ms)
        .scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildSmallActionButton(
    String label,
    Color color,
    bool isPrimary,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPrimary ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isPrimary
                ? null
                : Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isPrimary ? AppColors.white : color,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isPrimary ? AppColors.white : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
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
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 30,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                  _loadData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 70,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.primary,
                              context.primary.withValues(alpha: 0.8),
                            ],
                          )
                        : null,
                    color: isSelected ? null : context.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? context.primary
                          : context.dividerColor.withValues(alpha: 0.05),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: context.primary.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isSelected
                              ? AppColors.white
                              : context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isSelected
                              ? AppColors.white
                              : context.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
