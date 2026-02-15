import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/game_provider.dart';

class BrickAndBallGameScreen extends StatefulWidget {
  const BrickAndBallGameScreen({super.key});

  @override
  State<BrickAndBallGameScreen> createState() => _BrickAndBallGameScreenState();
}

class _BrickAndBallGameScreenState extends State<BrickAndBallGameScreen> {
  // Game state
  bool _isPlaying = false;
  int _score = 0;
  int _lives = 3;
  int _level = 1;
  double _ballSpeed = 3.5;
  Timer? _gameTimer;
  final math.Random _random = math.Random();

  // Screen dimensions
  late double _screenWidth;
  late double _screenHeight;

  // Paddle/Brick state
  late double _paddleX;
  final double _paddleWidth = 120.0;
  final double _paddleHeight = 20.0;
  bool _paddleColorLeftIsGreen = true; // Left side is green, right is red

  // Balls state
  final List<_Ball> _balls = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _paddleX = (_screenWidth - _paddleWidth) / 2;

    // Load user level if exists
    final progress = context.read<GameProvider>().getProgress('brick_ball');
    if (progress != null) {
      _level = progress.currentLevel;
      _ballSpeed = 3.5 + (_level - 1) * 0.5;
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _score = 0;
      _lives = 3;
      _balls.clear();
    });
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGame();
    });
  }

  void _updateGame() {
    if (!_isPlaying) return;

    setState(() {
      // 1. Probabilistically spawn balls
      if (_random.nextDouble() < 0.02 + (_level * 0.005)) {
        _balls.add(
          _Ball(
            x: _random.nextDouble() * (_screenWidth - 30),
            y: -40,
            isGreen: _random.nextBool(),
          ),
        );
      }

      // 2. Update ball positions and check collisions
      final List<_Ball> toRemove = [];
      for (var ball in _balls) {
        ball.y += _ballSpeed;

        // Collision with bottom/paddle
        if (ball.y + 30 >= _screenHeight - 120 &&
            ball.y <= _screenHeight - 100) {
          if (ball.x + 30 >= _paddleX && ball.x <= _paddleX + _paddleWidth) {
            // Hit the paddle
            bool hitLeft = ball.x + 15 < _paddleX + (_paddleWidth / 2);
            bool match =
                (hitLeft && _paddleColorLeftIsGreen == ball.isGreen) ||
                (!hitLeft && _paddleColorLeftIsGreen != ball.isGreen);

            if (match) {
              _score += 10;
              toRemove.add(ball);
            } else {
              _lives--;
              toRemove.add(ball);
              if (_lives <= 0) _gameOver();
            }
          }
        } else if (ball.y > _screenHeight) {
          // Missed ball
          _lives--;
          toRemove.add(ball);
          if (_lives <= 0) _gameOver();
        }
      }
      _balls.removeWhere((b) => toRemove.contains(b));

      // 3. Level Up condition
      if (_score >= _level * 100) {
        _levelUp();
      }
    });
  }

  void _levelUp() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      context.read<GameProvider>().clearLevel(
        userId,
        'brick_ball',
        _level,
        _score,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Level Cleared! 🎉'),
        content: Text('Congratulations! You reached Level ${_level + 1}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _level++;
                _ballSpeed += 0.5;
                _startGame();
              });
            },
            child: const Text('Next Level'),
          ),
        ],
      ),
    );
  }

  void _gameOver() {
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over ❌'),
        content: Text('Your Score: $_score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _togglePaddle() {
    setState(() {
      _paddleColorLeftIsGreen = !_paddleColorLeftIsGreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for focus
      body: Stack(
        children: [
          // Background Decor (Subtle)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [Colors.grey.withValues(alpha: 0.1), Colors.black],
                ),
              ),
            ),
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard('SCORE', '$_score', Colors.amber),
                  _buildStatCard('LEVEL', '$_level', Colors.blue),
                  _buildStatCard('LIVES', '$_lives', Colors.red),
                ],
              ),
            ),
          ),

          // Game Elements
          if (_isPlaying) ...[
            // Falling Balls
            ..._balls.map(
              (ball) => Positioned(
                left: ball.x,
                top: ball.y,
                child: _BallWidget(isGreen: ball.isGreen),
              ),
            ),

            // Paddle (Brick)
            Positioned(
              left: _paddleX,
              top: _screenHeight - 120,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _paddleX = (_paddleX + details.delta.dx).clamp(
                      0,
                      _screenWidth - _paddleWidth,
                    );
                  });
                },
                onTap: _togglePaddle,
                child: _PaddleWidget(
                  width: _paddleWidth,
                  height: _paddleHeight,
                  leftIsGreen: _paddleColorLeftIsGreen,
                ),
              ),
            ),

            // Instruction Label
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Tap to flip colors • Drag to move',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          // Start Screen Overlay
          if (!_isPlaying)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                          Icons.grid_view_rounded,
                          size: 100,
                          color: Colors.orange,
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 2.seconds),
                    const SizedBox(height: 24),
                    const Text(
                      'Brick & Ball',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Catch the green balls with green side and red with red side.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'START GAME',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Back to Menu',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Back button (floating)
          if (_isPlaying)
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 30,
                ),
                onPressed: () {
                  _gameTimer?.cancel();
                  Navigator.pop(context);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ball {
  double x;
  double y;
  final bool isGreen;
  _Ball({required this.x, required this.y, required this.isGreen});
}

class _BallWidget extends StatelessWidget {
  final bool isGreen;
  const _BallWidget({required this.isGreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isGreen ? Colors.green : Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isGreen ? Colors.green : Colors.red).withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _PaddleWidget extends StatelessWidget {
  final double width;
  final double height;
  final bool leftIsGreen;

  const _PaddleWidget({
    required this.width,
    required this.height,
    required this.leftIsGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: leftIsGreen ? Colors.green : Colors.red,
                ),
              ),
              Expanded(
                child: Container(
                  color: leftIsGreen ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        )
        .animate(target: leftIsGreen ? 0 : 1)
        .rotate(begin: 0, end: 0.5, duration: 200.ms);
  }
}
