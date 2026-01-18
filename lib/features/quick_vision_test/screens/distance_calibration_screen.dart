import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/eye_loader.dart';

/// Distance Calibration Screen with real camera preview and face detection
/// Shows real-time distance and guidance to position correctly
class DistanceCalibrationScreen extends StatefulWidget {
  /// Target distance in cm (default 40cm for near vision test)
  final double targetDistanceCm;

  /// Tolerance in cm (default ±5cm)
  final double toleranceCm;

  /// Callback when calibration is complete and distance is verified
  final VoidCallback onCalibrationComplete;

  /// Optional callback when user skips calibration
  final VoidCallback? onSkip;

  final double? minDistanceCm;
  final double? maxDistanceCm;

  const DistanceCalibrationScreen({
    super.key,
    this.targetDistanceCm = 40.0,
    this.toleranceCm = 5.0,
    this.minDistanceCm,
    this.maxDistanceCm,
    required this.onCalibrationComplete,
    this.onSkip,
  });

  @override
  State<DistanceCalibrationScreen> createState() =>
      _DistanceCalibrationScreenState();
}

class _DistanceCalibrationScreenState extends State<DistanceCalibrationScreen> {
  late DistanceDetectionService _distanceService;
  final TtsService _ttsService = TtsService();

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;

  // Distance state
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceStable = false;
  int _stableReadingsCount = 0;
  static const int _requiredStableReadings = 5;

  bool _hasAutoNavigated = false;

  // Last spoken guidance (to avoid repeating)
  DistanceStatus? _lastSpokenStatus;

