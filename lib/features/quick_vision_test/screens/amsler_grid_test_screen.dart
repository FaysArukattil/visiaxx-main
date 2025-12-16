import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/models/amsler_grid_result.dart';
import '../../../data/providers/test_session_provider.dart';
import 'distance_calibration_screen.dart';

/// Amsler Grid Test for detecting macular degeneration
class AmslerGridTestScreen extends StatefulWidget {
  const AmslerGridTestScreen({super.key});

  @override
  State<AmslerGridTestScreen> createState() => _AmslerGridTestScreenState();
}

class _AmslerGridTestScreenState extends State<AmslerGridTestScreen> {
  final TtsService _ttsService = TtsService();
  final DistanceDetectionService _distanceService = DistanceDetectionService(
    targetDistanceCm: 40.0,
    toleranceCm: 5.0,
  );

  // Test state
  String _currentEye = 'right';
  bool _testingStarted = false;
  bool _eyeSwitchPending = false;
  bool _testComplete = false;
  bool _showDistanceCalibration = true;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  bool _isDistanceOk = false;
  bool _isTestPausedForDistance = false;
  DistanceStatus? _lastSpokenDistanceStatus;

  // Distortion tracking
  final List<DistortionPoint> _rightEyePoints = [];
  final List<DistortionPoint> _leftEyePoints = [];

  // Questions
  bool? _allLinesStraight;
  bool? _hasMissingAreas;
  bool? _hasDistortions;

  // Current marking mode
  String _markingMode = 'distortion'; // 'distortion', 'missing', 'blurry'

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    _ttsService.speak(TtsService.amslerGridInstruction);

