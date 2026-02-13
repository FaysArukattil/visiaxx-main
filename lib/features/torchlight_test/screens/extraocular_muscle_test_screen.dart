import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/torchlight_test_result.dart';
import '../../../data/providers/extraocular_muscle_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/premium_dropdown.dart';
import '../../../core/services/tts_service.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';

class ExtraocularMuscleTestScreen extends StatefulWidget {
  const ExtraocularMuscleTestScreen({super.key});

  @override
  State<ExtraocularMuscleTestScreen> createState() =>
      _ExtraocularMuscleTestScreenState();
}

class _ExtraocularMuscleTestScreenState
    extends State<ExtraocularMuscleTestScreen> {
  String _currentDirection = 'Medial';
  final List<String> _directions = [
    'Medial',
    'Lateral',
    'Superior',
    'Inferior',
    'Superior Medial',
    'Superior Lateral',
    'Inferior Medial',
    'Inferior Lateral',
    'Convergence',
  ];
  int _directionIndex = 0;
  late final PageController _pageController;

  // Flashlight state
  bool _isFlashOn = false;

  // Video recording state
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String? _recordedVideoPath;
  bool _showPreview = false;

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExtraocularMuscleProvider>().startAlignment();
    });
    _pageController = PageController();
    _initCamera();
  }

  @override
  void dispose() {
    _turnOffFlash();
    _cameraController?.dispose();
    _pageController.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _toggleFlash(bool on) async {
    if (_cameraController == null || !_isCameraInitialized) {
      setState(() => _isFlashOn = on);
      return;
    }
    try {
      await _cameraController!.setFlashMode(
        on ? FlashMode.torch : FlashMode.off,
      );
      setState(() => _isFlashOn = on);
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  Future<void> _turnOffFlash() async {
    if (_isFlashOn) {
      await _toggleFlash(false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    if (_isRecording) {
      // Stop recording
      try {
        final xFile = await _cameraController!.stopVideoRecording();
        final tempDir = await getTemporaryDirectory();
        final savedPath =
            '${tempDir.path}/extraocular_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await File(xFile.path).copy(savedPath);
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordedVideoPath = savedPath;
          _showPreview = true;
        });
        _initializeVideoPlayer(savedPath);
        // Store in provider
        if (mounted) {
          context.read<ExtraocularMuscleProvider>().setVideoPath(savedPath);
        }
      } catch (e) {
        debugPrint('Stop recording error: $e');
        setState(() => _isRecording = false);
      }
    } else {
      // Start recording
      try {
        await _cameraController!.startVideoRecording();
        if (!mounted) return;
        setState(() => _isRecording = true);
      } catch (e) {
        debugPrint('Start recording error: $e');
      }
    }
  }

  Future<void> _initializeVideoPlayer(String path) async {
    await _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;

    final controller = VideoPlayerController.file(File(path));
    _videoPlayerController = controller;
    await controller.initialize();

    if (!mounted) return;

    _chewieController = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      aspectRatio: controller.value.aspectRatio,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: context.primary,
        handleColor: context.primary,
        bufferedColor: context.primary.withValues(alpha: 0.3),
        backgroundColor: Colors.white24,
      ),
    );
    setState(() {});
  }

  void _retakeVideo() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    setState(() {
      _recordedVideoPath = null;
      _showPreview = false;
    });
    context.read<ExtraocularMuscleProvider>().setVideoPath(null);
  }

  void _nextDirection() {
    if (_directionIndex < _directions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishTest();
    }
  }

  Future<void> _finishTest() async {
    // Stop recording if still active
    if (_isRecording && _cameraController != null) {
      try {
        final xFile = await _cameraController!.stopVideoRecording();
        final tempDir = await getTemporaryDirectory();
        final savedPath =
            '${tempDir.path}/extraocular_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await File(xFile.path).copy(savedPath);
        _recordedVideoPath = savedPath;
        if (mounted) {
          context.read<ExtraocularMuscleProvider>().setVideoPath(savedPath);
        }
      } catch (e) {
        debugPrint('Finish recording error: $e');
      }
    }
    _isRecording = false;
    _turnOffFlash();
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _cameraController = null;
    _videoPlayerController = null;
    _chewieController = null;

    if (!mounted) return;

    final provider = context.read<ExtraocularMuscleProvider>();
    final session = context.read<TestSessionProvider>();

    final extraocularResult = provider.buildResult('H-Pattern');

    // Finalize overall torchlight result (combining with pupillary if it exists)
    final existingPupillary = session.torchlight?.pupillary;

    final finalResult = TorchlightTestResult(
      pupillary: existingPupillary,
      extraocular: extraocularResult,
      clinicalInterpretation: TorchlightTestResult.generateInterpretation(
        pupillary: existingPupillary,
        extraocular: extraocularResult,
      ),
      recommendations: TorchlightTestResult.generateRecommendations(
        pupillary: existingPupillary,
        extraocular: extraocularResult,
      ),
      requiresFollowUp: TorchlightTestResult.determineFollowUp(
        pupillary: existingPupillary,
        extraocular: extraocularResult,
      ),
    );

    session.setTorchlightResult(finalResult);
    provider.reset();

    SnackbarUtils.showSuccess(context, 'Extraocular Muscle Test Complete');
    Navigator.pushReplacementNamed(context, '/quick-test-result');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExtraocularMuscleProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Extraocular Muscle Test'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _showRestartDialog,
              tooltip: 'Restart Test',
            ),
          ],
        ),
        body: provider.currentPhase == ExtraocularPhase.alignment
            ? _buildAlignmentView(provider)
            : _buildTestView(provider),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TestExitConfirmationDialog(
        onContinue: () {},
        onRestart: () {
          Navigator.pop(dialogContext);
          _showRestartDialog();
        },
        onExit: () {
          Navigator.pop(dialogContext);
          Navigator.pop(context);
        },
        hasCompletedTests: false,
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Test?'),
        content: const Text(
          'This will clear all current findings and take you back to the instructions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ExtraocularMuscleProvider>().reset();
              Navigator.pushReplacementNamed(
                context,
                '/torchlight-instructions',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.error),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentView(ExtraocularMuscleProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _StepHeader(
            title: 'Device Alignment',
            instruction:
                'Ensure the device is perfectly vertical to ensure accurate tracking results.',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: (provider.isAligned ? context.success : context.error)
                  .withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: (provider.isAligned ? context.success : context.error)
                    .withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Icon(
              provider.isAligned
                  ? Icons.check_circle_outline_rounded
                  : Icons.vibration_rounded,
              size: 100,
              color: provider.isAligned ? context.success : context.error,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            provider.isAligned
                ? 'Perfectly Aligned'
                : 'Align Device Vertically',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.isAligned
                  ? () {
                      provider.stopSensing();
                      provider.setPhase(ExtraocularPhase.hPattern);
                      _ttsService.speak('Follow the Flashlight');
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Begin Tracking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestView(ExtraocularMuscleProvider provider) {
    if (_showPreview) {
      return _buildVideoPreview();
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _directions.length,
      onPageChanged: (index) {
        setState(() {
          _directionIndex = index;
          _currentDirection = _directions[index];
        });
      },
      itemBuilder: (context, index) {
        return OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            if (isLandscape) {
              return Row(
                children: [
                  Expanded(child: _buildTargetContainer()),
                  Expanded(child: _buildControls(provider)),
                ],
              );
            }
            return Column(
              children: [
                _buildTargetContainer(),
                Expanded(child: _buildControls(provider)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _retakeVideo,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showPreview = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Continue to Grading'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetContainer() {
    return Container(
      height: 240,
      margin: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.dividerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: CameraPreview(_cameraController!),
              ),
            ),

          // Overlay gradient for better text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48), // Push down to stay away from icons
                Text(
                  _currentDirection.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Text(
                  'Follow the Flashlight',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Flashlight toggle
          Positioned(
            top: 20,
            left: 20,
            child: _buildCircularControl(
              onTap: () => _toggleFlash(!_isFlashOn),
              icon: _isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
              isActive: _isFlashOn,
              activeColor: Colors.amber,
            ),
          ),

          // Video recording toggle
          Positioned(
            top: 20,
            right: 20,
            child: _buildCircularControl(
              onTap: _isCameraInitialized ? _toggleRecording : null,
              icon: _isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
              isActive: _isRecording,
              activeColor: context.error,
            ),
          ),

          // Recording indicator
          if (_isRecording)
            Positioned(bottom: 20, left: 20, child: _buildRecordingBadge()),

          // Saved indicator
          if (_recordedVideoPath != null && !_isRecording)
            Positioned(bottom: 20, right: 20, child: _buildSavedBadge()),
        ],
      ),
    );
  }

  Widget _buildCircularControl({
    required VoidCallback? onTap,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? activeColor : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildRecordingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.error.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
          SizedBox(width: 8),
          Text(
            'RECORDING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.success.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            'SAVED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ExtraocularMuscleProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPremiumCard(
            title: 'Grading: $_currentDirection',
            child: PremiumDropdown<MovementQuality>(
              label: 'Movement Quality',
              value:
                  provider.getMovement(_currentDirection) ??
                  MovementQuality.full,
              items: MovementQuality.values,
              itemLabelBuilder: (q) => q.name.toUpperCase(),
              itemSubtitleBuilder: (q) => _getQualityDescription(q),
              onChanged: (val) {
                provider.recordMovement(_currentDirection, val, 0);
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildPremiumCard(
            title: 'Additional Observations',
            child: Column(
              children: [
                _buildObservationToggle(
                  label: 'Nystagmus Detected',
                  value: provider.nystagmusDetected,
                  onChanged: (val) => provider.setNystagmus(val ?? false),
                ),
                const Divider(height: 1),
                _buildObservationToggle(
                  label: 'Ptosis Detected',
                  value: provider.ptosisDetected,
                  onChanged: (val) => provider.setPtosis(val ?? false),
                ),
                if (provider.ptosisDetected) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<EyeSide>(
                    segments: const [
                      ButtonSegment(value: EyeSide.right, label: Text('Right')),
                      ButtonSegment(value: EyeSide.left, label: Text('Left')),
                    ],
                    selected: {provider.ptosisEye ?? EyeSide.right},
                    onSelectionChanged: (set) =>
                        provider.setPtosis(true, set.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: context.cardColor,
                      selectedBackgroundColor: context.primary,
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              if (_directionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Previous'),
                  ),
                ),
              if (_directionIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _nextDirection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _directionIndex == _directions.length - 1
                        ? 'Finish Test'
                        : 'Next Direction',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildObservationToggle({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: context.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getQualityDescription(MovementQuality q) {
    switch (q) {
      case MovementQuality.full:
        return 'Normal range of motion';
      case MovementQuality.restricted:
        return 'Partial limitation detected';
      case MovementQuality.absent:
        return 'No movement in this direction';
    }
  }

  Widget _buildPremiumCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String instruction;

  const _StepHeader({required this.title, required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: context.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          instruction,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
