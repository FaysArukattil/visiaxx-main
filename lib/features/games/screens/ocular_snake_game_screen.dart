import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/game_provider.dart';

enum Direction { up, down, left, right }

class OcularSnakeGameScreen extends StatefulWidget {
  const OcularSnakeGameScreen({super.key});

  @override
  State<OcularSnakeGameScreen> createState() => _OcularSnakeGameScreenState();
}

class _OcularSnakeGameScreenState extends State<OcularSnakeGameScreen> {
  // Game Configuration
  static const int _gridSize = 20;
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
    _startNewLevel();
  }

  void _startNewLevel() {
    _targetWord = _words[Random().nextInt(_words.length)].toUpperCase();
    _letterIndex = 0;
    _spawnLetter();
  }

  void _spawnLetter() {
    _currentLetter = _targetWord[_letterIndex];
    final random = Random();
    Point<int> newFood;
    do {
      newFood = Point(random.nextInt(_gridSize), random.nextInt(_gridSize));
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
          newHead.x >= _gridSize ||
          newHead.y < 0 ||
          newHead.y >= _gridSize ||
          _snake.contains(newHead)) {
        _endGame();
        return;
      }

      _snake.insert(0, newHead);

      // Check if food eaten
      if (newHead == _food) {
        _score += 10;
        _letterIndex++;
        if (_letterIndex >= _targetWord.length) {
          _score += 50; // Bonus for completion
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
    _saveProgress();
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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMainLayer()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'MISSION TARGET',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _targetWord.split('').asMap().entries.map((e) {
                    final isCleared = e.key < _letterIndex;
                    return AnimatedContainer(
                      duration: 300.ms,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCleared
                            ? Colors.greenAccent.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCleared
                              ? Colors.greenAccent
                              : Colors.white10,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: isCleared
                              ? Colors.greenAccent
                              : Colors.white38,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const Text(
                  'XP',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$_score',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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
          } else if (_swipeDelta.dy < 0 && _direction != Direction.down) {
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundGrid(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      _buildGrid(),
                      if (!_isPlaying && !_isGameOver) _buildStartOverlay(),
                      if (_isGameOver) _buildGameOverOverlay(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildHelpOverlay(),
        ],
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
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
    return Container(decoration: const BoxDecoration(color: Color(0xFF0F1115)));
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellSize = constraints.maxWidth / _gridSize;
        return Stack(
          children: [
            // Solid Grid Lines
            ...List.generate(
              _gridSize,
              (i) => Positioned(
                left: i * cellSize,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            ...List.generate(
              _gridSize,
              (i) => Positioned(
                top: i * cellSize,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Letter / Food
            if (_food != null)
              Positioned(
                left: _food!.x * cellSize,
                top: _food!.y * cellSize,
                child: Container(
                  width: cellSize,
                  height: cellSize,
                  alignment: Alignment.center,
                  child:
                      Container(
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.8),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Center(
                              child: Text(
                                _currentLetter,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: cellSize * 0.6,
                                ),
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.15, 1.15),
                            duration: 400.ms,
                            curve: Curves.easeInOut,
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
                      color: isHead ? Colors.white : Colors.greenAccent,
                      borderRadius: BorderRadius.circular(isHead ? 8 : 4),
                      boxShadow: [
                        BoxShadow(
                          color: (isHead ? Colors.white : Colors.greenAccent)
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
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
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
      },
    );
  }

  Widget _buildStartOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withValues(alpha: 0.1),
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    blurRadius: 40,
                  ),
                ],
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                color: Colors.greenAccent,
                size: 72,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
            const SizedBox(height: 32),
            const Text(
              'OCULAR SNAKE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                shadows: [Shadow(color: Colors.greenAccent, blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'HIGH-VELOCITY SWIPE SENSOR',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 56),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 64,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'INITIALIZE SYSTEM',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.1),
                border: Border.all(color: Colors.redAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 50,
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 80,
              ),
            ).animate(onPlay: (c) => c.repeat()).shake(duration: 2.seconds),
            const SizedBox(height: 32),
            const Text(
              'MISSION COMPROMISED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'FINAL SCORE: $_score',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 56),
            ElevatedButton(
              onPressed: () {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 64,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'RE-BOOT MISSION',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'TERMINATE SESSION',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms),
      ),
    );
  }
}