    // Show distance calibration first
    if (_showDistanceCalibration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCalibrationScreen();
      });
    }
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
  }

  /// Start continuous distance monitoring
  Future<void> _startContinuousDistanceMonitoring() async {
    _distanceService.onDistanceUpdate = (distance, status) {
      if (!mounted) return;

      // ✅ Use centralized helper
      final newIsOk = DistanceHelper.isDistanceAcceptable(distance, 40.0);
      final shouldPause = DistanceHelper.shouldPauseTest(status);

      setState(() {
        _currentDistance = distance;
        _distanceStatus = status;
        _isDistanceOk = newIsOk;
      });

      // ✅ AUTO PAUSE/RESUME during active test
      if (_testingStarted && !_testComplete && !_eyeSwitchPending) {
        if (shouldPause && !_isTestPausedForDistance) {
          _pauseTestForDistance();
        } else if (!shouldPause && _isTestPausedForDistance) {
          _resumeTestAfterDistance();
        }
      }

      // Speak guidance when paused and status changes
      if (_isTestPausedForDistance && status != _lastSpokenDistanceStatus) {
        _lastSpokenDistanceStatus = status;
        _speakDistanceGuidance(status);
      }
    };

    _distanceService.onError = (msg) => debugPrint('[DistanceMonitor] $msg');

    if (!_distanceService.isReady) {
      await _distanceService.initializeCamera();
    }

    if (!_distanceService.isMonitoring) {
      await _distanceService.startMonitoring();
    }
  }

  void _speakDistanceGuidance(DistanceStatus status) {
    switch (status) {
      case DistanceStatus.tooClose:
        _ttsService.speak('Move back, you are too close');
        break;
      case DistanceStatus.tooFar:
        _ttsService.speak('Move closer, you are too far');
        break;
      case DistanceStatus.optimal:
        _ttsService.speak('Good, distance is correct');
        break;
      case DistanceStatus.noFaceDetected:
        _ttsService.speak('Position your face in view');
        break;
    }
  }

  void _pauseTestForDistance() {
    setState(() => _isTestPausedForDistance = true);
    _ttsService.speak(
      'Test paused. Please adjust your distance to 40 centimeters.',
    );
    HapticFeedback.heavyImpact();
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

  void _addDistortionPoint(Offset position) {
    final point = DistortionPoint(
      x: position.dx,
      y: position.dy,
      type: _markingMode,
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

  void _completeCurrentEye() {
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

    final result = AmslerGridResult(
      eye: _currentEye,
      hasDistortions: hasDistortions,
      hasMissingAreas: hasMissing,
      hasBlurryAreas: hasBlurry,
      distortionPoints: List.from(points),
      status: status,
      description: description,
    );

    final provider = context.read<TestSessionProvider>();
    provider.setAmslerGridResult(result);

    if (_currentEye == 'right') {
      setState(() {
        _eyeSwitchPending = true;
      });
    } else {
      setState(() {
        _testComplete = true;
      });
      _ttsService.speak(TtsService.testComplete);
    }
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

  void _completeAllTests() {
    Navigator.pushReplacementNamed(context, '/quick-test-result');
  }

  @override
  void dispose() {
    _distanceService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.testBackground,
      appBar: AppBar(
        title: Text('Amsler Grid - ${_currentEye.toUpperCase()} Eye'),
        backgroundColor: _currentEye == 'right'
            ? AppColors.rightEye.withOpacity(0.1)
            : AppColors.leftEye.withOpacity(0.1),
        actions: [
          if (_testingStarted && !_eyeSwitchPending && !_testComplete)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoLastPoint,
              tooltip: 'Undo last mark',
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _buildContent(),
            // Distance indicator
            if (!_showDistanceCalibration && !_testComplete)
              Positioned(
                right: 12,
                bottom: 12,
                child: _buildDistanceIndicator(),
              ),
            // Distance warning overlay - only show when explicitly paused
            if (_isTestPausedForDistance &&
                _testingStarted &&
                !_testComplete &&
                !_eyeSwitchPending)
              _buildDistanceWarningOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_testComplete) {
      return _buildCompleteView();
    }

    if (_eyeSwitchPending) {
      return _buildEyeSwitchView();
    }

    if (!_testingStarted) {
      return _buildInstructionsView();
    }

    return _buildTestView();
  }

  Widget _buildInstructionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 8),
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionItem(
                  '1',
                  'Hold the screen at normal reading distance (about 30cm)',
                ),
                _buildInstructionItem(
                  '2',
                  'Cover your LEFT eye to test your RIGHT eye first',
                ),
                _buildInstructionItem('3', 'Look at the center dot'),
                _buildInstructionItem(
                  '4',
                  'Note any wavy, distorted, or missing lines',
                ),
                _buildInstructionItem(
                  '5',
                  'Tap on any problem areas you notice',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Preview grid
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              AppAssets.amslerGrid,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackGrid(),
            ),
          ),
          const SizedBox(height: 32),
          // Current eye indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.rightEye.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility, color: AppColors.rightEye),
                    const SizedBox(width: 8),
                    const Text(
                      'Testing RIGHT eye first',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cover your LEFT eye',
                  style: TextStyle(
                    color: AppColors.rightEye,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startTest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Start Test'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
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
        // Eye indicator
        Container(
          padding: const EdgeInsets.all(12),
          color: _currentEye == 'right'
              ? AppColors.rightEye.withOpacity(0.1)
              : AppColors.leftEye.withOpacity(0.1),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility,
                    size: 18,
                    color: _currentEye == 'right'
                        ? AppColors.rightEye
                        : AppColors.leftEye,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Testing ${_currentEye.toUpperCase()} eye',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentEye == 'right'
                          ? AppColors.rightEye
                          : AppColors.leftEye,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Cover your ${_currentEye == 'right' ? 'LEFT' : 'RIGHT'} eye',
                style: TextStyle(
                  fontSize: 12,
                  color: _currentEye == 'right'
                      ? AppColors.rightEye
                      : AppColors.leftEye,
                ),
              ),
            ],
          ),
        ),
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
                    onTapDown: (details) {
                      _addDistortionPoint(details.localPosition);
                    },
                    child: SizedBox(
                      width: gridSize,
                      height: gridSize,
                      child: Stack(
                        children: [
                          // Grid image
                          Image.asset(
                            AppAssets.amslerGrid,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _buildFallbackGrid(),
                          ),
                          // Marked points
                          ...currentPoints.map(
                            (point) => Positioned(
                              left: point.x - 15,
                              top: point.y - 15,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _getPointColor(
                                    point.type,
                                  ).withOpacity(0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _getPointColor(point.type),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _getPointIcon(point.type),
                                  size: 16,
                                  color: _getPointColor(point.type),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Marks count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${currentPoints.length} area(s) marked',
            style: TextStyle(color: AppColors.textSecondary),
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
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Clear Marks'),
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
              color: isSelected ? Colors.white : _getPointColor(mode),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : _getPointColor(mode),
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

  IconData _getPointIcon(String type) {
    switch (type) {
      case 'distortion':
        return Icons.waves;
      case 'missing':
        return Icons.visibility_off;
      case 'blurry':
        return Icons.blur_on;
      default:
        return Icons.error;
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackGrid() {
    return Container(
      color: Colors.white,
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          Text(
            'All Tests Complete!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Summary cards
          _buildEyeSummaryCard('Right Eye', rightResult, AppColors.rightEye),
          const SizedBox(height: 12),
          _buildEyeSummaryCard('Left Eye', leftResult, AppColors.leftEye),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeAllTests,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('View Results'),
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
    final isNormal = result?.isNormal ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.grid_on, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              eye,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isNormal ? AppColors.success : AppColors.warning,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isNormal ? 'Normal' : 'Review',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      40.0,
    );
    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'No face';

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
    final pauseReason = DistanceHelper.getPauseReason(_distanceStatus, 40.0);
    final instruction = DistanceHelper.getDetailedInstruction(40.0);
    final rangeText = DistanceHelper.getAcceptableRangeText(40.0);

    // ✅ Icon changes based on issue
    final icon = _distanceStatus == DistanceStatus.noFaceDetected
        ? Icons.face_retouching_off
        : Icons.warning_rounded;

    final iconColor = _distanceStatus == DistanceStatus.noFaceDetected
        ? AppColors.error
        : AppColors.warning;

    return Container(
      color: Colors.black.withOpacity(0.85),
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
                pauseReason, // ✅ Dynamic
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                instruction, // ✅ Dynamic
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // ✅ Only show distance if face is detected
              if (_distanceStatus != DistanceStatus.noFaceDetected) ...[
                Text(
                  _currentDistance > 0
                      ? 'Current: ${_currentDistance.toStringAsFixed(0)}cm'
                      : 'Measuring...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  rangeText, // ✅ Dynamic: "Minimum 40 cm"
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
                        'Position your face in the camera',
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

              // ✅ Show marking is paused
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_circle,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Marking paused',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Continue button
              TextButton(
                onPressed: () {
                  setState(() {
                    _isDistanceOk = true;
                    _isTestPausedForDistance = false;
                  });
                },
                child: Text(
                  'Continue Anyway',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
}

class _AmslerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
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
      ..color = Colors.red
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
