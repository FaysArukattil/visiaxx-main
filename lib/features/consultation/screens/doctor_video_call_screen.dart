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
import '../../../core/services/pip_service.dart';
import '../../../core/services/pdf_export_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class DoctorVideoCallScreen extends StatefulWidget {
  final ConsultationBookingModel booking;

  const DoctorVideoCallScreen({super.key, required this.booking});

  @override
  State<DoctorVideoCallScreen> createState() => _DoctorVideoCallScreenState();
}

class _DoctorVideoCallScreenState extends State<DoctorVideoCallScreen> {
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
  final _pdfExportService = PdfExportService();

  // Camera devices
  List<MediaDeviceInfo> _videoDevices = [];
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _videoCallService.initializeRenderers();

    // Check if already active
    if (_videoCallService.localRenderer.srcObject != null && _isConnected)
      return;

    // 0. Get available cameras (already filtered in service)
    _videoDevices = await _videoCallService.getVideoDevices();
    if (_videoDevices.isNotEmpty && _selectedDeviceId == null) {
      _selectedDeviceId = _videoDevices.first.deviceId;
    }

    // 1. Get local stream
    final stream = await _videoCallService.getLocalStream(
      deviceId: _selectedDeviceId,
    );
    setState(() => _videoCallService.localRenderer.srcObject = stream);

    // 2. Start signaling
    await _videoCallService.startCall(widget.booking.id);

    // 3. Listen for remote stream
    _videoCallService.onRemoteStream((remoteStream) {
      if (mounted) {
        setState(() {
          _videoCallService.remoteRenderer.srcObject = remoteStream;
          _isConnected = true;
        });
      }
    });
  }

  @override
  void dispose() {
    if (!PipService().isActive) {
      _videoCallService.dispose(widget.booking.id);
    }
    _notesController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Main Video Layout
            Row(
              children: [
                // Patient Video / Main Area
                Expanded(
                  flex:
                      _showDataOverlay &&
                          MediaQuery.of(context).size.width > 800
                      ? 5
                      : 1,
                  child: _buildMainVideoArea(),
                ),
                // Side Panel (Patient Data)
                if (_showDataOverlay && MediaQuery.of(context).size.width > 800)
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: context.surface,
                      child: _buildPatientDataPanel(),
                    ),
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
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          _showDataOverlay &&
                              MediaQuery.of(context).size.width > 800
                          ? MediaQuery.of(context).size.width * 0.5
                          : MediaQuery.of(context).size.width,
                    ),
                    child: _buildCallControls(),
                  ),
                ],
              ),
            ),

            // Side Panel Toggle (Web)
            if (MediaQuery.of(context).size.width > 800)
              Positioned(
                top: 20,
                right: _showDataOverlay
                    ? MediaQuery.of(context).size.width * 0.5 - 20
                    : 20,
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
      ),
    );
  }

  void _handleBackPress() {
    if (_isConnected) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Consultation in Progress'),
          content: const Text(
            'Do you want to minimize the call or quit entirely?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Resume'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                PipService().show(
                  context: this.context,
                  localRenderer: _videoCallService.localRenderer,
                  remoteRenderer: _videoCallService.remoteRenderer,
                  onRestore: () {
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            DoctorVideoCallScreen(booking: widget.booking),
                      ),
                    );
                  },
                  onEnd: () => _endCall(),
                );
                Navigator.of(this.context).popUntil((route) => route.isFirst);
              },
              child: const Text('Minimize (PiP)'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _endCall();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Quit Call'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildMainVideoArea() {
    return Stack(
      children: [
        // Main Video Area (Patient)
        Container(
          color: Colors.black,
          child: _isConnected
              ? RTCVideoView(
                  _videoCallService.remoteRenderer,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                          _videoCallService.localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
              ),
              if (_videoDevices.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedDeviceId,
                      dropdownColor: Colors.black87,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.videocam,
                        color: Colors.white70,
                        size: 16,
                      ),
                      items: _videoDevices.map((device) {
                        return DropdownMenuItem<String>(
                          value: device.deviceId,
                          child: Text(
                            device.label.length > 15
                                ? '${device.label.substring(0, 12)}...'
                                : device.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedDeviceId = val);
                        _initWebRTC(); // Re-init with new camera
                      },
                    ),
                  ),
                ),
            ],
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
          title: Text(
            _selectedResult?.testType.replaceAll('_', ' ').toUpperCase() ??
                'Result Detail',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_selectedResult != null)
              IconButton(
                icon: const Icon(Icons.fullscreen),
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
              ),
          ],
        ),
        Expanded(
          child: _isLoadingResult
              ? const Center(child: CircularProgressIndicator())
              : _selectedResult == null
              ? const Center(child: Text('Failed to load result'))
              : PdfPreview(
                  build: (format) =>
                      _pdfExportService.generatePdfBytes(_selectedResult!),
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  initialPageFormat: PdfPageFormat.a4,
                  maxPageWidth: 800,
                  loadingWidget: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
        ),
      ],
    );
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session Completed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide the final diagnosis and notes for the patient history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _diagnosisController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Final Diagnosis',
                  hintText: 'e.g. Mild Myopia',
                  prefixIcon: const Icon(Icons.assignment_rounded),
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
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Doctor Notes',
                  hintText: 'Prescription or advice...',
                  prefixIcon: const Icon(Icons.note_alt_rounded),
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _finalizeConsultation(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'SAVE & COMPLETE PORTAL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _initWebRTC();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'RE-JOIN SESSION',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
