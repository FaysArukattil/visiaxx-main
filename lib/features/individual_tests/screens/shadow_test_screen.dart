import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/shadow_test_provider.dart';
import '../../../core/widgets/eye_loader.dart';

class ShadowTestScreen extends StatefulWidget {
  const ShadowTestScreen({super.key});

  @override
  State<ShadowTestScreen> createState() => _ShadowTestScreenState();
}

class _ShadowTestScreenState extends State<ShadowTestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShadowTestProvider>().initializeCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShadowTestProvider>();
    final controller = provider.cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (controller != null && controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            )
          else
            const Center(child: EyeLoader()),

          // Overlay for instructions and feedback
          _buildOverlay(context, provider),

          // Back button
          Positioned(
            top: 48,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Loading Indicator for analysis
          if (provider.isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EyeLoader(),
                    SizedBox(height: 24),
                    Text(
                      'Analyzing Shadow Pattern...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, ShadowTestProvider provider) {
    return Column(
      children: [
        const SizedBox(height: 100),
        // Instructions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            'Testing ${provider.currentEye.toUpperCase()} Eye',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const Spacer(),

        // Eye detection guide
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: provider.isReadyForCapture
                    ? context.success
                    : Colors.white54,
                width: 3,
              ),
            ),
            child: provider.isCapturing
                ? null
                : Icon(
                    provider.isReadyForCapture
                        ? Icons.check_circle_rounded
                        : Icons.visibility_rounded,
                    color: provider.isReadyForCapture
                        ? context.success
                        : Colors.white54,
                    size: 48,
                  ),
          ),
        ),

        const Spacer(),

        // Feedback and Capture Action
        _buildFeedbackPanel(context, provider),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildFeedbackPanel(
    BuildContext context,
    ShadowTestProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                provider.isEyeDetected ? Icons.lens : Icons.lens_outlined,
                color: provider.isEyeDetected ? context.success : Colors.grey,
                size: 12,
              ),
              const SizedBox(width: 12),
              Text(
                provider.readinessFeedback,
                style: TextStyle(
                  color: provider.isReadyForCapture
                      ? Colors.white
                      : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: provider.isReadyForCapture && !provider.isCapturing
                  ? () => provider.captureAndAnalyze()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Capture Shadow',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              style: TextStyle(color: context.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