  @override
  void initState() {
    super.initState();

    // ✅ CRITICAL FIX: Initialize with widget parameters
    _distanceService = DistanceDetectionService(
      targetDistanceCm: widget.targetDistanceCm,
      toleranceCm: widget.toleranceCm,
      minDistanceCm: widget.minDistanceCm,
      maxDistanceCm: widget.maxDistanceCm,
    );

    debugPrint('═════════════════════════════════════');
    debugPrint('🎯 CALIBRATION INITIALIZED:');
    debugPrint('   Target Distance: ${widget.targetDistanceCm}cm');
    debugPrint('   Tolerance: ±${widget.toleranceCm}cm');
    debugPrint(
      '   Min Boundary: ${widget.minDistanceCm ?? (widget.targetDistanceCm - widget.toleranceCm)}cm',
    );
    debugPrint(
      '   Max Boundary: ${widget.maxDistanceCm ?? (widget.targetDistanceCm + widget.toleranceCm)}cm',
    );
    debugPrint('═════════════════════════════════════');

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await _ttsService.initialize();

      // Set up distance service callbacks
      _distanceService.onDistanceUpdate = _handleDistanceUpdate;
      _distanceService.onError = _handleError;

      debugPrint('[DistanceCalibration] 🔥 Initializing camera...');

      // Initialize camera with retry logic
      int retries = 0;
      const maxRetries = 3;

      while (retries < maxRetries && _cameraController == null) {
        try {
          _cameraController = await _distanceService.initializeCamera();

          if (_cameraController != null &&
              _cameraController!.value.isInitialized) {
            debugPrint(
              '[DistanceCalibration] ✅ Camera initialized successfully',
            );
            break;
          }

          retries++;
          if (retries < maxRetries) {
            debugPrint(
              '[DistanceCalibration] ⚠️ Retry $retries/$maxRetries...',
            );
            await Future.delayed(Duration(milliseconds: 500 * retries));
          }
        } catch (e) {
          debugPrint(
            '[DistanceCalibration] ❌ Camera init attempt $retries failed: $e',
          );
          retries++;
          if (retries < maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * retries));
          }
        }
      }

      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        // One last quick retry with a small delay
        await Future.delayed(const Duration(milliseconds: 500));
        _cameraController = await _distanceService.initializeCamera();

        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {
          throw Exception(
            'Failed to initialize camera after $maxRetries attempts',
          );
        }
      }

      // Add a listener to ensure UI updates on any controller changes
      _cameraController!.addListener(() {
        if (mounted) setState(() {});
      });

      // ✅ DEBUG: Log camera details
      debugPrint('=== CAMERA DEBUG INFO ===');
      debugPrint(
        'Camera initialized: ${_cameraController!.value.isInitialized}',
      );
      debugPrint('Preview size: ${_cameraController!.value.previewSize}');
      debugPrint('Aspect ratio: ${_cameraController!.value.aspectRatio}');
      debugPrint('Is streaming: ${_cameraController!.value.isStreamingImages}');
      debugPrint('Error: ${_cameraController!.value.errorDescription}');
      debugPrint('========================');

      // Small delay before starting monitoring to let camera stabilize
      await Future.delayed(const Duration(milliseconds: 200));

      // Start monitoring
      await _distanceService.startMonitoring();

      // Force a rebuild to show camera preview
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }

      // Debug logging
      debugPrint('[DistanceCalibration] Camera preview ready');
      debugPrint(
        '[DistanceCalibration] Preview size: ${_cameraController!.value.previewSize}',
      );
      debugPrint(
        '[DistanceCalibration] Aspect ratio: ${_cameraController!.value.aspectRatio}',
      );

      // Speak instructions
      final distanceText = widget.targetDistanceCm >= 100
          ? '1 meter'
          : '${widget.targetDistanceCm.toInt()} centimeters';

      _ttsService.speak(
        'Position yourself at $distanceText from the screen. '
        'Look at the camera and I will guide you.',
      );
    } catch (e) {
      debugPrint('[DistanceCalibration] ❌ Fatal error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Camera error: $e';
          _isInitializing = false;
        });
      }
    }
  }

  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;

      // Check stability
      if (status == DistanceStatus.optimal) {
        _stableReadingsCount++;
        if (_stableReadingsCount >= _requiredStableReadings) {
          _isDistanceStable = true;
          // Vibrate to indicate success
          HapticFeedback.mediumImpact();

          // ✅ AUTO-CONTINUE: Automatically proceed after 1 second
          if (!_hasAutoNavigated) {
            _hasAutoNavigated = true;
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && _isDistanceStable) {
                _onContinuePressed();
              }
            });
          }
        }
      } else {
        _stableReadingsCount = 0;
        _isDistanceStable = false;
        _hasAutoNavigated = false; // Reset flag if user moves
      }
    });

    // Speak guidance if status changed
    if (status != _lastSpokenStatus) {
      _lastSpokenStatus = status;
      _speakGuidance(status);
    }
  }

  void _speakGuidance(DistanceStatus status) {
    switch (status) {
      case DistanceStatus.tooClose:
        _ttsService.speak('Move back, you are too close');
        break;
      case DistanceStatus.tooFar:
        _ttsService.speak('Come closer, you are too far');
        break;
      case DistanceStatus.optimal:
        if (_stableReadingsCount == 1) {
          _ttsService.speak('Perfect distance! Hold still.');
        }
        break;
      case DistanceStatus.noFaceDetected:
        _ttsService.speak('Searching for face');
        break;
      case DistanceStatus.faceDetectedNoDistance:
        // Don't speak - using cached distance, test can continue
        break;
    }
  }

  void _handleError(String message) {
    debugPrint('[DistanceCalibration] Error: $message');
    // Don't show UI errors for transient issues
  }

  void _onContinuePressed() {
    _distanceService.stopMonitoring();
    _ttsService.speak('Great! Starting the test.');
    widget.onCalibrationComplete();
  }

  void _onSkipPressed() {
    _distanceService.stopMonitoring();
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      widget.onCalibrationComplete();
    }
  }

  Future<void> _disposeCamera() async {
    try {
      await _distanceService.stopMonitoring();
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      debugPrint('[DistanceCalibration] Error during camera disposal: $e');
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    _distanceService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _showExitConfirmation() {
    _ttsService.stop();
    _distanceService.stopMonitoring();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text(
          'Your progress will be lost. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                _distanceService.startMonitoring();
              }
            },
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await NavigationUtils.navigateHome(context);
            },
            child: const Text('Exit', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
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
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: _isInitializing
              ? _buildLoadingView()
              : _hasError
              ? _buildErrorView()
              : _buildCameraView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EyeLoader(size: 80),
          const SizedBox(height: 24),
          Text(
            'Initializing Camera...',
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: AppColors.white54,
            ),
            const SizedBox(height: 24),
            Text(
              'Camera Not Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  'Unable to access the camera for distance measurement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _onSkipPressed,
              child: const Text(
                'Skip Distance Check',
                style: TextStyle(color: AppColors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Immersive Camera Preview
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned.fill(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),

        // 2. Cinematic Deep Vignette
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  AppColors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ),

        // 3. Directional Guidance (Spatial Layer)
        Center(
          child: _DirectionalChevronOverlay(
            status: _distanceStatus,
            color: _getStatusColor(),
          ),
        ),

        // 4. Central Ethereal Halo (Core Alignment)
        Center(
          child: _EtherealLightHalo(
            status: _distanceStatus,
            color: _getStatusColor(),
            currentDistance: _currentDistance,
            targetDistance: widget.targetDistanceCm,
          ),
        ),

        // 5. Floating Precision HUD
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: _GlassHUDCard(
            status: _distanceStatus,
            currentDistance: _currentDistance,
            targetDistance: widget.targetDistanceCm,
            statusColor: _getStatusColor(),
            stableProgress: _stableReadingsCount / _requiredStableReadings,
            isStable: _isDistanceStable,
            onContinue: _onContinuePressed,
            onSkip: _onSkipPressed,
          ),
        ),

        // 6. Minimal Instrument Header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showExitConfirmation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'DISTANCE CALIBRATION',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(height: 2, width: 20, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_distanceStatus) {
      case DistanceStatus.optimal:
        return AppColors.success;
      case DistanceStatus.tooClose:
        return AppColors.error;
      case DistanceStatus.tooFar:
        return AppColors.warning;
      case DistanceStatus.noFaceDetected:
        return AppColors.white.withValues(alpha: 0.2);
      case DistanceStatus.faceDetectedNoDistance:
        return AppColors.successLight;
    }
  }
}

