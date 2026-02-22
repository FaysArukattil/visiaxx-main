import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoPipOverlay extends StatefulWidget {
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final VoidCallback onRestore;
  final VoidCallback onEnd;

  const VideoPipOverlay({
    super.key,
    required this.localRenderer,
    required this.remoteRenderer,
    required this.onRestore,
    required this.onEnd,
  });

  @override
  State<VideoPipOverlay> createState() => _VideoPipOverlayState();
}

class _VideoPipOverlayState extends State<VideoPipOverlay> {
  Offset _offset = const Offset(20, 60);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
            // Clamp to screen bounds
            _offset = Offset(
              _offset.dx.clamp(0.0, size.width - 150.0),
              _offset.dy.clamp(0.0, size.height - 200.0),
            );
          });
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 150,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              children: [
                // Remote Video
                RTCVideoView(
                  widget.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                // Local Video (Small Thumbnail)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 40,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: RTCVideoView(
                        widget.localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
                // Overlay Controls
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_full,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: widget.onRestore,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: widget.onEnd,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
