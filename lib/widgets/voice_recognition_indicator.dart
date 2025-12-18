import 'package:flutter/material.dart';
import 'dart:async';
import '../core/constants/app_colors.dart';

/// Universal voice recognition indicator widget
/// Shows listening state and recognized text like Siri
class VoiceRecognitionIndicator extends StatefulWidget {
  final bool isListening;
  final String? recognizedText;
  final Duration dismissDelay;
  final VoidCallback? onDismiss;

  const VoiceRecognitionIndicator({
    super.key,
    required this.isListening,
    this.recognizedText,
    this.dismissDelay = const Duration(seconds: 3),
    this.onDismiss,
  });

  @override
  State<VoiceRecognitionIndicator> createState() =>
      _VoiceRecognitionIndicatorState();
}

class _VoiceRecognitionIndicatorState extends State<VoiceRecognitionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _dismissTimer;
  String? _displayedText;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VoiceRecognitionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle listening state changes
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        setState(() => _isVisible = true);
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }

    // Handle recognized text changes
    if (widget.recognizedText != oldWidget.recognizedText &&
        widget.recognizedText != null &&
        widget.recognizedText!.isNotEmpty) {
      setState(() {
        _displayedText = widget.recognizedText;
        _isVisible = true;
      });

      // Cancel previous dismiss timer
      _dismissTimer?.cancel();

      // Start new dismiss timer
      _dismissTimer = Timer(widget.dismissDelay, () {
        if (mounted) {
          setState(() {
            _displayedText = null;
            if (!widget.isListening) {
              _isVisible = false;
            }
          });
          widget.onDismiss?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible && !widget.isListening) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedSlide(
        offset: _isVisible ? Offset.zero : const Offset(0, -0.5),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated microphone icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.isListening
                        ? 1.0 + (_pulseController.value * 0.2)
                        : 1.0,
                    child: Icon(
                      widget.isListening ? Icons.mic : Icons.mic_none,
                      color: widget.isListening
                          ? AppColors.primary
                          : Colors.white70,
                      size: 20,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),

              // Text content
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildTextContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    if (_displayedText != null && _displayedText!.isNotEmpty) {
      // Show recognized text
      return Text(
        _displayedText!,
        key: ValueKey(_displayedText),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    } else if (widget.isListening) {
      // Show listening state
      return Row(
        key: const ValueKey('listening'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Listening...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
