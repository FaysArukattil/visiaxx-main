import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/constants/app_colors.dart';

/// Interactive animation showing how to respond to the E test
/// Shows E appearing and the correct button being pressed or voice command
class HowToRespondAnimation extends StatefulWidget {
  final bool isCompact;

  const HowToRespondAnimation({super.key, this.isCompact = false});

  @override
  State<HowToRespondAnimation> createState() => _HowToRespondAnimationState();
}

class _HowToRespondAnimationState extends State<HowToRespondAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentDirection = 0;
  final List<_DirectionDemo> _directions = [
    _DirectionDemo(
      label: 'UPWARD',
      rotation: 0,
      voiceText: 'Say: "Upper" or "Upward"',
      buttonPosition: _ButtonPosition.top,
    ),
    _DirectionDemo(
      label: 'DOWNWARD',
      rotation: 180,
      voiceText: 'Say: "Down" or "Downward"',
      buttonPosition: _ButtonPosition.bottom,
    ),
    _DirectionDemo(
      label: 'LEFT',
      rotation: 270,
      voiceText: 'Say: "Left"',
      buttonPosition: _ButtonPosition.left,
    ),
    _DirectionDemo(
      label: 'RIGHT',
      rotation: 90,
      voiceText: 'Say: "Right"',
      buttonPosition: _ButtonPosition.right,
    ),
    _DirectionDemo(
      label: 'BLURRY',
      rotation: 0, // Doesn't matter for blurry
      voiceText: 'Say: "Blurry" or "Nothing" if you can\'t see clearly',
      buttonPosition: _ButtonPosition.blurry,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 3500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                setState(() {
                  _currentDirection =
                      (_currentDirection + 1) % _directions.length;
                });
                _controller.reset();
                _controller.forward();
              }
            });
          }
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.isCompact ? 50.0 : 60.0;
    final eSize = widget.isCompact ? 50.0 : 60.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main animation area
        Container(
          height: widget.isCompact ? 280.0 : 320.0,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final fadeIn = (_controller.value * 2).clamp(0.0, 1.0);
              final buttonPress =
                  (_controller.value > 0.4 && _controller.value < 0.7)
                  ? ((_controller.value - 0.4) / 0.3).clamp(0.0, 1.0)
                  : 0.0;

              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top button
                    _buildDirectionButton(
                      Icons.arrow_upward,
                      buttonSize,
                      _ButtonPosition.top,
                      buttonPress,
                      fadeIn,
                    ),
                    const SizedBox(height: 12),

                    // Middle row: Left button, E, Right button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDirectionButton(
                          Icons.arrow_back,
                          buttonSize,
                          _ButtonPosition.left,
                          buttonPress,
                          fadeIn,
                        ),
                        SizedBox(width: widget.isCompact ? 40 : 50),

                        // E letter in center (hidden for blurry demo)
                        _currentDirection < 4
                            ? Opacity(
                                opacity: fadeIn,
                                child: Transform.rotate(
                                  angle:
                                      _directions[_currentDirection].rotation *
                                      pi /
                                      180,
                                  child: Text(
                                    'E',
                                    style: TextStyle(
                                      fontSize: eSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: eSize,
                                height: eSize,
                                child: Icon(
                                  Icons.blur_on,
                                  size: eSize,
                                  color: Colors.grey.shade300,
                                ),
                              ),

                        SizedBox(width: widget.isCompact ? 40 : 50),
                        _buildDirectionButton(
                          Icons.arrow_forward,
                          buttonSize,
                          _ButtonPosition.right,
                          buttonPress,
                          fadeIn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bottom button
                    _buildDirectionButton(
                      Icons.arrow_downward,
                      buttonSize,
                      _ButtonPosition.bottom,
                      buttonPress,
                      fadeIn,
                    ),

                    const SizedBox(height: 16),

                    // Blurry button at bottom
                    Opacity(
                      opacity: fadeIn,
                      child: _buildBlurryButton(buttonPress, widget.isCompact),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: widget.isCompact ? 12 : 16),

        // Direction label with voice instruction
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey(_currentDirection),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 16 : 20,
              vertical: widget.isCompact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentDirection < 4
                          ? _getDirectionIcon()
                          : Icons.visibility_off,
                      color: _currentDirection < 4
                          ? AppColors.primary
                          : AppColors.warning,
                      size: widget.isCompact ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentDirection < 4
                          ? 'Tap ${_directions[_currentDirection].label} button'
                          : 'Tap "Can\'t See Clearly" button',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 13 : 14,
                        fontWeight: FontWeight.bold,
                        color: _currentDirection < 4
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic,
                      color: AppColors.success,
                      size: widget.isCompact ? 14 : 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _directions[_currentDirection].voiceText,
                        style: TextStyle(
                          fontSize: widget.isCompact ? 11 : 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionButton(
    IconData icon,
    double size,
    _ButtonPosition position,
    double pressProgress,
    double fadeIn,
  ) {
    final isActive = _directions[_currentDirection].buttonPosition == position;
    final scale = isActive ? 1.0 - (pressProgress * 0.15) : 1.0;

    return Opacity(
      opacity: fadeIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        child: Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: isActive && pressProgress > 0
                  ? AppColors.primary
                  : Colors.blue,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isActive && pressProgress > 0
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBlurryButton(double pressProgress, bool isCompact) {
    final isActive =
        _directions[_currentDirection].buttonPosition == _ButtonPosition.blurry;
    final scale = isActive ? 1.0 - (pressProgress * 0.1) : 1.0;

    return Transform.scale(
      scale: scale,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isCompact
              ? 150.0
              : 180.0, // Reduced width to prevent overflow
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive && pressProgress > 0
              ? AppColors.warning
              : Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning, width: 2),
          boxShadow: isActive && pressProgress > 0
              ? [
                  BoxShadow(
                    color: AppColors.warning.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off,
              size: isCompact ? 16 : 18,
              color: isActive && pressProgress > 0
                  ? Colors.white
                  : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "Can't See Clearly",
                style: TextStyle(
                  fontSize: isCompact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: isActive && pressProgress > 0
                      ? Colors.white
                      : AppColors.warning,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDirectionIcon() {
    switch (_currentDirection) {
      case 0:
        return Icons.arrow_upward;
      case 1:
        return Icons.arrow_downward;
      case 2:
        return Icons.arrow_back;
      case 3:
        return Icons.arrow_forward;
      default:
        return Icons.arrow_upward;
    }
  }
}

enum _ButtonPosition { top, bottom, left, right, blurry }

class _DirectionDemo {
  final String label;
  final double rotation;
  final String voiceText;
  final _ButtonPosition buttonPosition;

  _DirectionDemo({
    required this.label,
    required this.rotation,
    required this.voiceText,
    required this.buttonPosition,
  });
}
