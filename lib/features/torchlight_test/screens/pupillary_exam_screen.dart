import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:torch_light/torch_light.dart';
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
  bool _isTimerRunning = false;
  int _timerSeconds = 5;
  Timer? _countdownTimer;
  String? _rapdImagePath;
  bool _isCapturing = false;

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
  void dispose() {
    _turnOffFlash();
    _countdownTimer?.cancel();
    _cameraController?.dispose();
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
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
    _isCameraInitialized = false;
    _isTimerRunning = false;
    _timerSeconds = 5;
  }

  void _startRAPDTimer() {
    setState(() {
      _isTimerRunning = true;
      _timerSeconds = 5;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds <= 1) {
        timer.cancel();
        _captureRAPDImage();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  Future<void> _captureRAPDImage() async {
    if (_isCapturing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized)
      return;
    setState(() => _isCapturing = true);
    try {
      final xFile = await _cameraController!.takePicture();
      final tempDir = await getTemporaryDirectory();
      final savedPath =
          '${tempDir.path}/rapd_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(xFile.path).copy(savedPath);
      setState(() {
        _rapdImagePath = savedPath;
        _isTimerRunning = false;
        _isCapturing = false;
      });
    } catch (e) {
      debugPrint('Capture error: $e');
      setState(() {
        _isTimerRunning = false;
        _isCapturing = false;
      });
    }
  }

  void _retakeRAPDImage() {
    setState(() {
      _rapdImagePath = null;
      _timerSeconds = 5;
    });
  }

  Future<void> _toggleFlash(bool on) async {
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
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
        _initCamera();
      }

      if (_currentStep == PupillaryStep.finished) {
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
      rapdImagePath: _rapdImagePath,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: 'Baseline Assessment',
            instruction:
                'Observe both pupils in ambient light. Adjust sizes if they appear different.',
          ),
          const SizedBox(height: 32),
          _buildSizeSlider(
            'Right Pupil',
            _rightSize,
            (val) => setState(() => _rightSize = val),
          ),
          const SizedBox(height: 24),
          _buildSizeSlider(
            'Left Pupil',
            _leftSize,
            (val) => setState(() => _leftSize = val),
          ),
          const SizedBox(height: 32),
          _buildShapeSelector(
            'Right Shape',
            _rightShape,
            (val) => setState(() => _rightShape = val!),
          ),
          const SizedBox(height: 16),
          _buildShapeSelector(
            'Left Shape',
            _leftShape,
            (val) => setState(() => _leftShape = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectReflexStep() {
    final isRight = _currentStep == PupillaryStep.directRight;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _StepHeader(
            title: 'Direct Light Reflex',
            instruction:
                'Shine the light directly into the ${isRight ? "RIGHT" : "LEFT"} eye. Does the pupil constrict?',
          ),
          const SizedBox(height: 48),
          _buildReflexSelector(
            'Direct Response',
            _directReflex,
            (val) => setState(() => _directReflex = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildConsensualStep() {
    final isRightSource = _currentStep == PupillaryStep.consensualRight;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _StepHeader(
            title: 'Consensual Light Reflex',
            instruction:
                'Shine the light in the ${isRightSource ? "RIGHT" : "LEFT"} eye while observing the OTHER pupil.',
          ),
          const SizedBox(height: 48),
          _buildReflexSelector(
            'Consensual Response',
            _consensualReflex,
            (val) => setState(() => _consensualReflex = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildRAPDStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const _StepHeader(
            title: 'Swinging Light Test (RAPD)',
            instruction:
                'Swing the light rapidly from one eye to the other. Look for paradoxical dilation.',
          ),
          const SizedBox(height: 24),

          // Camera preview / captured image
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isTimerRunning ? context.primary : context.dividerColor,
                width: _isTimerRunning ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: _rapdImagePath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(_rapdImagePath!), fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.success,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _isCameraInitialized && _cameraController != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        if (_isTimerRunning)
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.primary,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$_timerSeconds',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_isCapturing)
                          Container(
                            color: Colors.white24,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white54),
                          SizedBox(height: 12),
                          Text(
                            'Initializing camera...',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Timer / Capture controls
          if (_rapdImagePath != null)
            OutlinedButton.icon(
              onPressed: _retakeRAPDImage,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake Image'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            )
          else if (!_isTimerRunning && _isCameraInitialized)
            ElevatedButton.icon(
              onPressed: _startRAPDTimer,
              icon: const Icon(Icons.timer),
              label: const Text('Start 5s Timer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // RAPD status dropdowns (original controls)
          DropdownButtonFormField<RAPDStatus>(
            value: _rapdStatus,
            decoration: const InputDecoration(labelText: 'RAPD Finding'),
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
              decoration: const InputDecoration(labelText: 'Affected Eye'),
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
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          instruction,
          style: TextStyle(color: context.textSecondary, fontSize: 16),
        ),
      ],
    );
  }
}
