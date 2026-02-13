import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/torchlight_test_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/premium_dropdown.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/services/tts_service.dart';

enum PupillaryStep {
  baseline,
  directRight,
  directLeft,
  consensualRight,
  consensualLeft,
  rapd,
  finished,
}

class PupillaryExamScreen extends StatefulWidget {
  const PupillaryExamScreen({super.key});

  @override
  State<PupillaryExamScreen> createState() => _PupillaryExamScreenState();
}

class _PupillaryExamScreenState extends State<PupillaryExamScreen> {
  PupillaryStep _currentStep = PupillaryStep.baseline;
  bool _isFlashOn = false;

  // Camera state for RAPD capture
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String? _recordedVideoPath;

  // Video Preview State
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _showPreview = false;

  // Results state
  double _leftSize = 3.5;
  double _rightSize = 3.5;
  PupilShape _leftShape = PupilShape.round;
  PupilShape _rightShape = PupilShape.round;
  LightReflex _directReflex = LightReflex.normal;
  LightReflex _consensualReflex = LightReflex.normal;
  RAPDStatus _rapdStatus = RAPDStatus.absent;
  EyeSide? _rapdEye;

  final PageController _pageController = PageController();
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    _initCamera();
    _ttsService.initialize();
  }

  @override
  void dispose() {
    _cameraController?.setFlashMode(FlashMode.off);
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // Use back camera for RAPD
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
        // Turn on flash for pupil observation
        await _toggleFlash(true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    _isCameraInitialized = false;
  }

  Future<void> _toggleRecording() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    if (_isRecording) {
      // Stop recording
      try {
        final xFile = await _cameraController!.stopVideoRecording();
        final tempDir = await getTemporaryDirectory();
        final savedPath =
            '${tempDir.path}/rapd_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await File(xFile.path).copy(savedPath);

        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordedVideoPath = savedPath;
          _showPreview = true;
        });

        _initializeVideoPlayer(savedPath);
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
    // Avoid disposal error by checking if already disposed or active
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

  void _retakeRAPDVideo() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    setState(() {
      _recordedVideoPath = null;
      _showPreview = false;
    });
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

  void _nextStep() {
    _turnOffFlash();
    final index = _currentStep.index;
    if (index < PupillaryStep.values.length - 1) {
      final nextStep = PupillaryStep.values[index + 1];
      if (nextStep == PupillaryStep.finished) {
        _disposeResources();
        _saveAndFinish();
      } else {
        setState(() => _currentStep = nextStep);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _disposeResources() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    _disposeCamera();
  }

  void _saveAndFinish() {
    final result = PupillaryResult(
      leftPupilSize: _leftSize,
      rightPupilSize: _rightSize,
      symmetric: (_leftSize - _rightSize).abs() < 0.5,
      leftShape: _leftShape,
      rightShape: _rightShape,
      directReflex: _directReflex,
      consensualReflex: _consensualReflex,
      rapdStatus: _rapdStatus,
      rapdAffectedEye: _rapdEye,
      anisocoriaDifference: (_leftSize - _rightSize).abs(),
      rapdVideoPath: _recordedVideoPath,
    );

    // This would normally be part of a larger TorchlightTestResult
    // For now, we'll store it in a temp location or build the final result
    _completeTest(result);
  }

  void _completeTest(PupillaryResult pupillary) {
    // In a real flow, this might navigate to Extraocular or Results
    final session = context.read<TestSessionProvider>();

    // Create final result (assuming extraocular is null for now if skipped)
    final finalResult = TorchlightTestResult(
      pupillary: pupillary,
      clinicalInterpretation: TorchlightTestResult.generateInterpretation(
        pupillary: pupillary,
      ),
      recommendations: TorchlightTestResult.generateRecommendations(
        pupillary: pupillary,
      ),
      requiresFollowUp: TorchlightTestResult.determineFollowUp(
        pupillary: pupillary,
      ),
    );

    session.setTorchlightResult(finalResult);

    SnackbarUtils.showSuccess(context, 'Pupillary Examination Complete');
    Navigator.pushReplacementNamed(context, '/extraocular-muscle-exam');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pupillary Examination'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _showRestartDialog,
              tooltip: 'Restart Test',
            ),
            IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: () => _toggleFlash(!_isFlashOn),
            ),
          ],
        ),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;
              return Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(
                          () => _currentStep = PupillaryStep.values[index],
                        );
                      },
                      children: [
                        _buildBaselineStep(),
                        _buildDirectReflexStep(eye: 'RIGHT'),
                        _buildDirectReflexStep(eye: 'LEFT'),
                        _buildConsensualStep(source: 'RIGHT'),
                        _buildConsensualStep(source: 'LEFT'),
                        _buildRAPDStep(),
                      ],
                    ),
                  ),
                  _buildBottomControls(isLandscape),
                ],
              );
            },
          ),
        ),
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

  Widget _buildProgressIndicator() {
    final progress =
        (_currentStep.index + 1) / (PupillaryStep.values.length - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep.index + 1} of ${PupillaryStep.values.length - 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(10),
            minHeight: 6,
            backgroundColor: context.dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildBaselineStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: 'Baseline Assessment',
            instruction:
                'Observe both pupils in ambient light. Adjust sizes and shapes if they appear abnormal.',
          ),
          const SizedBox(height: 24),
          _buildPremiumCard(
            title: 'Pupil Size (mm)',
            child: Column(
              children: [
                _buildSizeSlider(
                  'Right Pupil',
                  _rightSize,
                  (val) => setState(() => _rightSize = val),
                ),
                const SizedBox(height: 16),
                _buildSizeSlider(
                  'Left Pupil',
                  _leftSize,
                  (val) => setState(() => _leftSize = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPremiumCard(
            title: 'Pupil Shape',
            child: Column(
              children: [
                PremiumDropdown<PupilShape>(
                  label: 'Right Eye Shape',
                  value: _rightShape,
                  items: PupilShape.values,
                  itemLabelBuilder: (s) => s.name.toUpperCase(),
                  onChanged: (val) => setState(() => _rightShape = val),
                ),
                const SizedBox(height: 16),
                PremiumDropdown<PupilShape>(
                  label: 'Left Eye Shape',
                  value: _leftShape,
                  items: PupilShape.values,
                  itemLabelBuilder: (s) => s.name.toUpperCase(),
                  onChanged: (val) => setState(() => _leftShape = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectReflexStep({required String eye}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _StepHeader(
            title: 'Direct Light Reflex',
            instruction:
                'Shine the light directly into the $eye eye. Observe the immediate constriction.',
          ),
          const SizedBox(height: 32),
          _buildPremiumCard(
            title: 'Reaction Observed',
            child: _buildReflexSelector(
              'Direct Response',
              _directReflex,
              (val) => setState(() => _directReflex = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsensualStep({required String source}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _StepHeader(
            title: 'Consensual Reflex',
            instruction:
                'Shine the light in the $source eye while observing the OPPOSITE pupil.',
          ),
          const SizedBox(height: 32),
          _buildPremiumCard(
            title: 'Consensual Reaction',
            child: _buildReflexSelector(
              'Consensual Response',
              _consensualReflex,
              (val) => setState(() => _consensualReflex = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRAPDStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const _StepHeader(
            title: 'Swinging Light Test (RAPD)',
            instruction:
                'Swing the light rapidly from one eye to the other. Manually record the pupil reactions.',
          ),
          const SizedBox(height: 24),

          // Camera preview / Video preview
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isRecording
                    ? context.error
                    : context.dividerColor.withValues(alpha: 0.3),
                width: _isRecording ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? context.error : Colors.black)
                      .withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _showPreview && _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : _isCameraInitialized && _cameraController != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        if (_isRecording)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: _buildRecordingIndicator(),
                          ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          if (_showPreview)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retakeRAPDVideo,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retake Video'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
                ),
                label: Text(
                  _isRecording ? 'Stop Recording' : 'Start Recording',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording
                      ? context.error
                      : context.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Findings
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinical Finding',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                PremiumDropdown<RAPDStatus>(
                  label: 'RAPD Status',
                  value: _rapdStatus,
                  items: RAPDStatus.values,
                  itemLabelBuilder: (s) => s.name.toUpperCase(),
                  onChanged: (val) => setState(() => _rapdStatus = val),
                ),
                if (_rapdStatus == RAPDStatus.present) ...[
                  const SizedBox(height: 16),
                  PremiumDropdown<EyeSide>(
                    label: 'Affected Eye',
                    value: _rapdEye,
                    items: const [EyeSide.right, EyeSide.left],
                    itemLabelBuilder: (s) => s.name.toUpperCase(),
                    onChanged: (val) => setState(() => _rapdEye = val),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
          SizedBox(width: 6),
          Text(
            'REC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${value.toStringAsFixed(1)} mm',
              style: TextStyle(
                color: context.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1.0,
          max: 9.0,
          divisions: 16,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // Replaced by PremiumDropdown

  Widget _buildReflexSelector(
    String label,
    LightReflex value,
    ValueChanged<LightReflex?> onChanged,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: LightReflex.values.map((e) {
            final isSelected = e == value;
            return ChoiceChip(
              label: Text(e.name.toUpperCase()),
              selected: isSelected,
              onSelected: (_) => onChanged(e),
              selectedColor: context.primary,
              labelStyle: TextStyle(
                color: isSelected ? context.onPrimary : null,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomControls(bool isLandscape) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, isLandscape ? 8 : 24),
      decoration: BoxDecoration(
        color: context.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressIndicator(),
          SizedBox(height: isLandscape ? 8 : 16),
          Row(
            children: [
              if (_currentStep != PupillaryStep.baseline)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isLandscape ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (_currentStep != PupillaryStep.baseline)
                const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentStep == PupillaryStep.rapd ? 'Finish' : 'Next Step',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              textBaseline: TextBaseline.alphabetic,
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