/// Cinematic Directional Chevrons
class _DirectionalChevronOverlay extends StatefulWidget {
  final DistanceStatus status;
  final Color color;

  const _DirectionalChevronOverlay({required this.status, required this.color});

  @override
  State<_DirectionalChevronOverlay> createState() =>
      _DirectionalChevronOverlayState();
}

class _DirectionalChevronOverlayState extends State<_DirectionalChevronOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == DistanceStatus.optimal ||
        widget.status == DistanceStatus.noFaceDetected) {
      return const SizedBox.shrink();
    }

    final bool isTooClose = widget.status == DistanceStatus.tooClose;

    return Stack(
      alignment: Alignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double progress = (_controller.value + (index / 3)) % 1.0;
            // Reverse direction if too close (pointing away)
            double t = isTooClose ? progress : 1.0 - progress;

            return Transform.scale(
              scale: 0.5 + (t * 1.5),
              child: Opacity(
                opacity: (1.0 - t).clamp(0, 1) * 0.3,
                child: Container(
                  width: 300,
                  height: 360,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(150),
                    border: Border.all(color: widget.color, width: 2),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Ultra-Minimal Ethereal Light Halo with Depth Pulsing
class _EtherealLightHalo extends StatelessWidget {
  final DistanceStatus status;
  final Color color;
  final double currentDistance;
  final double targetDistance;

  const _EtherealLightHalo({
    required this.status,
    required this.color,
    required this.currentDistance,
    required this.targetDistance,
  });

  @override
  Widget build(BuildContext context) {
    final detected = status != DistanceStatus.noFaceDetected;
    // Scale Halo based on distance (closer = bigger)
    final double scale = detected
        ? (targetDistance / currentDistance.clamp(1, 200)).clamp(0.8, 1.2)
        : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOutCubic,
      width: (detected ? 280 : 260) * scale,
      height: (detected ? 340 : 320) * scale,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular((detected ? 140 : 130) * scale),
        border: Border.all(
          color: color.withValues(alpha: detected ? 0.8 : 0.1),
          width: detected ? 1.5 : 0.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // High-Reflectivity Glow
          if (detected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(140 * scale),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 60,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

          // Spatial Status Badge
          if (detected && status != DistanceStatus.optimal)
            Positioned(
              top: -60,
              child: _SpatialBadge(status: status, color: color),
            ),
        ],
      ),
    );
  }
}

/// Professional Spatial Status Badge
class _SpatialBadge extends StatelessWidget {
  final DistanceStatus status;
  final Color color;

  const _SpatialBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    if (status == DistanceStatus.optimal ||
        status == DistanceStatus.noFaceDetected) {
      return const SizedBox.shrink();
    }

    String label = status == DistanceStatus.tooClose
        ? 'MOVE BACK'
        : 'MOVE CLOSER';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedCommandArrow(status: status, color: color, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated Command Arrow for Directional Cues
class _AnimatedCommandArrow extends StatefulWidget {
  final DistanceStatus status;
  final Color color;
  final double size;

  const _AnimatedCommandArrow({
    required this.status,
    required this.color,
    this.size = 20,
  });

  @override
  State<_AnimatedCommandArrow> createState() => _AnimatedCommandArrowState();
}

class _AnimatedCommandArrowState extends State<_AnimatedCommandArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -6.0,
          end: 6.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 6.0,
          end: -6.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTooClose = widget.status == DistanceStatus.tooClose;
    final bool isTooFar = widget.status == DistanceStatus.tooFar;

    if (!isTooClose && !isTooFar) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        final double offset = isTooClose
            ? _slideAnimation.value
            : -_slideAnimation.value;
        final IconData icon = isTooClose
            ? Icons.keyboard_arrow_down_rounded
            : Icons.keyboard_arrow_up_rounded;

        return Transform.translate(
          offset: Offset(0, offset),
          child: Icon(icon, color: widget.color, size: widget.size),
        );
      },
    );
  }
}

/// Glassmorphic HUD Card with Precision Indicator
class _GlassHUDCard extends StatelessWidget {
  final DistanceStatus status;
  final double currentDistance;
  final double targetDistance;
  final Color statusColor;
  final double stableProgress;
  final bool isStable;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _GlassHUDCard({
    required this.status,
    required this.currentDistance,
    required this.targetDistance,
    required this.statusColor,
    required this.stableProgress,
    required this.isStable,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final message = _getGuidanceMessage();
    final detected = status != DistanceStatus.noFaceDetected;

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Command Guidance System
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AnimatedCommandArrow(
                    status: status,
                    color: statusColor,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          message,
                          key: ValueKey(message),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _AnimatedCommandArrow(
                    status: status,
                    color: statusColor,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // 2. Magnetic Precision Indicator (Zone Docking)
              _buildMagneticIndicator(detected),

              const SizedBox(height: 36),

              // 3. Locking Signal
              if (detected && status == DistanceStatus.optimal) ...[
                Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'STABILIZING SIGNAL...',
                        style: TextStyle(
                          color: statusColor.withValues(alpha: 0.4),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stableProgress,
                        minHeight: 4,
                        backgroundColor: AppColors.white.withValues(
                          alpha: 0.03,
                        ),
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // 4. Primary Command
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isStable ? onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStable
                        ? statusColor
                        : AppColors.white.withValues(alpha: 0.05),
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.white.withValues(
                      alpha: 0.05,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isStable
                              ? 'START EXAMINATION'
                              : 'CALIBRATING POSITION',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 14,
                            color: isStable
                                ? AppColors.white
                                : AppColors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        if (isStable) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_outline, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onSkip,
                child: Text(
                  'BYPASS CALIBRATION',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMagneticIndicator(bool detected) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Subdued Trace Line
            Container(
              height: 1,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: AppColors.white.withValues(alpha: 0.08),
            ),

            // Target Zone (The "Portion")
            Container(
              width: 60, // Optimal Zone Portion
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 2,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),

            // Magnetic Core (Gliding Capsule)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOutCubic,
              tween: Tween<double>(begin: 0, end: _getOffsetPercent()),
              builder: (context, percent, child) {
                return FractionallySizedBox(
                  widthFactor: 1.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(percent * 140, 0),
                        child: Container(
                          width: 36,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOutCubic,
              tween: Tween<double>(
                begin: targetDistance,
                end: detected ? currentDistance : targetDistance + 15,
              ),
              builder: (context, val, child) {
                return Text(
                  detected ? val.toStringAsFixed(0) : '--',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              'CM',
              style: TextStyle(
                color: statusColor.withValues(alpha: 0.4),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _getOffsetPercent() {
    final diff = currentDistance - targetDistance;
    // Higher sensitivity for tighter docking
    return (diff / 20).clamp(-1.0, 1.0);
  }

  String _getGuidanceMessage() {
    if (isStable) return 'POSITION SECURED';

    switch (status) {
      case DistanceStatus.optimal:
        return 'HOLD STEADY';
      case DistanceStatus.tooClose:
        return 'MOVE BACK';
      case DistanceStatus.tooFar:
        return 'MOVE CLOSER';
      case DistanceStatus.noFaceDetected:
        return 'ALIGN YOUR FACE';
      case DistanceStatus.faceDetectedNoDistance:
        return 'INITIALIZING...';
    }
  }
}
