import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/test_result_model.dart';

/// Practitioner Dashboard with tabbed interface
class PractitionerDashboardScreen extends StatefulWidget {
  const PractitionerDashboardScreen({super.key});

  @override
  State<PractitionerDashboardScreen> createState() =>
      _PractitionerDashboardScreenState();
}

class _PractitionerDashboardScreenState
    extends State<PractitionerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Demo data - would come from Firebase
  final List<_PatientResult> _allResults = [
    _PatientResult(
      id: '1',
      patientName: 'John Smith',
      patientAge: 45,
      date: DateTime.now().subtract(const Duration(hours: 2)),
      status: TestStatus.urgent,
      vaRight: '20/60',
      vaLeft: '20/50',
      colorVision: 'Deficiency detected',
      amsler: 'Distortions in both eyes',
      isReviewed: false,
      notes: '',
    ),
    _PatientResult(
      id: '2',
      patientName: 'Mary Johnson',
      patientAge: 62,
      date: DateTime.now().subtract(const Duration(hours: 5)),
      status: TestStatus.review,
      vaRight: '20/40',
      vaLeft: '20/30',
      colorVision: 'Normal',
      amsler: 'Mild distortions (right)',
      isReviewed: false,
      notes: '',
    ),
    _PatientResult(
      id: '3',
      patientName: 'Robert Williams',
      patientAge: 35,
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: TestStatus.normal,
      vaRight: '20/20',
      vaLeft: '20/20',
      colorVision: 'Normal',
      amsler: 'Normal',
      isReviewed: true,
      notes: 'All within normal limits. Recommend annual check.',
    ),
    _PatientResult(
      id: '4',
      patientName: 'Emily Brown',
      patientAge: 28,
      date: DateTime.now().subtract(const Duration(days: 2)),
      status: TestStatus.normal,
      vaRight: '20/25',
      vaLeft: '20/20',
      colorVision: 'Normal',
      amsler: 'Normal',
      isReviewed: true,
      notes: 'Mild reduction in right eye. Monitor.',
    ),
    _PatientResult(
      id: '5',
      patientName: 'Michael Davis',
      patientAge: 55,
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: TestStatus.review,
      vaRight: '20/50',
      vaLeft: '20/40',
      colorVision: 'Mild deficiency',
      amsler: 'Normal',
      isReviewed: true,
      notes: 'Possible early cataract. Schedule comprehensive exam.',
    ),
  ];

  List<_PatientResult> get _pendingResults =>
      _allResults.where((r) => !r.isReviewed).toList();

  List<_PatientResult> get _flaggedResults =>
      _allResults.where((r) => r.status != TestStatus.normal).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practitioner Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              SnackbarUtils.showInfo(context, 'Notifications coming soon');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (_pendingResults.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingResults.length}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Flagged'),
                  if (_flaggedResults.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_flaggedResults.length}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'All Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Pending Reviews
          _buildResultsList(
            _pendingResults,
            emptyMessage: 'No pending reviews',
          ),
          // Tab 2: Flagged Cases
          _buildResultsList(_flaggedResults, emptyMessage: 'No flagged cases'),
          // Tab 3: All Results
          _buildResultsList(_allResults, emptyMessage: 'No results yet'),
        ],
      ),
    );
  }

  Widget _buildResultsList(
    List<_PatientResult> results, {
    required String emptyMessage,
  }) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildPatientCard(results[index]);
      },
    );
  }

  Widget _buildPatientCard(_PatientResult result) {
    Color statusColor;
    switch (result.status) {
      case TestStatus.normal:
        statusColor = AppColors.success;
        break;
      case TestStatus.review:
        statusColor = AppColors.warning;
        break;
      case TestStatus.urgent:
        statusColor = AppColors.error;
        break;
    }

    return GestureDetector(
      onTap: () => _showPatientDetails(result),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: result.isReviewed
                ? AppColors.border
                : statusColor.withValues(alpha: 0.5),
            width: result.isReviewed ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Patient avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Text(
                    result.patientName
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            result.patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (!result.isReviewed) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.patientAge} years €¢ ${_formatDate(result.date)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.status.emoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        result.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Results grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildResultCell('VA (R)', result.vaRight),
                  _buildDivider(),
                  _buildResultCell('VA (L)', result.vaLeft),
                  _buildDivider(),
                  _buildResultCell('Color', result.colorVision, isWide: true),
                ],
              ),
            ),
            // Amsler summary
            if (result.amsler != 'Normal') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.grid_on,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amsler: ${result.amsler}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Notes if reviewed
            if (result.isReviewed && result.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Action button
            if (!result.isReviewed) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showPatientDetails(result),
                  style: ElevatedButton.styleFrom(backgroundColor: statusColor),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Review & Add Notes'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCell(String label, String value, {bool isWide = false}) {
    return Expanded(
      flex: isWide ? 2 : 1,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.border,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }

  void _showPatientDetails(_PatientResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PatientDetailSheet(
        result: result,
        onSave: (notes) {
          setState(() {
            result.notes = notes;
            result.isReviewed = true;
          });
          Navigator.pop(context);
          SnackbarUtils.showSuccess(context, 'Notes saved successfully');
        },
      ),
    );
  }
}

class _PatientDetailSheet extends StatefulWidget {
  final _PatientResult result;
  final Function(String notes) onSave;

  const _PatientDetailSheet({required this.result, required this.onSave});

  @override
  State<_PatientDetailSheet> createState() => _PatientDetailSheetState();
}

class _PatientDetailSheetState extends State<_PatientDetailSheet> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.result.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (widget.result.status) {
      case TestStatus.normal:
        statusColor = AppColors.success;
        break;
      case TestStatus.review:
        statusColor = AppColors.warning;
        break;
      case TestStatus.urgent:
        statusColor = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Patient info header
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Text(
                    widget.result.patientName
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.result.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.result.patientAge} years old',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.result.status.label,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Test date
            Text(
              'Test Date: ${DateFormat('MMMM dd, yyyy €¢ h:mm a').format(widget.result.date)}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            // Results section
            const Text(
              'Test Results',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Visual Acuity (Right)', widget.result.vaRight),
            _buildDetailRow('Visual Acuity (Left)', widget.result.vaLeft),
            _buildDetailRow('Color Vision', widget.result.colorVision),
            _buildDetailRow('Amsler Grid', widget.result.amsler),
            const SizedBox(height: 24),
            // Practitioner notes
            const Text(
              'Practitioner Notes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add your clinical notes and recommendations...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onSave(_notesController.text),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Save & Mark Reviewed'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isAbnormal =
        value.contains('Deficiency') ||
        value.contains('Distortion') ||
        (label.contains('VA') &&
            !value.contains('20/20') &&
            !value.contains('20/25'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isAbnormal ? AppColors.warning : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientResult {
  final String id;
  final String patientName;
  final int patientAge;
  final DateTime date;
  final TestStatus status;
  final String vaRight;
  final String vaLeft;
  final String colorVision;
  final String amsler;
  bool isReviewed;
  String notes;

  _PatientResult({
    required this.id,
    required this.patientName,
    required this.patientAge,
    required this.date,
    required this.status,
    required this.vaRight,
    required this.vaLeft,
    required this.colorVision,
    required this.amsler,
    required this.isReviewed,
    required this.notes,
  });
}


