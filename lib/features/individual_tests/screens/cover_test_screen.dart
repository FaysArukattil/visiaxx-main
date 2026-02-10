import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/cover_test_provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../data/models/cover_test_result.dart';
import '../../quick_vision_test/screens/quick_test_result_screen.dart';

class CoverTestScreen extends StatefulWidget {
  const CoverTestScreen({super.key});

  @override
  State<CoverTestScreen> createState() => _CoverTestScreenState();
}

class _CoverTestScreenState extends State<CoverTestScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isFlashOn = false;
  bool _isCameraInitialized = false;

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
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CoverTestProvider(),
      child: Consumer<CoverTestProvider>(
        builder: (context, provider, child) {
          return Scaffold(
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
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: SafeArea(child: _buildCurrentState(provider)),
          );
        },
      ),
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
                    _buildEyeAlignmentOverlay(isLeftCovered, isRightCovered),
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

  Widget _buildEyeAlignmentOverlay(bool leftCovered, bool rightCovered) {
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

  Widget _buildMovementOptions(CoverTestProvider provider) {
    return Column(
      children: [
        // Row 1: Outward, Inward
        Row(
          children: [
            _buildMovementButton(provider, EyeMovement.outward),
            const SizedBox(width: 12),
            _buildMovementButton(provider, EyeMovement.inward),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Downward, Upward
        Row(
          children: [
            _buildMovementButton(provider, EyeMovement.downward),
            const SizedBox(width: 12),
            _buildMovementButton(provider, EyeMovement.upward),
          ],
        ),
        const SizedBox(height: 12),
        // Row 3: No Movement
        _buildMovementButton(provider, EyeMovement.none, isFullWidth: true),
      ],
    );
  }

  Widget _buildMovementButton(
    CoverTestProvider provider,
    EyeMovement movement, {
    bool isFullWidth = false,
  }) {
    return Expanded(
      flex: isFullWidth ? 0 : 1,
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        child: InkWell(
          onTap: () => provider.recordObservation(movement),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _getMovementIcon(movement),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    movement.label,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
