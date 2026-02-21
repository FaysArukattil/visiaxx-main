import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../../data/models/test_result_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';
import '../../../core/widgets/eye_loader.dart';

class AttachResultsScreen extends StatefulWidget {
  const AttachResultsScreen({super.key});

  @override
  State<AttachResultsScreen> createState() => _AttachResultsScreenState();
}

class _AttachResultsScreenState extends State<AttachResultsScreen> {
  final _testResultService = TestResultService();
  final _authService = AuthService();

  DoctorModel? _doctor;
  DateTime? _date;
  TimeSlotModel? _slot;
  double? _latitude;
  double? _longitude;
  String? _exactAddress;
  String? _flat;
  String? _landmark;
  String? _pincode;
  ConsultationType? _type;
  String? _patientName;
  int? _patientAge;
  String? _patientGender;
  bool _isForSelf = true;

  List<TestResultModel> _results = [];
  final List<String> _selectedResultIds = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_doctor != null) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _doctor = args?['doctor'];
    _date = args?['date'];
    _slot = args?['slot'];
    _latitude = args?['latitude'];
    _longitude = args?['longitude'];
    _exactAddress = args?['exactAddress'];
    _flat = args?['flat'];
    _landmark = args?['landmark'];
    _pincode = args?['pincode'];
    _type = args?['type'];
    _patientName = args?['patientName'];
    _patientAge = args?['patientAge'];
    _patientGender = args?['patientGender'];
    _isForSelf = args?['isForSelf'] ?? true;

    // Handle pre-selected values for editability
    if (args?['preSelectedResultIds'] != null) {
      _selectedResultIds.clear();
      _selectedResultIds.addAll(
        List<String>.from(args?['preSelectedResultIds']),
      );
    }

    if (_doctor != null) {
      _loadResults();
    }
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final results = await _testResultService.getTestResults(user.uid);
        setState(() {
          _results = results;
          _isLoading = false;
        });
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to load results: $e');
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text('Consultation missing')));
    }

    final theme = Theme.of(context);
    final color = context.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -60,
            child: _buildDecorativeCircle(color, 400, 0.04),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _buildDecorativeCircle(color, 320, 0.03),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: isLandscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  0,
                                  12,
                                ),
                                child: _buildContextInfo(),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _isLoading
                                  ? const Center(child: EyeLoader(size: 60))
                                  : _results.isEmpty
                                  ? _buildEmptyState()
                                  : _buildResultsList(),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                              child: Text(
                                'Share your previous test results with Dr. ${_doctor!.fullName} for a more accurate clinical evaluation.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: context.textSecondary,
                                  height: 1.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _isLoading
                                  ? const Center(child: EyeLoader(size: 60))
                                  : _results.isEmpty
                                  ? _buildEmptyState()
                                  : _buildResultsList(),
                            ),
                          ],
                        ),
                ),
                _buildBottomAction(),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: context.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: _doctor!.photoUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_doctor!.photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _doctor!.photoUrl.isEmpty
                ? Icon(
                    Icons.person_rounded,
                    color: context.primary.withValues(alpha: 0.4),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Attach Results',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                if (_selectedResultIds.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selectedResultIds.length}/10',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: context.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLINICAL REVIEW',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: context.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sharing your vision history helps Dr. ${_doctor!.fullName} provide a more comprehensive consultation.',
          style: TextStyle(
            fontSize: 16,
            color: context.textPrimary,
            height: 1.6,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 32),
        _buildInfoItem(
          Icons.health_and_safety_rounded,
          'Identify pattern changes in your vision.',
        ),
        const SizedBox(height: 16),
        _buildInfoItem(Icons.speed_rounded, 'Speed up your diagnosis process.'),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: context.primary, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return GridView.builder(
        key: const PageStorageKey('results_grid'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          return _buildResultCard(_results[index], index);
        },
      );
    }

    return ListView.builder(
      key: const PageStorageKey('results_list'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        return _buildResultCard(_results[index], index);
      },
    );
  }

  Widget _buildResultCard(TestResultModel result, int index) {
    final isSelected = _selectedResultIds.contains(result.id);
    final color = context.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.only(bottom: isLandscape ? 0 : 16),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedResultIds.remove(result.id);
            } else {
              if (_selectedResultIds.length >= 10) {
                SnackbarUtils.showWarning(
                  context,
                  'Maximum of 10 results can be attached at once.',
                );
                return;
              }
              _selectedResultIds.add(result.id);
            }
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        result.overallStatus,
                      ).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(result.overallStatus),
                      color: _getStatusColor(result.overallStatus),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.profileName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getProfileSubtitle(result),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildSelectedIndicator(isSelected),
                ],
              ),
              const SizedBox(height: 12),
              isLandscape
                  ? Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.scaffoldBackground.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.dividerColor.withValues(alpha: 0.05),
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getTestsPerformedSummary(result),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(result.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_hasAmslerIssues(result))
                                _buildAmslerThumbnails(result),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.scaffoldBackground.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.dividerColor.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTestsPerformedSummary(result),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd MMM yyyy').format(result.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_hasAmslerIssues(result))
                            _buildAmslerThumbnails(result),
                        ],
                      ),
                    ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            QuickTestResultScreen(historicalResult: result),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Quick Preview',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index % 6 * 100).ms).slideX(begin: 0.05, end: 0);
  }

  bool _hasAmslerIssues(TestResultModel result) {
    if (result.overallStatus == TestStatus.normal) return false;
    final r = result.amslerGridRight;
    final l = result.amslerGridLeft;
    return (r != null && r.needsAttention) || (l != null && l.needsAttention);
  }

  Widget _buildAmslerThumbnails(TestResultModel result) {
    final List<Widget> thumbs = [];
    final r = result.amslerGridRight;
    final l = result.amslerGridLeft;

    if (r != null &&
        r.needsAttention &&
        (r.awsImageUrl != null || r.firebaseImageUrl != null)) {
      thumbs.add(
        _buildThumb(r.awsImageUrl ?? r.firebaseImageUrl!, 'Right Eye'),
      );
    }
    if (l != null &&
        l.needsAttention &&
        (l.awsImageUrl != null || l.firebaseImageUrl != null)) {
      thumbs.add(_buildThumb(l.awsImageUrl ?? l.firebaseImageUrl!, 'Left Eye'));
    }

    if (thumbs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amsler Grid Findings:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.textTertiary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: thumbs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => thumbs[index],
          ),
        ),
      ],
    );
  }

  Widget _buildThumb(String url, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.dividerColor.withValues(alpha: 0.1),
              ),
              image: DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedIndicator(bool isSelected) {
    final color = context.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? color
              : context.dividerColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }

  String _getProfileSubtitle(TestResultModel result) {
    final type = result.profileType == 'self' ? 'Myself' : 'Family Member';
    final testType = result.testType == 'comprehensive'
        ? 'Full Test'
        : 'Quick Test';
    return '$type • $testType';
  }

  String _getTestsPerformedSummary(TestResultModel result) {
    final List<String> tests = [];
    if (result.visualAcuityRight != null || result.visualAcuityLeft != null)
      tests.add('Acuity');
    if (result.colorVision != null) tests.add('Color Vision');
    if (result.amslerGridRight != null || result.amslerGridLeft != null)
      tests.add('Amsler');
    if (result.shortDistance != null) tests.add('Reading');
    if (result.pelliRobson != null) tests.add('Contrast');
    if (result.mobileRefractometry != null) tests.add('Refraction');
    if (result.shadowTest != null) tests.add('Cataract');
    if (result.stereopsis != null) tests.add('Depth');
    if (result.eyeHydration != null) tests.add('Hydration');
    if (result.visualFieldRight != null || result.visualFieldLeft != null)
      tests.add('Field');
    if (result.coverTest != null) tests.add('Alignment');
    if (result.torchlight != null) tests.add('Torch');

    if (tests.isEmpty) return 'General Screening';
    return tests.join(' • ');
  }

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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 64,
              color: context.primary.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tests recorded',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your previous vision tests will appear here once completed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textTertiary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildBottomAction() {
    final isSelected = _selectedResultIds.isNotEmpty;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, isLandscape ? 12 : 32),
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
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: () => _navigateToConfirmation(),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, isLandscape ? 48 : 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: context.dividerColor.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: const FittedBox(
                child: Text(
                  'Skip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _navigateToConfirmation(),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: Colors.white,
                minimumSize: Size(0, isLandscape ? 48 : 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isSelected
                          ? 'Attach & Proceed (${_selectedResultIds.length}/10)'
                          : 'Proceed',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  void _navigateToConfirmation() {
    Navigator.pushNamed(
      context,
      '/booking-confirmation',
      arguments: {
        'doctor': _doctor,
        'date': _date,
        'slot': _slot,
        'attachedResultIds': _selectedResultIds,
        'latitude': _latitude,
        'longitude': _longitude,
        'exactAddress': _exactAddress,
        'flat': _flat,
        'landmark': _landmark,
        'pincode': _pincode,
        'type': _type,
        'patientName': _patientName,
        'patientAge': _patientAge,
        'patientGender': _patientGender,
        'isForSelf': _isForSelf,
      },
    );
  }
}
