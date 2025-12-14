import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../core/services/tts_service.dart';

//
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

class _DistanceCalibrationScreenState extends State<DistanceCalibrationScreen>
    with WidgetsBindingObserver {
  late final DistanceDetectionService _distanceService;
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

  // Last spoken guidance (to avoid repeating)
  DistanceStatus? _lastSpokenStatus;

  // Auto-skip timeout - prevents getting stuck
  Timer? _autoSkipTimer;

  @override
  void initState() {
    super.initState();
    // Initialize distance service with widget's target parameters
    _distanceService = DistanceDetectionService(
      targetDistanceCm: widget.targetDistanceCm,
      toleranceCm: widget.toleranceCm,
    );
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();

    // Start auto-skip timer - auto skip after 30 seconds no matter what
    _autoSkipTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isDistanceStable) {
        debugPrint('[DistanceCalibration] Auto-skipping due to timeout');
        _onSkipPressed();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes for camera
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
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
        }
      } else {
        _stableReadingsCount = 0;
        _isDistanceStable = false;
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
    _autoSkipTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _distanceService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isInitializing
            ? _buildLoadingView()
            : _hasError
            ? _buildErrorView()
            : _buildCameraView(),
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
        // 🔥 FIXED: Camera preview with proper aspect ratio handling
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          )
        else
          // Loading state with gray background instead of black
          Container(
            color: Colors.grey.shade800,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
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
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
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
                colors: [Colors.black.withOpacity(0.85), Colors.transparent],
              ),
            ),
          ),
        ),

        // Face guide frame
        Center(
          child: Container(
            width: 220,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: _getStatusColor().withOpacity(0.6),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(120),
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
                    const SizedBox(width: 48), // Balance for close button
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
            'Target: ${widget.targetDistanceCm.toInt()} ± ${widget.toleranceCm.toInt()} cm',
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
              ? 'Distance locked! Ready to continue.'
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
    }
  }
}
