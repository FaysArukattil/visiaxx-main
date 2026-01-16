import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/core/widgets/distance_warning_overlay.dart';
import 'package:visiaxx/core/widgets/test_exit_confirmation_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/models/amsler_grid_result.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/services/distance_skip_manager.dart';
import 'amsler_grid_instructions_screen.dart';
import '../../../core/utils/navigation_utils.dart';
import 'distance_calibration_screen.dart';
import 'amsler_grid_cover_eye_screen.dart';

/// Amsler Grid Test for detecting macular degeneration
class AmslerGridTestScreen extends StatefulWidget {
  const AmslerGridTestScreen({super.key});

  @override
  State<AmslerGridTestScreen> createState() => _AmslerGridTestScreenState();
}

class _AmslerGridTestScreenState extends State<AmslerGridTestScreen>
    with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();
  final DistanceDetectionService _distanceService = DistanceDetectionService(
    targetDistanceCm: 40.0,
    toleranceCm: 5.0,
  );
  final DistanceSkipManager _skipManager = DistanceSkipManager();
  final GlobalKey _gridKey = GlobalKey();

  // Test state
  String _currentEye = 'right';
  bool _testingStarted = false;
  bool _eyeSwitchPending = false;
  bool _testComplete = false;
  bool _isNavigatingToNextTest = false;
  bool _showDistanceCalibration = true;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isTestPausedForDistance = false;
  bool _isPausedForExit =
      false; // âœ… Prevent distance warning during pause dialog

  // Distortion tracking
  final List<DistortionPoint> _rightEyePoints = [];
  final List<DistortionPoint> _leftEyePoints = [];

  // Auto-navigation
  Timer? _autoNavigationTimer;
  int _autoNavigationCountdown = 5;
  DateTime? _lastShouldPauseTime;
  // Questions
  bool? _allLinesStraight;
  bool? _hasMissingAreas;
  bool? _hasDistortions;

  // Current marking mode
  String _markingMode = 'distortion'; // 'distortion', 'missing', 'blurry'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  void _handleAppPaused() {
    _distanceService.stopMonitoring();
    _ttsService.stop();
    setState(() {
      _isPausedForExit = true;
      _isTestPausedForDistance = true;
    });
  }

  void _handleAppResumed() {
    if (!mounted || _showDistanceCalibration) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_showDistanceCalibration && _testingStarted) {
        _showPauseDialog(reason: 'minimized');
      }
    });
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();

    // Show instruction screen first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialInstructions();
    });
  }

  void _showInitialInstructions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AmslerGridInstructionsScreen(
          onContinue: () {
            Navigator.of(context).pop();
            if (_showDistanceCalibration) {
              _showCalibrationScreen();
            } else {
              _startTest();
            }
          },
        ),
      ),
    );
  }

  /// Show distance calibration screen
  void _showCalibrationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: 40.0,
          toleranceCm: 5.0,
          onCalibrationComplete: () {
            Navigator.of(context).pop();
            _onDistanceCalibrationComplete();
          },
          onSkip: () {
            Navigator.of(context).pop();
            _onDistanceCalibrationComplete();
          },
        ),
      ),
    );
  }

  void _onDistanceCalibrationComplete() {
    setState(() => _showDistanceCalibration = false);
    _startContinuousDistanceMonitoring();
    _showCoverEyeInstruction('left'); // Cover LEFT to test RIGHT
  }

  void _showCoverEyeInstruction(String eyeToCover) {
    // âœ… FIX: Stop distance monitoring before showing cover eye instruction
    _distanceService.stopMonitoring();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AmslerGridCoverEyeScreen(
          eyeToCover: eyeToCover,
          onContinue: () {
            Navigator.of(context).pop();
            // âœ… FIX: Resume monitoring AFTER user confirms they've covered their eye
            _startContinuousDistanceMonitoring();

            if (eyeToCover == 'left') {
              _startTest();
            } else {
              _switchToLeftEye();
            }
          },
        ),
      ),
    );
  }

  /// Start continuous distance monitoring
  /// Start continuous distance monitoring
  /// Start continuous distance monitoring
  Future<void> _startContinuousDistanceMonitoring() async {
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    _distanceService.onError = (msg) => debugPrint('[DistanceMonitor] $msg');

    if (!_distanceService.isReady) {
      await _distanceService.initializeCamera();
    }

    if (!_distanceService.isMonitoring) {
      await _distanceService.startMonitoring();
    }
  }

  /// Handle real-time distance updates with debouncing
  /// Handle real-time distance updates with debouncing
  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    // âœ… FIX: Don't process distance updates while pause dialog is showing
    if (_isPausedForExit) return;

    // âœ… SIMPLIFIED: Only check if distance is too close
    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      'amsler_grid',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
      // âœ… FIX: Synchronize pause state when distance becomes good
      if (!shouldPause && _isTestPausedForDistance) {
        _resumeTestAfterDistance();
      }
    });

    // âœ… Only trigger pause/resume during active testing
    if (_testingStarted && !_testComplete && !_eyeSwitchPending) {
      if (shouldPause && !_isTestPausedForDistance) {
        _lastShouldPauseTime ??= DateTime.now();
        final timeSinceFirst = DateTime.now().difference(_lastShouldPauseTime!);

        // âœ… Only show overlay after 1.5 seconds of continuous issue
        if (timeSinceFirst >= const Duration(milliseconds: 1500)) {
          _skipManager.canShowDistanceWarning(DistanceTestType.amslerGrid).then(
            (canShow) {
              if (!mounted) return;
              if (canShow) {
                _pauseTestForDistance();
              }
            },
          );
        }
      } else if (!shouldPause) {
        _lastShouldPauseTime = null;
        if (_isTestPausedForDistance) {
          _resumeTestAfterDistance();
        }
      }
    }
  }

  void _pauseTestForDistance() {
    setState(() => _isTestPausedForDistance = true);
    _ttsService.speak(
      'Test paused. Please adjust your distance to 40 centimeters.',
    );
    HapticFeedback.heavyImpact();
  }

  /// Unified pause dialog for both back button and app minimization
  void _showPauseDialog({String reason = 'back button'}) {
    // Pause services while dialog is shown
    _distanceService.stopMonitoring();
    _ttsService.stop();
    _autoNavigationTimer?.cancel(); // âœ… Pause auto-navigation timer

    setState(() {
      _isPausedForExit = true;
      _isTestPausedForDistance = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => TestExitConfirmationDialog(
        onContinue: () {
          _resumeTestFromDialog();
        },
        onRestart: () {
          _restartCurrentTest();
        },
        onExit: () async {
          await NavigationUtils.navigateHome(context);
        },
      ),
    ).then((_) {
      if (mounted && _isPausedForExit) {
        _resumeTestFromDialog();
      }
    });
  }

  /// Alias for back button
  void _showExitConfirmation() => _showPauseDialog();

  /// Resume the test from the pause dialog
  void _resumeTestFromDialog() {
    if (!mounted) return;

    if (_testComplete) {
      setState(() {
        _isPausedForExit = false;
        _isTestPausedForDistance = false;
      });
      _startAutoNavigationTimer(); // âœ… Resume auto-navigation
      return;
    }

    setState(() {
      _isPausedForExit = false;
      _isTestPausedForDistance = false;
    });

    // Restart distance monitoring
    _startContinuousDistanceMonitoring();

    _ttsService.speak('You may continue marking the grid');
  }

  /// Restart only the current test, preserving other test data
  void _restartCurrentTest() {
    // Reset only Amsler Grid test data in provider
    context.read<TestSessionProvider>().resetAmslerGrid();

    _distanceService.stopMonitoring();
    _ttsService.stop();

    setState(() {
      _currentEye = 'right';
      _testingStarted = false;
      _eyeSwitchPending = false;
      _testComplete = false;
      _showDistanceCalibration = true;
      _isTestPausedForDistance = false;
      _isPausedForExit = false;
      _rightEyePoints.clear();
      _leftEyePoints.clear();
      _allLinesStraight = null;
      _hasMissingAreas = null;
      _hasDistortions = null;
    });

    _initServices();
  }

  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;
    setState(() => _isTestPausedForDistance = false);
    _ttsService.speak('You may continue marking the grid');
    HapticFeedback.mediumImpact();
  }

  void _startTest() {
    setState(() {
      _testingStarted = true;
    });
    _ttsService.speakEyeInstruction(_currentEye);
  }



  void _addDistortionPoint(Offset position, {bool isStrokeStart = false}) {
    final point = DistortionPoint(
      x: position.dx,
      y: position.dy,
      type: _markingMode,
      isStrokeStart: isStrokeStart,
    );

    setState(() {
      if (_currentEye == 'right') {
        _rightEyePoints.add(point);
      } else {
        _leftEyePoints.add(point);
      }
    });
  }

  void _onPanStartRestricted(DragStartDetails details, double gridSize) {
    final RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);

    // Check if touch is within grid bounds
    if (_isWithinGridBounds(localPosition, gridSize)) {
      _addDistortionPoint(localPosition, isStrokeStart: true);
    }
  }

  void _onPanUpdateRestricted(DragUpdateDetails details, double gridSize) {
    final RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);

    // Check if touch is within grid bounds
    if (_isWithinGridBounds(localPosition, gridSize)) {
      _addDistortionPoint(localPosition, isStrokeStart: false);
    }
  }

  bool _isWithinGridBounds(Offset position, double gridSize) {
    return position.dx >= 0 &&
        position.dx <= gridSize &&
        position.dy >= 0 &&
        position.dy <= gridSize;
  }

  void _undoLastPoint() {
    setState(() {
      if (_currentEye == 'right' && _rightEyePoints.isNotEmpty) {
        _rightEyePoints.removeLast();
      } else if (_currentEye == 'left' && _leftEyePoints.isNotEmpty) {
        _leftEyePoints.removeLast();
      }
    });
  }

  void _clearPoints() {
    setState(() {
      if (_currentEye == 'right') {
        _rightEyePoints.clear();
      } else {
        _leftEyePoints.clear();
      }
    });
  }

  Future<String?> _captureGridImage() async {
    try {
      debugPrint('========================================');
      debugPrint('ðŸ–¼ï¸ CAPTURING AMSLER GRID IMAGE');
      debugPrint('========================================');

      final boundary =
          _gridKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('âŒ Boundary is NULL - cannot capture image');
        return null;
      }

      debugPrint('âœ… Boundary found, capturing image...');

      final image = await boundary.toImage(
        pixelRatio: 2.5,
      ); // Increased quality
      debugPrint('âœ… Image captured: ${image.width}x${image.height}');

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('âŒ ByteData is NULL - conversion failed');
        return null;
      }

      debugPrint('âœ… ByteData created: ${byteData.lengthInBytes} bytes');

      final bytes = byteData.buffer.asUint8List();
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'amsler_${_currentEye}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';

      debugPrint('ðŸ“ Saving to: $filePath');

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Verify the file was actually saved
      final exists = await file.exists();
      final fileSize = exists ? await file.length() : 0;

      debugPrint('========================================');
      debugPrint('âœ… IMAGE SAVED SUCCESSFULLY');
      debugPrint('   Path: $filePath');
      debugPrint('   Exists: $exists');
      debugPrint('   Size: $fileSize bytes');
      debugPrint('   Eye: $_currentEye');
      debugPrint('========================================');

      return filePath;
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('âŒ ERROR CAPTURING AMSLER IMAGE');
      debugPrint('   Error: $e');
      debugPrint('   StackTrace: $stackTrace');
      debugPrint('========================================');
      return null;
    }
  }

  Future<void> _completeCurrentEye() async {
    debugPrint('========================================');
    debugPrint('ðŸ“Š COMPLETING EYE TEST: $_currentEye');
    debugPrint('========================================');

    // Capture the grid image before saving
    String? imagePath;
    try {
      debugPrint('ðŸ–¼ï¸ Starting image capture...');
      imagePath = await _captureGridImage();

      if (imagePath != null) {
        debugPrint('âœ… Image captured successfully: $imagePath');
      } else {
        debugPrint('âš ï¸ Image capture returned NULL');
      }
    } catch (e) {
      debugPrint('âŒ Error capturing grid image: $e');
    }

    // Save result for current eye
    final points = _currentEye == 'right' ? _rightEyePoints : _leftEyePoints;

    final hasDistortions =
        points.any((p) => p.type == 'distortion') || (_hasDistortions ?? false);
    final hasMissing =
        points.any((p) => p.type == 'missing') || (_hasMissingAreas ?? false);
    final hasBlurry = points.any((p) => p.type == 'blurry');

    String status;
    if (!hasDistortions &&
        !hasMissing &&
        !hasBlurry &&
        (_allLinesStraight ?? true)) {
      status = 'Normal';
    } else {
      status = 'Abnormal - Further evaluation recommended';
    }

    String? description;
    if (hasDistortions || hasMissing || hasBlurry) {
      List<String> issues = [];
      if (hasDistortions) issues.add('wavy/distorted lines');
      if (hasMissing) issues.add('missing areas');
      if (hasBlurry) issues.add('blurry areas');
      description = 'Patient reported: ${issues.join(', ')}';
    }

    debugPrint('ðŸ“‹ Creating AmslerGridResult:');
    debugPrint('   Eye: $_currentEye');
    debugPrint('   Image Path: $imagePath');
    debugPrint('   Has Distortions: $hasDistortions');
    debugPrint('   Has Missing: $hasMissing');
    debugPrint('   Has Blurry: $hasBlurry');
    debugPrint('   Points Count: ${points.length}');
    debugPrint('   Status: $status');

    final result = AmslerGridResult(
      eye: _currentEye,
      hasDistortions: hasDistortions,
      hasMissingAreas: hasMissing,
      hasBlurryAreas: hasBlurry,
      distortionPoints: List.from(points),
      status: status,
      description: description,
      annotatedImagePath: imagePath,
    );

    if (!mounted) return;
    debugPrint('ðŸ’¾ Saving result to TestSessionProvider...');
    final provider = context.read<TestSessionProvider>();
    provider.setAmslerGridResult(result);
    debugPrint('âœ… Result saved to provider');
    debugPrint('========================================');

    if (_currentEye == 'right') {
      _showCoverEyeInstruction('right');
    } else {
      // Both eyes complete
      _distanceService.stopMonitoring();
      setState(() {
        _testComplete = true;
      });

      if (provider.isComprehensiveTest) {
        _ttsService.speak(
          'Amsler grid test completed. Please review your results.',
        );
      } else {
        _ttsService.speak(
          'Amsler grid test completed. Preparing your results.',
        );
      }

      _startAutoNavigationTimer();
    }
  }

  void _showContrastTransition() {
    if (_isNavigatingToNextTest) return;
    _isNavigatingToNextTest = true;

    final provider = context.read<TestSessionProvider>();

    // Check for individual test mode FIRST
    if (provider.isIndividualTest) {
      Navigator.pushReplacementNamed(context, '/quick-test-result');
      return;
    }

    if (!provider.isComprehensiveTest) {
      Navigator.pushReplacementNamed(context, '/quick-test-result');
      return;
    }
    // Navigate to Pelli-Robson test for Comprehensive tests only
    Navigator.pushReplacementNamed(context, '/pelli-robson-test');
  }

  void _switchToLeftEye() {
    final provider = context.read<TestSessionProvider>();
    provider.switchEye();

    setState(() {
      _currentEye = 'left';
      _eyeSwitchPending = false;
      _allLinesStraight = null;
      _hasMissingAreas = null;
      _hasDistortions = null;
    });

    _ttsService.speakEyeInstruction('left');
  }

  void _startAutoNavigationTimer() {
    _autoNavigationTimer?.cancel();

    setState(() {
      _autoNavigationCountdown = 5;
    });

    _autoNavigationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _autoNavigationCountdown--;
      });

      if (_autoNavigationCountdown <= 0) {
        timer.cancel();
        if (!_isNavigatingToNextTest) {
          _showContrastTransition();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoNavigationTimer?.cancel();
    _distanceService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _testComplete ? _buildCompleteView() : _buildManualScaffold();

    return PopScope(
      canPop: false, // Prevent accidental exit
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: body,
    );
  }

  Widget _buildManualScaffold() {
    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: Text(
          'Amsler Grid - ${_currentEye.toUpperCase()} Eye',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _showExitConfirmation,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildInfoBar(),
                Expanded(
                  child: _eyeSwitchPending
                      ? _buildEyeSwitchView()
                      : (!_testingStarted
                            ? const Center(child: CircularProgressIndicator())
                            : _buildTestView()),
                ),
              ],
            ),
            // Distance indicator

            // Undo and Delete buttons (bottom-right corner)
            if (_testingStarted && !_eyeSwitchPending && !_testComplete)
              // Distance warning overlay - only show when explicitly paused
              // âœ… FIX: Don't show overlay when pause dialog is active
              // NEW CODE (PASTE THIS):
              DistanceWarningOverlay(
                isVisible:
                    _isTestPausedForDistance &&
                    !_isPausedForExit &&
                    _testingStarted &&
                    !_testComplete &&
                    !_eyeSwitchPending,
                status: _distanceStatus,
                currentDistance: _currentDistance,
                targetDistance: 40.0,
                onSkip: () {
                  _skipManager.recordSkip(DistanceTestType.amslerGrid);
                  _resumeTestAfterDistance();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Eye indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  '${_currentEye.toUpperCase()} Eye',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Distance indicator (acuity-style)
          if (!_showDistanceCalibration && !_testComplete)
            _buildAcuityStyleDistanceIndicator(),
        ],
      ),
    );
  }

  Widget _buildAcuityStyleDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      40.0,
      testType: 'amsler_grid',
    );

    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'Searching...';

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: 0.15),
                AppColors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: indicatorColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: indicatorColor.withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulse-like status circle
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISTANCE',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: indicatorColor.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    distanceText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: indicatorColor,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTestView() {
    final currentPoints = _currentEye == 'right'
        ? _rightEyePoints
        : _leftEyePoints;

    return Column(
      children: [
        // MASSIVE Grid - takes maximum space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate maximum grid size (98% of available space for HUGE grid)
                final maxSize =
                    min(constraints.maxWidth, constraints.maxHeight) * 0.98;

                return Center(
                  child: Container(
                    width: maxSize,
                    height: maxSize,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: GestureDetector(
                        onPanStart: (details) =>
                            _onPanStartRestricted(details, maxSize),
                        onPanUpdate: (details) =>
                            _onPanUpdateRestricted(details, maxSize),
                        child: RepaintBoundary(
                          key: _gridKey,
                          child: Stack(
                            children: [
                              // Grid image
                              Positioned.fill(
                                child: Image.asset(
                                  AppAssets.amslerGrid,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildFallbackGrid(),
                                ),
                              ),
                              // Drawing overlay
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: AmslerGridPainter(
                                    points: currentPoints,
                                    distortionColor: _getPointColor(
                                      'distortion',
                                    ),
                                    missingColor: _getPointColor('missing'),
                                    blurryColor: _getPointColor('blurry'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Questions section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildQuestionRow(
                'Do all lines appear straight?',
                _allLinesStraight,
                (v) => setState(() => _allLinesStraight = v),
              ),
              const SizedBox(height: 10),
              _buildQuestionRow(
                'Any missing or dark areas?',
                _hasMissingAreas,
                (v) => setState(() => _hasMissingAreas = v),
              ),
              const SizedBox(height: 10),
              _buildQuestionRow(
                'Any wavy or distorted lines?',
                _hasDistortions,
                (v) => setState(() => _hasDistortions = v),
              ),
            ],
          ),
        ),

        // Mode Selector + Action Buttons in same row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              // Mode Selector Row
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeChip('distortion', 'Wavy', Icons.waves),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildModeChip(
                        'missing',
                        'Missing',
                        Icons.visibility_off,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildModeChip('blurry', 'Blurry', Icons.blur_on),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // ✅ Undo Button - Enhanced
                  _buildActionButton(
                    icon: Icons.undo_rounded,
                    onTap: _undoLastPoint,
                    color: AppColors.primary,
                    tooltip: 'Undo',
                  ),
                  const SizedBox(width: 8),
                  // ✅ Delete Button - Enhanced
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: _clearPoints,
                    color: AppColors.error,
                    tooltip: 'Clear All',
                  ),
                  const SizedBox(width: 12),
                  // Continue Button (keep existing code)
                  Expanded(
                    child: _ContinueButton(
                      label: _currentEye == 'right'
                          ? 'Continue'
                          : 'Complete Test',
                      onTap: _completeCurrentEye,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action Buttons Row
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(String mode, String label, IconData icon) {
    final isSelected = _markingMode == mode;
    final color = _getPointColor(mode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact(); // ✅ Instant haptic feedback
          setState(() => _markingMode = mode);
        },
        borderRadius: BorderRadius.circular(10),
        splashColor: color.withValues(alpha: 0.4),
        highlightColor: color.withValues(alpha: 0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), // ✅ Reduced from 300ms
          curve: Curves.easeOutCubic, // ✅ Faster, more responsive curve
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [color, color.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
                : Border.all(color: color.withValues(alpha: 0.2), width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200), // ✅ Reduced
                curve: Curves.easeOutCubic, // ✅ Faster curve
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.white : color,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200), // ✅ Reduced
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? AppColors.white : color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: _ActionButton(icon: icon, onTap: onTap, color: color),
    );
  }

  Color _getPointColor(String type) {
    switch (type) {
      case 'distortion':
        return AppColors.error;
      case 'missing':
        return AppColors.warning;
      case 'blurry':
        return AppColors.info;
      default:
        return AppColors.error;
    }
  }

  Widget _buildQuestionRow(
    String question,
    bool? value,
    Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Expanded(child: Text(question, style: const TextStyle(fontSize: 13))),
        Row(
          children: [
            _buildYesNoButton('No', value == false, () => onChanged(false)),
            const SizedBox(width: 8),
            _buildYesNoButton('Yes', value == true, () => onChanged(true)),
          ],
        ),
      ],
    );
  }

  Widget _buildYesNoButton(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact(); // ✅ Instant haptic
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withValues(alpha: 0.4),
        highlightColor: AppColors.primary.withValues(alpha: 0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150), // ✅ Faster (was 300ms)
          curve: Curves.easeOut, // ✅ More responsive curve
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF005FCC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150), // ✅ Faster
            curve: Curves.easeOut,
            style: TextStyle(
              color: selected ? AppColors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
            child: Text(label.toUpperCase()),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackGrid() {
    return Container(
      color: AppColors.white,
      child: CustomPaint(painter: _AmslerGridPainter(), size: Size.infinite),
    );
  }

  Widget _buildEyeSwitchView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_off, size: 80, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Right Eye Complete!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Now let\'s test your left eye.\n\nCover your RIGHT eye and tap Continue when ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _switchToLeftEye,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Continue with Left Eye'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteView() {
    final provider = context.read<TestSessionProvider>();
    final rightResult = provider.amslerGridRight;
    final leftResult = provider.amslerGridLeft;

    final isNormal =
        (rightResult?.isNormal ?? true) && (leftResult?.isNormal ?? true);

    // Qualitative feedback has been integrated into cards.

    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: const Text('Amsler Grid Result'),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.testBackground,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // Header Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            (isNormal ? AppColors.success : AppColors.warning)
                                .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              (isNormal ? AppColors.success : AppColors.warning)
                                  .withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  (isNormal
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isNormal
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 40,
                              color: isNormal
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Amsler Grid Test Completed',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Separate Eye Result Cards
                    _buildEyeSummaryCard(
                      'Right Eye',
                      rightResult,
                      AppColors.rightEye,
                    ),
                    const SizedBox(height: 16),
                    _buildEyeSummaryCard(
                      'Left Eye',
                      leftResult,
                      AppColors.leftEye,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Bottom Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _autoNavigationTimer?.cancel();
                  _showContrastTransition();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.isComprehensiveTest
                          ? 'Continue Test'
                          : 'View Results',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_autoNavigationCountdown}s',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeSummaryCard(
    String eye,
    AmslerGridResult? result,
    Color color,
  ) {
    final bool isNormal = result?.isNormal ?? true;
    final List<String> findings = [];

    if (!isNormal) {
      if (result?.hasDistortions == true) findings.add('Wavy Lines');
      if (result?.hasBlurryAreas == true) findings.add('Blurry regions');
      if (result?.hasMissingAreas == true) findings.add('Missing Areas');
    }

    // Determine severity
    String severityLabel = 'Normal';
    Color severityColor = AppColors.success;

    if (!isNormal) {
      final pointCount = result?.distortionPoints.length ?? 0;
      if (pointCount >= 8 || findings.length >= 3) {
        severityLabel = 'Severe';
        severityColor = AppColors.error;
      } else if (pointCount >= 4 || findings.length >= 2) {
        severityLabel = 'Moderate';
        severityColor = Colors.orange;
      } else {
        severityLabel = 'Mild';
        severityColor = AppColors.warning;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.grid_on_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eye,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      severityLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: severityColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isNormal) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),
            Text(
              'FINDINGS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: findings
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: severityColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

}

class _AmslerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.amslerGridLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final gridSize = size.width < size.height ? size.width : size.height;
    final cellSize = gridSize / 20;
    final offset = Offset(
      (size.width - gridSize) / 2,
      (size.height - gridSize) / 2,
    );

    // Draw grid lines
    for (int i = 0; i <= 20; i++) {
      // Vertical lines
      canvas.drawLine(
        Offset(offset.dx + i * cellSize, offset.dy),
        Offset(offset.dx + i * cellSize, offset.dy + gridSize),
        paint,
      );
      // Horizontal lines
      canvas.drawLine(
        Offset(offset.dx, offset.dy + i * cellSize),
        Offset(offset.dx + gridSize, offset.dy + i * cellSize),
        paint,
      );
    }

    // Draw center dot
    final centerDotPaint = Paint()
      ..color = AppColors.amslerCenterDot
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(offset.dx + gridSize / 2, offset.dy + gridSize / 2),
      5,
      centerDotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for rendering Amsler grid user strokes
class AmslerGridPainter extends CustomPainter {
  final List<DistortionPoint> points;
  final Color distortionColor;
  final Color missingColor;
  final Color blurryColor;

  AmslerGridPainter({
    required this.points,
    required this.distortionColor,
    required this.missingColor,
    required this.blurryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final Map<String, Paint> paints = {
      'distortion': Paint()
        ..color = distortionColor
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
      'missing': Paint()
        ..color = missingColor
        ..strokeWidth =
            10.0 // Missing areas are thicker
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
      'blurry': Paint()
        ..color = blurryColor
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    };

    for (int i = 0; i < points.length; i++) {
      if (points[i].isStrokeStart) continue;
      if (i > 0 && !points[i].isStrokeStart) {
        // Draw line between current point and previous if previous is same type and same eye
        if (points[i].type == points[i - 1].type) {
          canvas.drawLine(
            points[i - 1].offset,
            points[i].offset,
            paints[points[i].type]!,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant AmslerGridPainter oldDelegate) => true;
}

/// Stateful button with press animation and haptic feedback
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.mediumImpact(); // ✅ Instant haptic
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100), // ✅ Fast response
          curve: Curves.easeOut,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _isPressed
                ? widget.color.withValues(alpha: 0.12) // ✅ Fill on press
                : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isPressed
                  ? widget.color.withValues(alpha: 0.5)
                  : widget.color.withValues(alpha: 0.3),
              width: _isPressed ? 2.0 : 1.5,
            ),
            boxShadow: _isPressed
                ? [] // ✅ No shadow when pressed
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedScale(
              scale: _isPressed ? 0.85 : 1.0, // ✅ Icon scales down
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stateful Continue button with premium press animation
class _ContinueButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ContinueButton({required this.label, required this.onTap});

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPressed
                  ? [
                      const Color(0xFF005FCC),
                      const Color(0xFF004A99),
                    ] // ✅ Darker when pressed
                  : [AppColors.primary, const Color(0xFF005FCC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isPressed
                ? [] // ✅ No shadow when pressed
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.3,
                shadows: _isPressed
                    ? null
                    : [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
