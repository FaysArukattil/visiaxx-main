import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/eye_hydration_result.dart';

class EyeHydrationProvider extends ChangeNotifier {
  // NEW APPROACH: Detect the DIP in eye openness, not absolute values
  // A blink is a RAPID decrease followed by RAPID increase

  static const double SIGNIFICANT_DROP = 0.25; // Drop of 25% indicates closing
  static const double SIGNIFICANT_RISE = 0.20; // Rise of 20% indicates opening
  static const int MIN_BETWEEN_BLINKS_MS = 150;
  static const double MIN_BASELINE = 0.5; // Minimum "normal" eye openness

  // Broadcast stream for blink events
  final _blinkStreamController = StreamController<void>.broadcast();
  Stream<void> get blinkStream => _blinkStreamController.stream;

  bool _isTestRunning = false;
  int _blinkCount = 0;
  DateTime? _testStartTime;
  EyeHydrationResult? _finalResult;
  double _screenBrightness = 0.5;

  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isProcessing = false;
  bool _faceDetected = false;

  // Tracking for blink detection
  double _previousProb = 1.0;
  double _baselineProb = 1.0; // Running average of "normal" open state
  bool _inPotentialBlink = false;
  double _lowestProbInBlink = 1.0;
  DateTime? _lastBlinkTime;

  // Eye probability tracking
  double _currentLeftProb = 1.0;
  double _currentRightProb = 1.0;
  double _displayProb = 1.0;

  // Getters
  bool get isTestRunning => _isTestRunning;
  int get blinkCount => _blinkCount;
  bool get faceDetected => _faceDetected;
  double get leftEyeOpenProbability => _currentLeftProb;
  double get rightEyeOpenProbability => _currentRightProb;
  double get currentBlinkProbability => _displayProb;
  EyeHydrationResult? get finalResult => _finalResult;

  set screenBrightness(double value) {
    _screenBrightness = value;
    notifyListeners();
  }

  String _selectedTopic = 'Digital World';
  String get selectedTopic => _selectedTopic;

  void setTopic(String topic) {
    _selectedTopic = topic;
    notifyListeners();
  }

