import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/game_provider.dart';
import '../../../core/services/audio_service.dart';
import '../widgets/game_menus.dart';

class BrickAndBallGameScreen extends StatefulWidget {
  const BrickAndBallGameScreen({super.key});

  @override
  State<BrickAndBallGameScreen> createState() => _BrickAndBallGameScreenState();
}

class _BrickAndBallGameScreenState extends State<BrickAndBallGameScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    AudioService().init(); // Ensure audio is initialized
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseGame();
    }
  }

  // Game state
  bool _isPlaying = false;
  int _score = 0;
  int _lives = 3;
  int _level = 1;
  Timer? _gameTimer;
  bool _disposed = false;
  bool _hasGameStarted = false; // Persistent game background state

  // Screen dimensions
  late double _screenWidth;
  late double _screenHeight;
  double _lastWidth = 0;

  late double _paddleX;
  final double _paddleWidth = 150.0;
  final double _paddleHeight = 32.0; // Thicker bar
  bool _isPaddleFlipped = false;
  // Effects
  double _shakeAmount = 0.0;
  final List<_Particle> _particles = [];

  // Bricks state
  final List<_Brick> _bricks = [];
  int _rows = 4;

  // Balls state
  late List<_Ball> _balls;

  // Max ball limits to prevent performance issues
  static const int _maxBallsPerColor = 3;
  static const int _maxTotalBalls = 6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _paddleX = (_screenWidth - _paddleWidth) / 2;

    // Load user level if exists
    try {
      final progress = context.read<GameProvider>().getProgress('brick_ball');
      if (progress != null) {
        _level = progress.currentLevel;
      }
    } catch (e) {
      debugPrint('[BrickBall] Error loading progress: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _gameTimer?.cancel();
    _gameTimer = null;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _startGame() {
    if (_disposed || !mounted) return;
    _score = 0;
    _lives = 3;
    _isPlaying = true;
    _hasGameStarted = true;
    _isPaddleFlipped = false;
    _initBricks();
    _initBalls();
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_disposed || !mounted) {
        timer.cancel();
        return;
      }
      _updateGame();
    });
    AudioService().playClick(); // Start sound
  }

  void _initBricks() {
    _bricks.clear();
    final random = math.Random();

    // Professional Mechanic: Bricks get smaller as level increases
    double baseWidth = (70.0 - (_level * 2)).clamp(40.0, 70.0);
    double baseHeight = (30.0 - (_level * 0.5)).clamp(20.0, 30.0);

    _rows = (3 + (_level / 2).floor()).clamp(3, 8);

    double currentY = 100.0;
    for (int r = 0; r < _rows; r++) {
      double currentX = 20.0;
      while (currentX < _screenWidth - 40) {
        // Randomize width for each brick
        double w = baseWidth * (0.8 + random.nextDouble() * 0.4);
        double h = baseHeight * (0.9 + random.nextDouble() * 0.2);

        // Ensure it doesn't overflow screen width
        if (currentX + w > _screenWidth - 20) {
          w = _screenWidth - 20 - currentX;
        }

        if (w < 20) break;

        // Level 3+ introduces Strong bricks (2 hits)
        int health =
            (_level >= 3 && random.nextDouble() < 0.2 + (_level * 0.05))
            ? 2
            : 1;

        _bricks.add(
          _Brick(
            rect: Rect.fromLTWH(currentX, currentY, w, h),
            isGreen: random.nextBool(),
            health: health,
          ),
        );
        currentX += w + 5;
      }
      currentY += baseHeight + 5;
    }
  }

  void _initBalls() {
    // Professional Mechanic: Balls go UP initially and start at paddle
    double initialSpeed = (2.8 + (_level * 0.2)).clamp(2.8, 5.0);
    _balls = [
      _Ball(
        x: _paddleX + 20,
        y: _screenHeight - 150,
        vx: -initialSpeed * 0.8,
        vy: -initialSpeed,
        isGreen: true,
        bricksHitInOneFlight: 0,
      ),
    ];

    // Second ball (Red) spawns after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (_isPlaying && !_disposed && mounted) {
        setState(() {
          _balls.add(
            _Ball(
              x: _paddleX + _paddleWidth - 40,
              y: _screenHeight - 150,
              vx: initialSpeed * 0.8,
              vy: -initialSpeed,
              isGreen: false,
              bricksHitInOneFlight: 0,
            ),
          );
        });
      }
    });
  }

  void _updateGame() {
    if (!_isPlaying || _disposed || !mounted) return;

    setState(() {
      List<_Ball> ballsToRemove = [];
      List<_Ball> ballsToAdd = [];

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
          ball.bricksHitInOneFlight = 0; // Reset powerup counter

          bool hitLeft = ball.x + 10 < _paddleX + (_paddleWidth / 2);

          // If flipped, left is red, right is green. If not, left is green, right is red.
          bool correctSide;
          if (!_isPaddleFlipped) {
            correctSide =
                (hitLeft && ball.isGreen) || (!hitLeft && !ball.isGreen);
          } else {
            correctSide =
                (!hitLeft && ball.isGreen) || (hitLeft && !ball.isGreen);
          }

          if (!correctSide) {
            ball.vx *= 1.1;
            ball.vy *= 1.1;
            // Cap max speed to prevent invisible balls
            ball.vx = ball.vx.clamp(-8.0, 8.0);
            ball.vy = ball.vy.clamp(-8.0, 8.0);
            _createParticles(
              ball.x + 10,
              ball.y + 10,
              Colors.white.withValues(alpha: 0.5),
            );
          }

          ball.vy = -ball.vy.abs(); // Bounce up
          _score += 1;
          HapticFeedback.lightImpact();
          AudioService().playPaddleBounce();
        }

        // Brick collisions
        for (var brick in _bricks.where((b) => !b.isBroken)) {
          if (brick.rect.overlaps(Rect.fromLTWH(ball.x, ball.y, 20, 20))) {
            if (brick.isGreen == ball.isGreen) {
              brick.health--;
              ball.bricksHitInOneFlight++;

              // POWER-UP: Spawn new ball if 3 bricks hit in one flight
              // Hard cap: max _maxBallsPerColor per color, _maxTotalBalls total
              final sameColorBalls =
                  _balls.where((b) => b.isGreen == ball.isGreen).length +
                  ballsToAdd.where((b) => b.isGreen == ball.isGreen).length;
              final totalBalls = _balls.length + ballsToAdd.length;
              if (ball.bricksHitInOneFlight >= 3 &&
                  sameColorBalls < _maxBallsPerColor &&
                  totalBalls < _maxTotalBalls) {
                ballsToAdd.add(
                  _Ball(
                    x: ball.x,
                    y: ball.y,
                    vx: -ball.vx * 0.9,
                    vy: ball.vy,
                    isGreen: ball.isGreen,
                    bricksHitInOneFlight: 0,
                  ),
                );
                ball.bricksHitInOneFlight = 0;
                AudioService().playBallMultiply();
              }

              if (brick.isBroken) {
                _score += 10;
                _createParticles(
                  ball.x + 10,
                  ball.y + 10,
                  ball.isGreen ? Colors.green : Colors.red,
                );
                HapticFeedback.mediumImpact();
                AudioService().playBrickSmash(); // Only on full break
              } else {
                HapticFeedback.lightImpact();
              }
              ball.vy *= -1;
            } else {
              ball.vy *= -1;
            }
            break;
          }
        }

        // Bottom collision (Game Over/Life Loss)
        if (ball.y > _screenHeight) {
          ballsToRemove.add(ball);
        }
      }

      _balls.addAll(ballsToAdd);

      bool lifeLost = false;
      for (var ball in ballsToRemove) {
        bool lastOfColor =
            _balls.where((b) => b.isGreen == ball.isGreen).length == 1;
        if (lastOfColor) {
          lifeLost = true;
          break;
        } else {
          _balls.remove(ball);
          AudioService().playBallOut();
        }
      }

      if (lifeLost) {
        _lives--;
        _triggerShake();
        HapticFeedback.heavyImpact();
        if (_lives <= 0) {
          AudioService().playSnakeGameOver(); // Better for game over
          _gameOver();
        } else {
          AudioService().playLifeLost();
          _initBalls();
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
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
    });
    _saveProgress();
    AudioService().playSuccess();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(dialogContext).cardColor,
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 80)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut)
                      .shimmer(delay: 600.ms),
                  const SizedBox(height: 24),
                  Text(
                    'LEVEL COMPLETE!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Challenge increases as you progress.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textPrimary.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            setState(() {
                              _level++;
                              _startGame();
                            });
                          }
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _gameOver() {
    _gameTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
    });

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dc) => GameOverDialog(
        gameTitle: 'Brick & Ball',
        score: _score,
        onRestart: () {
          Navigator.pop(dc);
          if (mounted) _startGame();
        },
        onExit: () {
          Navigator.pop(dc);
          if (mounted) Navigator.pop(context);
        },
        additionalStats: [_buildMiniStat('LEVEL', '$_level', Colors.blue)],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
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
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _saveProgress() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        // Get role from AuthService cached user
        final role = AuthService().cachedUser?.role.name ?? 'user';

        context.read<GameProvider>().clearLevel(
          user.uid,
          'brick_ball',
          _level,
          _score,
          userName: user.displayName ?? 'Player',
          userRole: role,
        );
      }
    } catch (e) {
      debugPrint('[BrickBall] Error saving progress: $e');
    }
  }

  void _triggerShake() {
    if (!mounted) return;
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

  void _pauseGame() {
    if (!_isPlaying || !mounted) return;
    _gameTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GamePauseDialog(
        gameTitle: 'Brick & Ball',
        onResume: () {
          Navigator.pop(dialogContext);
          if (!mounted) return;
          setState(() {
            _isPlaying = true;
          });
          _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (
            timer,
          ) {
            if (_disposed || !mounted) {
              timer.cancel();
              return;
            }
            _updateGame();
          });
        },
        onRestart: () {
          Navigator.pop(dialogContext);
          if (mounted) _startGame();
        },
        onExit: () {
          Navigator.pop(dialogContext); // Close dialog
          if (mounted) Navigator.pop(context); // Exit game
        },
      ),
    );
  }

  void _handleExitAttempt() {
    if (_isPlaying) {
      _pauseGame();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExitAttempt();
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (_lastWidth != 0 && _lastWidth != constraints.maxWidth) {
                double ratio = constraints.maxWidth / _lastWidth;
                // Scale bricks
                for (var brick in _bricks) {
                  brick.rect = Rect.fromLTWH(
                    brick.rect.left * ratio,
                    brick.rect.top,
                    brick.rect.width * ratio,
                    brick.rect.height,
                  );
                }
                // Scale paddle
                _paddleX *= ratio;
                _paddleX = _paddleX.clamp(
                  0,
                  constraints.maxWidth - _paddleWidth,
                );

                // Scale balls
                if (_isPlaying) {
                  for (var ball in _balls) {
                    ball.x *= ratio;
                    ball.x = ball.x.clamp(0, constraints.maxWidth - 20);
                  }
                }
              }
              _lastWidth = constraints.maxWidth;
              _screenWidth = constraints.maxWidth;
              _screenHeight = constraints.maxHeight;

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: Stack(
                  children: [
                    // Background Decor (Subtle)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.5,
                            colors: [
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.05),
                              Theme.of(context).scaffoldBackgroundColor,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Header
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: _screenWidth - 40,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatCard(
                                  'SCORE',
                                  '$_score',
                                  Colors.amber,
                                ),
                                _buildStatCard('LEVEL', '$_level', Colors.blue),
                                Row(
                                  children: [
                                    Row(
                                      children: List.generate(
                                        3,
                                        (index) =>
                                            Icon(
                                                  index < _lives
                                                      ? Icons.favorite_rounded
                                                      : Icons
                                                            .favorite_border_rounded,
                                                  color: index < _lives
                                                      ? Colors.red
                                                      : Colors.red.withValues(
                                                          alpha: 0.3,
                                                        ),
                                                  size: 20,
                                                )
                                                .animate(
                                                  target: index < _lives
                                                      ? 0
                                                      : 1,
                                                )
                                                .shake(duration: 400.ms),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.pause_circle_filled_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onPressed: _pauseGame,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                        onDoubleTap: () {
                          if (!_isPlaying) return;
                          setState(() {
                            _isPaddleFlipped = !_isPaddleFlipped;
                          });
                          HapticFeedback.mediumImpact();
                          AudioService().playClick();
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

                    // Game Elements (Bricks)
                    ..._bricks
                        .where((b) => !b.isBroken)
                        .map(
                          (brick) => Positioned(
                            left: brick.rect.left,
                            top: brick.rect.top,
                            child: _BrickWidget(brick: brick),
                          ),
                        ),

                    // Game Elements (Balls)
                    if (_isPlaying || _hasGameStarted) ...[
                      ..._balls.map((ball) => _BallWidget(ball: ball)),

                      // Paddle (Brick)
                      Positioned(
                        left: _paddleX,
                        top: _screenHeight - 110,
                        child:
                            AnimatedRotation(
                                  turns: _isPaddleFlipped ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  child: _PaddleWidget(
                                    width: _paddleWidth,
                                    height: _paddleHeight,
                                    isFlipped: _isPaddleFlipped,
                                  ),
                                )
                                .animate(target: _shakeAmount > 0 ? 1 : 0)
                                .shake(hz: 10, offset: const Offset(4, 0)),
                      ),

                      // Instruction Label
                      if (_isPlaying)
                        Positioned(
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'Keep both colored balls in play',
                              style: TextStyle(
                                color: context.textPrimary.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Pause Overlay (Dim/Blur)
                      if (!_isPlaying && _hasGameStarted)
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                    ],

                    if (!_hasGameStarted)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0D1B2A),
                              const Color(0xFF1B2838),
                              context.scaffoldBackground,
                            ],
                          ),
                        ),
                        width: double.infinity,
                        height: double.infinity,
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
                                    constraints: const BoxConstraints(
                                      maxWidth: 450,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Shimmering Icon
                                        Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.orange.withValues(
                                                  alpha: 0.1,
                                                ),
                                                border: Border.all(
                                                  color: Colors.orange,
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.orange
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 40,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.grid_view_rounded,
                                                size: 56,
                                                color: Colors.white,
                                              ),
                                            )
                                            .animate(onPlay: (c) => c.repeat())
                                            .shimmer(duration: 2.seconds)
                                            .animate()
                                            .scale(
                                              duration: 600.ms,
                                              curve: Curves.elasticOut,
                                            ),
                                        const SizedBox(height: 24),
                                        // Title block
                                        const Text(
                                          'BRICK & BALL',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 6,
                                            shadows: [
                                              Shadow(
                                                color: Colors.orangeAccent,
                                                blurRadius: 15,
                                              ),
                                            ],
                                          ),
                                        ).animate().fadeIn(duration: 400.ms),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Multi-Target Tracking Mission',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ).animate().fadeIn(delay: 100.ms),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Master focus by keeping multiple balls in play. Train your eyes to track and react to moving targets.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ).animate().fadeIn(delay: 200.ms),
                                        const SizedBox(height: 24),
                                        // Benefits
                                        _buildPremiumBenefit(
                                          Icons.visibility_rounded,
                                          'Visual Tracking',
                                          'Follow multiple moving objects.',
                                        ),
                                        _buildPremiumBenefit(
                                          Icons.psychology_rounded,
                                          'Concentration',
                                          'Build sustained attention.',
                                        ),
                                        _buildPremiumBenefit(
                                          Icons.speed_rounded,
                                          'Reflexes',
                                          'Respond instantly to changes.',
                                        ),
                                        const SizedBox(height: 32),
                                        // Actions
                                        SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: _startGame,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.black,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 20,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
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
                                            )
                                            .animate()
                                            .fadeIn(delay: 400.ms)
                                            .slideY(begin: 0.3),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            'Return to Games',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
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
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPremiumBenefit(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.1);
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.textPrimary.withValues(alpha: 0.1),
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
            style: TextStyle(
              color: context.textPrimary,
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
  int bricksHitInOneFlight = 0;
  final List<Offset> trail = [];
  _Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isGreen,
    this.bricksHitInOneFlight = 0,
  });
}

class _Brick {
  Rect rect;
  final bool isGreen;
  int health;
  final int initialHealth;
  _Brick({required this.rect, required this.isGreen, this.health = 1})
    : initialHealth = health;
  bool get isBroken => health <= 0;
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
      clipBehavior: Clip.none,
      children: [
        // Trail
        ...ball.trail.asMap().entries.map((entry) {
          final i = entry.key;
          final pos = entry.value;
          return Positioned(
            left: pos.dx - 5,
            top: pos.dy - 5,
            child: Opacity(
              opacity: (1 - i / ball.trail.length) * 0.3,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ball.isGreen ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
        // Ball
        Positioned(
          left: ball.x,
          top: ball.y,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: ball.isGreen
                    ? [Colors.green.shade300, Colors.green.shade700]
                    : [Colors.red.shade300, Colors.red.shade700],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (ball.isGreen ? Colors.green : Colors.red).withValues(
                    alpha: 0.8,
                  ),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 5,
                  spreadRadius: 1,
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
  final bool isFlipped;

  const _PaddleWidget({
    required this.width,
    required this.height,
    required this.isFlipped,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on flipped state
    // Normal: Green Left, Red Right
    // Flipped (180 deg rotation in parent): Green Right, Red Left (visually)
    // Actually, since we rotate the WHOLE widget in the parent using AnimatedRotation,
    // the COLORS will also rotate. So we just need to DRAW them once.
    // Left = Green, Right = Red.
    // When Turns = 0.5 (180 deg), the widget will upside down.
    // To make it look like a flip, we should probably just rotate or swap.
    // The user said "Double tap... flip the colors gets reversed like with nice animation and all instantly."

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: Colors.black.withValues(alpha: 0.2), // Base color under splits
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(4, 0),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            // Solid colors without gradient
            Row(
              children: [
                Expanded(child: Container(color: Colors.green)),
                Expanded(child: Container(color: Colors.red)),
              ],
            ),
            // Center divider
            Center(
              child: Container(
                width: 4,
                height: height * 0.7,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            // Thicker indicator rings
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrickWidget extends StatelessWidget {
  final _Brick brick;
  const _BrickWidget({required this.brick});

  @override
  Widget build(BuildContext context) {
    final bool isCracked = brick.initialHealth > 1 && brick.health == 1;
    return SizedBox(
      width: brick.rect.width,
      height: brick.rect.height,
      child: Container(
        decoration: BoxDecoration(
          color: brick.isGreen ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: isCracked
            ? CustomPaint(painter: _CrackPainter(color: Colors.white))
            : null,
      ),
    );
  }
}

class _CrackPainter extends CustomPainter {
  final Color color;
  _CrackPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.45, size.height * 0.4);
    path.lineTo(size.width * 0.35, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.7);
    path.lineTo(size.width * 0.4, size.height);

    final path2 = Path();
    path2.moveTo(size.width * 0.45, size.height * 0.4);
    path2.lineTo(size.width * 0.65, size.height * 0.55);

    canvas.drawPath(path, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
