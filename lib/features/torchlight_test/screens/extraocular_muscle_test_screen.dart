import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:torch_light/torch_light.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/torchlight_test_result.dart';
import '../../../data/providers/extraocular_muscle_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/utils/snackbar_utils.dart';

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

  // Flashlight state
  bool _isFlashOn = false;

  // Video recording state
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String? _recordedVideoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExtraocularMuscleProvider>().startAlignment();
    });
    _initCamera();
  }

  @override
  void dispose() {
    _turnOffFlash();
    _cameraController?.dispose();
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
        setState(() {
          _isRecording = false;
          _recordedVideoPath = savedPath;
        });
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
        setState(() => _isRecording = true);
      } catch (e) {
        debugPrint('Start recording error: $e');
      }
    }
  }

  void _nextDirection() {
    setState(() {
      if (_directionIndex < _directions.length - 1) {
        _directionIndex++;
        _currentDirection = _directions[_directionIndex];
      } else {
        _finishTest();
      }
    });
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
    _cameraController = null;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Extraocular Muscle Test')),
      body: provider.currentPhase == ExtraocularPhase.alignment
          ? _buildAlignmentView(provider)
          : _buildTestView(provider),
    );
  }

  Widget _buildAlignmentView(ExtraocularMuscleProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            provider.isAligned
                ? Icons.check_circle_outline_rounded
                : Icons.vibration_rounded,
            size: 80,
            color: provider.isAligned ? context.success : context.error,
          ),
          const SizedBox(height: 32),
          Text(
            provider.isAligned ? 'Device Aligned' : 'Align Device Vertical',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Hold the device steady and vertical at eye level to ensure accurate tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: provider.isAligned
                ? () {
                    provider.stopSensing();
                    provider.setPhase(ExtraocularPhase.hPattern);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            ),
            child: const Text('Start Test'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestView(ExtraocularMuscleProvider provider) {
    return Column(
      children: [
        _buildTargetContainer(),
        Expanded(child: _buildControls(provider)),
      ],
    );
  }

  Widget _buildTargetContainer() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Target indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.gps_fixed_rounded,
                  color: Colors.blue,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Follow the target: $_currentDirection',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Flashlight toggle (top-left)
          Positioned(
            top: 12,
            left: 12,
            child: GestureDetector(
              onTap: () => _toggleFlash(!_isFlashOn),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isFlashOn
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.white12,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isFlashOn ? Colors.amber : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
                  color: _isFlashOn ? Colors.amber : Colors.white54,
                  size: 22,
                ),
              ),
            ),
          ),

          // Video recording toggle (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _isCameraInitialized ? _toggleRecording : null,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.white12,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _isRecording
                      ? Icons.stop_circle_rounded
                      : Icons.videocam_rounded,
                  color: _isRecording ? Colors.red : Colors.white54,
                  size: 22,
                ),
              ),
            ),
          ),

          // Recording indicator (bottom-center)
          if (_isRecording)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 12,
                      ),
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
                ),
              ),
            ),

          // Recorded video indicator (bottom-right)
          if (_recordedVideoPath != null && !_isRecording)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Video Saved',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  Widget _buildControls(ExtraocularMuscleProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Grading of Movement',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildMovementToggle(provider),
          const SizedBox(height: 32),
          const Text(
            'Additional Observations',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          CheckboxListTile(
            title: const Text('Nystagmus Detected'),
            value: provider.nystagmusDetected,
            onChanged: (val) => provider.setNystagmus(val ?? false),
            activeColor: context.primary,
          ),
          CheckboxListTile(
            title: const Text('Ptosis Detected'),
            value: provider.ptosisDetected,
            onChanged: (val) => provider.setPtosis(val ?? false),
            activeColor: context.primary,
          ),
          if (provider.ptosisDetected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: SegmentedButton<EyeSide>(
                    segments: const [
                      ButtonSegment(value: EyeSide.right, label: Text('Right')),
                      ButtonSegment(value: EyeSide.left, label: Text('Left')),
                    ],
                    selected: {provider.ptosisEye ?? EyeSide.right},
                    onSelectionChanged: (set) =>
                        provider.setPtosis(true, set.first),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              if (_directionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _directionIndex--;
                        _currentDirection = _directions[_directionIndex];
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _directionIndex == _directions.length - 1
                        ? 'Finish Test'
                        : 'Next Direction',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementToggle(ExtraocularMuscleProvider provider) {
    final currentQuality =
        provider.getMovement(_currentDirection) ?? MovementQuality.full;

    return Column(
      children: MovementQuality.values
          .map(
            (q) => RadioListTile<MovementQuality>(
              title: Text(q.name.toUpperCase()),
              subtitle: Text(_getQualityDescription(q)),
              value: q,
              groupValue: currentQuality,
              onChanged: (val) =>
                  provider.recordMovement(_currentDirection, val!, 0),
              activeColor: context.primary,
            ),
          )
          .toList(),
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
}
