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

    _distanceService = DistanceDetectionService(
      targetDistanceCm: widget.targetDistanceCm,
      toleranceCm: widget.toleranceCm,
      minDistanceCm: widget.minDistanceCm,
      maxDistanceCm: widget.maxDistanceCm,
    );

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
      _distanceService.onDistanceUpdate = _handleDistanceUpdate;
      _distanceService.onError = _handleError;

      int retries = 0;
      const maxRetries = 3;

      while (retries < maxRetries && _cameraController == null) {
        try {
          _cameraController = await _distanceService.initializeCamera();
          if (_cameraController != null &&
              _cameraController!.value.isInitialized) {
            break;
          }
          retries++;
          if (retries < maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * retries));
          }
        } catch (e) {
          retries++;
          if (retries < maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * retries));
          }
        }
      }

      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        throw Exception('Failed to initialize camera');
      }

      _cameraController!.addListener(() {
        if (mounted) setState(() {});
      });

      await Future.delayed(const Duration(milliseconds: 200));
      await _distanceService.startMonitoring();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }

      final distanceText = widget.targetDistanceCm >= 100
          ? '1 meter'
          : '${widget.targetDistanceCm.toInt()} centimeters';

      _ttsService.speak(
        'Position yourself at $distanceText from the screen. Look at the camera and I will guide you.',
      );
    } catch (e) {
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

      if (status == DistanceStatus.optimal) {
        _stableReadingsCount++;
        if (_stableReadingsCount >= _requiredStableReadings) {
          _isDistanceStable = true;
          HapticFeedback.mediumImpact();

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
        _hasAutoNavigated = false;
      }
    });

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
        break;
    }
  }

  void _handleError(String message) {
    debugPrint('[DistanceCalibration] Error: $message');
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
              Navigator.pop(context);
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

        OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            if (isLandscape) {
              return Positioned(
                top: 80,
                bottom: 20,
                right: 20,
                width: MediaQuery.of(context).size.width * 0.45,
                child: _GlassHUDCard(
                  status: _distanceStatus,
                  currentDistance: _currentDistance,
                  targetDistance: widget.targetDistanceCm,
                  statusColor: _getStatusColor(),
                  stableProgress:
                      _stableReadingsCount / _requiredStableReadings,
                  isStable: _isDistanceStable,
                  onContinue: _onContinuePressed,
                  onSkip: _onSkipPressed,
                  isLandscape: true,
                ),
              );
            }

            return Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              top: 140, // Stricter top boundary to avoid title overlap
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _GlassHUDCard(
                  status: _distanceStatus,
                  currentDistance: _currentDistance,
                  targetDistance: widget.targetDistanceCm,
                  statusColor: _getStatusColor(),
                  stableProgress:
                      _stableReadingsCount / _requiredStableReadings,
                  isStable: _isDistanceStable,
                  onContinue: _onContinuePressed,
                  onSkip: _onSkipPressed,
                  isLandscape: false,
                ),
              ),
            );
          },
        ),

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

