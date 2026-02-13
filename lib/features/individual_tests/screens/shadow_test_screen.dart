import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'dart:ui' as ui;
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/shadow_test_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/utils/navigation_utils.dart';

class ShadowTestScreen extends StatefulWidget {
  const ShadowTestScreen({super.key});

  @override
  State<ShadowTestScreen> createState() => _ShadowTestScreenState();
}

class _ShadowTestScreenState extends State<ShadowTestScreen> {
  // Local reference to camera controller to ensure reliable UI updates in release mode
  CameraController? _localController;

  @override
  void initState() {
    super.initState();
    // Reset state IMMEDIATELY and synchronously before the first build
    context.read<ShadowTestProvider>().setState(ShadowTestState.initial);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shadowProvider = context.read<ShadowTestProvider>();
      await shadowProvider.initializeCamera();
      if (!mounted) return;
      context.read<TestSessionProvider>().startIndividualTest('shadow_test');

      // Get the controller and add local listener for reliable release mode updates
      final controller = shadowProvider.cameraController;
      if (controller != null) {
        controller.addListener(_onCameraUpdate);
        setState(() {
          _localController = controller;
        });
      }
    });
  }

  void _onCameraUpdate() {
    if (mounted && _localController != null) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _localController?.removeListener(_onCameraUpdate);
    // Mandatory teardown to prevent camera/flash from staying on
    context.read<ShadowTestProvider>().stopCamera();
    super.dispose();
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          onContinue: () {
            // Just close the dialog
          },
          onRestart: () {
            provider.resetKeepProfile();
            // Start the test again with a clean state
            final shadowProvider = context.read<ShadowTestProvider>();
            shadowProvider.setState(ShadowTestState.initial);
            shadowProvider.initializeCamera();
          },
          onExit: () async {
            // Ensure flash is off before navigating away
            final shadowProvider = context.read<ShadowTestProvider>();
            await shadowProvider.stopCamera();
            if (mounted) {
              await NavigationUtils.navigateHome(context);
            }
          },
          hasCompletedTests: provider.hasAnyCompletedTest,
          onSaveAndExit: provider.hasAnyCompletedTest
              ? () async {
                  // Ensure flash is off before navigating away
                  final shadowProvider = context.read<ShadowTestProvider>();
                  await shadowProvider.stopCamera();
                  if (mounted) {
                    Navigator.pushReplacementNamed(
                      context,
                      '/quick-test-result',
                    );
                  }
                }
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShadowTestProvider>();
    // Use local controller for reliable release mode updates
    final controller = _localController;

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera Preview - Using explicit sizing for release mode compatibility
            if (controller != null &&
                controller.value.isInitialized &&
                !provider.isCameraStarting)
              Positioned.fill(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize!.height,
                      height: controller.value.previewSize!.width,
                      child: CameraPreview(controller),
                    ),
                  ),
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
                onPressed: _showExitConfirmation,
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
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, ShadowTestProvider provider) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final safeArea = MediaQuery.of(context).padding;

        return Stack(
          children: [
            // Instructions at the top
            Positioned(
              top: isLandscape ? 20 : 100,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Testing ${provider.currentEye.toUpperCase()} Eye',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Eye detection guide circle in the center
            Center(
              child: Container(
                width: isLandscape ? 200 : 280,
                height: isLandscape ? 200 : 280,
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

            // Feedback and Capture Action at the bottom
            Positioned(
              bottom: isLandscape ? 8 : 28 + safeArea.bottom,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.error.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        provider.errorMessage!,
                        style: TextStyle(
                          color: context.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Feedback Card - Refined to be more compact
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: provider.isReadyForCapture
                              ? context.success.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: provider.isReadyForCapture
                                ? context.success.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              provider.isReadyForCapture
                                  ? 'READY TO CAPTURE'
                                  : 'POSITIONING...',
                              style: TextStyle(
                                color: provider.isReadyForCapture
                                    ? context.success
                                    : Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              provider.readinessFeedback,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Capture Action
                  GestureDetector(
                    onTap: provider.isReadyForCapture && !provider.isCapturing
                        ? () {
                            final sessionProvider = context
                                .read<TestSessionProvider>();
                            provider.captureAndAnalyze(sessionProvider);
                          }
                        : null,
                    child: Container(
                      width: isLandscape ? 64 : 76,
                      height: isLandscape ? 64 : 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (provider.isReadyForCapture)
                            BoxShadow(
                              color: context.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: provider.isReadyForCapture
                              ? [
                                  context.primary,
                                  context.primary.withValues(alpha: 0.8),
                                ]
                              : [Colors.white24, Colors.white12],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 3.5,
                        ),
                      ),
                      child: provider.isCapturing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: isLandscape ? 28 : 32,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
