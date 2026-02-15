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
  static const Duration _baseSpeed = Duration(milliseconds: 150);

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

  // Joystick State
  Offset _joystickPos = Offset.zero;

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

      // Calculate level based on score (100 pts per level)
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildGameBoard()),
            _buildJoystick(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                'TARGET WORD',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: _targetWord.split('').asMap().entries.map((e) {
                  final isCleared = e.key < _letterIndex;
                  return Text(
                    e.value,
                    style: TextStyle(
                      color: isCleared ? Colors.green : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                'SCORE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_score',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (_direction != Direction.up && details.delta.dy > 5) {
          _direction = Direction.down;
        } else if (_direction != Direction.down && details.delta.dy < -5) {
          _direction = Direction.up;
        }
      },
      onHorizontalDragUpdate: (details) {
        if (_direction != Direction.left && details.delta.dx > 5) {
          _direction = Direction.right;
        } else if (_direction != Direction.right && details.delta.dx < -5) {
          _direction = Direction.left;
        }
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            children: [
              _buildGrid(),
              if (!_isPlaying && !_isGameOver) _buildStartOverlay(),
              if (_isGameOver) _buildGameOverOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellSize = constraints.maxWidth / _gridSize;
        return Stack(
          children: [
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
                      Text(
                            _currentLetter,
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: cellSize * 0.7,
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.2, 1.2),
                            duration: 500.ms,
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
                left: p.x * cellSize,
                top: p.y * cellSize,
                child: Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: isHead
                        ? context.primary
                        : context.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(isHead ? 6 : 4),
                    boxShadow: isHead
                        ? [
                            BoxShadow(
                              color: context.primary.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ]
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_rounded, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'SWIPE TO START',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'START GAME',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied_rounded,
              color: Colors.redAccent,
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Final Score: $_score',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
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
                backgroundColor: context.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoystick() {
    return Container(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CONTROL TRACKPAD',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onPanUpdate: (details) {
              if (!_isPlaying && !_isGameOver) return;

              // Center is 75,75 for a 150x150 container
              final center = const Offset(75, 75);
              final rawOffset = details.localPosition - center;

              // Constrain ball movement to a radius of 35
              final distance = rawOffset.distance;
              final limitedOffset = distance > 35
                  ? rawOffset * (35 / distance)
                  : rawOffset;

              setState(() {
                _joystickPos = limitedOffset;
              });

              // Significant movement required to change direction (threshold 10)
              if (limitedOffset.dx.abs() > limitedOffset.dy.abs()) {
                if (limitedOffset.dx > 10 && _direction != Direction.left) {
                  _direction = Direction.right;
                } else if (limitedOffset.dx < -10 &&
                    _direction != Direction.right) {
                  _direction = Direction.left;
                }
              } else {
                if (limitedOffset.dy > 10 && _direction != Direction.up) {
                  _direction = Direction.down;
                } else if (limitedOffset.dy < -10 &&
                    _direction != Direction.up) {
                  _direction = Direction.up;
                }
              }
            },
            onPanEnd: (_) => setState(() => _joystickPos = Offset.zero),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.05),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.primary.withValues(alpha: 0.3),
                        context.primary.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Transform.translate(
                      offset: _joystickPos,
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: context.primary.withValues(alpha: 0.4),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
