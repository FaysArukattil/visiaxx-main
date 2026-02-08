import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../../core/extensions/theme_extension.dart';
import '../../../../core/widgets/eye_loader.dart';

class CameraCaptureWidget extends StatelessWidget {
  final bool isRightEye;
  final CameraController? cameraController;
  final VoidCallback onCapture;
  final VoidCallback onFlashToggle;
  final bool isFlashlightOn;
  final String? distanceFeedback;
  final bool isAtProperDistance;

  const CameraCaptureWidget({
    super.key,
    required this.isRightEye,
    this.cameraController,
    required this.onCapture,
    required this.onFlashToggle,
    required this.isFlashlightOn,
    this.distanceFeedback,
    required this.isAtProperDistance,
  });

  @override
  Widget build(BuildContext context) {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return const Center(child: EyeLoader());
    }

    final size = MediaQuery.of(context).size;
    final scale = 1 / (cameraController!.value.aspectRatio * size.aspectRatio);

    return Stack(
      children: [
        // Camera Preview
        ClipRect(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: CameraPreview(cameraController!),
            ),
          ),
        ),

        // Guide Overlay
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isAtProperDistance ? context.success : Colors.white24,
                width: 3,
              ),
            ),
          ),
        ),

        // Top Info
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Capturing ${isRightEye ? "RIGHT" : "LEFT"} Eye',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // Controls Area
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Distance Feedback
              if (distanceFeedback != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isAtProperDistance
                        ? context.success.withValues(alpha: 0.8)
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    distanceFeedback!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Flash Toggle
                  IconButton(
                    onPressed: onFlashToggle,
                    icon: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFlashlightOn
                            ? context.primary
                            : Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFlashlightOn
                            ? Icons.flashlight_on
                            : Icons.flashlight_off,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Capture Button
                  GestureDetector(
                    onTap: onCapture,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: isAtProperDistance
                            ? context.primary
                            : Colors.white10,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                  // Spacer for symmetry
                  const SizedBox(width: 48),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
