import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_recognition_provider.dart';
import '../services/voice_recognition_service.dart';
import '../extensions/theme_extension.dart';

/// A draggable, glassmorphic overlay widget for voice input visualization
///
/// Features:
/// - Waveform animation (primary color when active, red when error)
/// - Drag-to-move functionality
/// - Restart button for error recovery
/// - Recognized speech subtitle display
/// - Glassmorphic transparent design
class VoiceInputOverlay extends StatefulWidget {
  /// Whether voice recognition is actively being used for this screen
  final bool isActive;

  /// Callback when voice is recognized (provides matched text and if final)
  final Function(String recognizedText, bool isFinal)? onVoiceResult;

  /// Optional vocabulary for matching
  final List<String>? vocabulary;

  const VoiceInputOverlay({
    super.key,
    this.isActive = true,
    this.onVoiceResult,
    this.vocabulary,
  });

  @override
  State<VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends State<VoiceInputOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  Offset _position = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Start listening when widget is created and active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isActive) {
        _startListening();
      }
    });
  }

  @override
  void didUpdateWidget(VoiceInputOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.isActive) {
            _startListening();
          } else {
            _stopListening();
          }
        }
      });
    }
  }

  void _startListening() {
    final provider = context.read<VoiceRecognitionProvider>();
    if (!provider.isEnabled) return;

    provider.startListening(
      onResult: (text, isFinal) {
        if (widget.onVoiceResult != null) {
          // If vocabulary is provided, try to match
          if (widget.vocabulary != null && widget.vocabulary!.isNotEmpty) {
            final matched = provider.service.matchVocabulary(
              text,
              widget.vocabulary!,
            );
            if (matched != null) {
              widget.onVoiceResult!(matched, isFinal);
            }
          } else {
            widget.onVoiceResult!(text, isFinal);
          }
        }
      },
      vocabularyHints:
          widget.vocabulary, // Pass vocabulary hints for better recognition
    );
  }

  void _stopListening() {
    context.read<VoiceRecognitionProvider>().stopListening();
  }

  void _restartRecognition() {
    final provider = context.read<VoiceRecognitionProvider>();
    provider.restart();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceRecognitionProvider>(
      builder: (context, provider, child) {
        // Show if enabled, even if not yet fully available (we'll show a loading state)
        if (!provider.isEnabled) {
          return const SizedBox.shrink();
        }

        final screenSize = MediaQuery.of(context).size;
        final isError =
            provider.state == VoiceRecognitionState.error ||
            provider.state == VoiceRecognitionState.unavailable;
        final isListening =
            provider.state == VoiceRecognitionState.listening ||
            provider.state == VoiceRecognitionState.processing;

        final stateColor = isError
            ? context.error
            : !provider.isInitialized
            ? context.textSecondary.withValues(alpha: 0.5)
            : isListening
            ? context.primary
            : context.textSecondary;

        // Sync position with provider if needed
        if (_position == Offset.zero) {
          if (provider.overlayPosition != Offset.zero) {
            _position = provider.overlayPosition;
          } else {
            _position = Offset(
              (screenSize.width - 180) / 2,
              screenSize.height - 180,
            );
          }
        }

        return Positioned(
          left: _position.dx.clamp(0, screenSize.width - 180),
          top: _position.dy.clamp(0, screenSize.height - 100),
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
              });
            },
            onPanEnd: (_) {
              setState(() => _isDragging = false);
              provider.setOverlayPosition(_position);
            },
            child: AnimatedOpacity(
              opacity: _isDragging ? 0.7 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: _buildOverlayContent(
                provider,
                stateColor,
                isError,
                isListening,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayContent(
    VoiceRecognitionProvider provider,
    Color stateColor,
    bool isError,
    bool isListening,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.isDarkMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.7),
                context.isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: stateColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: stateColor.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waveform + Controls Row
              Row(
                children: [
                  // Mic icon with status
                  Icon(
                    isError
                        ? Icons.mic_off_rounded
                        : isListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    color: stateColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  // Waveform visualization
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(80, 24),
                          painter: _WaveformPainter(
                            animation: _waveController.value,
                            audioLevel: provider.audioLevel,
                            color: stateColor,
                            isActive: isListening,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Restart button (only show on error)
                  if (isError)
                    GestureDetector(
                      onTap: _restartRecognition,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: context.error,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
              // Recognized text or status subtitle
              if (provider.recognizedText.isNotEmpty ||
                  !provider.isInitialized) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider.recognizedText.isNotEmpty
                        ? provider.recognizedText
                        : isError
                        ? (provider.lastError ?? 'Unknown Error')
                        : !provider.isInitialized
                        ? 'Initializing voice...'
                        : 'Listening...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isError ? context.error : context.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for waveform visualization
class _WaveformPainter extends CustomPainter {
  final double animation;
  final double audioLevel;
  final Color color;
  final bool isActive;

  _WaveformPainter({
    required this.animation,
    required this.audioLevel,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    const barCount = 7;
    final barWidth = size.width / (barCount * 2);
    final maxHeight = size.height * 0.8;
    final minHeight = size.height * 0.2;

    for (int i = 0; i < barCount; i++) {
      // Create wave pattern with audio level influence
      double height;
      if (isActive) {
        // Active: respond to audio level and animation
        final wave = (animation * 2 - 1).abs();
        final barFactor = 0.5 + 0.5 * ((i / barCount) * wave);
        final levelHeight = minHeight + (maxHeight - minHeight) * audioLevel;
        height = minHeight + (levelHeight - minHeight) * barFactor;
      } else {
        // Inactive: show minimal height
        height = minHeight;
      }

      final x = i * barWidth * 2 + barWidth;
      final top = (size.height - height) / 2;

      canvas.drawLine(Offset(x, top), Offset(x, top + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.color != color ||
        oldDelegate.isActive != isActive;
  }
}