  static const Map<String, List<String>> _topicContent = {
    'Digital World': [
      "The Wonders of Our Digital World",
      "Technology has changed the way we live and work. We use our smartphones and computers for almost everything. While these tools make our life easier, it is important to take care of our eyes.",
      "When we look at screens for a long time, we often forget to blink. This can make our eyes feel tired or dry. Taking small breaks every twenty minutes is a great way to stay fresh.",
      "Spending time outdoors and looking at distant objects also helps. Natural light is good for our overall health. Balance is the key to enjoying all the benefits of the digital age.",
      "Remember to stay hydrated and get enough sleep. Tiny habits like these make a big difference in how we feel. Your eyes are precious, so give them the rest they deserve today.",
    ],
    'Zero to One': [
      "Zero to One: Notes on Startups",
      "Every moment in business happens only once. The next Bill Gates will not build an operating system. The next Larry Page or Sergey Brin won't make a search engine. And the next Mark Zuckerberg won't create a social network. If you are copying these guys, you aren't learning from them.",
      "Of course, it's easier to copy a model than to make something new. Doing what we already know how to do takes the world from 1 to n, adding more of something familiar. But every time we create something new, we go from 0 to 1.",
      "The act of creation is singular, as is the moment of creation, and the result is something fresh and strange. Successful people find value in unexpected places, and they do this by thinking about business from first principles instead of formulas.",
      "Tomorrow's champions will not win by competing ruthlessly in today's marketplace. They will escape competition altogether, because their businesses will be unique.",
    ],
    'Talk to Anyone': [
      "How to Talk to Anyone",
      "Don't flash an immediate smile when you greet someone, as though anyone who walked into your line of sight would be the beneficiary. Instead, look at the other person's face for a second. Pause. Soak in their persona.",
      "Then let a big, warm, responsive smile flood over your face and overflow into your eyes. It will engulf the recipient like a warm wave. The split-second delay convinces people your flooding smile is genuine and only for them.",
      "Your eyes are personal grenades that can blast through the toughest of barriers. When you're talking to someone, don't look away the second they stop talking. Maintain eye contact even during the silences.",
      "Technique number two is 'Sticky Eyes'. Pretend your eyes are glued to your conversation partner with sticky warm taffy. Don't break eye contact even after he or she has finished speaking.",
    ],
    'Influence Others': [
      "How to Win Friends and Influence People",
      "You can make more friends in two months by becoming interested in other people than you can in two years by trying to get other people interested in you. This is one of the most important secrets of success.",
      "If you want to be a good conversationalist, be an attentive listener. To be interesting, be interested. Ask questions that other persons will enjoy answering. Encourage them to talk about themselves and their accomplishments.",
      "The royal road to a person's heart is to talk about the things he or she treasures most. Whenever you go out-of-doors, draw the chin in, carry the crown of the head high, and fill the lungs to the utmost.",
      "Smile! Happiness doesn't depend on outward conditions. It depends on inner conditions. It isn't what you have or who you are or where you are or what you are doing that makes you happy or unhappy. It is what you think about it.",
    ],
    'Think & Grow Rich': [
      "Think and Grow Rich: Napoleon Hill",
      "All achievement, all earned riches, have their beginning in an idea! The starting point of all achievement is DESIRE. Keep this constantly in mind. Weak desire brings weak results, just as a small fire makes a small amount of heat.",
      "You are the master of your destiny. You can influence, direct and control your own environment. You can make your life what you want it to be.",
      "Our only limitations are those we set up in our own minds. If you do not see great riches in your imagination, you will never see them in your bank balance.",
      "Every adversity, every failure, every heartbreak, carries with it the seed of an equal or greater benefit. Success comes to those who become success conscious.",
    ],
    'Lean Startup': [
      "The Lean Startup: Eric Ries",
      "Most startups fail. But those failures are preventable. The Lean Startup is a new approach being adopted across the globe, changing the way companies are built and new products are launched.",
      "We must learn what customers really want, not what they say they want or what we think they should want. Success is not delivering a feature; success is learning how to solve the customer's problem.",
      "The only way to win is to learn faster than anyone else. If you cannot fail, you cannot learn. The goal of a startup is to figure out the right thing to build as quickly as possible.",
      "A pivot is a structured course correction designed to test a new fundamental hypothesis about the product, strategy, and engine of growth.",
    ],
    'Biz Adventures': [
      "Business Adventures: John Brooks",
      "The 1960s were a time of rapid change and excitement in the business world, and John Brooks captures this era perfectly. His stories about the Ford Edsel and Xerox are classics.",
      "A brand is a set of expectations, memories, stories and relationships that, taken together, account for a consumer's decision to choose one product or service over another.",
      "The main difference between a success and a failure is the ability to adapt to changing circumstances. A business must be willing to change its strategy if it wants to survive.",
      "Innovation is the key to success in any industry. Companies that fail to innovate will eventually be left behind by their competitors.",
    ],
    'Intelligent Investor': [
      "The Intelligent Investor: Benjamin Graham",
      "The intelligent investor is a realist who sells to optimists and buys from pessimists. Investing is most intelligent when it is most businesslike.",
      "In the short run, the market is a voting machine but in the long run, it is a weighing machine. The margin of safety is the most important concept in value investing.",
      "Successful investing is about managing risk, not avoiding it. An investor should always have a clear understanding of the difference between the price and value.",
      "The stock market is filled with individuals who know the price of everything, but the value of nothing. Patience is a virtue in the world of finance.",
    ],
  };

  List<String> get readingContent =>
      _topicContent[_selectedTopic] ?? _topicContent['Digital World']!;

  List<String> get availableTopics => _topicContent.keys.toList();

