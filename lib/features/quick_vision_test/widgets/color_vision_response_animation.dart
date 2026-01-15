import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ColorVisionResponseAnimation extends StatefulWidget {
  const ColorVisionResponseAnimation({super.key});

  @override
  State<ColorVisionResponseAnimation> createState() =>
      _ColorVisionResponseAnimationState();
}

class _ColorVisionResponseAnimationState
    extends State<ColorVisionResponseAnimation>
    with TickerProviderStateMixin {
  late AnimationController _handController;
  late Animation<Offset> _handMoveAnimation;
  late Animation<double> _handTapAnimation;

  int _selectedOptionIndex = -1;
  final List<String> _options = ['8', '12', 'X', '5'];
  final int _correctIndex = 1; // '12'

  @override
  void initState() {
    super.initState();
    _handController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Initial position to center-bottom, move to option 1
    _handMoveAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.5, 1.2),
          end: const Offset(0.5, 0.5),
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.5, 0.5)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.5, 0.5),
          end: const Offset(0.3, 0.75),
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.3, 0.75)),
        weight: 20,
      ),
    ]).animate(_handController);

    _handTapAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.8), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 10),
    ]).animate(_handController);

    _handController.addListener(() {
      if (_handController.value > 0.75 && _selectedOptionIndex == -1) {
        setState(() => _selectedOptionIndex = _correctIndex);
      } else if (_handController.value < 0.1 && _selectedOptionIndex != -1) {
        setState(() => _selectedOptionIndex = -1);
      }
    });

    _handController.repeat();
  }

  @override
  void dispose() {
    _handController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              // Mock Plate
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '12',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Options Grid
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.5,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedOptionIndex == index;
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          _options[index],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Animated Hand
          AnimatedBuilder(
            animation: _handController,
            builder: (context, child) {
              return Positioned(
                left:
                    MediaQuery.of(context).size.width *
                    0.7 *
                    _handMoveAnimation.value.dx,
                top: 220 * _handMoveAnimation.value.dy,
                child: Transform.scale(
                  scale: _handTapAnimation.value,
                  child: Icon(
                    Icons.touch_app,
                    size: 40,
                    color: AppColors.secondary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
