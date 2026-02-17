import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/game_provider.dart';
import '../widgets/game_menus.dart';

class ColorRushGameScreen extends StatefulWidget {
  const ColorRushGameScreen({super.key});

  @override
  State<ColorRushGameScreen> createState() => _ColorRushGameScreenState();
}

class _ColorRushGameScreenState extends State<ColorRushGameScreen>
    with TickerProviderStateMixin {
  // ─── Game State ───
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _lives = 3;
  bool _disposed = false;

  // ─── Player ───
  bool _playerIsGreen = true; // Current avatar color (auto-switches)
  int _lane = 1; // 0=left, 1=center, 2=right
  double _targetLane = 1.0; // For smooth lane transitions

  // ─── Road Speed & Progression ───
  double _speed = 2.5;
  double _roadOffset = 0; // Scrolling road lines

  // ─── Screen ───
  double _screenWidth = 0;
  double _screenHeight = 0;

  // ─── Coins ───
  final List<_RunnerCoin> _coins = [];
  Timer? _gameTimer;
  Timer? _coinSpawnTimer;
  Timer? _colorSwitchTimer;
  final math.Random _rng = math.Random();
  static const int _maxCoinsOnScreen = 15;

  // ─── Animation ───
  late AnimationController _playerBounceCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _colorFlashCtrl;

  // ─── Distance tracking ───
  double _distance = 0;
  int _coinsCollected = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    AudioService().init();

    _playerBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 0).animate(_shakeCtrl);

    _colorFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final progress = context.read<GameProvider>().getProgress('color_rush');
        if (progress != null) {
          // Use saved progress
        }
      } catch (e) {
        debugPrint('[ColorRush] Error loading progress: $e');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
  }

  @override
  void dispose() {
    _disposed = true;
    _gameTimer?.cancel();
    _coinSpawnTimer?.cancel();
    _colorSwitchTimer?.cancel();
    _playerBounceCtrl.dispose();
    _shakeCtrl.dispose();
    _colorFlashCtrl.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // ─── Game Start ───
  void _startGame() {
    if (_disposed || !mounted) return;
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _lives = 3;
      _coins.clear();
      _lane = 1;
      _targetLane = 1.0;
      _playerIsGreen = true;
      _speed = 2.5;
      _distance = 0;
      _coinsCollected = 0;
      _roadOffset = 0;
    });

    AudioService().playClick();

    // Main game loop ~60fps
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (_disposed || !mounted) {
        t.cancel();
        return;
      }
      _updateGame();
    });

    // Spawn coins
    _coinSpawnTimer?.cancel();
    _coinSpawnTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (_disposed || !mounted) {
        t.cancel();
        return;
      }
      _spawnCoin();
    });

    // Auto color switch every 3-6 seconds
    _scheduleColorSwitch();
  }

  void _scheduleColorSwitch() {
    _colorSwitchTimer?.cancel();
    final interval = 3000 + _rng.nextInt(3000); // 3-6 seconds
    _colorSwitchTimer = Timer(Duration(milliseconds: interval), () {
      if (_disposed || !mounted || !_isPlaying) return;
      setState(() => _playerIsGreen = !_playerIsGreen);
      AudioService().playColorSwitch();
      _colorFlashCtrl.forward(from: 0);
      _scheduleColorSwitch(); // Schedule next
    });
  }

  void _spawnCoin() {
    if (!_isPlaying || _disposed || !mounted) return;
    if (_coins.length >= _maxCoinsOnScreen) return;

    final lane = _rng.nextInt(3);
    final isGreen = _rng.nextBool();

    _coins.add(
      _RunnerCoin(
        lane: lane,
        z: 1.0, // Start far away (z=1 is horizon, z=0 is player)
        isGreen: isGreen,
      ),
    );
  }

  // ─── Game Loop ───
  void _updateGame() {
    if (!_isPlaying || _disposed || !mounted) return;

    setState(() {
      // Smooth lane transition
      _targetLane += (_lane - _targetLane) * 0.15;

      // Advance road
      _roadOffset += _speed * 0.01;
      if (_roadOffset >= 1.0) _roadOffset -= 1.0;

      // Distance & speed increase
      _distance += _speed * 0.016;
      _score = (_distance * 10).toInt() + (_coinsCollected * 10);

      // Gradually increase speed
      _speed = (2.5 + _distance * 0.01).clamp(2.5, 8.0);

      // Move coins toward player (decrease z)
      List<_RunnerCoin> toRemove = [];
      for (var coin in _coins) {
        coin.z -= _speed * 0.006; // Move closer

        // Collision zone: z near 0 and same lane
        if (coin.z <= 0.08 && coin.z >= -0.05) {
          final laneDiff = (coin.lane - _targetLane).abs();
          if (laneDiff < 0.7) {
            // Hit!
            if (coin.isGreen == _playerIsGreen) {
              // Correct color — collect
              _coinsCollected++;
              toRemove.add(coin);
              HapticFeedback.lightImpact();
              AudioService().playCoinCollect();
            } else {
              // Wrong color — lose life
              _lives--;
              toRemove.add(coin);
              HapticFeedback.heavyImpact();
              _triggerShake();
              AudioService().playWrongCoin();

              if (_lives <= 0) {
                _gameOver();
                return;
              }
            }
          }
        }

        // Passed behind player
        if (coin.z < -0.1) {
          toRemove.add(coin);
        }
      }
      _coins.removeWhere((c) => toRemove.contains(c));
    });
  }

  void _triggerShake() {
    if (_disposed) return;
    try {
      _shakeAnim = Tween<double>(
        begin: -8,
        end: 8,
      ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
      _shakeCtrl.forward(from: 0).then((_) {
        if (!_disposed) _shakeCtrl.reverse();
      });
    } catch (_) {}
  }

  // ─── Controls ───
  void _moveLeft() {
    if (_lane > 0 && mounted) {
      setState(() => _lane--);
      HapticFeedback.selectionClick();
    }
  }

  void _moveRight() {
    if (_lane < 2 && mounted) {
      setState(() => _lane++);
      HapticFeedback.selectionClick();
    }
  }

  // ─── Game Over ───
  void _gameOver() {
    _gameTimer?.cancel();
    _coinSpawnTimer?.cancel();
    _colorSwitchTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
    AudioService().playGameOver();
    _saveProgress();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dc) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(dc).cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.2),
                  blurRadius: 40,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.heart_broken_rounded,
                    color: Colors.red,
                    size: 72,
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    'GAME OVER',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.textPrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _miniStat('SCORE', '$_score', Colors.amber),
                        const SizedBox(width: 20),
                        _miniStat('COINS', '$_coinsCollected', Colors.green),
                        const SizedBox(width: 20),
                        _miniStat(
                          'DISTANCE',
                          '${_distance.toStringAsFixed(0)}m',
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dc);
                          if (mounted) _startGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'RETRY',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dc);
                          if (mounted) Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('EXIT'),
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

  Widget _miniStat(String label, String value, Color color) {
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _saveProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        final role = AuthService().cachedUser?.role.name ?? 'user';
        context.read<GameProvider>().clearLevel(
          user.uid,
          'color_rush',
          1,
          _score,
          userName: user.displayName ?? 'Player',
          userRole: role,
        );
      }
    } catch (e) {
      debugPrint('[ColorRush] Error saving progress: $e');
    }
  }

  void _pauseGame() {
    if (!_isPlaying || !mounted) return;
    _gameTimer?.cancel();
    _coinSpawnTimer?.cancel();
    _colorSwitchTimer?.cancel();
    setState(() => _isPlaying = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dc) => GamePauseDialog(
        gameTitle: 'Color Rush',
        onResume: () {
          Navigator.pop(dc);
          if (!mounted) return;
          setState(() => _isPlaying = true);
          _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
            if (_disposed || !mounted) {
              t.cancel();
              return;
            }
            _updateGame();
          });
          _coinSpawnTimer = Timer.periodic(const Duration(milliseconds: 700), (
            t,
          ) {
            if (_disposed || !mounted) {
              t.cancel();
              return;
            }
            _spawnCoin();
          });
          _scheduleColorSwitch();
        },
        onRestart: () {
          Navigator.pop(dc);
          if (mounted) _startGame();
        },
        onExit: () {
          Navigator.pop(dc);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isPlaying,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isPlaying) _pauseGame();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        body: _isPlaying || _isGameOver
            ? _buildGameView()
            : _buildStartScreen(),
      ),
    );
  }

  // ─── Start Screen ───
  Widget _buildStartScreen() {
    return Container(
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
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 3D road preview icon
                Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF00C853), Color(0xFFFF1744)],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00C853,
                            ).withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(-8, 12),
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFFFF1744,
                            ).withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(8, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .shimmer(delay: 800.ms, duration: 1200.ms),
                const SizedBox(height: 32),
                const Text(
                  'COLOR RUSH',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
                const SizedBox(height: 8),
                Text(
                  'Infinite Runner',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),
                // How to play
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _howToRow(Icons.swipe, 'Swipe left/right to dodge'),
                      const SizedBox(height: 12),
                      _howToRow(
                        Icons.autorenew_rounded,
                        'Color auto-switches — stay alert!',
                      ),
                      const SizedBox(height: 12),
                      _howToRow(Icons.circle, 'Collect matching coins'),
                      const SizedBox(height: 12),
                      _howToRow(
                        Icons.visibility,
                        'Improves color perception & reflexes',
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 12,
                      shadowColor: const Color(
                        0xFF00C853,
                      ).withValues(alpha: 0.5),
                    ),
                    child: const Text(
                      'START RUNNING',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Back to Games',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _howToRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00C853), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Game View (3D Perspective) ───
  Widget _buildGameView() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (!_isPlaying) return;
              final v = details.primaryVelocity ?? 0;
              if (v < -200) _moveRight();
              if (v > 200) _moveLeft();
            },
            onTapDown: (details) {
              if (!_isPlaying) return;
              // Tap left/right side of screen
              if (details.globalPosition.dx < _screenWidth / 2) {
                _moveLeft();
              } else {
                _moveRight();
              }
            },
            child: Stack(
              children: [
                // 3D Road
                CustomPaint(
                  painter: _RoadPainter(
                    screenWidth: _screenWidth,
                    screenHeight: _screenHeight,
                    roadOffset: _roadOffset,
                    isDark: context.isDarkMode,
                    playerColor: _playerIsGreen ? Colors.green : Colors.red,
                  ),
                  size: Size(_screenWidth, _screenHeight),
                ),

                // Coins in perspective
                ..._coins.map((coin) => _buildPerspectiveCoin(coin)),

                // Player avatar
                _buildPerspectivePlayer(),

                // Color indicator flash
                AnimatedBuilder(
                  animation: _colorFlashCtrl,
                  builder: (_, __) {
                    final opacity = (1.0 - _colorFlashCtrl.value).clamp(
                      0.0,
                      0.3,
                    );
                    return IgnorePointer(
                      child: Container(
                        width: _screenWidth,
                        height: _screenHeight,
                        color: (_playerIsGreen ? Colors.green : Colors.red)
                            .withValues(alpha: opacity),
                      ),
                    );
                  },
                ),

                // HUD
                _buildHUD(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 3D Perspective Helpers ───

  /// Convert z (0=near player, 1=horizon) + lane to screen position
  _PerspectivePos _getScreenPos(double z, double lane) {
    final horizonY = _screenHeight * 0.35;
    final playerY = _screenHeight * 0.82;
    final y = horizonY + (playerY - horizonY) * (1.0 - z);

    // Road narrows toward horizon
    final roadWidthAtPlayer = _screenWidth * 0.85;
    final roadWidthAtHorizon = _screenWidth * 0.08;
    final roadWidth =
        roadWidthAtHorizon +
        (roadWidthAtPlayer - roadWidthAtHorizon) * (1.0 - z);

    final centerX = _screenWidth / 2;
    final laneSpacing = roadWidth / 3;
    final x = centerX + (lane - 1) * laneSpacing;

    // Scale objects based on distance
    final scale = (1.0 - z * 0.8).clamp(0.15, 1.0);

    return _PerspectivePos(x: x, y: y, scale: scale);
  }

  Widget _buildPerspectiveCoin(_RunnerCoin coin) {
    if (coin.z < 0 || coin.z > 1.0) return const SizedBox.shrink();

    final pos = _getScreenPos(coin.z, coin.lane.toDouble());
    final size = 40.0 * pos.scale;

    return Positioned(
      left: pos.x - size / 2,
      top: pos.y - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: coin.isGreen
                ? [const Color(0xFF69F0AE), const Color(0xFF00C853)]
                : [const Color(0xFFFF8A80), const Color(0xFFFF1744)],
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (coin.isGreen
                          ? const Color(0xFF00C853)
                          : const Color(0xFFFF1744))
                      .withValues(alpha: 0.6 * pos.scale),
              blurRadius: 12 * pos.scale,
              spreadRadius: 2 * pos.scale,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            coin.isGreen ? Icons.circle : Icons.circle,
            color: Colors.white.withValues(alpha: 0.8),
            size: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPerspectivePlayer() {
    final pos = _getScreenPos(0.0, _targetLane);
    const size = 52.0;

    return AnimatedBuilder(
      animation: _playerBounceCtrl,
      builder: (_, __) {
        final bounce = math.sin(_playerBounceCtrl.value * math.pi) * 4;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          left: pos.x - size / 2,
          top: pos.y - size - 10 + bounce,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _playerIsGreen
                  ? const Color(0xFF00C853)
                  : const Color(0xFFFF1744),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color:
                      (_playerIsGreen
                              ? const Color(0xFF00C853)
                              : const Color(0xFFFF1744))
                          .withValues(alpha: 0.7),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.directions_run_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHUD() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pause
                IconButton(
                  onPressed: _isPlaying ? _pauseGame : null,
                  icon: Icon(
                    Icons.pause_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lives
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          i < _lives
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: i < _lives ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Color indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color:
                    (_playerIsGreen
                            ? const Color(0xFF00C853)
                            : const Color(0xFFFF1744))
                        .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _playerIsGreen
                      ? const Color(0xFF00C853)
                      : const Color(0xFFFF1744),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    color: _playerIsGreen
                        ? const Color(0xFF00C853)
                        : const Color(0xFFFF1744),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _playerIsGreen ? 'COLLECTING GREEN' : 'COLLECTING RED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
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

// ─── Data Models ───

class _RunnerCoin {
  int lane;
  double z; // 1.0 = horizon, 0.0 = player position
  bool isGreen;

  _RunnerCoin({required this.lane, required this.z, required this.isGreen});
}

class _PerspectivePos {
  final double x, y, scale;
  _PerspectivePos({required this.x, required this.y, required this.scale});
}

// ─── 3D Road Painter ───

class _RoadPainter extends CustomPainter {
  final double screenWidth;
  final double screenHeight;
  final double roadOffset;
  final bool isDark;
  final Color playerColor;

  _RoadPainter({
    required this.screenWidth,
    required this.screenHeight,
    required this.roadOffset,
    required this.isDark,
    required this.playerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sky gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF0A0E1A),
                const Color(0xFF1A1F35),
                const Color(0xFF252B45),
              ]
            : [
                const Color(0xFF1A237E),
                const Color(0xFF283593),
                const Color(0xFF3949AB),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    final horizonY = screenHeight * 0.35;
    final bottomY = screenHeight;
    final centerX = screenWidth / 2;

    // Road trapezoid
    final roadWidthBottom = screenWidth * 0.85;
    final roadWidthTop = screenWidth * 0.08;

    final roadPath = Path()
      ..moveTo(centerX - roadWidthTop / 2, horizonY)
      ..lineTo(centerX + roadWidthTop / 2, horizonY)
      ..lineTo(centerX + roadWidthBottom / 2, bottomY)
      ..lineTo(centerX - roadWidthBottom / 2, bottomY)
      ..close();

    // Road fill
    final roadPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [const Color(0xFF37474F), const Color(0xFF455A64)],
          ).createShader(
            Rect.fromLTWH(0, horizonY, size.width, bottomY - horizonY),
          );
    canvas.drawPath(roadPath, roadPaint);

    // Road edge glow lines
    final edgePaint = Paint()
      ..color = playerColor.withValues(alpha: 0.4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Left edge
    canvas.drawLine(
      Offset(centerX - roadWidthTop / 2, horizonY),
      Offset(centerX - roadWidthBottom / 2, bottomY),
      edgePaint,
    );
    // Right edge
    canvas.drawLine(
      Offset(centerX + roadWidthTop / 2, horizonY),
      Offset(centerX + roadWidthBottom / 2, bottomY),
      edgePaint,
    );

    // Lane dividers (perspective)
    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.5;

    for (int i = -1; i <= 1; i += 2) {
      final fraction = i * 0.333;
      final topX = centerX + fraction * roadWidthTop / 2;
      final botX = centerX + fraction * roadWidthBottom / 2;
      canvas.drawLine(Offset(topX, horizonY), Offset(botX, bottomY), lanePaint);
    }

    // Scrolling dashes (center line) for motion effect
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 2;

    const dashCount = 12;
    for (int i = 0; i < dashCount; i++) {
      double t = (i / dashCount + roadOffset) % 1.0;
      // Perspective scale: closer = bigger gap
      double perspT = t * t; // Quadratic for perspective
      double y = horizonY + (bottomY - horizonY) * perspT;
      double dashLen = 4 + 16 * perspT;

      if (y > horizonY + 5 && y < bottomY - 5) {
        canvas.drawLine(
          Offset(centerX, y - dashLen / 2),
          Offset(centerX, y + dashLen / 2),
          dashPaint..strokeWidth = 1 + 2 * perspT,
        );
      }
    }

    // Vanishing point glow
    final vanishPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [playerColor.withValues(alpha: 0.15), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, horizonY), radius: 80),
          );
    canvas.drawCircle(Offset(centerX, horizonY), 80, vanishPaint);

    // Side stars/particles (ambient)
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    final rng = math.Random(42); // Fixed seed for consistent stars
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * screenWidth;
      final y = rng.nextDouble() * horizonY;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.5 + 0.5, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.roadOffset != roadOffset ||
      old.isDark != isDark ||
      old.playerColor != playerColor;
}
