import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
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

    // Check if we already have a video for this phase
    if (provider.currentVideoPath != null) {
      final confirmed = await _showReRecordingConfirmation(provider);
      if (!confirmed) return;
      // Clear existing video before starting new one
      provider.setRecording(false, clearPath: true);
    }

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

  Future<bool> _showReRecordingConfirmation(CoverTestProvider provider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.primary, size: 28),
            const SizedBox(width: 12),
            const Text('Overwrite Video?'),
          ],
        ),
        content: Text(
          'Should this remove the current captured video of ${provider.currentPhaseLabel}?',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Remove & Re-record'),
          ),
        ],
      ),
    );
    return result ?? false;
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
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              title: _buildAppBarTitle(provider),
              actions: [
                if (provider.currentStep != CoverTestStep.instructions &&
                    provider.currentStep != CoverTestStep.result)
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: _toggleFlash,
                  ),
              ],
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: _showExitConfirmation,
              ),
            ),
            body: _buildCurrentState(provider),
          ),
        );
      },
    );
  }

  Widget _buildAppBarTitle(CoverTestProvider provider) {
    if (provider.currentStep == CoverTestStep.instructions ||
        provider.currentStep == CoverTestStep.result) {
      return const Text(
        'Cover-Uncover Test',
        style: TextStyle(fontWeight: FontWeight.bold),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final stepNum = index + 1;
        final isCompleted = index < provider.observations.length;
        final isCurrent = index == provider.observations.length;

        return Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isCompleted
                ? context.primary
                : isCurrent
                ? context.primary.withValues(alpha: 0.2)
                : context.dividerColor.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? context.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: context.primary, size: 14)
                : Text(
                    '$stepNum',
                    style: TextStyle(
                      color: isCurrent
                          ? context.primary
                          : context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      }),
    );
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

    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full Screen Camera Preview
        if (_isCameraInitialized && _cameraController != null)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: context.primary),
            ),
          ),

        // Eye alignment overlay (Full Screen)
        Positioned.fill(
          child: _buildEyeAlignmentOverlay(
            isLeftCovered,
            isRightCovered,
            provider.isRecording,
          ),
        ),

        // 🟢 Instructions Overlay (Top - Safe Area)
        SafeArea(
          child: _buildInstructionOverlay(
            instruction,
            eyeToObserve,
            provider.currentVideoPath != null,
          ),
        ),

        // Recording Border
        if (provider.isRecording)
          Positioned.fill(
            child:
                Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 4),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(
                      duration: 1000.ms,
                      color: Colors.red.withValues(alpha: 0.2),
                    ),
          ),

        // Recording Status & Time (Safe Area)
        SafeArea(child: _buildRecordingOverlay(provider.isRecording)),

        // 🟢 Diagnostic Buttons Overlay (Bottom in Portrait, Right in Landscape)
        if (isLandscape)
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Center(
                child: SizedBox(
                  width: 210, // Compact for landscape to avoid overlap
                  child: _buildMovementOptions(provider),
                ),
              ),
            ),
          )
        else
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: _buildMovementOptions(provider),
              ),
            ),
          ),
      ],
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

  Widget _buildInstructionOverlay(
    String instruction,
    String eyeToObserve,
    bool isCaptured,
  ) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  instruction.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  eyeToObserve,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.primary.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isCaptured) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.success.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'CAPTURED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideX(begin: -0.2),
          ],
        ],
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
    const double spacing = 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: [Spacer] | Upward | [Spacer]
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(width: spacing),
            Expanded(child: _buildDPadButton(provider, EyeMovement.upward)),
            const SizedBox(width: spacing),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: spacing),
        // Row 2: Inward | NO MOVEMENT | Outward
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: _buildDPadButton(provider, EyeMovement.inward)),
            const SizedBox(width: spacing),
            Expanded(
              child: _buildDPadButton(
                provider,
                EyeMovement.none,
                label: 'NO\nMOVEMENT',
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(child: _buildDPadButton(provider, EyeMovement.outward)),
          ],
        ),
        const SizedBox(height: spacing),
        // Row 3: [Spacer] | Downward | [Spacer]
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(width: spacing),
            Expanded(child: _buildDPadButton(provider, EyeMovement.downward)),
            const SizedBox(width: spacing),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildDPadButton(
    CoverTestProvider provider,
    EyeMovement movement, {
    String? label,
    bool isFullWidth = false,
  }) {
    final movementLabel = label ?? movement.name.toUpperCase();
    final isNone = movement == EyeMovement.none;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
              splashColor: context.primary.withValues(alpha: 0.3),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Container(
                width: isFullWidth ? double.infinity : null,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNone
                          ? Icons.do_not_disturb_on_rounded
                          : _getMovementIcon(movement),
                      color: isNone ? Colors.white70 : context.primary,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movementLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getMovementIcon(EyeMovement movement) {
    switch (movement) {
      case EyeMovement.inward:
        return Icons.keyboard_arrow_left;
      case EyeMovement.outward:
        return Icons.keyboard_arrow_right;
      case EyeMovement.upward:
        return Icons.keyboard_arrow_up;
      case EyeMovement.downward:
        return Icons.keyboard_arrow_down;
      default:
        return Icons.circle;
    }
  }
}
