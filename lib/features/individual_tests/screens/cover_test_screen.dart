import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/cover_test_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/cover_test_result.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/utils/snackbar_utils.dart';

class CoverTestScreen extends StatelessWidget {
  const CoverTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CoverTestProvider(),
      child: const _CoverTestScreenContent(),
    );
  }
}

class _CoverTestScreenContent extends StatefulWidget {
  const _CoverTestScreenContent();

  @override
  State<_CoverTestScreenContent> createState() =>
      _CoverTestScreenContentState();
}

class _CoverTestScreenContentState extends State<_CoverTestScreenContent>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isFlashOn = false;
  bool _isCameraInitialized = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int maxRecordingSeconds = 5;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _startRecording(CoverTestProvider provider) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      SnackbarUtils.showError(context, 'Camera not initialized');
      return;
    }
    if (_cameraController!.value.isRecordingVideo) return;

    // Optimistic UI update
    provider.setRecording(true);

    try {
      debugPrint('[CoverTest] 🎥 Starting video recording...');
      await _cameraController!.startVideoRecording();
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();

      setState(() {
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingSeconds++;
        });

        if (_recordingSeconds >= maxRecordingSeconds) {
          debugPrint('[CoverTest] ⏳ Max recording time reached');
          _stopRecording(provider);
        }
      });
      debugPrint('[CoverTest] ✅ Video recording started');
    } catch (e) {
      debugPrint('[CoverTest] ❌ Error starting video recording: $e');
      provider.setRecording(false); // Rollback
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to start recording');
      }
    }
  }

  Future<void> _stopRecording(CoverTestProvider provider) async {
    // If provider thinks we're recording but camera says no, sync back
    if (_cameraController == null ||
        !_cameraController!.value.isRecordingVideo) {
      debugPrint(
        '[CoverTest] ⚠️ stopRecording called but camera not recording',
      );
      provider.setRecording(false);
      return;
    }

    // Prevents "Error loading Video" by ensuring file is finalized
    if (_recordingSeconds < 2) {
      debugPrint('[CoverTest] ⏳ Too short! Minimum 2 seconds required.');
      if (mounted) {
        SnackbarUtils.showInfo(context, 'Please record for at least 2 seconds');
      }
      return;
    }

    _recordingTimer?.cancel();

    try {
      debugPrint('[CoverTest] ⏹️ Stopping video recording...');
      final file = await _cameraController!.stopVideoRecording();
      debugPrint('[CoverTest] 📁 Video saved to: ${file.path}');

      provider.setRecording(false, path: file.path);
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _recordingSeconds = 0;
        });
      }
    } catch (e) {
      debugPrint('[CoverTest] ❌ Error stopping video recording: $e');
      provider.setRecording(false);
    }
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
            // Go back to the instructions screen for a full restart
            Navigator.pushReplacementNamed(context, '/cover-test-intro');
          },
          onExit: () async {
            if (mounted) {
              await NavigationUtils.navigateHome(context);
            }
          },
          hasCompletedTests: provider.hasAnyCompletedTest,
          onSaveAndExit: provider.hasAnyCompletedTest
              ? () async {
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
    return Consumer<CoverTestProvider>(
      builder: (context, provider, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _showExitConfirmation();
          },
          child: Scaffold(
            backgroundColor: context.scaffoldBackground,
            appBar: AppBar(
              title: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Cover-Uncover Test',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (provider.currentStep != CoverTestStep.instructions &&
                    provider.currentStep != CoverTestStep.result)
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: context.primary,
                    ),
                    onPressed: _toggleFlash,
                  ),
              ],
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: context.textPrimary,
                ),
                onPressed: _showExitConfirmation,
              ),
            ),
            body: SafeArea(child: _buildCurrentState(provider)),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(CoverTestProvider provider) {
    if (provider.currentStep == CoverTestStep.instructions ||
        provider.currentStep == CoverTestStep.result) {
      return const SizedBox.shrink();
    }

    final progress = (provider.observations.length) / 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assessment in Progress',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.dividerColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(context.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildCurrentState(CoverTestProvider provider) {
    switch (provider.currentStep) {
      case CoverTestStep.instructions:
        // Auto-start since we already came from the instructions screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.startTest();
        });
        return Center(child: CircularProgressIndicator(color: context.primary));
      case CoverTestStep.result:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final sessionProvider = Provider.of<TestSessionProvider>(
            context,
            listen: false,
          );
          final result = provider.calculateResult(
            sessionProvider.profileId,
            sessionProvider.profileName,
          );

          // Save to TestSessionProvider
          sessionProvider.setCoverTestResult(result);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const QuickTestResultScreen(),
            ),
          );
        });
        return Center(child: CircularProgressIndicator(color: context.primary));
      default:
        return _buildTestPhase(provider);
    }
  }

  Widget _buildTestPhase(CoverTestProvider provider) {
    String instruction = '';
    String eyeToObserve = '';
    bool isRightCovered = false;
    bool isLeftCovered = false;

    switch (provider.currentStep) {
      case CoverTestStep.coverRight:
        instruction = 'Cover the Right Eye';
        eyeToObserve = 'Observe the LEFT Eye for movement';
        isRightCovered = true;
        break;
      case CoverTestStep.uncoverRight:
        instruction = 'Uncover the Right Eye';
        eyeToObserve = 'Observe the RIGHT Eye for movement';
        isRightCovered = false;
        break;
      case CoverTestStep.coverLeft:
        instruction = 'Cover the Left Eye';
        eyeToObserve = 'Observe the RIGHT Eye for movement';
        isLeftCovered = true;
        break;
      case CoverTestStep.uncoverLeft:
        instruction = 'Uncover the Left Eye';
        eyeToObserve = 'Observe the LEFT Eye for movement';
        isLeftCovered = false;
        break;
      default:
        break;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProgressIndicator(provider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Text(
                  instruction,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  eyeToObserve,
                  style: TextStyle(color: context.primary, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (provider.currentVideoPath != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: context.success,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'VIDEO CAPTURED',
                          style: TextStyle(
                            color: context.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isCameraInitialized && _cameraController != null)
                      CameraPreview(_cameraController!)
                    else
                      Center(
                        child: CircularProgressIndicator(
                          color: context.primary,
                        ),
                      ),

                    // Overlay to guide eye alignment
                    _buildEyeAlignmentOverlay(
                      isLeftCovered,
                      isRightCovered,
                      provider.isRecording,
                    ),

                    // Pulsing Red Border when recording
                    if (provider.isRecording)
                      Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.red, width: 4),
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(
                            duration: 1000.ms,
                            color: Colors.red.withValues(alpha: 0.2),
                          )
                          .fadeIn(duration: 500.ms),

                    // Video Recording UI
                    _buildRecordingOverlay(provider.isRecording),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Text(
                  'What movement did you observe?',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _buildMovementOptions(provider),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEyeAlignmentOverlay(
    bool leftCovered,
    bool rightCovered,
    bool isRecording,
  ) {
    return Stack(
      children: [
        // Semi-transparent overlay with eye holes
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(decoration: const BoxDecoration(color: Colors.black)),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _eyeHole(), // Patient's Right Eye (Left side of screen)
                    const SizedBox(width: 40),
                    _eyeHole(), // Patient's Left Eye (Right side of screen)
                  ],
                ),
              ),
            ],
          ),
        ),
        // Indicators for which eye is covered
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _eyeStatusIndicator(
                'Right',
                rightCovered,
              ), // Patient's perspective
              const SizedBox(width: 40),
              _eyeStatusIndicator('Left', leftCovered), // Patient's perspective
            ],
          ),
        ),
      ],
    );
  }

  Widget _eyeHole() {
    return Container(
      width: 100,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  Widget _eyeStatusIndicator(String label, bool isCovered) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(
              color: isCovered
                  ? context.primary
                  : context.dividerColor.withValues(alpha: 0.4),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(30),
            color: isCovered
                ? context.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: isCovered
              ? Icon(Icons.visibility_off, color: context.primary)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isCovered
                ? context.primary
                : context.dividerColor.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingOverlay(bool isRecording) {
    return Stack(
      children: [
        if (isRecording)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fadeIn(duration: 500.ms)
                      .fadeOut(delay: 500.ms),
                  const SizedBox(width: 8),
                  Text(
                    '0:0${maxRecordingSeconds - _recordingSeconds}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 24,
          right: 24,
          child:
              GestureDetector(
                    onTap: () {
                      final p = context.read<CoverTestProvider>();
                      if (isRecording) {
                        _stopRecording(p);
                      } else {
                        _startRecording(p);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRecording ? Colors.red : context.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isRecording ? Colors.red : context.primary)
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isRecording ? Icons.stop : Icons.videocam,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  )
                  .animate(
                    target: isRecording ? 1 : 0,
                    onPlay: (controller) {
                      if (isRecording) controller.repeat(reverse: true);
                    },
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.15, 1.15),
                    duration: 600.ms,
                    curve: Curves.easeInOut,
                  ),
        ),
      ],
    );
  }

  Widget _buildMovementOptions(CoverTestProvider provider) {
    return Column(
      children: [
        // D-Pad Layout - Horizontal Compact
        Center(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                // Top: Upward (Centered, 50% width)
                Row(
                  children: [
                    const Spacer(),
                    Expanded(
                      flex: 2,
                      child: _buildDPadButton(provider, EyeMovement.upward),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                // Middle: Inward | Outward
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildDPadButton(provider, EyeMovement.inward),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDPadButton(provider, EyeMovement.outward),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Bottom: Downward (Centered, 50% width)
                Row(
                  children: [
                    const Spacer(),
                    Expanded(
                      flex: 2,
                      child: _buildDPadButton(provider, EyeMovement.downward),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // No Movement Button
        _buildDPadButton(provider, EyeMovement.none, isFullWidth: true),
      ],
    );
  }

  Widget _buildDPadButton(
    CoverTestProvider provider,
    EyeMovement movement, {
    bool isFullWidth = false,
  }) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final p = context.read<CoverTestProvider>();
          if (p.isRecording) {
            await _stopRecording(p);
          }
          await HapticFeedback.mediumImpact();
          p.recordObservation(movement);
        },
        splashColor: context.primary.withValues(alpha: 0.15),
        highlightColor: context.primary.withValues(alpha: 0.1),
        child: Container(
          width: isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _getMovementIcon(movement),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  movement.label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getMovementIcon(EyeMovement movement) {
    IconData icon;
    switch (movement) {
      case EyeMovement.none:
        icon = Icons.block;
        break;
      case EyeMovement.inward:
        icon = Icons.arrow_back;
        break;
      case EyeMovement.outward:
        icon = Icons.arrow_forward;
        break;
      case EyeMovement.upward:
        icon = Icons.arrow_upward;
        break;
      case EyeMovement.downward:
        icon = Icons.arrow_downward;
        break;
    }
    return Icon(icon, color: context.primary, size: 18);
  }
}
