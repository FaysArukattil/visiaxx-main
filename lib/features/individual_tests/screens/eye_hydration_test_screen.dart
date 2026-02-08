import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/providers/eye_hydration_provider.dart';
import '../../quick_vision_test/screens/distance_calibration_screen.dart';
import '../widgets/eye_blink_animation.dart';

class EyeHydrationTestScreen extends StatefulWidget {
  const EyeHydrationTestScreen({super.key});

  @override
  State<EyeHydrationTestScreen> createState() => _EyeHydrationTestScreenState();
}

class _EyeHydrationTestScreenState extends State<EyeHydrationTestScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _showDistanceCalibration = true;

  @override
  void initState() {
    super.initState();

    // Do NOT initialize camera here if showing distance calibration
    // It will be initialized in _onCalibrationComplete
    if (!_showDistanceCalibration) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        // We will start the test after distance calibration
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          onContinue: () {},
          onRestart: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const EyeHydrationTestScreen(),
              ),
            );
          },
          onExit: () async => await NavigationUtils.navigateHome(context),
          hasCompletedTests: provider.hasAnyCompletedTest,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Consumer<EyeHydrationProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: context.scaffoldBackground,
            appBar: AppBar(
              title: const Text(
                'Eye Hydration',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              backgroundColor: context.cardColor,
              leading: IconButton(
                icon: Icon(Icons.close, color: context.textPrimary),
                onPressed: _showExitConfirmation,
              ),
            ),
            body: SafeArea(
              child: _showDistanceCalibration
                  ? _buildDistanceCalibrationView()
                  : OrientationBuilder(
                      builder: (context, orientation) {
                        if (orientation == Orientation.landscape) {
                          return _buildLandscapeBody(provider);
                        }
                        return _buildPortraitBody(provider);
                      },
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDistanceCalibrationView() {
    return DistanceCalibrationScreen(
      targetDistanceCm: 40.0,
      toleranceCm: 5.0,
      onCalibrationComplete: () {
        setState(() => _showDistanceCalibration = false);
        // Add a small delay to ensure previous camera is fully released
        Future.delayed(const Duration(milliseconds: 500), () {
          _initializeCamera().then((_) {
            final provider = context.read<EyeHydrationProvider>();
            provider.startTest(_controller!);
          });
        });
      },
      onSkip: () {
        setState(() => _showDistanceCalibration = false);
        // Add a small delay to ensure previous camera is fully released
        Future.delayed(const Duration(milliseconds: 500), () {
          _initializeCamera().then((_) {
            final provider = context.read<EyeHydrationProvider>();
            provider.startTest(_controller!);
          });
        });
      },
    );
  }

  Widget _buildPortraitBody(EyeHydrationProvider provider) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildAnimationHeader(provider),
        _buildBlinkCounterPremium(provider),
        _buildDetectionWarning(provider),
        Expanded(child: _buildReadingContent(provider)),
        _buildActionButtons(provider),
      ],
    );
  }

  Widget _buildLandscapeBody(EyeHydrationProvider provider) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Main reading area
              Expanded(flex: 5, child: _buildReadingContent(provider)),
              // Sidebar with controls and feedback
              Container(
                width: 220,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  border: Border(
                    left: BorderSide(
                      color: context.dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildAnimationHeader(provider, size: 70),
                      const SizedBox(height: 12),
                      _buildBlinkCounterPremium(provider, isCompact: true),
                      const SizedBox(height: 8),
                      _buildDetectionWarning(provider),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Full width bottom button
        _buildActionButtons(provider),
      ],
    );
  }

  Widget _buildAnimationHeader(
    EyeHydrationProvider provider, {
    double size = 120,
  }) {
    return SizedBox(
      height: size + 20,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.cardColor,
            boxShadow: [
              BoxShadow(
                color: (provider.faceDetected ? context.primary : context.error)
                    .withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: provider.faceDetected ? context.success : context.error,
              width: 2,
            ),
          ),
          child: Center(
            child: EyeBlinkAnimation(
              size: size * 0.8,
              blinkStream: provider.blinkStream,
              isFaceDetected: provider.faceDetected,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionWarning(EyeHydrationProvider provider) {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
          child: Text(
            provider.faceDetected
                ? 'Scanning for blinks...'
                : 'No face detected! Reposition device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: provider.faceDetected ? context.primary : context.error,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(duration: 800.ms)
        .fadeOut(delay: 1500.ms, duration: 800.ms);
  }

  Widget _buildReadingContent(EyeHydrationProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.readingContent[0],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...provider.readingContent
                .skip(1)
                .map(
                  (para) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      para,
                      style: TextStyle(
                        fontSize: 17,
                        color: context.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    EyeHydrationProvider provider, {
    bool isCompact = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, isCompact ? 8 : 24),
      child: SizedBox(
        width: double.infinity,
        height: isCompact ? 48 : 56,
        child: ElevatedButton(
          onPressed: () async {
            debugPrint('🏁 Finish Reading pressed');
            await provider.stopTest();
            if (mounted) {
              final result = provider.finalResult;
              if (result != null) {
                debugPrint('✅ Saving result and navigating');
                context.read<TestSessionProvider>().setEyeHydrationResult(
                  result,
                );
                Navigator.pushReplacementNamed(context, '/quick-test-result');
              } else {
                debugPrint('❌ Error: Final result is NULL');
                Navigator.of(context).pop();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: Text(
            'Finish Reading',
            style: TextStyle(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlinkCounterPremium(
    EyeHydrationProvider provider, {
    bool isCompact = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${provider.blinkCount}',
          style: TextStyle(
            fontSize: isCompact ? 28 : 36,
            fontWeight: FontWeight.w900,
            color: context.primary,
            height: 1.1,
          ),
        ),
        Text(
          'BLINKS DETECTED',
          style: TextStyle(
            fontSize: isCompact ? 8 : 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: context.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
