import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../core/services/tts_service.dart';

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

  const DistanceCalibrationScreen({
    super.key,
    this.targetDistanceCm = 40.0,
    this.toleranceCm = 5.0,
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
    );

    debugPrint('═══════════════════════════════════');
    debugPrint('🎯 CALIBRATION INITIALIZED:');
    debugPrint('   Target Distance: ${widget.targetDistanceCm}cm');
    debugPrint('   Tolerance: ±${widget.toleranceCm}cm');
    debugPrint(
      '   Acceptable Range: ${widget.targetDistanceCm - widget.toleranceCm}cm - ${widget.targetDistanceCm + widget.toleranceCm}cm',
    );
    debugPrint('═══════════════════════════════════');

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
        throw Exception(
          'Failed to initialize camera after $maxRetries attempts',
        );
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
        _ttsService.speak('Position your face in the camera');
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
    await _distanceService.stopMonitoring();
    await _cameraController?.dispose();
    _cameraController = null;
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
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
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
        backgroundColor: Colors.black,
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
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'Initializing Camera...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
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
              color: Colors.white54,
            ),
            const SizedBox(height: 24),
            Text(
              'Camera Not Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  'Unable to access the camera for distance measurement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
                style: TextStyle(color: Colors.white70),
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
        // ✅ FIX: Camera preview with proper error handling and fallback
        // ✅ ENHANCED: Better camera preview rendering
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
          )
        else
          // ✅ ENHANCED: Better loading state
          Container(
            color: Colors.black87, // Dark but not pure black
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Add animated loading indicator
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _hasError ? 'Camera not available' : 'Starting camera...',
                    style: TextStyle(
                      color: _hasError ? AppColors.error : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasError
                        ? 'Please allow camera permission'
                        : 'This may take a few seconds',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (_hasError) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _initializeCamera,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        // Overlay gradient (top)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Overlay gradient (bottom)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Face guide frame - centered and responsive
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.width * 0.75,
            constraints: const BoxConstraints(maxWidth: 280, maxHeight: 350),
            decoration: BoxDecoration(
              border: Border.all(
                color: _getStatusColor().withValues(alpha: 0.6),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(140),
            ),
          ),
        ),

        // Content overlay
        Positioned.fill(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _distanceService.stopMonitoring();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Distance Calibration',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const Spacer(),

              // Distance display
              _buildDistanceDisplay(),
              const SizedBox(height: 12),

              // Guidance message
              _buildGuidanceMessage(),
              const SizedBox(height: 24),

              // Progress indicator
              _buildProgressIndicator(),
              const SizedBox(height: 32),

              // Action buttons
              _buildActionButtons(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistanceDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _currentDistance > 0
                ? '${_currentDistance.toStringAsFixed(0)} cm'
                : '--',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ${widget.targetDistanceCm.toInt()} cm (±${widget.toleranceCm.toInt()} cm)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceMessage() {
    final message = _getGuidanceMessage();
    final icon = _getGuidanceIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _getStatusColor(), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _getStatusColor(), size: 24),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _distanceStatus == DistanceStatus.optimal
        ? _stableReadingsCount / _requiredStableReadings
        : 0.0;

    return Column(
      children: [
        Text(
          _isDistanceStable
              ? 'Distance locked! Auto-continuing...'
              : _distanceStatus == DistanceStatus.optimal
              ? 'Hold still...'
              : 'Adjust your position',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: _isDistanceStable
                    ? AppColors.success
                    : AppColors.warning,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isDistanceStable ? _onContinuePressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                disabledBackgroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDistanceStable ? Icons.check_circle : Icons.lock,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDistanceStable ? 'Continue to Test' : 'Adjust Distance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _onSkipPressed,
            child: Text(
              'Skip Distance Calibration',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_distanceStatus) {
      case DistanceStatus.optimal:
        return _isDistanceStable ? AppColors.success : AppColors.successLight;
      case DistanceStatus.tooClose:
        return AppColors.error;
      case DistanceStatus.tooFar:
        return AppColors.warning;
      case DistanceStatus.noFaceDetected:
        return Colors.white54;
      case DistanceStatus.faceDetectedNoDistance:
        return AppColors.successLight; // Face visible, using cached distance
    }
  }

  String _getGuidanceMessage() {
    if (_isDistanceStable) {
      return 'Perfect! Distance locked';
    }

    switch (_distanceStatus) {
      case DistanceStatus.optimal:
        return 'Hold still...';
      case DistanceStatus.tooClose:
        return 'Move back';
      case DistanceStatus.tooFar:
        return 'Move closer';
      case DistanceStatus.noFaceDetected:
        return 'Position your face';
      case DistanceStatus.faceDetectedNoDistance:
        return 'Using last distance';
    }
  }

  IconData _getGuidanceIcon() {
    if (_isDistanceStable) {
      return Icons.check_circle;
    }

    switch (_distanceStatus) {
      case DistanceStatus.optimal:
        return Icons.hourglass_empty;
      case DistanceStatus.tooClose:
        return Icons.arrow_back;
      case DistanceStatus.tooFar:
        return Icons.arrow_forward;
      case DistanceStatus.noFaceDetected:
        return Icons.face;
      case DistanceStatus.faceDetectedNoDistance:
        return Icons.visibility; // Eye icon - face detected but partial
    }
  }
}