// ignore: unused_element
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
  final bool isLandscape;

  const _GlassHUDCard({
    required this.status,
    required this.currentDistance,
    required this.targetDistance,
    required this.statusColor,
    required this.stableProgress,
    required this.isStable,
    required this.onContinue,
    required this.onSkip,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final message = _getGuidanceMessage();
    final detected = status != DistanceStatus.noFaceDetected;

    return ClipRRect(
      borderRadius: BorderRadius.circular(isLandscape ? 30 : 40),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 20 : 28,
            vertical: isLandscape ? 20 : 30, // Reduced from 70 to 30
          ),
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(isLandscape ? 30 : 40),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                  ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  message,
                                  key: ValueKey(message),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: isLandscape ? 14 : 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLandscape ? 8 : 48),

                      _buildMagneticIndicator(detected),

                      if (detected && status == DistanceStatus.optimal) ...[
                        SizedBox(height: isLandscape ? 12 : 20),
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
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: isLandscape ? 12 : 24),

              // Buttons - Always visible at bottom of card
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    // Main Action Button / Status Indicator
                    if (isStable)
                      ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'START EXAMINATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.check_circle_outline, size: 16),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          'CALIBRATING POSITION...',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.2),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Premium Button-style Bypass (No Toggle)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onSkip,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'BYPASS CALIBRATION',
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMagneticIndicator(bool detected) {
    // Calculate the vertical offset for silhouette animation
    // percent positive (Too Far) -> Move DOWN
    // percent negative (Too Close) -> Move UP (towards phone)
    final double percent = _getOffsetPercent();

    // Use a more compact height if space is constrained
    final double indicatorHeight = isLandscape ? 180 : 200;
    final double trackHeight = indicatorHeight - 30;
    final double targetPos = trackHeight / 2 + 10;

    final double verticalOffset = targetPos + (percent * 70);

    return Column(
      children: [
        SizedBox(
          height: indicatorHeight,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Vertical Track Line
              Container(
                width: 1,
                height: trackHeight,
                color: AppColors.white.withValues(alpha: 0.1),
              ),

              // 2. FIXED REFERENCE: Phone (TOP)
              Positioned(
                top: 0,
                child: Icon(
                  Icons.phone_iphone_rounded,
                  color: AppColors.white.withValues(alpha: 0.35),
                  size: 24,
                ),
              ),

              // 3. TARGET ZONE: Centered on track
              Positioned(
                top: targetPos,
                child: Container(
                  width: 50,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // 4. VERTICAL GLIDING USER: Enhanced Silhouette with Dual Arrows
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                top: verticalOffset - 18, // Centering
                child: _DualArrowGlider(
                  status: status,
                  statusColor: statusColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // CM Display - Compact size
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Text(
                detected ? currentDistance.toStringAsFixed(0) : '--',
                key: ValueKey<String>(
                  detected ? currentDistance.toStringAsFixed(0) : '--',
                ),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 42, // Reduced from 54
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CM',
              style: TextStyle(
                color: statusColor.withValues(alpha: 0.4),
                fontSize: 14, // Reduced from 18
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _getOffsetPercent() {
    // If no face detected, return 0 (centered)
    if (status == DistanceStatus.noFaceDetected) return 0.0;

    final diff = currentDistance - targetDistance;
    // Increase divisor for more responsive movement
    // Positive diff = too far = move down (positive offset)
    // Negative diff = too close = move up (negative offset)
    return (diff / 35).clamp(-1.0, 1.0);
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

/// Enlarged User Silhouette with Dual Side Animating Arrows
class _DualArrowGlider extends StatefulWidget {
  final DistanceStatus status;
  final Color statusColor;

  const _DualArrowGlider({required this.status, required this.statusColor});

  @override
  State<_DualArrowGlider> createState() => _DualArrowGliderState();
}

class _DualArrowGliderState extends State<_DualArrowGlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _arrowSlide;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _arrowSlide = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 12.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 12.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_arrowController);
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Enlarged Human Silhouette
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Head
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: widget.statusColor, width: 2.5),
                color: widget.statusColor.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 2),
            // Body
            Container(
              width: 38,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                border: Border.all(color: widget.statusColor, width: 2.5),
                color: widget.statusColor.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),

        // Dual Animating Arrows
        if (widget.status == DistanceStatus.tooClose) ...[
          // Move BACK -> Arrows DOWN on both sides
          _buildAnimatingSideArrow(left: -32, down: true),
          _buildAnimatingSideArrow(right: -32, down: true),
        ],
        if (widget.status == DistanceStatus.tooFar) ...[
          // Move CLOSER -> Arrows UP on both sides
          _buildAnimatingSideArrow(left: -32, down: false),
          _buildAnimatingSideArrow(right: -32, down: false),
        ],
      ],
    );
  }

  Widget _buildAnimatingSideArrow({
    double? left,
    double? right,
    required bool down,
  }) {
    return Positioned(
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _arrowSlide,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, down ? _arrowSlide.value : -_arrowSlide.value),
            child: Icon(
              down ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: widget.statusColor,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}
