import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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
  Timer? _gameTimer;

  // Screen dimensions
  late double _screenWidth;
  late double _screenHeight;

  // Paddle/Brick state
  late double _paddleX;
  final double _paddleWidth = 120.0;
  final double _paddleHeight = 20.0;
  // Effects
  double _shakeAmount = 0.0;
  final List<_Particle> _particles = [];

  // Bricks state
  final List<_Brick> _bricks = [];
  double _brickWidth = 60.0;
  double _brickHeight = 25.0;
  int _rows = 4;
  int _cols = 6;

  // Balls state
  late List<_Ball> _balls;

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
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _score = 0;
    _lives = 3;
    _isPlaying = true;
    _initBricks();
    _initBalls();
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGame();
    });
  }

  void _initBricks() {
    _bricks.clear();
    // Professional Mechanic: Bricks get smaller as level increases
    _brickWidth = (60.0 - (_level * 2)).clamp(35.0, 60.0);
    _brickHeight = (25.0 - (_level * 0.5)).clamp(18.0, 25.0);
    _cols = (_screenWidth / (_brickWidth + 5)).floor().clamp(4, 9);
    _rows = (3 + (_level / 2).floor()).clamp(3, 7);

    double totalGridWidth = _cols * (_brickWidth + 5);
    double startX = (_screenWidth - totalGridWidth) / 2;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        _bricks.add(
          _Brick(
            rect: Rect.fromLTWH(
              startX + c * (_brickWidth + 5),
              100 + r * (_brickHeight + 5),
              _brickWidth,
              _brickHeight,
            ),
            isGreen: (r + c) % 2 == 0,
          ),
        );
      }
    }
  }

  void _initBalls() {
    // Professional Mechanic: Balls go UP initially and start at paddle
    double initialSpeed = (2.5 + (_level * 0.2)).clamp(2.5, 4.5);
    _balls = [
      _Ball(
        x: _paddleX + 20,
        y: _screenHeight - 150,
        vx: -initialSpeed,
        vy: -initialSpeed,
        isGreen: true,
      ),
      _Ball(
        x: _paddleX + _paddleWidth - 40,
        y: _screenHeight - 150,
        vx: initialSpeed,
        vy: -initialSpeed,
        isGreen: false,
      ),
    ];
  }

  void _updateGame() {
    if (!_isPlaying) return;

    setState(() {
      for (var ball in _balls) {
        // Update position
        ball.x += ball.vx;
        ball.y += ball.vy;

        // Add to trail
        ball.trail.insert(0, Offset(ball.x + 10, ball.y + 10));
        if (ball.trail.length > 5) ball.trail.removeLast();

        // Wall collisions
        if (ball.x <= 0 || ball.x >= _screenWidth - 20) {
          ball.vx *= -1;
          ball.x = ball.x.clamp(0, _screenWidth - 20);
        }
        if (ball.y <= 0) {
          ball.vy *= -1;
          ball.y = 0;
        }

        // Paddle collision
        if (ball.y + 20 >= _screenHeight - 120 &&
            ball.y <= _screenHeight - 100 &&
            ball.x + 20 >= _paddleX &&
            ball.x <= _paddleX + _paddleWidth) {
          // Professional Mechanic: Speed increases only if color mismatch
          bool hitLeft = ball.x + 10 < _paddleX + (_paddleWidth / 2);
          bool correctSide =
              (hitLeft && ball.isGreen) || (!hitLeft && !ball.isGreen);

          if (!correctSide) {
            ball.vx *= 1.1;
            ball.vy *= 1.1;
            _createParticles(
              ball.x + 10,
              ball.y + 10,
              Colors.white.withValues(alpha: 0.5),
            );
          } else {
            // Perfect catch: heal/stabilize? (Optional)
          }

          ball.vy = -ball.vy.abs(); // Bounce up
          _score += 1;
          HapticFeedback.lightImpact();
          SystemSound.play(SystemSoundType.click);
        }

        // Brick collisions
        for (var brick in _bricks.where((b) => !b.isBroken)) {
          if (brick.rect.overlaps(Rect.fromLTWH(ball.x, ball.y, 20, 20))) {
            if (brick.isGreen == ball.isGreen) {
              brick.isBroken = true;
              _score += 10;
              _createParticles(
                ball.x + 10,
                ball.y + 10,
                ball.isGreen ? Colors.green : Colors.red,
              );
              ball.vy *= -1;
              HapticFeedback.mediumImpact();
              SystemSound.play(SystemSoundType.click);
            } else {
              // Wrong color: just bounce without breaking
              ball.vy *= -1;
            }
            break;
          }
        }

        // Bottom collision (Game Over/Life Loss)
        if (ball.y > _screenHeight) {
          _lives--;
          _triggerShake();
          if (_lives <= 0) {
            _gameOver();
          } else {
            // Reset ball position
            ball.x = _paddleX + (_paddleWidth / 2);
            ball.y = _screenHeight / 2;
            ball.vy = 3.5;
            ball.vx = ball.isGreen ? -3 : 3;
            HapticFeedback.heavyImpact();
          }
        }
      }

      // Win condition: All bricks broken
      if (_bricks.every((b) => b.isBroken)) {
        _levelUp();
      }

      // Update particles
      for (var p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.life -= 0.05;
      }
      _particles.removeWhere((p) => p.life <= 0);
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
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: context.primary.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.primary.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 80)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .shimmer(delay: 600.ms),
              const SizedBox(height: 24),
              const Text(
                'LEVEL COMPLETE!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Challenge increases as you progress.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _level++;
                    _startGame();
                  });
                },
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
                  'NEXT LEVEL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
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

  void _triggerShake() {
    setState(() {
      _shakeAmount = 10.0;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _shakeAmount = 0.0;
        });
      }
    });
  }

  void _createParticles(double x, double y, Color color) {
    for (int i = 0; i < 8; i++) {
      _particles.add(
        _Particle(
          x: x,
          y: y,
          vx: (math.Random().nextDouble() - 0.5) * 10,
          vy: (math.Random().nextDouble() - 0.5) * 10,
          color: color,
        ),
      );
    }
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
                  Row(
                    children: List.generate(
                      3,
                      (index) =>
                          Icon(
                                index < _lives
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: index < _lives
                                    ? Colors.red
                                    : Colors.red.withValues(alpha: 0.3),
                                size: 20,
                              )
                              .animate(target: index < _lives ? 0 : 1)
                              .shake(duration: 400.ms),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Drag Handler (Bottom Region)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                if (!_isPlaying) return;
                setState(() {
                  _paddleX = (_paddleX + details.delta.dx).clamp(
                    0,
                    _screenWidth - _paddleWidth,
                  );
                });
              },
            ),
          ),

          // Particle Layer
          ..._particles.map(
            (p) => Positioned(
              left: p.x,
              top: p.y,
              child: Opacity(
                opacity: p.life.clamp(0.0, 1.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          // Game Elements
          // Game Elements (Bricks)
          ..._bricks
              .where((b) => !b.isBroken)
              .map(
                (brick) => Positioned(
                  left: brick.rect.left,
                  top: brick.rect.top,
                  child: _BrickWidget(
                    isGreen: brick.isGreen,
                    width: _brickWidth,
                    height: _brickHeight,
                  ),
                ),
              ),

          // Game Elements (Balls)
          if (_isPlaying) ...[
            ..._balls.map((ball) => _BallWidget(ball: ball)),

            // Paddle (Brick)
            Positioned(
              left:
                  _paddleX + (math.Random().nextDouble() - 0.5) * _shakeAmount,
              top:
                  _screenHeight -
                  120 +
                  (math.Random().nextDouble() - 0.5) * _shakeAmount,
              child: _PaddleWidget(width: _paddleWidth, height: _paddleHeight),
            ),

            // Instruction Label
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Keep both colored balls in play',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
                        'This game improves your hand-eye coordination, saccadic eye movements, and color-specific tracking. By managing two targets at once, you strengthen your visual focus and reaction time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Tip: Catching a ball on the WRONG color of the paddle increases its speed!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
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
  double vx;
  double vy;
  final bool isGreen;
  final List<Offset> trail = [];
  _Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isGreen,
  });
}

class _Brick {
  final Rect rect;
  final bool isGreen;
  bool isBroken = false;
  _Brick({required this.rect, required this.isGreen});
}

class _Particle {
  double x, y, vx, vy;
  double life = 1.0;
  final Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
  });
}

