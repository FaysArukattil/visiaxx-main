import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/widgets/eye_loader.dart';
import 'patient_results_view_screen.dart';

class DoctorBookingReviewScreen extends StatefulWidget {
  const DoctorBookingReviewScreen({super.key});

  @override
  State<DoctorBookingReviewScreen> createState() =>
      _DoctorBookingReviewScreenState();
}

class _DoctorBookingReviewScreenState extends State<DoctorBookingReviewScreen>
    with SingleTickerProviderStateMixin {
  final _consultationService = ConsultationService();
  final _authService = AuthService();
  List<ConsultationBookingModel> _allBookings = [];
  List<ConsultationBookingModel> _filteredBookings = [];
  bool _isLoading = true;
  late TabController _tabController;
  StreamSubscription<List<ConsultationBookingModel>>? _bookingsSubscription;

  static const _tabs = ['Pending', 'Confirmed', 'Completed', 'Cancelled'];
  static const _tabStatuses = [
    BookingStatus.requested,
    BookingStatus.confirmed,
    BookingStatus.completed,
    BookingStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _startListening();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _filterBookings();
    }
  }

  void _filterBookings() {
    final status = _tabStatuses[_tabController.index];
    setState(() {
      _filteredBookings = _allBookings
          .where((b) => b.status == status)
          .toList();
    });
  }

  void _startListening() {
    final uid = _authService.currentUserId;
    if (uid != null) {
      // Auto-expire old pending bookings first, then start stream
      _consultationService.autoExpireBookings(uid).then((_) {
        _bookingsSubscription?.cancel();
        _bookingsSubscription = _consultationService
            .getDoctorBookingsStream(uid)
            .listen((allBookings) {
              if (mounted) {
                setState(() {
                  _allBookings = allBookings;
                  _isLoading = false;
                });
                _filterBookings();
              }
            });
      });
    }
  }

  Future<void> _loadRequests() async {
    // Kept for pull-to-refresh; re-subscribes to the stream
    _bookingsSubscription?.cancel();
    setState(() => _isLoading = true);
    _startListening();
  }

  Future<void> _updateStatus(
    ConsultationBookingModel booking,
    BookingStatus newStatus,
  ) async {
    final success = await _consultationService.updateBookingStatus(
      booking.id,
      newStatus,
    );

    if (success) {
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Booking ${newStatus == BookingStatus.confirmed ? 'confirmed' : 'rejected'}.',
        );
      }
      // No need to manually reload — the stream handles it
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
            top: -100,
            left: -100,
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
                expandedHeight: 120,
                floating: false,
                pinned: true,
                stretch: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 62),
                  title: Text(
                    'Review Requests',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: context.onSurface,
                    ),
                  ),
                  background: Stack(
                    children: [
                      Positioned(
                        right: 20,
                        top: 40,
                        child: Icon(
                          Icons.request_quote_rounded,
                          size: 80,
                          color: context.primary.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: context.dividerColor.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      labelColor: context.primary,
                      unselectedLabelColor: context.textSecondary,
                      indicatorColor: context.primary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      tabs: _tabs.map((t) {
                        final index = _tabs.indexOf(t);
                        final count = _allBookings
                            .where((b) => b.status == _tabStatuses[index])
                            .length;

                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t),
                              if (count > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _tabStatuses[index] ==
                                            BookingStatus.requested
                                        ? AppColors.error
                                        : context.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color:
                                          _tabStatuses[index] ==
                                              BookingStatus.requested
                                          ? Colors.white
                                          : context.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: EyeLoader(size: 40)),
                )
              else if (_filteredBookings.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: MediaQuery.of(context).size.width > 900
                      ? SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    MediaQuery.of(context).size.width > 1600
                                    ? 3
                                    : 2,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                mainAxisExtent: 420,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final booking = _filteredBookings[index];
                            return _buildRequestCard(booking, isGrid: true);
                          }, childCount: _filteredBookings.length),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final booking = _filteredBookings[index];
                            return _buildRequestCard(booking);
                          }, childCount: _filteredBookings.length),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    ConsultationBookingModel booking, {
    bool isGrid = false,
  }) {
    return Container(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.type == ConsultationType.online
                            ? 'Online Consultation'
                            : 'In-Person Visit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(
                  _getStatusLabel(booking.status),
                  _getStatusColor(booking.status),
                ),
              ],
            ),
          ),

          // Info Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.02),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: context.dividerColor.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoItem(
                      Icons.calendar_today_rounded,
                      DateFormat('MMM d').format(booking.dateTime),
                    ),
                    _infoItem(Icons.access_time_rounded, booking.timeSlot),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _infoItem(
                      Icons.cake_rounded,
                      '${booking.patientAge ?? "--"} yrs',
                    ),
                    _infoItem(
                      Icons.wc_rounded,
                      booking.patientGender ?? 'Unknown',
                    ),
                  ],
                ),
                if (booking.type == ConsultationType.inPerson &&
                    booking.exactAddress != null) ...[
                  const SizedBox(height: 10),
                  _infoItem(
                    Icons.location_on_rounded,
                    booking.exactAddress!,
                    isLong: true,
                  ),
                ],
              ],
            ),
          ),

          // Results Preview
          if (booking.attachedResultIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: InkWell(
                onTap: () {
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        size: 18,
                        color: context.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${booking.attachedResultIds.length} Reports Attached',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: context.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Spacer(),

          // Actions
          if (booking.status == BookingStatus.requested)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'REJECT',
                      AppColors.error,
                      false,
                      () => _updateStatus(booking, BookingStatus.cancelled),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'CONFIRM',
                      Colors.green,
                      true,
                      () => _updateStatus(booking, BookingStatus.confirmed),
                    ),
                  ),
                ],
              ),
            ),

          if (booking.status == BookingStatus.confirmed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildActionButton('JOIN CALL', Colors.blue, true, () {
                // Navigate to call if it's today
                Navigator.pushNamed(
                  context,
                  '/doctor-video-call',
                  arguments: booking,
                );
              }),
            ),

          if (booking.status == BookingStatus.cancelled &&
              booking.doctorNotes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                booking.doctorNotes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOut);
  }

  Widget _infoItem(IconData icon, String label, {bool isLong = false}) {
    return Expanded(
      flex: isLong ? 2 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.onSurface,
              ),
            ),
          ),
        ],
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

  String _getStatusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.requested:
        return 'PENDING';
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
        return context.primary;
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.noShow:
        return Colors.grey;
    }
  }

  Widget _buildActionButton(
    String label,
    Color color,
    bool isPrimary,
    VoidCallback onTap, {
    double? width,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPrimary ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isPrimary
                ? null
                : Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? AppColors.white : color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.1,
            ),
          ),
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
              Icons.check_circle_outline_rounded,
              size: 80,
              color: context.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: context.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending consultation requests found.',
            style: TextStyle(color: context.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildActionButton(
            'REFRESH',
            context.primary,
            true,
            _loadRequests,
            width: 160.0,
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
    );
  }
}
