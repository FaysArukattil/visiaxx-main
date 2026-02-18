import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/providers/game_provider.dart';
import '../../../core/services/audio_service.dart';
import '../widgets/game_menus.dart';
import '../../../core/extensions/theme_extension.dart';

enum Direction { up, down, left, right }

class OcularSnakeGameScreen extends StatefulWidget {
  const OcularSnakeGameScreen({super.key});

  @override
  State<OcularSnakeGameScreen> createState() => _OcularSnakeGameScreenState();
}

class _OcularSnakeGameScreenState extends State<OcularSnakeGameScreen>
    with WidgetsBindingObserver {
  // Game Configuration
  static const int _gridSizeX = 20;
  int _gridSizeY = 20;
  static const Duration _baseSpeed = Duration(milliseconds: 140);

  // Input Handling
  Offset _swipeDelta = Offset.zero;
  bool _directionChangedThisTick = false;

  // Game State
  List<Point<int>> _snake = [
    const Point(10, 10),
    const Point(10, 11),
    const Point(10, 12),
  ];
  Direction _direction = Direction.up;
  Point<int>? _food;
  String _currentLetter = '';
  String _targetWord = '';
  int _letterIndex = 0;
  int _score = 0;
  bool _isGameOver = false;
  bool _isPlaying = false;
  bool _hasGameStarted = false; // For persistent game background
  Timer? _timer;

  final List<String> _words = [
    'IRIS',
    'LENS',
    'OPTIC',
    'RETINA',
    'CORNEA',
    'PUPIL',
    'SCLERA',
    'MACULA',
    'FOVEA',
    'VISION',
    'ASTIG',
    'MYOPIA',
    'PHEME',
    'CRYST',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _startNewLevel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseGame();
    }
  }

  void _startNewLevel() {
    _targetWord = _words[Random().nextInt(_words.length)].toUpperCase();
    _letterIndex = 0;
    _spawnLetter();
  }

  void _pauseGame() {
    if (!_isPlaying || _isGameOver) return;
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GamePauseDialog(
        gameTitle: 'Ocular Snake',
        onResume: () {
          Navigator.pop(context);
          setState(() {
            _isPlaying = true;
          });
          _timer = Timer.periodic(_baseSpeed, (timer) => _moveSnake());
        },
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            _snake = [
              const Point(10, 10),
              const Point(10, 11),
              const Point(10, 12),
            ];
            _direction = Direction.up;
            _score = 0;
            _isGameOver = false;
            _startNewLevel();
          });
          _startGame();
        },
        onExit: () {
          Navigator.pop(context); // Close dialog
          if (mounted) Navigator.pop(context); // Exit game
        },
      ),
    );
  }

  void _spawnLetter() {
    _currentLetter = _targetWord[_letterIndex];
    final random = Random();
    Point<int> newFood;
    do {
      newFood = Point(random.nextInt(_gridSizeX), random.nextInt(_gridSizeY));
    } while (_snake.contains(newFood));

    setState(() {
      _food = newFood;
    });
  }

  void _startGame() {
    if (_isPlaying) return;
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _hasGameStarted = true;
    });
    _timer = Timer.periodic(_baseSpeed, (timer) => _moveSnake());
  }

  void _moveSnake() {
    setState(() {
      final head = _snake.first;
      Point<int> newHead;

      switch (_direction) {
        case Direction.up:
          newHead = Point(head.x, head.y - 1);
          break;
        case Direction.down:
          newHead = Point(head.x, head.y + 1);
          break;
        case Direction.left:
          newHead = Point(head.x - 1, head.y);
          break;
        case Direction.right:
          newHead = Point(head.x + 1, head.y);
          break;
      }

      // Check collisions
      if (newHead.x < 0 ||
          newHead.x >= _gridSizeX ||
          newHead.y < 0 ||
          newHead.y >= _gridSizeY ||
          _snake.contains(newHead)) {
        _endGame();
        return;
      }

      _snake.insert(0, newHead);

      // Check if food eaten
      if (newHead == _food) {
        AudioService().playSnakeEat(); // Snake eating
        _score += 10;
        _letterIndex++;
        if (_letterIndex >= _targetWord.length) {
          _score += 50; // Bonus for completion
          AudioService().playSnakeLevelUp(); // Level complete
          _startNewLevel();
        } else {
          _spawnLetter();
        }
      } else {
        _snake.removeLast();
      }
    });
    _directionChangedThisTick = false;
  }

  void _endGame() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
    AudioService().playSnakeGameOver(); // Synced game over sound
    _saveProgress();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dc) => GameOverDialog(
        gameTitle: 'Ocular Snake',
        score: _score,
        onRestart: () {
          Navigator.pop(dc);
          setState(() {
            _snake = [
              const Point(10, 10),
              const Point(10, 11),
              const Point(10, 12),
            ];
            _direction = Direction.up;
            _score = 0;
            _isGameOver = false;
            _startNewLevel();
          });
          _startGame();
        },
        onExit: () {
          Navigator.pop(dc);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final provider = context.read<GameProvider>();
      final currentProgress = provider.getProgress('ocular_snake');

      final newLevel = (_score / 100).floor() + 1;

      if (_score > (currentProgress?.totalScore ?? 0)) {
        await provider.clearLevel(
          user.uid,
          'ocular_snake',
          newLevel,
          _score,
          userName: user.displayName ?? 'Player',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isPlaying) {
          _pauseGame();
        } else if (_isGameOver || !_hasGameStarted) {
          Navigator.pop(context);
        }
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        body: Stack(
          children: [
            // Game Layer (Always visible once started)
            if (_hasGameStarted)
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildMainLayer()),
                  ],
                ),
              ),

            // Intro Screen (Before game starts)
            if (!_hasGameStarted) _buildPremiumIntro(),

            // Pause Overlay (Blur/Dim)
            if (!_isPlaying && _hasGameStarted && !_isGameOver)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.scaffoldBackground,
        border: Border(
          bottom: BorderSide(
            color: context.dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OCULAR SNAKE',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: _targetWord.split('').asMap().entries.map((e) {
                      final isCleared = e.key < _letterIndex;
                      return AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCleared
                              ? Colors.greenAccent.withValues(alpha: 0.1)
                              : context.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCleared
                                ? Colors.greenAccent
                                : context.dividerColor.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            color: isCleared
                                ? Colors.greenAccent
                                : context.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildXPBadge(),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              Icons.pause_circle_filled_rounded,
              color: context.textPrimary,
              size: 32,
            ),
            onPressed: _pauseGame,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildXPBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade700, Colors.amber.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            '$_score XP',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLayer() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _swipeDelta = Offset.zero,
      onPanUpdate: (details) {
        if (!_isPlaying && !_isGameOver) return;
        if (_directionChangedThisTick) return;

        _swipeDelta += details.delta;

        // Threshold of 20 pixels for instant turn
        if (_swipeDelta.distance < 20) return;

        Direction? newDir;
        if (_swipeDelta.dx.abs() > _swipeDelta.dy.abs()) {
          if (_swipeDelta.dx > 0 && _direction != Direction.left) {
            newDir = Direction.right;
          } else if (_swipeDelta.dx < 0 && _direction != Direction.right) {
            newDir = Direction.left;
          }
        } else {
          if (_swipeDelta.dy > 0 && _direction != Direction.up) {
            newDir = Direction.down;
          } else if (_swipeDelta.dy < 0 && _direction != Direction.up) {
            newDir = Direction.up;
          }
        }

        if (newDir != null && newDir != _direction) {
          setState(() {
            _direction = newDir!;
            _directionChangedThisTick = true;
            _swipeDelta = Offset.zero;
          });
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cellSize = constraints.maxWidth / _gridSizeX;
          final int calculatedY = (constraints.maxHeight / cellSize).floor();
          if (_gridSizeY != calculatedY && calculatedY > 0) {
            Future.microtask(() {
              if (mounted) setState(() => _gridSizeY = calculatedY);
            });
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildBackgroundGrid(),
              ClipRect(child: _buildGrid(cellSize)),
              _buildHelpOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHelpOverlay() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.dividerColor.withValues(alpha: 0.05),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swipe_rounded, color: Colors.greenAccent, size: 18),
              SizedBox(width: 10),
              Text(
                'INSTANT SWIPE ENABLED',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGrid() {
    return Container(
      decoration: BoxDecoration(color: context.scaffoldBackground),
    );
  }

  Widget _buildGrid(double cellSize) {
    return Stack(
      children: [
        // Grid Lines
        ...List.generate(
          _gridSizeX + 1,
          (i) => Positioned(
            left: i * cellSize,
            top: 0,
            bottom: 0,
            child: Container(
              width: 1,
              color: context.dividerColor.withValues(alpha: 0.15),
            ),
          ),
        ),
        ...List.generate(
          _gridSizeY + 1,
          (i) => Positioned(
            top: i * cellSize,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: context.dividerColor.withValues(alpha: 0.15),
            ),
          ),
        ),

        // Pulsing Grid Center for focus (Eye Health)
        Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(150, 150),
              duration: 4.seconds,
              curve: Curves.easeOutQuart,
            )
            .fadeOut(duration: 4.seconds),

        // Letter / Food
        if (_food != null)
          Positioned(
            left: _food!.x * cellSize,
            top: _food!.y * cellSize,
            width: cellSize,
            height: cellSize,
            child: OverflowBox(
              maxWidth: cellSize * 4,
              maxHeight: cellSize * 4,
              child:
                  Text(
                        _currentLetter,
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w900,
                          fontSize: cellSize * 1.8,
                          shadows: [
                            Shadow(
                              color: Colors.amber.withValues(alpha: 0.9),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.15, 1.15),
                        duration: 500.ms,
                        curve: Curves.easeInOut,
                      )
                      .shimmer(
                        delay: 400.ms,
                        duration: 2.seconds,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
            ),
          ),
        // Snake
        ..._snake.asMap().entries.map((e) {
          final idx = e.key;
          final p = e.value;
          final isHead = idx == 0;

          return Positioned(
            key: ValueKey('snake_$idx'),
            left: p.x * cellSize,
            top: p.y * cellSize,
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Container(
                width: cellSize - 2,
                height: cellSize - 2,
                decoration: BoxDecoration(
                  color: isHead ? context.primary : Colors.greenAccent,
                  borderRadius: BorderRadius.circular(isHead ? 8 : 4),
                  boxShadow: [
                    BoxShadow(
                      color: (isHead ? context.primary : Colors.greenAccent)
                          .withValues(alpha: 0.6),
                      blurRadius: isHead ? 15 : 6,
                      spreadRadius: isHead ? 1 : 0,
                    ),
                  ],
                ),
                child: isHead
                    ? Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.isDarkMode
                                    ? Colors.black
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.isDarkMode
                                    ? Colors.black
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPremiumIntro() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.scaffoldBackground,
            context.scaffoldBackground.withValues(alpha: 0.95),
            context.scaffoldBackground.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Shimmering Icon
                      Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.primary.withValues(alpha: 0.1),
                              border: Border.all(
                                color: context.primary,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.primary.withValues(alpha: 0.3),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.flash_on_rounded,
                              color: context.primary,
                              size: 56,
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(duration: 2.seconds)
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 24),
                      Text(
                        'OCULAR SNAKE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          shadows: [
                            Shadow(color: context.primary, blurRadius: 15),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: 4),
                      Text(
                        'Precision Navigation Mission',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 16),
                      Text(
                        'Hunt for letters to build medical terms while navigating at high speed. Sharpen your visual search and saccadic accuracy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 24),
                      // Benefits Section
                      _buildPremiumBenefit(
                        Icons.center_focus_strong_rounded,
                        'Saccadic Accuracy',
                        'Precision target-to-target leaps.',
                      ),
                      _buildPremiumBenefit(
                        Icons.spellcheck_rounded,
                        'Lexical Recognition',
                        'Identify words while navigating.',
                      ),
                      _buildPremiumBenefit(
                        Icons.grid_4x4_rounded,
                        'Spatial Awareness',
                        'Manage flow in confined spaces.',
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primary,
                            foregroundColor: context.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 12,
                          ),
                          child: const Text(
                            'INITIALIZE MISSION',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Return to Games',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildPremiumBenefit(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: context.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
