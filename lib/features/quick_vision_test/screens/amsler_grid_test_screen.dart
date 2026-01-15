import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
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
      false; // ✅ Prevent distance warning during pause dialog

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
    if (!mounted || _testComplete) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_testComplete && _testingStarted) {
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
    // ✅ FIX: Stop distance monitoring before showing cover eye instruction
    _distanceService.stopMonitoring();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AmslerGridCoverEyeScreen(
          eyeToCover: eyeToCover,
          onContinue: () {
            Navigator.of(context).pop();
            // ✅ FIX: Resume monitoring AFTER user confirms they've covered their eye
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

    // ✅ FIX: Don't process distance updates while pause dialog is showing
    if (_isPausedForExit) return;

    // ✅ SIMPLIFIED: Only check if distance is too close
    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      'amsler_grid',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
    });

    // ✅ Only trigger pause/resume during active testing
    if (_testingStarted && !_testComplete && !_eyeSwitchPending) {
      if (shouldPause && !_isTestPausedForDistance) {
        _lastShouldPauseTime ??= DateTime.now();
        final timeSinceFirst = DateTime.now().difference(_lastShouldPauseTime!);

        // ✅ Only show overlay after 1.5 seconds of continuous issue
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
    _autoNavigationTimer?.cancel(); // ✅ Pause auto-navigation timer

    setState(() {
      _isPausedForExit = true;
      _isTestPausedForDistance = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.pause_circle_outline,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Test Paused',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason == 'minimized'
                  ? 'The test was paused because the app was minimized.'
                  : 'What would you like to do?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Continue Test - Primary action
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _resumeTestFromDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue Test',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              // Restart Current Test
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _restartCurrentTest();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning),
                  foregroundColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Restart Current Test',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              // Exit Test
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await NavigationUtils.navigateHome(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Exit and Lose Progress',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ],
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
      _startAutoNavigationTimer(); // ✅ Resume auto-navigation
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

  void _onPanStart(DragStartDetails details) {
    _addDistortionPoint(details.localPosition, isStrokeStart: true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _addDistortionPoint(details.localPosition, isStrokeStart: false);
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
      debugPrint('🖼️ CAPTURING AMSLER GRID IMAGE');
      debugPrint('========================================');

      final boundary =
          _gridKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('❌ Boundary is NULL - cannot capture image');
        return null;
      }

      debugPrint('✅ Boundary found, capturing image...');

      final image = await boundary.toImage(
        pixelRatio: 2.5,
      ); // Increased quality
      debugPrint('✅ Image captured: ${image.width}x${image.height}');

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('❌ ByteData is NULL - conversion failed');
        return null;
      }

      debugPrint('✅ ByteData created: ${byteData.lengthInBytes} bytes');

      final bytes = byteData.buffer.asUint8List();
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'amsler_${_currentEye}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';

      debugPrint('📁 Saving to: $filePath');

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Verify the file was actually saved
      final exists = await file.exists();
      final fileSize = exists ? await file.length() : 0;

      debugPrint('========================================');
      debugPrint('✅ IMAGE SAVED SUCCESSFULLY');
      debugPrint('   Path: $filePath');
      debugPrint('   Exists: $exists');
      debugPrint('   Size: $fileSize bytes');
      debugPrint('   Eye: $_currentEye');
      debugPrint('========================================');

      return filePath;
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('❌ ERROR CAPTURING AMSLER IMAGE');
      debugPrint('   Error: $e');
      debugPrint('   StackTrace: $stackTrace');
      debugPrint('========================================');
      return null;
    }
  }

  Future<void> _completeCurrentEye() async {
    debugPrint('========================================');
    debugPrint('📊 COMPLETING EYE TEST: $_currentEye');
    debugPrint('========================================');

    // Capture the grid image before saving
    String? imagePath;
    try {
      debugPrint('🖼️ Starting image capture...');
      imagePath = await _captureGridImage();

      if (imagePath != null) {
        debugPrint('✅ Image captured successfully: $imagePath');
      } else {
        debugPrint('⚠️ Image capture returned NULL');
      }
    } catch (e) {
      debugPrint('❌ Error capturing grid image: $e');
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

    debugPrint('📋 Creating AmslerGridResult:');
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
    debugPrint('💾 Saving result to TestSessionProvider...');
    final provider = context.read<TestSessionProvider>();
    provider.setAmslerGridResult(result);
    debugPrint('✅ Result saved to provider');
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
        actions: [
          if (_testingStarted && !_eyeSwitchPending && !_testComplete)
            IconButton(
              icon: const Icon(Icons.undo, color: AppColors.textPrimary),
              onPressed: _undoLastPoint,
              tooltip: 'Undo last mark',
            ),
          if (_testingStarted && !_eyeSwitchPending && !_testComplete)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
              onPressed: _clearPoints,
              tooltip: 'Reset marks',
            ),
        ],
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
            if (!_showDistanceCalibration && !_testComplete)
              Positioned(
                right: 12,
                bottom: 12,
                child: _buildDistanceIndicator(),
              ),
            // Distance warning overlay - only show when explicitly paused
            // ✅ FIX: Don't show overlay when pause dialog is active
            if (_isTestPausedForDistance &&
                !_isPausedForExit &&
                _testingStarted &&
                !_testComplete &&
                !_eyeSwitchPending)
              _buildDistanceWarningOverlay(),
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
            color: AppColors.border.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Eye status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'EYE: ${_currentEye.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Marks count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_location_alt_outlined,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_currentEye == 'right' ? _rightEyePoints : _leftEyePoints).length} MARKS',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestView() {
    final currentPoints = _currentEye == 'right'
        ? _rightEyePoints
        : _leftEyePoints;

    return Column(
      children: [
        // Marking mode selector
        // Marking mode selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Mark: ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              _buildModeChip('distortion', 'Wavy', Icons.waves),
              const SizedBox(width: 8),
              _buildModeChip('missing', 'Missing', Icons.visibility_off),
              const SizedBox(width: 8),
              _buildModeChip('blurry', 'Blurry', Icons.blur_on),
            ],
          ),
        ),
        // Grid with tap detection
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridSize = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight;

                return Center(
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    child: Container(
                      color: AppColors.white,
                      child: RepaintBoundary(
                        key: _gridKey,
                        child: SizedBox(
                          width: gridSize,
                          height: gridSize,
                          child: Stack(
                            children: [
                              // Grid image
                              Image.asset(
                                AppAssets.amslerGrid,
                                width: gridSize,
                                height: gridSize,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildFallbackGrid(),
                              ),
                              // Custom Painter for strokes
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
        // Marks status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            '${currentPoints.length} AREA(S) MARKED',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        // Questions
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            children: [
              _buildQuestionRow(
                'Do all lines appear straight?',
                _allLinesStraight,
                (v) => setState(() => _allLinesStraight = v),
              ),
              const SizedBox(height: 8),
              _buildQuestionRow(
                'Any missing or dark areas?',
                _hasMissingAreas,
                (v) => setState(() => _hasMissingAreas = v),
              ),
              const SizedBox(height: 8),
              _buildQuestionRow(
                'Any wavy or distorted lines?',
                _hasDistortions,
                (v) => setState(() => _hasDistortions = v),
              ),
            ],
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearPoints,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Clear Marks',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _completeCurrentEye,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _currentEye == 'right'
                          ? 'Next: Left Eye'
                          : 'Complete Test',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(String mode, String label, IconData icon) {
    final isSelected = _markingMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _markingMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _getPointColor(mode) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _getPointColor(mode)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.white : _getPointColor(mode),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.white : _getPointColor(mode),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.border.withOpacity(0.5),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: selected ? AppColors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.5,
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
                                .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              (isNormal ? AppColors.success : AppColors.warning)
                                  .withOpacity(0.15),
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
                                      .withOpacity(0.1),
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
                        color: AppColors.white.withOpacity(0.2),
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
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
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
                  color: color.withOpacity(0.1),
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
                        color: severityColor.withOpacity(0.1),
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

  Widget _buildDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      40.0,
      testType: 'amsler_grid',
    );

    // ✅ Show distance always (even if face lost temporarily)
    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'Searching...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: indicatorColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.straighten, size: 14, color: indicatorColor),
          const SizedBox(width: 4),
          Text(
            distanceText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: indicatorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceWarningOverlay() {
    // ✅ Dynamic messages based on status
    final instruction = DistanceHelper.getDetailedInstruction(40.0);
    final rangeText = DistanceHelper.getAcceptableRangeText(40.0);

    // ✅ Icon changes based on issue
    final icon = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? Icons.face_retouching_off
        : Icons.warning_rounded;

    final iconColor = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? AppColors.error
        : AppColors.warning;

    return Container(
      color: AppColors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 60, color: iconColor),
              const SizedBox(height: 16),
              Text(
                'Searching for face...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              if (DistanceHelper.isFaceDetected(_distanceStatus)) ...[
                Text(
                  'Current: ${_currentDistance.toStringAsFixed(0)}cm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Target: $rangeText',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                // ✅ Special message when no face
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Distance search active',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Voice indicator (always show it's listening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Voice recognition active',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _skipManager.recordSkip(DistanceTestType.amslerGrid);
                  _resumeTestAfterDistance();
                },
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        ),
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
