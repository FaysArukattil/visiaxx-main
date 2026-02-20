import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../core/services/video_call_service.dart';

class PatientVideoCallScreen extends StatefulWidget {
  final ConsultationBookingModel booking;

  const PatientVideoCallScreen({super.key, required this.booking});

  @override
  State<PatientVideoCallScreen> createState() => _PatientVideoCallScreenState();
}

class _PatientVideoCallScreenState extends State<PatientVideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _videoCallService = VideoCallService();

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isConnected = false;

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

    // 2. Start signaling (Join as patient)
    await _videoCallService.joinCall(widget.booking.id);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Video (Doctor)
          _buildMainVideoArea(),

          // Self View (PIP)
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 100,
              height: 150,
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

          // Doctor Info (Top Left)
          Positioned(
            top: 40,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.booking.doctorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                  ),
                ),
                Text(
                  _isConnected ? 'Connected' : 'Waiting for doctor...',
                  style: TextStyle(
                    color: _isConnected
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 12,
                    shadows: const [
                      Shadow(blurRadius: 10, color: Colors.black54),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Call Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVideoArea() {
    return Container(
      width: double.infinity,
      height: double.infinity,
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
                  const Icon(Icons.person, size: 100, color: Colors.white10),
                  const SizedBox(height: 16),
                  Text(
                    "Connecting with ${widget.booking.doctorName}...",
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
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
        const SizedBox(width: 24),
        _buildControlButton(
          onTap: () => Navigator.pop(context), // End call
          icon: Icons.call_end,
          color: Colors.red,
          isLarge: true,
        ),
        const SizedBox(width: 24),
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
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: EdgeInsets.all(isLarge ? 20 : 16),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: isLarge ? 32 : 24),
      ),
    );
  }
}
