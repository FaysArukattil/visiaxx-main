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
    _loadRequests();
  }

  @override
  void dispose() {
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

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final uid = _authService.currentUserId;
    if (uid != null) {
      // Auto-expire old pending bookings first
      await _consultationService.autoExpireBookings(uid);

      final allBookings = await _consultationService.getDoctorBookings(uid);
      if (mounted) {
        setState(() {
          _allBookings = allBookings;
          _isLoading = false;
        });
        _filterBookings();
      }
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
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Booking ${newStatus == BookingStatus.confirmed ? 'confirmed' : 'rejected'}.',
        );
      }
      _loadRequests();
    }
  }

  Future<String?> _showLinkDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Add Meeting Link',
          style: TextStyle(fontWeight: FontWeight.w900, color: context.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste your Zoom or Google Meet link for this session.',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'https://meet.google.com/...',
                filled: true,
                fillColor: context.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: context.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
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
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Review Requests',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    labelColor: context.primary,
                    unselectedLabelColor: context.textSecondary,
                    indicatorColor: context.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: _tabs.map((t) {
                      final count = _allBookings
                          .where(
                            (b) => b.status == _tabStatuses[_tabs.indexOf(t)],
                          )
                          .length;
                      return Tab(text: '$t ($count)');
                    }).toList(),
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
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
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

  Widget _buildRequestCard(ConsultationBookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Padding(
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
                  child: Icon(
                    Icons.person_rounded,
                    color: context.primary,
                    size: 30,
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
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.type == ConsultationType.online
                            ? 'Online Consultation'
                            : 'In-Person Visit',
                        style: TextStyle(
                          fontSize: 12,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.025),
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
                      DateFormat('MMM d, yyyy').format(booking.dateTime),
                    ),
                    const SizedBox(width: 24),
                    _infoItem(Icons.access_time_rounded, booking.timeSlot),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _infoItem(
                      Icons.cake_rounded,
                      '${booking.patientAge ?? "--"} years',
                    ),
                    const SizedBox(width: 24),
                    _infoItem(
                      Icons.wc_rounded,
                      booking.patientGender ?? 'Unknown',
                    ),
                  ],
                ),
                if (booking.type == ConsultationType.inPerson &&
                    booking.exactAddress != null) ...[
                  const SizedBox(height: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      size: 16,
                      color: context.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${booking.attachedResultIds.length} Medical Reports Attached',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.primary,
                      ),
                    ),
                  ),
                  _buildTextButton('VIEW ALL', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientResultsViewScreen(
                          resultIds: booking.attachedResultIds,
                          patientName: booking.patientName,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Actions — only for pending bookings
          if (booking.status == BookingStatus.requested)
            Padding(
              padding: const EdgeInsets.all(20),
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
                  const SizedBox(width: 16),
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

          // Show info for other statuses
          if (booking.status == BookingStatus.confirmed &&
              booking.zoomLink != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Icon(Icons.videocam_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Meeting link set',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (booking.status == BookingStatus.cancelled &&
              booking.doctorNotes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.doctorNotes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut);
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

  Widget _buildTextButton(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: context.primary,
            letterSpacing: 1,
          ),
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
    VoidCallback onTap,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPrimary ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
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
              fontSize: 14,
              letterSpacing: 1.2,
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
          _buildActionButton('REFRESH', context.primary, true, _loadRequests),
        ],
      ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
    );
  }
}