class _BallWidget extends StatelessWidget {
  final _Ball ball;
  const _BallWidget({required this.ball});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Trail
        ...List.generate(ball.trail.length, (index) {
          final opacity = 1.0 - (index / ball.trail.length);
          final size = 30.0 * (1.0 - (index / ball.trail.length) * 0.5);
          return Positioned(
            left: ball.trail[index].dx - (size / 2),
            top: ball.trail[index].dy - (size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: (ball.isGreen ? Colors.green : Colors.red).withValues(
                  alpha: opacity * 0.3,
                ),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
        // Main Ball
        Positioned(
          left: ball.x,
          top: ball.y,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: ball.isGreen ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (ball.isGreen ? Colors.green : Colors.red).withValues(
                    alpha: 0.6,
                  ),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaddleWidget extends StatelessWidget {
  final double width;
  final double height;

  const _PaddleWidget({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withValues(alpha: 0.6),
                        Colors.green.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withValues(alpha: 0.2),
                        Colors.red.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Center(
            child: Container(width: 2, height: height, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _BrickWidget extends StatelessWidget {
  final bool isGreen;
  final double width;
  final double height;

  const _BrickWidget({
    required this.isGreen,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isGreen
            ? Colors.green.withValues(alpha: 0.6)
            : Colors.red.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isGreen ? Colors.green : Colors.red,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isGreen ? Colors.green : Colors.red).withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
