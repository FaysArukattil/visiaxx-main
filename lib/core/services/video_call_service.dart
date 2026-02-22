import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/app_logger.dart';

class VideoCallService {
  static final VideoCallService _instance = VideoCallService._internal();
  factory VideoCallService() => _instance;
  VideoCallService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  Function(MediaStream)? _remoteStreamCallback;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;

  Future<void> initializeRenderers() async {
    if (_renderersInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersInitialized = true;
  }

  // Configuration for STUN servers
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ],
  };

  /// Get available video devices
  Future<List<MediaDeviceInfo>> getVideoDevices() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices.where((d) => d.kind == 'videoinput').toList();
  }

  /// Initialize the local media stream (camera/mic)
  Future<MediaStream> getLocalStream({String? deviceId}) async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': {
        if (deviceId != null) 'deviceId': deviceId,
        if (deviceId == null) 'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
    };

    try {
      if (_localStream != null) {
        await _localStream!.dispose();
      }
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      return _localStream!;
    } catch (e) {
      AppLogger.log(
        'Error getting local stream: $e',
        tag: 'VideoCallService',
        isError: true,
      );
      rethrow;
    }
  }

  /// Start a call (Doctor Side)
  Future<void> startCall(String bookingId) async {
    _peerConnection = await createPeerConnection(_iceServers);

    // Add local stream tracks to peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // Handle ICE Candidates
    _peerConnection?.onIceCandidate = (candidate) {
      _db
          .ref('video_calls/$bookingId/doctorCandidates')
          .push()
          .set(candidate.toMap());
    };

    // Create Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Save Offer to Firebase
    await _db.ref('video_calls/$bookingId').set({
      'offer': offer.toMap(),
      'status': 'ringing',
      'createdAt': ServerValue.timestamp,
    });

    // Listen for Answer
    _db.ref('video_calls/$bookingId/answer').onValue.listen((event) async {
      if (event.snapshot.value != null &&
          _peerConnection?.getRemoteDescription() == null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        RTCSessionDescription answer = RTCSessionDescription(
          data['sdp'],
          data['type'],
        );
        await _peerConnection!.setRemoteDescription(answer);
      }
    });

    // Listen for Patient ICE Candidates
    _db.ref('video_calls/$bookingId/patientCandidates').onChildAdded.listen((
      event,
    ) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      }
    });
  }

  /// Join a call (Patient Side)
  Future<void> joinCall(String bookingId) async {
    _peerConnection = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onIceCandidate = (candidate) {
      _db
          .ref('video_calls/$bookingId/patientCandidates')
          .push()
          .set(candidate.toMap());
    };

    // Listen for Offer from Firebase
    _db.ref('video_calls/$bookingId/offer').onValue.listen((event) async {
      if (event.snapshot.value != null &&
          _peerConnection?.getRemoteDescription() == null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        RTCSessionDescription offer = RTCSessionDescription(
          data['sdp'],
          data['type'],
        );
        await _peerConnection!.setRemoteDescription(offer);

        // Create Answer
        RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        // Save Answer to Firebase
        await _db.ref('video_calls/$bookingId/answer').set(answer.toMap());
        await _db.ref('video_calls/$bookingId/status').set('active');
      }
    });

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamCallback?.call(_remoteStream!);
      }
    };

    // Listen for Doctor ICE Candidates
    _db.ref('video_calls/$bookingId/doctorCandidates').onChildAdded.listen((
      event,
    ) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      }
    });
  }

  /// Listen for remote stream
  void onRemoteStream(Function(MediaStream) callback) {
    _remoteStreamCallback = callback;
    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamCallback?.call(_remoteStream!);
      }
    };
    // If we already have a stream, trigger immediately
    if (_remoteStream != null) {
      callback(_remoteStream!);
    }
  }

  /// Clean up
  Future<void> dispose(String bookingId) async {
    try {
      await _localStream?.dispose();
      _localStream = null;
      await _remoteStream?.dispose();
      _remoteStream = null;
      await _peerConnection?.close();
      _peerConnection = null;

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      await _db.ref('video_calls/$bookingId/status').set('ended');
    } catch (e) {
      AppLogger.log(
        'Video call error: $e. Path: video_calls/$bookingId',
        tag: 'VideoCallService',
        isError: true,
      );
    }
  }

  /// Manually remove call data from Firebase
  Future<void> clearCallData(String bookingId) async {
    await _db.ref('video_calls/$bookingId').remove();
  }
}
