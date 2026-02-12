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
  bool _isCapturing = false;

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

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.setFlashMode(FlashMode.off);
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    _videoPlayerController = VideoPlayerController.file(File(path));
    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: context.primary,
        handleColor: context.primary,
        bufferedColor: context.primary.withValues(alpha: 0.3),
        backgroundColor: Colors.white24,
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _retakeRAPDVideo() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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
    final previousStep = _currentStep;
    setState(() {
      final index = _currentStep.index;
      if (index < PupillaryStep.values.length - 1) {
        _currentStep = PupillaryStep.values[index + 1];
      }

      if (_currentStep == PupillaryStep.rapd &&
          previousStep != PupillaryStep.rapd) {
        // Camera is already initialized in initState
      }

      if (_currentStep == PupillaryStep.finished) {
        _videoPlayerController?.dispose();
        _chewieController?.dispose();
        _disposeCamera();
        _saveAndFinish();
      }
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pupillary Examination'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () => _toggleFlash(!_isFlashOn),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(child: _buildStepContent()),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: LinearProgressIndicator(
        value: (_currentStep.index + 1) / PupillaryStep.values.length,
        borderRadius: BorderRadius.circular(10),
        minHeight: 8,
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case PupillaryStep.baseline:
        return _buildBaselineStep();
      case PupillaryStep.directRight:
      case PupillaryStep.directLeft:
        return _buildDirectReflexStep();
      case PupillaryStep.consensualRight:
      case PupillaryStep.consensualLeft:
        return _buildConsensualStep();
      case PupillaryStep.rapd:
        return _buildRAPDStep();
      case PupillaryStep.finished:
        return const Center(child: CircularProgressIndicator());
    }
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
                _buildShapeSelector(
                  'Right Eye',
                  _rightShape,
                  (val) => setState(() => _rightShape = val!),
                ),
                const SizedBox(height: 16),
                _buildShapeSelector(
                  'Left Eye',
                  _leftShape,
                  (val) => setState(() => _leftShape = val!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectReflexStep() {
    final isRight = _currentStep == PupillaryStep.directRight;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _StepHeader(
            title: 'Direct Light Reflex',
            instruction:
                'Shine the light directly into the ${isRight ? "RIGHT" : "LEFT"} eye. Observe the immediate constriction.',
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

  Widget _buildConsensualStep() {
    final isRightSource = _currentStep == PupillaryStep.consensualRight;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _StepHeader(
            title: 'Consensual Reflex',
            instruction:
                'Shine the light in the ${isRightSource ? "RIGHT" : "LEFT"} eye while observing the OPPOSITE pupil.',
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
                DropdownButtonFormField<RAPDStatus>(
                  value: _rapdStatus,
                  decoration: InputDecoration(
                    labelText: 'RAPD Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: RAPDStatus.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _rapdStatus = val!),
                ),
                if (_rapdStatus == RAPDStatus.present) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EyeSide>(
                    value: _rapdEye,
                    decoration: InputDecoration(
                      labelText: 'Affected Eye',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [EyeSide.right, EyeSide.left]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
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

  Widget _buildShapeSelector(
    String label,
    PupilShape value,
    ValueChanged<PupilShape?> onChanged,
  ) {
    return DropdownButtonFormField<PupilShape>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: PupilShape.values
          .map(
            (e) =>
                DropdownMenuItem(value: e, child: Text(e.name.toUpperCase())),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

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

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Row(
        children: [
          if (_currentStep != PupillaryStep.baseline)
            OutlinedButton(
              onPressed: () => setState(
                () =>
                    _currentStep = PupillaryStep.values[_currentStep.index - 1],
              ),
              child: const Text('Back'),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text(
              _currentStep == PupillaryStep.rapd ? 'Finish' : 'Next Step',
            ),
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
