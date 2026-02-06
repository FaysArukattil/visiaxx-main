import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/shadow_test_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';

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
      context.read<TestSessionProvider>().startIndividualTest('shadow_test');
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShadowTestProvider>();
    final controller = provider.cameraController;

    // Handle navigation to results
    if (provider.state == ShadowTestState.result) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const QuickTestResultScreen(),
            ),
          );
        }
      });
    }

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

          // Flashlight Toggle Button
          Positioned(
            top: 60,
            right: 20,
            child: Column(
              children: [
                IconButton(
                  onPressed: () => provider.toggleFlashlight(),
                  icon: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: provider.isFlashOn
                          ? context.primary.withValues(alpha: 0.8)
                          : Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Icon(
                      provider.isFlashOn
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.isFlashOn ? 'Flash On' : 'Flash Off',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
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
                : const Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ],
                  ),
          ),
        ),

        const Spacer(),

        // Feedback and Capture Action
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.readinessFeedback,
                style: TextStyle(
                  color: provider.isReadyForCapture
                      ? Colors.white
                      : Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: provider.isReadyForCapture && !provider.isCapturing
                    ? () {
                        final sessionProvider = context
                            .read<TestSessionProvider>();
                        provider.captureAndAnalyze(sessionProvider);
                      }
                    : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: provider.isReadyForCapture
                        ? context.primary
                        : Colors.white24,
                  ),
                  child: provider.isCapturing
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Center(
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: provider.isReadyForCapture
                                ? Colors.white
                                : Colors.white38,
                            size: 32,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
