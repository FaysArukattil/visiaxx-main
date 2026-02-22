import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../widgets/video_pip_overlay.dart';

class PipService {
  static final PipService _instance = PipService._internal();
  factory PipService() => _instance;
  PipService._internal();

  OverlayEntry? _overlayEntry;
  bool get isActive => _overlayEntry != null;

  void show({
    required BuildContext context,
    required RTCVideoRenderer localRenderer,
    required RTCVideoRenderer remoteRenderer,
    required VoidCallback onRestore,
    required VoidCallback onEnd,
  }) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => VideoPipOverlay(
        localRenderer: localRenderer,
        remoteRenderer: remoteRenderer,
        onRestore: () {
          hide();
          onRestore();
        },
        onEnd: () {
          hide();
          onEnd();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
