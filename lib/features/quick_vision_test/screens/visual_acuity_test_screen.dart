// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visiaxx/core/utils/distance_helper.dart';
import 'package:visiaxx/core/utils/navigation_utils.dart';

import 'package:visiaxx/features/quick_vision_test/screens/both_eyes_open_instruction_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/test_constants.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/continuous_speech_manager.dart';
import '../../../core/services/distance_detection_service.dart';
import '../../../data/models/visiual_acuity_result.dart';
import '../../../data/providers/test_session_provider.dart';
import 'distance_calibration_screen.dart';
import 'cover_right_eye_instruction_screen.dart';
import 'cover_left_eye_instruction_screen.dart';
import '../../../core/services/distance_skip_manager.dart';
import '../../../core/widgets/eye_loader.dart';

/// Visual Acuity Test using Tumbling E chart with distance monitoring
/// Implements Visiaxx specification for 1-meter testing
class VisualAcuityTestScreen extends StatefulWidget {
  const VisualAcuityTestScreen({super.key, this.startWithLeftEye = false});

  final bool startWithLeftEye;

  @override
  State<VisualAcuityTestScreen> createState() => _VisualAcuityTestScreenState();
}

class _VisualAcuityTestScreenState extends State<VisualAcuityTestScreen>
    with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final DistanceSkipManager _skipManager = DistanceSkipManager();
  late ContinuousSpeechManager _continuousSpeech;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Test state
  int _currentLevel = 0;
  int _correctAtLevel = 0;
  int _totalAtLevel = 0;
  int _totalCorrect = 0;
  int _totalResponses = 0;
  EDirection _currentDirection = EDirection.right;
  final List<EResponseRecord> _responses = [];

  // Eye being tested
  String _currentEye = 'right';
  bool _eyeSwitchPending = false;

  // Timing
  Timer? _eDisplayTimer;
  Timer? _relaxationTimer;
  int _relaxationCountdown = 10;
  DateTime? _eDisplayStartTime;
  int _eDisplayCountdown = TestConstants
      .eDisplayDurationSeconds; // 7 seconds per E as per user requirement
  Timer? _eCountdownTimer;

  // Display states
  bool _showDistanceCalibration = true; // Start with distance calibration
  bool _showRelaxation = false;
  bool _showE = false;
  bool _showResult = false;
  bool _testComplete = false;
  bool _waitingForResponse = false;

  // Voice recognition feedback
  bool _isListening = false;
  bool _isSpeechActive = false; // New: for waveform responsiveness
  Timer? _speechActiveTimer; // New: for debouncing responsiveness
  String? _lastDetectedSpeech;

  // Distance monitoring
  double _currentDistance = 0;
  DistanceStatus _distanceStatus = DistanceStatus.noFaceDetected;
  final bool _useDistanceMonitoring =
      true; // Enabled for real-time distance display
  bool _isTestPausedForDistance = false; // Test is paused due to wrong distance

  final Random _random = Random();

  // Pixels per mm for this device (calculated based on screen metrics)
  double _pixelsPerMm = 6.0;

  Timer? _autoNavigationTimer;
  int _autoNavigationCountdown = 3;

  bool _isPausedForExit = false;

  Timer? _speechEraserTimer; // ✅ Timer to clear recognized text

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ FIX: Initialize synchronously to prevent LateInitializationError
    _continuousSpeech = ContinuousSpeechManager(_speechService);

    _initServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App minimized or going to background
      _handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      // App resumed
      _handleAppResumed();
    }
  }

  void _handleAppPaused() {
    // Pause test timers
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();

    // Stop distance monitoring
    _distanceService.stopMonitoring();

    // Stop speech recognition
    _continuousSpeech.stop();

    setState(() {
      _isTestPausedForDistance = true;
    });
  }

  void _handleAppResumed() {
    if (!mounted || _testComplete || _showDistanceCalibration) return;

    // Show unified pause dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_testComplete && !_showDistanceCalibration) {
        _showPauseDialog(reason: 'minimized');
      }
    });
  }

  /// Unified pause dialog for both back button and app minimization
  void _showPauseDialog({String reason = 'back button'}) {
    // Pause timers and services while dialog is shown
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();

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
              style: TextStyle(fontWeight: FontWeight.bold),
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
                  foregroundColor: Colors.white,
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
                  side: const BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
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
    );
  }

  /// Resume the test from the pause dialog
  void _resumeTestFromDialog() {
    if (!mounted || _testComplete) return;

    debugPrint('[VisualAcuity] 🔄 Resuming test from dialog');
    debugPrint(
      '[VisualAcuity] Current state: showE=$_showE, showRelaxation=$_showRelaxation, eCountdown=$_eDisplayCountdown, relaxCountdown=$_relaxationCountdown',
    );

    // Clear pause flags
    setState(() {
      _isPausedForExit = false;
      _isTestPausedForDistance = false;
      _lastShouldPauseTime = null;
    });

    // Restart distance monitoring
    _startContinuousDistanceMonitoring();

    // Resume based on current test phase
    if (_showE && _waitingForResponse) {
      debugPrint('[VisualAcuity] 🔄 Resuming E display phase');
      // Resume speech recognition
      if (!_continuousSpeech.isActive) {
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
      _restartEDisplayTimer();
    } else if (_showRelaxation) {
      debugPrint('[VisualAcuity] 🔄 Resuming relaxation phase');
      // Resume mic if already below 3s
      if (_relaxationCountdown <= 3 && !_continuousSpeech.isActive) {
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
      _restartRelaxationTimer();
    } else {
      debugPrint('[VisualAcuity] 🔄 Starting fresh relaxation');
      // Not in an active phase, start relaxation
      _startRelaxation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculatePixelsPerMm();
  }

  void _calculatePixelsPerMm() {
    // Calculate pixels per mm based on device screen
    // Using a reasonable approximation for mobile devices
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final devicePixelRatio = mediaQuery.devicePixelRatio;

    // Average phone screen is approximately 65-75mm wide
    // Using 70mm as a reasonable estimate
    const estimatedScreenWidthMm = 70.0;
    _pixelsPerMm =
        (screenWidth * devicePixelRatio) /
        estimatedScreenWidthMm /
        devicePixelRatio;

    // Clamp to reasonable values (5-10 pixels per mm)
    _pixelsPerMm = _pixelsPerMm.clamp(5.0, 10.0);

    debugPrint(
      '🔥 [VisualAcuity] 📏 PixelsPerMm calculated: $_pixelsPerMm '
      '(Screen Width: $screenWidth, DPR: $devicePixelRatio)',
    );
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();
    await _speechService.initialize();

    // Initialize continuous speech manager configuration
    _continuousSpeech.onFinalResult = _handleVoiceResponse;
    _continuousSpeech.onSpeechDetected = _handleSpeechDetected;
    _continuousSpeech.onListeningStateChanged = (isListening) {
      if (mounted) setState(() => _isListening = isListening);
    };
    // 🔥 ULTRA-RELIABLE: Pause speech when TTS is speaking to prevent self-recognition
    _ttsService.onSpeakingStateChanged = (isSpeaking) {
      if (isSpeaking) {
        _continuousSpeech.pauseForTts();
      } else {
        _continuousSpeech.resumeAfterTts();
      }
    };

    // Mic start will be handled by relaxation timer (at 3 seconds remaining)
    // as per user requirement to avoid interference.

    // 🔥 KEY FIX: Check if we should start with left eye
    if (!mounted) return;
    final provider = context.read<TestSessionProvider>();

    if (widget.startWithLeftEye ||
        (provider.currentEye == 'left' && provider.visualAcuityRight != null)) {
      // We're starting/resuming left eye - NO calibration needed
      debugPrint(
        '🔥 [VisualAcuity] Starting LEFT EYE test - skipping calibration',
      );
      _showDistanceCalibration = false;
      _currentEye = 'left';
      provider.switchEye();

      // 🔥 KEY: Resume continuous distance monitoring without recalibration
      await _startContinuousDistanceMonitoring();

      // Start test immediately
      _startEyeTest();
      return;
    }

    // First time (right eye) - show calibration
    debugPrint(
      '🔥 [VisualAcuity] Starting RIGHT EYE test - showing calibration',
    );
    if (_useDistanceMonitoring && _showDistanceCalibration) {
      // Wait for build to complete, then show calibration screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCalibrationScreen();
      });
    } else {
      // Skip distance calibration and start directly
      _showDistanceCalibration = false;
      _startEyeTest();
    }
  }

  /// Shows the distance calibration screen as a full-screen overlay
  void _showCalibrationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DistanceCalibrationScreen(
          targetDistanceCm: 100.0,
          toleranceCm: 8.0,
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

  void _handleSpeechDetected(String partialResult) {
    debugPrint('[VisualAcuity] 🎤 Speech detected: "$partialResult"');
    if (mounted) {
      setState(() {
        _lastDetectedSpeech = partialResult;
        _isSpeechActive = true;
      });

      // ✅ RAPID RESPONSE: If we match a direction even in partial speech, trigger now!
      // ✅ GUARD: Results arriving within ~800ms of rotation are ignored (likely from relaxation)
      if (_showE && _waitingForResponse) {
        if (_eDisplayStartTime != null) {
          final sinceRotation = DateTime.now().difference(_eDisplayStartTime!);
          if (sinceRotation < const Duration(milliseconds: 1500)) {
            return;
          }
        }

        final direction = SpeechService.parseDirection(partialResult);
        if (direction != null) {
          debugPrint(
            '[VisualAcuity] ⚡ Rapid recognition from partial speech: $direction',
          );
          _recordResponse(direction, source: 'partial_speech');
          return;
        }

        // Check for blurry
        final normalized = partialResult.toLowerCase().trim();
        final blurryKeywords = [
          'blurry',
          'blur',
          'cannot see',
          'can\'t see',
          'country',
        ];
        for (var keyword in blurryKeywords) {
          if (normalized.contains(keyword)) {
            _recordResponse('blurry');
            return;
          }
        }
      }

      // ✅ Make waveform responsive for 500ms
      _speechActiveTimer?.cancel();
      _speechActiveTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isSpeechActive = false);
      });

      // ✅ Auto-erase recognized text after 2.5 seconds
      _speechEraserTimer?.cancel();
      _speechEraserTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _lastDetectedSpeech = null;
          });
        }
      });
    }
  }

  void _onDistanceCalibrationComplete() {
    setState(() {
      _showDistanceCalibration = false;
    });
    // Start continuous distance monitoring after calibration
    _startContinuousDistanceMonitoring();

    // ✅ FIX: Show cover eye instruction AFTER calibration for right eye
    if (_currentEye == 'right') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CoverLeftEyeInstructionScreen(
            onContinue: () {
              Navigator.of(context).pop();
              _startEyeTest();
            },
          ),
        ),
      );
    } else {
      _startEyeTest();
    }
  }

  /// Start continuous distance monitoring during the test
  Future<void> _startContinuousDistanceMonitoring() async {
    if (!_useDistanceMonitoring) return;

    debugPrint('🔥 [DistanceMonitor] Starting/Resuming distance monitoring');

    // Set up distance update callback
    _distanceService.onDistanceUpdate = _handleDistanceUpdate;
    _distanceService.onError = (msg) => debugPrint('[DistanceMonitor] $msg');

    // ✅ FIX: Always ensure camera is initialized/re-initialized
    // This prevents "stale" camera handles after returning from calibration screen or restarts
    debugPrint('🔥 [DistanceMonitor] Initializing/Ensuring camera');
    await _distanceService.initializeCamera();

    if (!_distanceService.isMonitoring) {
      debugPrint('🔥 [DistanceMonitor] Starting monitoring');
      await _distanceService.startMonitoring();
    } else {
      debugPrint('🔥 [DistanceMonitor] Monitoring already active');
    }
  }

  /// Handle real-time distance updates
  /// Handle real-time distance updates with auto pause/resume
  DateTime? _lastShouldPauseTime;
  static const Duration _distancePauseDebounce = Duration(milliseconds: 1000);

  void _handleDistanceUpdate(double distance, DistanceStatus status) {
    if (!mounted) return;

    // ✅ FIX: Don't process distance updates while pause dialog is showing
    if (_isPausedForExit) return;

    final shouldPause = DistanceHelper.shouldPauseTestForDistance(
      distance,
      status,
      'visual_acuity',
    );

    setState(() {
      _currentDistance = distance;
      _distanceStatus = status;
    });

    // ✅ AUTO PAUSE/RESUME logic with DEBOUNCING
    // ALWAYS check if we should pause, regardless of _showE, but only apply pause if we are in a state where it matters
    if (shouldPause) {
      _lastShouldPauseTime ??= DateTime.now();
      final durationSinceFirstIssue = DateTime.now().difference(
        _lastShouldPauseTime!,
      );

      if (durationSinceFirstIssue >= _distancePauseDebounce &&
          !_isTestPausedForDistance) {
        // Only pause if actually in a test phase (E or Relaxation)
        if (_showE || _showRelaxation) {
          _skipManager
              .canShowDistanceWarning(DistanceTestType.visualAcuity)
              .then((canShow) {
                if (mounted && canShow && !_isPausedForExit) {
                  _pauseTestForDistance();
                }
              });
        }
      }
    } else {
      _lastShouldPauseTime = null;
      if (_isTestPausedForDistance && !_isPausedForExit) {
        _resumeTestAfterDistance();
      }
    }
  }

  /// Pause the test due to incorrect distance
  void _pauseTestForDistance() {
    setState(() {
      _isTestPausedForDistance = true;
    });

    // Cancel timers
    _eCountdownTimer?.cancel();
    _eDisplayTimer?.cancel();

    // 🔥 NO verbal "Test Paused" here - visual overlay is sufficient
    // This allows the user's voice to be heard even if they are slightly too close
    HapticFeedback.mediumImpact();
  }

  /// Resume the test after distance is corrected or dialog is closed
  void _resumeTestAfterDistance() {
    if (!_isTestPausedForDistance) return;

    setState(() {
      _isTestPausedForDistance = false;
      _lastShouldPauseTime = null;
    });

    // Resume distance monitoring if needed
    if (!_showDistanceCalibration) {
      _startContinuousDistanceMonitoring();
    }

    // Restart the countdown timer with remaining time
    if (_showE && _waitingForResponse) {
      // Resume speech recognition if needed
      if (!_continuousSpeech.isActive) {
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
      _restartEDisplayTimer();
    } else if (_showRelaxation) {
      // ✅ RESUME MIC: If we were already below 3s when distance was corrected
      if (_relaxationCountdown <= 3 && !_continuousSpeech.isActive) {
        debugPrint(
          '[VisualAcuity] 🎤 Resuming mic (already below 3s in relaxation)',
        );
        _continuousSpeech.start(
          listenDuration: const Duration(minutes: 10),
          minConfidence: 0.15,
          bufferMs: 1000,
        );
      }
      _restartRelaxationTimer();
    }
  }

  void _restartRelaxationTimer() {
    _relaxationTimer?.cancel();
    _relaxationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // ✅ CRITICAL FIX: If paused for distance, do not decrement countdown
      if (_isTestPausedForDistance) return;

      setState(() {
        _relaxationCountdown--;
      });

      if (_relaxationCountdown == 3) {
        debugPrint('[VisualAcuity] 3s remaining in relaxation...');
      }

      if (_relaxationCountdown <= 0) {
        timer.cancel();
        _showTumblingE();
      }
    });
  }

  /// Restart the E display timer with remaining time
  void _restartEDisplayTimer() {
    if (_eDisplayCountdown <= 0) {
      // If no time left, record no response
      _recordResponse(null);
      return;
    }

    // ✅ Ensure mic is active when resuming E phase
    if (!_continuousSpeech.isActive) {
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.15,
        bufferMs: 1000,
      );
    }

    // Restart countdown timer
    _eCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) {
        timer.cancel();
        return;
      }
      setState(() {
        _eDisplayCountdown--;
      });
      if (_eDisplayCountdown <= 0) {
        timer.cancel();
      }
    });

    // Restart main display timer
    _eDisplayTimer = Timer(Duration(seconds: _eDisplayCountdown), () {
      if (_waitingForResponse && !_isTestPausedForDistance) {
        final lastValue = _continuousSpeech.getLastRecognized();
        if (lastValue != null) {
          final direction = SpeechService.parseDirection(lastValue);
          _recordResponse(direction);
        } else {
          _recordResponse(null);
        }
      }
    });
  }

  void _startEyeTest() {
    if (!mounted || _testComplete || _showE || _showRelaxation) {
      debugPrint(
        '[VisualAcuity] ⚠️ _startEyeTest IGNORED: Test already in progress',
      );
      return;
    }

    debugPrint('🔥 [VisualAcuity] _startEyeTest called for eye: $_currentEye');
    setState(() {
      _isTestPausedForDistance = false;
    });
    _ttsService.speakEyeInstruction(_currentEye);

    // Wait 4 seconds for instructions to finish, then start relaxation
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        debugPrint(
          '🔥 [VisualAcuity] Delay finished, calling _startRelaxation',
        );
        _startRelaxation();
      }
    });
  }

  void _startRelaxation() {
    debugPrint(
      '🔥 [VisualAcuity] _startRelaxation starting (Duration: ${TestConstants.relaxationDurationSeconds}s)',
    );
    // ✅ Stop mic when relaxation starts
    _continuousSpeech.stop();

    setState(() {
      _showRelaxation = true;
      _showE = false;
      _showResult = false; // ✅ Ensure result screen from prev trial is cleared
      _isTestPausedForDistance =
          false; // Reset to ensure no accidental carry-over
      _relaxationCountdown = TestConstants.relaxationDurationSeconds;
    });

    _eDisplayStartTime = null; // ✅ Reset timing guard for next E
    _ttsService.speak(TtsService.relaxationInstruction);

    _restartRelaxationTimer();
  }

  void _showTumblingE() {
    if (!mounted || (_showE && _waitingForResponse)) {
      debugPrint(
        '[VisualAcuity] ⚠️ _showTumblingE IGNORED: Already in E phase',
      );
      return;
    }

    debugPrint(
      '🔥 [VisualAcuity] _showTumblingE called (Current Level: $_currentLevel)',
    );
    // ✅ NEW: Clear ANY stale speech before rotation to prevent "leakage" from last E
    _continuousSpeech.clearAccumulated();

    // ✅ Explicitly reset display state
    _eDisplayCountdown = TestConstants.eDisplayDurationSeconds;
    _eDisplayStartTime = DateTime.now();

    // ✅ Cancel ANY existing timers for this eye/trial
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();

    _currentLevel = _currentLevel.clamp(
      0,
      TestConstants.visualAcuityLevels.length - 1,
    );

    final directions = EDirection.values
        .where((d) => d != _currentDirection && d != EDirection.blurry)
        .toList();
    final newDirection = directions[_random.nextInt(directions.length)];

    debugPrint(
      '🔥 [VisualAcuity] DIRECTION ROTATION: $_currentDirection -> $newDirection',
    );
    _currentDirection = newDirection;

    // ✅ Reset preview when NEW E starts
    _lastDetectedSpeech = null;

    setState(() {
      _showRelaxation = false;
      _showE = true;
      _showResult = false;
      _waitingForResponse = true;
      _lastDetectedSpeech = null;
      _eDisplayStartTime =
          DateTime.now(); // ✅ Re-capture precisely after setState triggers

      debugPrint(
        '🔥 [VisualAcuity] 🎯 Displaying E: Size=${TestConstants.visualAcuityLevels[_currentLevel].sizeMm}mm '
        '(Index: $_currentLevel)',
      );
    });

    // ✅ Start mic ONLY AFTER E is shown and state is updated
    _continuousSpeech.start(
      listenDuration: const Duration(minutes: 10),
      minConfidence: 0.15,
      bufferMs: 1000,
    );

    // ✅ FALLBACK: If mic isn't active at the moment E appears, force a start
    if (!_continuousSpeech.isActive) {
      debugPrint(
        '[VisualAcuity] 🎤 Fallback: Mic not active at E start, starting now',
      );
      _continuousSpeech.start(
        listenDuration: const Duration(minutes: 10),
        minConfidence: 0.15,
        bufferMs: 1000,
      );
    }

    // ✅ CRITICAL FIX: If already paused due to distance, do not start interaction timers yet
    if (_isTestPausedForDistance) {
      debugPrint(
        '[VisualAcuity] 🛑 Postponing timers: test is currently paused for distance',
      );
      return;
    }

    // Start countdown timer for display
    _eCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isTestPausedForDistance) {
        // If paused or unmounted, we don't clear the timer here as we want it to survive for resume,
        // but we stop the countdown from progressing.
        if (!mounted) timer.cancel();
        return;
      }
      setState(() {
        _eDisplayCountdown--;
      });
      if (_eDisplayCountdown <= 0) {
        timer.cancel();
      }
    });

    // Auto-advance if no response within time limit
    _eDisplayTimer = Timer(
      Duration(seconds: _eDisplayCountdown), // Use remaining countdown
      () {
        if (_waitingForResponse && !_isTestPausedForDistance) {
          // Use last recognized value if available
          final lastValue = _continuousSpeech.getLastRecognized();
          if (lastValue != null) {
            final direction = SpeechService.parseDirection(lastValue);
            _recordResponse(direction, source: 'timer_timeout_last_value');
          } else {
            _recordResponse(
              null,
              source: 'timer_timeout_no_value',
            ); // No response
          }
        }
      },
    );
  }

  void _handleVoiceResponse(String recognized) {
    debugPrint(
      '[VisualAcuity] 🔥🔥🔥 _handleVoiceResponse called with: "$recognized"',
    );

    // Only process if the E is currently displayed and we are waiting for a response
    if (!mounted || !_showE || !_waitingForResponse) {
      debugPrint(
        '[VisualAcuity] ⚠️ Not in E display phase or not waiting for response - ignoring voice input',
      );
      return;
    }

    // ✅ NEW: Strict timing guard - ignore speech that arrived too quickly after rotation
    // Results arriving within ~1500ms of rotation are likely for the PREVIOUS orientation
    if (_eDisplayStartTime != null) {
      final sinceRotation = DateTime.now().difference(_eDisplayStartTime!);
      if (sinceRotation < const Duration(milliseconds: 1500)) {
        debugPrint(
          '[VisualAcuity] ⏳ Ignoring final result: arrived too fast after rotation (${sinceRotation.inMilliseconds}ms)',
        );
        return;
      }
    }

    debugPrint('[VisualAcuity] Voice recognized: "$recognized"');

    final normalized = recognized.toLowerCase().trim();

    // Check for blurry keywords first
    final blurryKeywords = [
      'blurry',
      'blur',
      'bloody', // Common misrecognition of 'blurry'
      'cannot see',
      'can\'t see',
      'kanchi', // Common misrecognition of 'can't see'
      'cannot see clearly',
      'can\'t see clearly',
      'too blurry',
      'not clear',
      'nothing', // User can't see anything
      'country', // Common misrecognition of 'can't see'
    ];

    for (var keyword in blurryKeywords) {
      if (normalized.contains(keyword)) {
        debugPrint('[VisualAcuity] 📝 Recognized "blurry" keyword');
        _recordResponse(
          'blurry',
          source: 'voice_blurry_keyword',
        ); // Record "blurry" as the response
        return;
      }
    }

    // If not blurry, try to match a direction
    debugPrint('[VisualAcuity] 🔍 Parsing direction from: "$recognized"');
    final direction = SpeechService.parseDirection(normalized);
    debugPrint('[VisualAcuity] 📝 Parsed direction: $direction');

    if (direction != null) {
      debugPrint('[VisualAcuity] ✅ Recording direction: $direction');
      // ✅ Update preview IMMEDIATELY so user sees what was recognized
      if (mounted) setState(() => _lastDetectedSpeech = recognized);
      _recordResponse(direction, source: 'voice_final');
      return;
    } else {
      debugPrint('[VisualAcuity] ❌ Direction is NULL - not recording');
    }
  }

  void _handleButtonResponse(EDirection direction) {
    if (!_waitingForResponse) return;
    _recordResponse(direction.label.toLowerCase(), source: 'manual_button');
  }

  void _recordResponse(String? userResponse, {String source = 'unknown'}) {
    debugPrint(
      '[VisualAcuity] 📝 _recordResponse called from $source with: $userResponse',
    );
    if (!_waitingForResponse) {
      debugPrint('[VisualAcuity] ⚠️ _recordResponse IGNORED: Already recorded');
      return;
    }

    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    // ✅ Keep listening continuously - just clear buffers when E changes
    _continuousSpeech.clearAccumulated();
    // ❌ DO NOT clear _lastDetectedSpeech here - let it persist for result screen

    // ✅ HANDLE NO RESPONSE: Rotate E in SAME size and try again
    if (userResponse == null) {
      debugPrint(
        '[VisualAcuity] Timeout - Rotating E (staying at level $_currentLevel)',
      );
      // Give a tiny delay for the user to see the "I didn't hear you" state if we had one
      // But user wants it integrated, so we just rotate.
      _showTumblingE(); // Direct rotation without changing size
      return;
    }

    // Reset distance pause if we were paused but got a response
    _isTestPausedForDistance = false;

    final responseTime = _eDisplayStartTime != null
        ? DateTime.now().difference(_eDisplayStartTime!).inMilliseconds
        : 0;

    // Check if response was "blurry"
    final wasBlurry = userResponse.toLowerCase() == 'blurry';
    final isCorrect =
        !wasBlurry &&
        userResponse.toLowerCase() == _currentDirection.label.toLowerCase();

    // Create response record
    final record = EResponseRecord(
      level: _currentLevel,
      eSize: TestConstants.visualAcuityLevels[_currentLevel].flutterFontSize,
      expectedDirection: _currentDirection.label,
      userResponse: userResponse,
      isCorrect: isCorrect,
      responseTimeMs: responseTime,
      wasBlurry: wasBlurry,
    );

    _responses.add(record);
    _totalResponses++;

    // Voice confirmation feedback
    if (isCorrect) {
      _correctAtLevel++;
      _totalCorrect++;
      _ttsService.speakCorrect(userResponse);
    } else {
      _incorrectCounterAtLevel++; // NEW track incorrect specifically
      _ttsService.speakIncorrect(userResponse);
    }
    _totalAtLevel++;

    setState(() {
      _waitingForResponse = false;
      _showE = false;
      _showResult = true;
    });

    // Clear timing guard to prevent reuse
    _eDisplayStartTime = null;

    // Show result briefly - REDUCED for "instant" feel
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _evaluateAndContinue();
    });
  }

  // Helper counter for incorrect responses
  int _incorrectCounterAtLevel = 0;

  // ✅ FIXED METHOD: Test exactly 7 plates (one per level)
  void _evaluateAndContinue() {
    setState(() => _showResult = false);

    // ✅ ALWAYS move to next level after any response (correct or incorrect)
    // As per user requirement: "once i get one size once should n't ask again in the same size"
    _currentLevel++;
    _correctAtLevel = 0;
    _totalAtLevel = 0;
    _incorrectCounterAtLevel = 0;

    if (_currentLevel >= TestConstants.visualAcuityLevels.length) {
      debugPrint('✅ [VisualAcuity] Finished all levels');
      _completeEyeTest();
    } else {
      debugPrint('✅ [VisualAcuity] Moving to next level: $_currentLevel');
      _startRelaxation();
    }
  }

  void _completeEyeTest() {
    // ✅ NEW SCORING LOGIC: Find the BEST (smallest) font size correctly identified
    int bestLevelIndex = -1;
    for (var response in _responses) {
      if (response.isCorrect) {
        // Higher level index means smaller size (6/6 is index 6)
        if (bestLevelIndex == -1 || response.level > bestLevelIndex) {
          bestLevelIndex = response.level;
        }
      }
    }

    // Default to level 0 (6/60) if none were correct
    final vaLevel = bestLevelIndex != -1
        ? TestConstants.visualAcuityLevels[bestLevelIndex]
        : TestConstants.visualAcuityLevels[0];

    String status;
    if (bestLevelIndex == -1) {
      status = 'Significant reduction (Below 6/60)';
    } else if (vaLevel.logMAR <= 0.0) {
      status = 'Normal Vision';
    } else if (vaLevel.logMAR <= 0.3) {
      status = 'Mild reduction';
    } else {
      status = 'Significant reduction';
    }

    final result = VisualAcuityResult(
      eye: _currentEye,
      snellenScore: bestLevelIndex == -1 ? 'Worse than 6/60' : vaLevel.snellen,
      logMAR: vaLevel.logMAR,
      correctResponses: _totalCorrect,
      totalResponses: _totalResponses,
      durationSeconds: _responses.isNotEmpty
          ? (_responses.map((r) => r.responseTimeMs).reduce((a, b) => a + b) /
                    1000)
                .round()
          : 0,
      responses: _responses.toList(),
      status: status,
    );

    // Save result
    final provider = context.read<TestSessionProvider>();
    provider.setVisualAcuityResult(result);

    if (_currentEye == 'right') {
      // Switch to left eye
      setState(() {
        _eyeSwitchPending = true;
      });
    } else {
      // Both eyes complete - START AUTO-NAVIGATION TIMER
      setState(() {
        _testComplete = true;
        _autoNavigationCountdown = 3; // Reset countdown
      });

      // Start the auto-navigation countdown
      _startAutoNavigationTimer();
    }
  }

  void _startAutoNavigationTimer() {
    _autoNavigationTimer?.cancel();

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
        _proceedToBothEyesTest();
      }
    });
  }

  void _proceedToBothEyesTest() {
    // Stop distance monitoring before navigating
    _distanceService.stopMonitoring();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const BothEyesOpenInstructionScreen(
          title: 'Reading Test', // ✅ Changed from "Long Distance Test"
          subtitle: 'Short Distance - 40cm', // ✅ Changed from "1 Meter"
          ttsMessage:
              'Now we will test your reading vision at close distance. Keep both eyes open. Hold your device at 40 centimeters from your eyes. That is about the length from your elbow to your fingertips. Read each sentence aloud clearly and completely.', // ✅ New message for reading
          targetDistance: 40.0, // ✅ Changed from 100.0 to 40.0
          startButtonText: 'Start Reading Test', // ✅ Changed button text
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speechEraserTimer?.cancel();
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _continuousSpeech.dispose();
    _ttsService.dispose();
    _speechService.dispose();
    _distanceService.stopMonitoring();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent accidental exit
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: AppColors.testBackground,
        appBar: AppBar(
          title: Text('Visual Acuity - ${_currentEye.toUpperCase()} Eye'),
          backgroundColor: _currentEye == 'right'
              ? AppColors.rightEye.withValues(alpha: 0.1)
              : AppColors.leftEye.withValues(alpha: 0.1),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main test content
              Column(
                children: [
                  // Progress and info bar
                  _buildInfoBar(),

                  // Main content
                  Expanded(child: _buildMainContent()),

                  // Direction buttons (when showing E)
                  if (_showE && _waitingForResponse) _buildDirectionButtons(),
                ],
              ),

              // Distance indicator (bottom right corner)
              if (_useDistanceMonitoring && !_showDistanceCalibration)
                Positioned(
                  right: 12,
                  bottom: _showE && _waitingForResponse ? 120 : 12,
                  child: _buildDistanceIndicator(),
                ),

              // Recognized text (bottom center)
              if (_showE || _showRelaxation)
                Positioned(
                  bottom: _showE && _waitingForResponse ? 150 : 50,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildRecognizedTextIndicator()),
                ),
              // Distance warning overlay when explicitly paused (during E or Relaxation)
              // ✅ FIX: Don't show when exit/pause dialog is active
              if (_useDistanceMonitoring &&
                  _isTestPausedForDistance &&
                  !_isPausedForExit &&
                  (_showE || _showRelaxation))
                _buildDistanceWarningOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    final indicatorColor = DistanceHelper.getDistanceColor(
      _currentDistance,
      100.0,
      testType: 'visual_acuity',
    );
    // ✅ Show distance always (even if face lost temporarily)
    final distanceText = _currentDistance > 0
        ? '${_currentDistance.toStringAsFixed(0)}cm'
        : 'Searching...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.15),
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
    final pauseReason = DistanceHelper.getPauseReason(_distanceStatus, 100.0);
    final instruction = DistanceHelper.getDetailedInstruction(100.0);
    final rangeText = DistanceHelper.getAcceptableRangeText(100.0);

    // ✅ Icon changes based on issue
    final icon = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? Icons.face_retouching_off
        : Icons.warning_rounded;

    final iconColor = !DistanceHelper.isFaceDetected(_distanceStatus)
        ? AppColors.error
        : AppColors.warning;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
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
                pauseReason, // ✅ Dynamic title
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                instruction, // ✅ Dynamic instruction
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // ✅ Only show distance if face is detected
              if (DistanceHelper.isFaceDetected(_distanceStatus)) ...[
                Text(
                  _currentDistance > 0
                      ? 'Current: ${_currentDistance.toStringAsFixed(0)}cm'
                      : 'Searching...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  rangeText, // ✅ Dynamic range text
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
                    color: AppColors.error.withValues(alpha: 0.1),
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

              // ✅ Voice indicator (always show it's listening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SpeechWaveform(
                      isListening:
                          _continuousSpeech.shouldBeListening &&
                          !_continuousSpeech.isPausedForTts,
                      isTalking: _isSpeechActive,
                      color: AppColors.success,
                    ),
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
              const SizedBox(height: 16),

              // Skip button
              TextButton(
                onPressed: () {
                  _skipManager.recordSkip(DistanceTestType.visualAcuity);
                  setState(() {
                    _isTestPausedForDistance = false;
                  });

                  _restartEDisplayTimer();
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

  void _showExitConfirmation() {
    _showPauseDialog(reason: 'back button');
  }

  void _restartCurrentTest() {
    _eDisplayTimer?.cancel();
    _eCountdownTimer?.cancel();
    _relaxationTimer?.cancel();
    _continuousSpeech.stop();
    _distanceService.stopMonitoring();

    if (_currentEye == 'right') {
      _resetTest();
    } else {
      // Restarting left eye should take back to left eye instruction
      final provider = Provider.of<TestSessionProvider>(context, listen: false);
      provider.resetVisualAcuityLeft();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CoverRightEyeInstructionScreen(),
        ),
      );
    }
  }

  void _resetTest() {
    final provider = Provider.of<TestSessionProvider>(context, listen: false);
    provider.resetVisualAcuity();

    setState(() {
      _currentLevel = 0;
      _correctAtLevel = 0;
      _totalAtLevel = 0;
      _totalCorrect = 0;
      _totalResponses = 0;
      _responses.clear();
      _currentEye = widget.startWithLeftEye ? 'left' : 'right';
      _eyeSwitchPending = false;
      _showRelaxation = false;
      _showE = false;
      _showResult = false;
      _testComplete = false;
      _waitingForResponse = false;
      _isTestPausedForDistance = false;
      _showDistanceCalibration = true;
    });

    // ✅ FIX: Explicitly show calibration screen after state reset
    // Wait for setState to complete, then show calibration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showDistanceCalibration) {
        _showCalibrationScreen();
      }
    });
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          // Eye indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _currentEye == 'right'
                  ? AppColors.rightEye.withValues(alpha: 0.1)
                  : AppColors.leftEye.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility,
                  size: 14,
                  color: _currentEye == 'right'
                      ? AppColors.rightEye
                      : AppColors.leftEye,
                ),
                const SizedBox(width: 4),
                Text(
                  _currentEye.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _currentEye == 'right'
                        ? AppColors.rightEye
                        : AppColors.leftEye,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Level indicator (repositioned to left)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_currentEye[0].toUpperCase()}${_currentLevel + 1}/${TestConstants.visualAcuityLevels.length}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Score indicator (pill style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '$_totalCorrect/$_totalResponses',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          // Speech waveform (always visible, animates when listening)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SpeechWaveform(
                  // ✅ Indicator should be active whenever mic is INTENDED to be on
                  isListening:
                      _continuousSpeech.shouldBeListening &&
                      !_continuousSpeech.isPausedForTts,
                  isTalking: _isSpeechActive,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Icon(Icons.mic, size: 14, color: AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizedTextIndicator() {
    final bool hasRecognized =
        _lastDetectedSpeech != null && _lastDetectedSpeech!.isNotEmpty;

    if (!hasRecognized) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _lastDetectedSpeech!,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMainContent() {
    if (_testComplete) {
      return _buildTestCompleteView();
    }

    if (_eyeSwitchPending) {
      return _buildEyeSwitchView();
    }

    if (_showDistanceCalibration) {
      return _buildDistanceCalibrationView();
    }

    if (_showRelaxation) {
      return _buildRelaxationView();
    }

    if (_showE) {
      return _buildEView();
    }

    if (_showResult) {
      return _buildResultFeedback();
    }

    return const Center(child: EyeLoader(size: 60));
  }

  Widget _buildDistanceCalibrationView() {
    // This view is shown briefly while navigating to the calibration screen
    // The actual calibration happens in DistanceCalibrationScreen
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EyeLoader(size: 80),
          const SizedBox(height: 24),
          Text(
            'Opening Distance Calibration...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Relaxation image
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              AppAssets.relaxationImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primary.withValues(alpha: 0.1),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.landscape, size: 80, color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Focus on the distance...',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Countdown
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Relax and focus on the distance',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: Center(
                  child: Text(
                    '$_relaxationCountdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
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

  Widget _buildEView() {
    final level = TestConstants.visualAcuityLevels[_currentLevel];
    final eSize = level
        .flutterFontSize; // ✅ REVERTED to use fixed flutterFontSize as requested

    return Column(
      children: [
        // Timer and Size indicator row - ALWAYS VISIBLE
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.surface.withValues(alpha: 0.9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ PROMINENT Size indicator on LEFT
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      level.snellen,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Timer on RIGHT
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 20,
                    color: _eDisplayCountdown <= 1
                        ? AppColors.error
                        : _isTestPausedForDistance
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTestPausedForDistance
                        ? 'PAUSED'
                        : '${_eDisplayCountdown}s',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _eDisplayCountdown <= 1
                          ? AppColors.error
                          : _isTestPausedForDistance
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Main E display area
        Expanded(
          child: Center(
            child: Transform.rotate(
              angle: _currentDirection.rotationDegrees * pi / 180,
              // ✅ FIX: Force antialiasing and proper rendering
              filterQuality: FilterQuality.high,
              child: Text(
                'E',
                style: TextStyle(
                  fontSize: eSize,
                  fontWeight: FontWeight.bold, // Maximum boldness

                  color: Colors.black,
                  letterSpacing: 0,
                  height: 1.0,
                ),
                // ✅ Add text scaling to ensure crisp rendering
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),

        // Instruction text with voice status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isListening)
                    Icon(
                      Icons.mic,
                      size: 20,
                      color: _isTestPausedForDistance
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  if (_isListening) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _isTestPausedForDistance
                          ? 'Test paused - Adjust distance'
                          : 'Which way is the E pointing?',
                      style: TextStyle(
                        color: _isTestPausedForDistance
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: _isTestPausedForDistance
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isTestPausedForDistance
                    ? 'Voice recognition active - waiting to resume'
                    : 'Use buttons or say: Upper or Upward, Down or Downward, Left, Right',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up button
          _DirectionButton(
            direction: EDirection.up,
            onPressed: () => _handleButtonResponse(EDirection.up),
          ),
          const SizedBox(height: 12),
          // Left, Right buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DirectionButton(
                direction: EDirection.left,
                onPressed: () => _handleButtonResponse(EDirection.left),
              ),
              const SizedBox(width: 60),
              _DirectionButton(
                direction: EDirection.right,
                onPressed: () => _handleButtonResponse(EDirection.right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Down button
          _DirectionButton(
            direction: EDirection.down,
            onPressed: () => _handleButtonResponse(EDirection.down),
          ),
          const SizedBox(height: 20),
          // Blurry/Can't See Clearly button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleButtonResponse(EDirection.blurry),
              icon: const Icon(Icons.visibility_off, size: 20),
              label: const Text(
                "Can't See Clearly / Blurry",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: BorderSide(color: AppColors.warning, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultFeedback() {
    final lastResponse = _responses.isNotEmpty ? _responses.last : null;
    final isCorrect = lastResponse?.isCorrect ?? false;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 100,
            color: isCorrect ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? 'Correct!' : 'Incorrect',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isCorrect ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeSwitchView() {
    // Navigate to instruction screen - only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_eyeSwitchPending && mounted) {
        // ✅ FIX: Stop monitoring before showing cover eye instruction
        _distanceService.stopMonitoring();

        // Mark as handled immediately
        setState(() {
          _eyeSwitchPending = false;
        });

        // Navigate to instruction screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CoverRightEyeInstructionScreen(),
          ),
        );
      }
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EyeLoader(size: 45),
          const SizedBox(height: 24),
          Text(
            'Preparing left eye test...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCompleteView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          Text(
            'Visual Acuity Test Complete!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Summary cards
          _buildSummaryCard(
            'Right Eye',
            context
                    .read<TestSessionProvider>()
                    .visualAcuityRight
                    ?.snellenScore ??
                'N/A',
            AppColors.rightEye,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Left Eye',
            context
                    .read<TestSessionProvider>()
                    .visualAcuityLeft
                    ?.snellenScore ??
                'N/A',
            AppColors.leftEye,
          ),
          const SizedBox(height: 32),

          // Auto-continue countdown indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: Center(
                    child: Text(
                      '$_autoNavigationCountdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Continuing in $_autoNavigationCountdown...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Continue button (now can be clicked immediately or wait for auto)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _autoNavigationTimer?.cancel();
                _proceedToBothEyesTest();
              },
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Continue Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String eye, String score, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility, color: color),
          const SizedBox(width: 12),
          Text(
            eye,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              score,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final EDirection direction;
  final VoidCallback onPressed;

  const _DirectionButton({required this.direction, required this.onPressed});

  IconData get _icon {
    switch (direction) {
      case EDirection.up:
        return Icons.arrow_upward;
      case EDirection.down:
        return Icons.arrow_downward;
      case EDirection.left:
        return Icons.arrow_back;
      case EDirection.right:
        return Icons.arrow_forward;
      case EDirection.blurry:
        return Icons.visibility_off; // Can't see clearly icon
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 70,
          height: 70,
          child: Icon(_icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

// ✅ NEW Waveform animation for microphone
class _SpeechWaveform extends StatefulWidget {
  final bool isListening;
  final bool isTalking;
  final Color color;

  const _SpeechWaveform({
    required this.isListening,
    required this.isTalking,
    required this.color,
  });

  @override
  State<_SpeechWaveform> createState() => _SpeechWaveformState();
}

class _SpeechWaveformState extends State<_SpeechWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Animate when either listening OR actively talking
    final shouldAnimate = widget.isListening || widget.isTalking;

    if (!shouldAnimate) {
      // Static bars when not active
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Container(
            width: 3,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Create wave effect with different phases
            final phase = (index * 0.3) + _controller.value;
            final height = 4.0 + (10.0 * (0.5 + 0.5 * sin(phase * 2 * pi)));

            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
