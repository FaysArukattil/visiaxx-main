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
      label: 'RIGHT',
      rotation: 0,
      voiceText: 'Say: "Right"',
      buttonPosition: _ButtonPosition.right,
    ),
    _DirectionDemo(
      label: 'DOWNWARD',
      rotation: 90,
      voiceText: 'Say: "Down" or "Downward"',
      buttonPosition: _ButtonPosition.bottom,
    ),
    _DirectionDemo(
      label: 'LEFT',
      rotation: 180,
      voiceText: 'Say: "Left"',
      buttonPosition: _ButtonPosition.left,
    ),
    _DirectionDemo(
      label: 'UPWARD',
      rotation: 270,
      voiceText: 'Say: "Upper" or "Upward"',
      buttonPosition: _ButtonPosition.top,
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
    const buttonSize = 60.0;
    const eSize = 60.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final fadeIn = (_controller.value * 2.5).clamp(0.0, 1.0);
              final buttonPress =
                  (_controller.value > 0.5 && _controller.value < 0.8)
                  ? ((_controller.value - 0.5) / 0.3).clamp(0.0, 1.0)
                  : 0.0;

              final interactivePart = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDirectionButton(
                    Icons.arrow_upward,
                    buttonSize,
                    _ButtonPosition.top,
                    buttonPress,
                    fadeIn,
                  ),
                  const SizedBox(height: 12),
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
                      const SizedBox(width: 50),
                      _currentDirection < 4
                          ? Opacity(
                              opacity: fadeIn,
                              child: Transform.rotate(
                                angle:
                                    _directions[_currentDirection].rotation *
                                    pi /
                                    180,
                                child: const Text(
                                  'E',
                                  style: TextStyle(
                                    fontSize: eSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
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
                                color: AppColors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                      const SizedBox(width: 50),
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
                  _buildDirectionButton(
                    Icons.arrow_downward,
                    buttonSize,
                    _ButtonPosition.bottom,
                    buttonPress,
                    fadeIn,
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: fadeIn,
                    child: _buildBlurryButton(buttonPress, false),
                  ),
                ],
              );

              final labelsPart = AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_currentDirection),
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      width: 1,
                    ),
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
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _currentDirection < 4
                                  ? 'Tap ${_directions[_currentDirection].label}'
                                  : 'Tap "Can\'t See Clearly"',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _currentDirection < 4
                                    ? AppColors.primary
                                    : AppColors.warning,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mic,
                            color: AppColors.success,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _directions[_currentDirection].voiceText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: isLandscape
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            interactivePart,
                            const SizedBox(width: 30),
                            labelsPart,
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            interactivePart,
                            const SizedBox(height: 20),
                            labelsPart,
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
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
    final isPressed = isActive && pressProgress > 0.2;
    final scale = isPressed ? 1.0 - (pressProgress * 0.15) : 1.0;

    return Opacity(
      opacity: fadeIn,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  color: isPressed ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary,
                    width: isPressed ? 0 : 2,
                  ),
                  boxShadow: isPressed
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Icon(
                  icon,
                  color: isPressed ? AppColors.surface : AppColors.primary,
                  size: size * 0.5,
                ),
              ),
            ),
          ),
          if (isActive && pressProgress > 0.1)
            Positioned(
              right: -5,
              bottom: -5,
              child: Opacity(
                opacity: (pressProgress * 2).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    (1.0 - (pressProgress * 2).clamp(0.0, 1.0)) * 20,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: Icon(
                      Icons.touch_app,
                      color: AppColors.warning,
                      size: size * 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlurryButton(double pressProgress, bool isCompact) {
    final isActive =
        _directions[_currentDirection].buttonPosition == _ButtonPosition.blurry;
    final isPressed = isActive && pressProgress > 0.2;
    final scale = isPressed ? 1.0 - (pressProgress * 0.1) : 1.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.scale(
          scale: scale,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isPressed ? AppColors.warning : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning, width: 2),
              boxShadow: isPressed
                  ? [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
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
                  size: 18,
                  color: isPressed ? AppColors.white : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Can't See Clearly",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPressed ? AppColors.surface : AppColors.warning,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isActive && pressProgress > 0.1)
          Positioned(
            right: -10,
            bottom: -5,
            child: Opacity(
              opacity: (pressProgress * 2).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(
                  0,
                  (1.0 - (pressProgress * 2).clamp(0.0, 1.0)) * 20,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: Icon(
                    Icons.touch_app,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getDirectionIcon() {
    switch (_currentDirection) {
      case 0: // RIGHT
        return Icons.arrow_forward;
      case 1: // DOWNWARD
        return Icons.arrow_downward;
      case 2: // LEFT
        return Icons.arrow_back;
      case 3: // UPWARD
        return Icons.arrow_upward;
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
