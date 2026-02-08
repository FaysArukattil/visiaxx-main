import 'package:flutter/material.dart';
import '../../../../core/widgets/eye_loader.dart';

class AnalysisLoadingWidget extends StatelessWidget {
  final bool isRightEye;

  const AnalysisLoadingWidget({super.key, required this.isRightEye});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.94),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EyeLoader.fullScreen(),
          const SizedBox(height: 48),
          Text(
            'Analyzing ${isRightEye ? "RIGHT" : "LEFT"} Eye',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Processing clinical patterns...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
