import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../data/models/test_result_model.dart';
import '../../../core/services/video_call_service.dart';
import '../../../core/services/test_result_service.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import 'patient_results_view_screen.dart';

class DoctorVideoCallScreen extends StatefulWidget {
  final ConsultationBookingModel booking;

  const DoctorVideoCallScreen({super.key, required this.booking});

  @override
  State<DoctorVideoCallScreen> createState() => _DoctorVideoCallScreenState();
}

class _DoctorVideoCallScreenState extends State<DoctorVideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _videoCallService = VideoCallService();
  final _consultationService = ConsultationService();

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _showDataOverlay = true;
  bool _isConnected = false;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();

  // State for in-place result viewing
  String? _selectedResultId;
  TestResultModel? _selectedResult;
  bool _isLoadingResult = false;
  final _testResultService = TestResultService();

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // 1. Get local stream
    final stream = await _videoCallService.getLocalStream();
    setState(() => _localRenderer.srcObject = stream);

    // 2. Start signaling
    await _videoCallService.startCall(widget.booking.id);

    // 3. Listen for remote stream
    _videoCallService.onRemoteStream((remoteStream) {
      setState(() {
        _remoteRenderer.srcObject = remoteStream;
        _isConnected = true;
      });
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _videoCallService.dispose(widget.booking.id);
    _notesController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Video Layout
          Row(
            children: [
              // Patient Video / Main Area
              Expanded(flex: 3, child: _buildMainVideoArea()),
              // Side Panel (Patient Data)
              if (_showDataOverlay && MediaQuery.of(context).size.width > 800)
                Container(
                  width: 350,
                  color: context.surface,
                  child: _buildPatientDataPanel(),
                ),
            ],
          ),

          // Mobile Data Overlay (Bottom Sheet toggle or Floating)
          if (MediaQuery.of(context).size.width <= 800)
            Positioned(
              top: 40,
              right: 20,
              child: FloatingActionButton.small(
                onPressed: () => _showMobileDataDialog(),
                child: const Icon(Icons.description),
              ),
            ),

          // Call Controls (Bottom Center)
          Positioned(
            bottom: 30,
            left: 0,
            right: _showDataOverlay && MediaQuery.of(context).size.width > 800
                ? 350
                : 0,
            child: _buildCallControls(),
          ),

          // Side Panel Toggle (Web)
          if (MediaQuery.of(context).size.width > 800)
            Positioned(
              top: 20,
              right: _showDataOverlay ? 360 : 20,
              child: FloatingActionButton.small(
                onPressed: () =>
                    setState(() => _showDataOverlay = !_showDataOverlay),
                backgroundColor: context.surface,
                child: Icon(
                  _showDataOverlay ? Icons.chevron_right : Icons.chevron_left,
                  color: context.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainVideoArea() {
    return Stack(
      children: [
        // Main Video Area (Patient)
        Container(
          color: Colors.black,
          child: _isConnected
              ? RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person,
                        size: 100,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.booking.patientName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                        ),
                      ),
                      const Text(
                        "Waiting for patient to join...",
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
        ),

        // Self View (PIP)
        Positioned(
          top: 40,
          left: 20,
          child: Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: _isVideoOff
                ? const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white24),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientDataPanel() {
    if (_selectedResultId != null) {
      return _buildDetailedResultPanel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Patient Overview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.booking.patientName,
                style: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.calendar_today,
                'Consultation',
                DateFormat('MMM dd, yyyy').format(widget.booking.dateTime),
              ),
              _buildInfoRow(Icons.access_time, 'Slot', widget.booking.timeSlot),
              _buildInfoRow(
                Icons.medical_services_outlined,
                'Type',
                widget.booking.type.name.toUpperCase(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _endCall(),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('END & FINALIZE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'ATTACHED RESULTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.booking.attachedResultIds.isEmpty)
                const Text(
                  'No results attached',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                )
              else
                ...widget.booking.attachedResultIds.map(
                  (id) => _buildResultTile(id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedResultPanel() {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => setState(() {
              _selectedResultId = null;
              _selectedResult = null;
            }),
          ),
          title: const Text(
            'Test Result Detail',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _isLoadingResult
              ? const Center(child: CircularProgressIndicator())
              : _selectedResult == null
              ? const Center(child: Text('Failed to load result'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildResultDetailHeader(_selectedResult!),
                    const SizedBox(height: 20),
                    _buildResultDetailSummary(_selectedResult!),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientResultsViewScreen(
                              resultIds: [_selectedResultId!],
                              patientName: widget.booking.patientName,
                              patientId: widget.booking.patientId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.fullscreen, size: 18),
                      label: const Text('View Full Screen'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.primary),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildResultDetailHeader(TestResultModel result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.testType.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              color: context.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMMM dd, yyyy').format(result.timestamp),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            result.profileName,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResultDetailSummary(TestResultModel result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OVERALL STATUS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(result.overallStatus).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            result.overallStatus.label.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(result.overallStatus),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'QUICK SUMMARY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        _buildSummaryItem(
          'Right Eye',
          result.visualAcuityRight?.snellenScore ?? 'N/A',
        ),
        _buildSummaryItem(
          'Left Eye',
          result.visualAcuityLeft?.snellenScore ?? 'N/A',
        ),
        if (result.colorVision != null)
          _buildSummaryItem('Color Vision', result.colorVision!.status),
        if (result.recommendation.isNotEmpty)
          _buildSummaryItem('Rec.', result.recommendation),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(height: 1.4, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TestStatus status) {
    switch (status) {
      case TestStatus.normal:
        return Colors.green;
      case TestStatus.review:
        return Colors.orange;
      case TestStatus.urgent:
        return Colors.red;
    }
  }

  Widget _buildResultTile(String id) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        title: Text(
          'Result #$id',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.launch, size: 16, color: context.primary),
        onTap: () async {
          setState(() {
            _selectedResultId = id;
            _isLoadingResult = true;
          });

          try {
            final result = await _testResultService.getTestResultById(
              widget.booking.patientId,
              id,
            );
            setState(() {
              _selectedResult = result;
              _isLoadingResult = false;
            });
          } catch (e) {
            setState(() {
              _isLoadingResult = false;
            });
            if (mounted) {
              SnackbarUtils.showError(context, 'Error loading result: $e');
            }
          }
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          onTap: () => setState(() => _isMuted = !_isMuted),
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          color: _isMuted ? Colors.red : Colors.white24,
        ),
        const SizedBox(width: 20),
        _buildControlButton(
          onTap: () => _endCall(),
          icon: Icons.call_end,
          color: Colors.red,
          isLarge: true,
        ),
        const SizedBox(width: 20),
        _buildControlButton(
          onTap: () => setState(() => _isVideoOff = !_isVideoOff),
          icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
          color: _isVideoOff ? Colors.red : Colors.white24,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    bool isLarge = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLarge ? 20 : 12),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: isLarge ? 32 : 24),
      ),
    );
  }

  void _showMobileDataDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _buildPatientDataPanel(),
      ),
    );
  }

  void _endCall() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPostConsultationPopup(),
    );
  }

  Widget _buildPostConsultationPopup() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Session Completed', textAlign: TextAlign.center),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide the final diagnosis and notes for the patient.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _diagnosisController,
              decoration: InputDecoration(
                labelText: 'Final Diagnosis',
                hintText: 'e.g. Mild Myopia',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Doctor Notes',
                hintText: 'Prescription or advice...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _finalizeConsultation(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save & Close Portal'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _initWebRTC(); // Restart WebRTC
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: context.primary.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Restart / Resume Session'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _finalizeConsultation() async {
    if (_diagnosisController.text.isEmpty) {
      SnackbarUtils.showError(context, 'Please enter a diagnosis');
      return;
    }

    setState(() => _showDataOverlay = false); // Hide overlay during loading

    final success = await _consultationService.completeConsultation(
      widget.booking.id,
      _diagnosisController.text,
      _notesController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pop(); // Close dialog
      Navigator.of(context).pop(); // Exit video call
    }
  }
}