  Future<void> startTest(CameraController controller) async {
    _cameraController = controller;
    _isTestRunning = true;
    _blinkCount = 0;
    _testStartTime = DateTime.now();
    _finalResult = null;
    _inPotentialBlink = false;
    _previousProb = 1.0;
    _baselineProb = 1.0;
    _lowestProbInBlink = 1.0;
    _lastBlinkTime = null;
    _isProcessing = false;

    _startImageStream();
    notifyListeners();
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final faces = await _processImage(image);
        if (faces.isNotEmpty) {
          if (!_faceDetected) {
            debugPrint('🙂 Face detected');
            _faceDetected = true;
          }
          _analyzeFace(faces.first);
        } else {
          if (_faceDetected) {
            debugPrint('❓ Face lost');
            _faceDetected = false;
            _inPotentialBlink = false;
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Error processing image: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<List<Face>> _processImage(CameraImage image) async {
    final format = _getInputImageFormat(image.format.group);

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _getImageRotation(),
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
    return await _faceDetector.processImage(inputImage);
  }

  InputImageRotation _getImageRotation() {
    final orientation = _cameraController!.description.sensorOrientation;
    switch (orientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat _getInputImageFormat(ImageFormatGroup format) {
    if (Platform.isAndroid) {
      return InputImageFormat.nv21;
    } else if (Platform.isIOS) {
      return InputImageFormat.bgra8888;
    }
    return InputImageFormat.nv21;
  }

  void _analyzeFace(Face face) {
    _currentLeftProb = face.leftEyeOpenProbability ?? 1.0;
    _currentRightProb = face.rightEyeOpenProbability ?? 1.0;

    // Use average of both eyes
    double currentProb = (_currentLeftProb + _currentRightProb) / 2.0;

    // Update display probability with light smoothing for UI
    _displayProb = (0.5 * currentProb) + (0.5 * _displayProb);

    // Calculate change from previous frame
    double change = currentProb - _previousProb;

    DateTime now = DateTime.now();

    if (!_inPotentialBlink) {
      // NOT in a blink - looking for a significant DROP

      // Update baseline when eyes are relatively stable and open
      if (currentProb >= MIN_BASELINE && change.abs() < 0.1) {
        _baselineProb = (0.9 * _baselineProb) + (0.1 * currentProb);
      }

      // Detect significant drop from baseline
      double dropFromBaseline = _baselineProb - currentProb;

      if (dropFromBaseline > SIGNIFICANT_DROP) {
        // Potential blink started!
        _inPotentialBlink = true;
        _lowestProbInBlink = currentProb;
        debugPrint(
          '👁️ Blink START detected (baseline: ${_baselineProb.toStringAsFixed(2)}, current: ${currentProb.toStringAsFixed(2)}, drop: ${dropFromBaseline.toStringAsFixed(2)})',
        );
      }
    } else {
      // IN a potential blink - looking for a significant RISE

      // Track the lowest point
      if (currentProb < _lowestProbInBlink) {
        _lowestProbInBlink = currentProb;
      }

      // Detect significant rise from lowest point
      double riseFromLowest = currentProb - _lowestProbInBlink;

      if (riseFromLowest > SIGNIFICANT_RISE) {
        // Blink completed!

        // Check debounce
        bool validBlink = true;
        if (_lastBlinkTime != null) {
          final timeSinceLastBlink = now
              .difference(_lastBlinkTime!)
              .inMilliseconds;
          if (timeSinceLastBlink < MIN_BETWEEN_BLINKS_MS) {
            validBlink = false;
            debugPrint(
              '👁️ Blink too soon - ignored (${timeSinceLastBlink}ms)',
            );
          }
        }

        if (validBlink) {
          _blinkCount++;
          _lastBlinkTime = now;

          // Trigger animation
          _blinkStreamController.add(null);

          debugPrint(
            '✅ BLINK #$_blinkCount COMPLETE (lowest: ${_lowestProbInBlink.toStringAsFixed(2)}, current: ${currentProb.toStringAsFixed(2)}, rise: ${riseFromLowest.toStringAsFixed(2)})',
          );
        }

        _inPotentialBlink = false;
        _lowestProbInBlink = 1.0;
      }

      // Safety: If eye probability goes back to near baseline without completing blink, reset
      if (currentProb >= (_baselineProb - 0.1) && change > 0) {
        double totalDrop = _baselineProb - _lowestProbInBlink;
        if (totalDrop < 0.15) {
          // Wasn't a real blink, just noise
          debugPrint(
            '👁️ False blink - reset (total drop was only ${totalDrop.toStringAsFixed(2)})',
          );
          _inPotentialBlink = false;
          _lowestProbInBlink = 1.0;
        }
      }
    }

    _previousProb = currentProb;
    notifyListeners();
  }

  Future<void> stopTest() async {
    if (!_isTestRunning) return;

    _isTestRunning = false;
    await _cameraController?.stopImageStream();

    final testDuration = DateTime.now().difference(_testStartTime!);
    _finalResult = EyeHydrationResult.analyze(
      blinkCount: _blinkCount,
      duration: testDuration,
      screenBrightness: _screenBrightness,
    );

    debugPrint(
      '🏁 Test stopped - Total blinks: $_blinkCount, Duration: ${testDuration.inSeconds}s',
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _blinkStreamController.close();
    _faceDetector.close();
    super.dispose();
  }
}
