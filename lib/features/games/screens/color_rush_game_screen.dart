import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
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

// ═══════════════════════════════════════════════════════════════════
//  COLOR RUSH — Premium Endless Runner (Subway Surfers–inspired)
// ═══════════════════════════════════════════════════════════════════

class ColorRushGameScreen extends StatefulWidget {
  const ColorRushGameScreen({super.key});
  @override
  State<ColorRushGameScreen> createState() => _ColorRushGameScreenState();
}

class _ColorRushGameScreenState extends State<ColorRushGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ══════════ GAME STATE ══════════
  bool _playing = false;
  bool _gameOver = false;
  bool _started = false; // true once player taps START
  bool _disposed = false;
  int _score = 0;
  int _lives = 3;

  // New Feedback/Effect States
  bool _isInvulnerable = false;
  bool _hitPulse = false;
  double _glitchValue = 0;

  // ══════════ PLAYER ══════════
  bool _isGreen = true; // current collection color
  int _lane = 1; // 0 / 1 / 2
  double _smoothLane = 1.0; // interpolated lane for rendering
  double _rotationAngle = 0; // For drone blades

  // ══════════ JUMP ══════════
  bool _jumping = false;
  double _jumpY = 0;
  double _jumpVel = 0;
  static const double _gravity = -0.5;
  static const double _jumpPow = 10.0;

  // ══════════ ROAD ══════════
  double _speed = 1.5;
  double _roadT = 0; // 0‑1 cyclic, drives road dashes
  double _distance = 0;
  int _coins = 0;

  // ══════════ OBJECTS ══════════
  final List<_Obj> _objs = [];
  final _rng = math.Random();
  static const _maxObjs = 12;

  // ══════════ TIMERS ══════════
  Timer? _tick;
  Timer? _spawn;
  Timer? _colorSwitch;

  // ══════════ ANIMATION CONTROLLERS ══════════
  late final AnimationController _bounceCtrl;
  late final AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late final AnimationController _flashCtrl;

  // ══════════ SCREEN ══════════
  double _w = 0, _h = 0;

  // ────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    AudioService().init();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 0).animate(_shakeCtrl);

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // load saved progress (silently)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<GameProvider>().getProgress('color_rush');
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive)
      _pause();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context).size;
    _w = mq.width;
    _h = mq.height;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _spawn?.cancel();
    _colorSwitch?.cancel();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    _flashCtrl.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  //  START / RESTART
  // ────────────────────────────────────────────────────────────────
  void _start() {
    if (_disposed || !mounted) return;
    setState(() {
      _playing = true;
      _gameOver = false;
      _started = true;
      _score = 0;
      _lives = 3;
      _coins = 0;
      _distance = 0;
      _lane = 1;
      _smoothLane = 1.0;
      _isGreen = true;
      _speed = 1.5;
      _roadT = 0;
      _jumpY = 0;
      _jumping = false;
      _jumpVel = 0;
      _objs.clear();
    });
    AudioService().playClick();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 16), (_) => _update());
    _spawn?.cancel();
    _spawn = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _spawnObj(),
    );
    _scheduleColorSwitch();
  }

  // ────────────────────────────────────────────────────────────────
  //  COLOR SWITCH
  // ────────────────────────────────────────────────────────────────
  void _scheduleColorSwitch() {
    _colorSwitch?.cancel();
    _colorSwitch = Timer(Duration(milliseconds: 3500 + _rng.nextInt(3000)), () {
      if (_disposed || !mounted || !_playing) return;
      setState(() => _isGreen = !_isGreen);
      AudioService().playColorSwitch();
      _flashCtrl.forward(from: 0);
      _scheduleColorSwitch();
    });
  }

  // ────────────────────────────────────────────────────────────────
  //  SPAWN
  // ────────────────────────────────────────────────────────────────
  void _spawnObj() {
    if (!_playing || _disposed || !mounted || _objs.length >= _maxObjs) return;
    final lane = _rng.nextInt(3);
    if (_rng.nextDouble() < 0.20) {
      // obstacle
      _objs.add(
        _Obj(
          lane: lane,
          z: 1.0,
          green: false,
          type: _rng.nextBool() ? _ObjType.hurdle : _ObjType.barrier,
        ),
      );
    } else {
      _objs.add(
        _Obj(lane: lane, z: 1.0, green: _rng.nextBool(), type: _ObjType.coin),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  GAME LOOP (~60 fps)
  // ────────────────────────────────────────────────────────────────
  void _update() {
    if (!_playing || _disposed || !mounted) return;
    setState(() {
      // smooth lane lerp
      _smoothLane += (_lane - _smoothLane) * 0.14;

      // road advance
      _roadT = (_roadT + _speed * 0.006) % 1.0;

      // jump physics
      if (_jumping) {
        _jumpY += _jumpVel;
        _jumpVel += _gravity;
        if (_jumpY <= 0) {
          _jumpY = 0;
          _jumping = false;
          _jumpVel = 0;
        }
      }

      // distance + score
      _distance += _speed * 0.014;
      _score = (_distance * 10).toInt() + _coins * 15;

      // gentle speed increase
      _speed = (1.5 + _distance * 0.003).clamp(1.5, 5.0);

      // Update drone rotation
      _rotationAngle = (_rotationAngle + 0.5) % (math.pi * 2);

      // advance objects
      final remove = <_Obj>[];
      for (final o in _objs) {
        o.z -= _speed * 0.004;

        // collision zone
        if (o.z <= 0.07 && o.z >= -0.04) {
          final ld = (o.lane - _smoothLane).abs();
          if (ld < 0.65) {
            bool hit = false;
            // Shield check - can't be hit if invulnerable
            if (!_isInvulnerable) {
              if (o.type == _ObjType.coin) {
                if (o.green == _isGreen) {
                  _coins++;
                  remove.add(o);
                  HapticFeedback.lightImpact();
                  AudioService().playCoinCollect();
                } else {
                  hit = true;
                }
              } else if (o.type == _ObjType.hurdle) {
                if (_jumpY < 20)
                  hit = true;
                else
                  remove.add(o);
              } else {
                hit = true; // barrier — can't jump
              }

              if (hit) {
                _lives--;
                remove.add(o);
                _triggerHitFeedback();
                if (_lives <= 0) {
                  _end();
                  return;
                }
              }
            } else {
              // If invulnerable, we still want to collect correct coins
              if (o.type == _ObjType.coin && o.green == _isGreen) {
                _coins++;
                remove.add(o);
                HapticFeedback.lightImpact();
                AudioService().playCoinCollect();
              }
            }
          }
        }
        if (o.z < -0.12) remove.add(o);
      }
      _objs.removeWhere(remove.contains);
    });
  }

  void _triggerHitFeedback() {
    setState(() {
      _isInvulnerable = true;
      _hitPulse = true;
    });
    HapticFeedback.heavyImpact();
    _shake(25);
    AudioService().playCrash();

    // Pulse off
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _hitPulse = false);
    });

    // Invulnerability off after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isInvulnerable = false);
    });

    // Glitch effect loop
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_isInvulnerable) {
        timer.cancel();
        if (mounted) setState(() => _glitchValue = 0);
        return;
      }
      setState(() => _glitchValue = _rng.nextDouble());
    });
  }

  // ────────────────────────────────────────────────────────────────
  //  SHAKE
  // ────────────────────────────────────────────────────────────────
  void _shake(double intensity) {
    if (_disposed || !mounted) return;
    try {
      _shakeAnim = Tween<double>(
        begin: -intensity,
        end: intensity,
      ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
      _shakeCtrl.forward(from: 0).then((_) {
        if (!_disposed && mounted) _shakeCtrl.reverse();
      });
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────────
  //  CONTROLS
  // ────────────────────────────────────────────────────────────────
  void _left() {
    if (_lane > 0 && mounted) {
      setState(() => _lane--);
      HapticFeedback.selectionClick();
    }
  }

  void _right() {
    if (_lane < 2 && mounted) {
      setState(() => _lane++);
      HapticFeedback.selectionClick();
    }
  }

  void _jump() {
    if (!_jumping && _playing && mounted) {
      setState(() {
        _jumping = true;
        _jumpVel = _jumpPow;
      });
      HapticFeedback.mediumImpact();
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  GAME OVER
  // ────────────────────────────────────────────────────────────────
  void _end() {
    _tick?.cancel();
    _spawn?.cancel();
    _colorSwitch?.cancel();
    if (!mounted) return;
    setState(() {
      _playing = false;
      _gameOver = true;
    });
    AudioService().playGameOver();
    _save();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dc) => GameOverDialog(
        gameTitle: 'Color Rush',
        score: _score,
        onRestart: () {
          Navigator.pop(dc);
          if (mounted) _start();
        },
        onExit: () {
          Navigator.pop(dc);
          if (mounted) Navigator.pop(context);
        },
        additionalStats: [
          _stat('COINS', '$_coins', Colors.greenAccent),
          const SizedBox(width: 24),
          _stat(
            'DISTANCE',
            '${_distance.toStringAsFixed(0)}m',
            Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(
    children: [
      Text(
        l,
        style: TextStyle(
          color: c.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        v,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  Future<void> _save() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null && mounted) {
        final role = AuthService().cachedUser?.role.name ?? 'user';
        context.read<GameProvider>().clearLevel(
          u.uid,
          'color_rush',
          1,
          _score,
          userName: u.displayName ?? 'Player',
          userRole: role,
        );
      }
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────────
  //  PAUSE
  // ────────────────────────────────────────────────────────────────
  void _pause() {
    if (!_playing || !mounted) return;
    _tick?.cancel();
    _spawn?.cancel();
    _colorSwitch?.cancel();
    setState(() => _playing = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dc) => GamePauseDialog(
        gameTitle: 'Color Rush',
        onResume: () {
          Navigator.pop(dc);
          if (!mounted) return;
          setState(() => _playing = true);
          _tick = Timer.periodic(
            const Duration(milliseconds: 16),
            (_) => _update(),
          );
          _spawn = Timer.periodic(
            const Duration(milliseconds: 900),
            (_) => _spawnObj(),
          );
          _scheduleColorSwitch();
        },
        onRestart: () {
          Navigator.pop(dc);
          if (mounted) _start();
        },
        onExit: () {
          Navigator.pop(dc);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_playing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_playing)
          _pause();
        else if (!_started)
          Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E1A),
        body: Stack(
          children: [
            if (_started) _gameLayer(),
            if (!_started) _introScreen(),
            if (!_playing && _started && !_gameOver)
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

  // ────────────────────────────────────────────────────────────────
  //  INTRO SCREEN
  // ────────────────────────────────────────────────────────────────
  Widget _introScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0E1A), Color(0xFF1A1040), Color(0xFF0D1B2A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // ── Glowing Icon ──
                  Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF304FFE)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7C4DFF,
                              ).withValues(alpha: 0.4),
                              blurRadius: 50,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_run_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 2500.ms, color: Colors.white24)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 28),

                  // ── Title ──
                  const Text(
                    'COLOR RUSH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 8,
                      shadows: [
                        Shadow(color: Color(0xFF7C4DFF), blurRadius: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'CHROMATIC VELOCITY',
                    style: TextStyle(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Swipe to dodge barriers, jump over hurdles, and collect orbs that match your color.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 28),
                  _infoPill(
                    Icons.filter_center_focus,
                    'Color Perception',
                    'Rapid hue identification',
                  ),
                  _infoPill(
                    Icons.bolt_rounded,
                    'Precision Reflexes',
                    'Lane-switching accuracy',
                  ),
                  _infoPill(
                    Icons.visibility_rounded,
                    'Peripheral Vision',
                    'Wide-field tracking',
                  ),
                  const SizedBox(height: 36),

                  // ── Start Button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _start,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 16,
                        shadowColor: const Color(0xFF7C4DFF),
                      ),
                      child: const Text(
                        'START MISSION',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Return to Games',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData ic, String t, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ic, color: const Color(0xFF7C4DFF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  s,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
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

  // ════════════════════════════════════════════════════════════════
  //  GAME LAYER
  // ════════════════════════════════════════════════════════════════
  Widget _gameLayer() {
    return LayoutBuilder(
      builder: (ctx, box) {
        _w = box.maxWidth;
        _h = box.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (d) {
            if (_playing && (d.primaryVelocity ?? 0) < -180) _jump();
          },
          onHorizontalDragEnd: (d) {
            if (!_playing) return;
            final v = d.primaryVelocity ?? 0;
            if (v < -180) _left();
            if (v > 180) _right();
          },
          onTapDown: (d) {
            if (!_playing) return;
            d.globalPosition.dx < _w / 2 ? _left() : _right();
          },
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: Stack(
                children: [
                  // ── Road Canvas ──
                  CustomPaint(
                    painter: _RoadPainter(
                      w: _w,
                      h: _h,
                      roadT: _roadT,
                      speed: _speed,
                      playerColor: _isGreen
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF5252),
                    ),
                    size: Size(_w, _h),
                  ),

                  // ── Objects ──
                  ..._objs.map(_objWidget),

                  // ── Player ──
                  _playerWidget(),

                  // ── Color flash overlay ──
                  AnimatedBuilder(
                    animation: _flashCtrl,
                    builder: (_, __) {
                      final a = (1.0 - _flashCtrl.value).clamp(0.0, 0.25);
                      return IgnorePointer(
                        child: Container(
                          width: _w,
                          height: _h,
                          color:
                              (_isGreen
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFFFF5252))
                                  .withValues(alpha: a),
                        ),
                      );
                    },
                  ),

                  // ── Hit Pulse Layer ──
                  if (_hitPulse)
                    IgnorePointer(
                      child: Container(
                        width: _w,
                        height: _h,
                        color: Colors.red.withValues(alpha: 0.4),
                      ),
                    ),

                  // ── HUD ──
                  _hud(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  3D PERSPECTIVE HELPERS
  // ────────────────────────────────────────────────────────────────
  static const double _horizon = 0.32;

  _Pos _pos(double z, double lane) {
    final hy = _h * _horizon;
    final py = _h * 0.84;
    final y = hy + (py - hy) * (1.0 - z);

    final rwP = _w * 0.88;
    final rwH = _w * 0.07;
    final rw = rwH + (rwP - rwH) * (1.0 - z);

    final cx = _w / 2;
    final ls = rw / 3;
    final x = cx + (lane - 1) * ls;
    final sc = (1.0 - z * 0.8).clamp(0.12, 1.0);
    return _Pos(x, y, sc);
  }

  // ────────────────────────────────────────────────────────────────
  //  OBJECT WIDGET
  // ────────────────────────────────────────────────────────────────
  Widget _objWidget(_Obj o) {
    if (o.z <= 0 || o.z > 1.0) return const SizedBox.shrink();
    final p = _pos(o.z, o.lane.toDouble());
    double sz = (o.type == _ObjType.coin ? 44 : 64) * p.s;

    Widget child;
    switch (o.type) {
      case _ObjType.coin:
        final c1 = o.green ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80);
        final c2 = o.green ? const Color(0xFF00C853) : const Color(0xFFFF1744);
        child = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [c1, c2],
              focal: const Alignment(-0.3, -0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: c2.withValues(alpha: 0.7 * p.s),
                blurRadius: 18 * p.s,
                spreadRadius: 4 * p.s,
              ),
            ],
          ),
          child: CustomPaint(painter: _GemPainter(color: c1)),
        );
        break;

      case _ObjType.hurdle:
        child = Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(painter: _TripwirePainter(), size: Size(sz * 2.5, sz)),
            Positioned(
              top: 0,
              child: Text(
                'JUMP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10 * p.s,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: const [
                    Shadow(color: Colors.cyanAccent, blurRadius: 10),
                  ],
                ),
              ),
            ),
          ],
        );
        sz *= 1.2;
        break;

      case _ObjType.barrier:
        child = CustomPaint(
          painter: _ObeliskPainter(),
          size: Size(sz * 2.5, sz * 3),
        );
        sz *= 2.2;
        break;
    }

    final isWide = o.type != _ObjType.coin;
    final cw = isWide ? sz * 2.5 : sz;
    return Positioned(
      left: p.x - cw / 2,
      top: p.y - sz,
      child: SizedBox(width: cw, height: sz, child: child),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  PLAYER WIDGET
  // ────────────────────────────────────────────────────────────────
  Widget _playerWidget() {
    final p = _pos(0.0, _smoothLane);
    const sz = 60.0;
    final color = _isGreen ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return AnimatedBuilder(
      animation: _bounceCtrl,
      builder: (_, __) {
        final b = math.sin(_bounceCtrl.value * math.pi) * 3.5;
        final shadowS = (1.0 - (_jumpY / 80)).clamp(0.4, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ground shadow
            Positioned(
              left: p.x - sz * 0.45 * shadowS,
              top: p.y - 8,
              child: Container(
                width: sz * 0.9 * shadowS,
                height: 8 * shadowS,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4 * shadowS),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(22 * shadowS, 4 * shadowS),
                  ),
                ),
              ),
            ),
            // drone with glitch/invulnerability
            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              left: p.x - sz / 2 + (_glitchValue * 6 - 3), // Glitch jitter
              top: p.y - sz - 10 + b - _jumpY,
              child: Opacity(
                opacity: _isInvulnerable
                    ? (0.6 +
                          0.4 *
                              math.sin(
                                DateTime.now().millisecondsSinceEpoch * 0.02,
                              ))
                    : 1.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow/Shield
                    if (_isInvulnerable)
                      Container(
                        width: sz * 1.4,
                        height: sz * 1.4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.2),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    // Drone Body
                    SizedBox(
                      width: sz,
                      height: sz,
                      child: CustomPaint(
                        painter: _DronePainter(
                          color: color,
                          angle: _rotationAngle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HUD
  // ────────────────────────────────────────────────────────────────
  Widget _hud() {
    final col = _isGreen ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pause
                _glassPill(
                  child: IconButton(
                    onPressed: _playing ? _pause : null,
                    icon: Icon(
                      Icons.pause_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                // Score
                _glassPill(
                  px: 20,
                  py: 10,
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lives
                _glassPill(
                  px: 10,
                  py: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          i < _lives
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: i < _lives
                              ? const Color(0xFFFF5252)
                              : Colors.white24,
                          size: 18,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: col.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(color: col.withValues(alpha: 0.15), blurRadius: 12),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: col,
                      boxShadow: [BoxShadow(color: col, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isGreen ? 'COLLECT GREEN' : 'COLLECT RED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
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

  Widget _glassPill({Widget? child, double px = 10, double py = 10}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: child,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════════════
enum _ObjType { coin, hurdle, barrier }

class _Obj {
  int lane;
  double z;
  bool green;
  _ObjType type;
  _Obj({
    required this.lane,
    required this.z,
    required this.green,
    required this.type,
  });
}

class _Pos {
  final double x, y, s;
  const _Pos(this.x, this.y, this.s);
}

// ══════════════════════════════════════════════════════════════════
//  ROAD PAINTER — Premium 3D perspective road
// ══════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════
//  PAINTERS
// ══════════════════════════════════════════════════════════════════

class _DronePainter extends CustomPainter {
  final Color color;
  final double angle;
  _DronePainter({required this.color, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.height * 0.3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      p,
    );

    // Arms
    final armP = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.1, size.height * 0.2),
      armP,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.3),
      Offset(size.width * 0.9, size.height * 0.2),
      armP,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.1, size.height * 0.8),
      armP,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.7),
      Offset(size.width * 0.9, size.height * 0.8),
      armP,
    );

    // Blades
    final bP = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    void drawBlade(double x, double y) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), bP);
      canvas.rotate(math.pi / 2);
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), bP);
      canvas.restore();
    }

    drawBlade(size.width * 0.1, size.height * 0.2);
    drawBlade(size.width * 0.9, size.height * 0.2);
    drawBlade(size.width * 0.1, size.height * 0.8);
    drawBlade(size.width * 0.9, size.height * 0.8);

    // Eye/Light
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DronePainter old) => old.angle != angle;
}

class _ObeliskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF263238), Color(0xFF455A64)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width * 0.2, size.height)
      ..lineTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(size.width * 0.8, size.height)
      ..close();
    canvas.drawPath(path, p);

    // Glow Lines
    final glow = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      glow,
    );

    // Warning
    final wP = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2 - 10, size.height / 2 + 5)
        ..lineTo(size.width / 2 + 10, size.height / 2 + 5)
        ..lineTo(size.width / 2, size.height / 2 - 15)
        ..close(),
      wP,
    );
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

class _TripwirePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      p,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      p
        ..maskFilter = null
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    // Posts
    final postP = Paint()..color = Colors.grey.shade400;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.3, 6, size.height * 0.4),
      postP,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - 6, size.height * 0.3, 6, size.height * 0.4),
      postP,
    );
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

class _GemPainter extends CustomPainter {
  final Color color;
  _GemPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 3)
      ..lineTo(size.width * 0.8, size.height)
      ..lineTo(size.width * 0.2, size.height)
      ..lineTo(0, size.height / 3)
      ..close();
    canvas.drawPath(path, p);

    // Highlight
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.2, size.height * 0.4)
        ..lineTo(size.width * 0.5, size.height * 0.2)
        ..lineTo(size.width * 0.3, size.height * 0.5)
        ..close(),
      Paint()..color = Colors.white30,
    );
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

class _RoadPainter extends CustomPainter {
  final double w, h, roadT, speed;
  final Color playerColor;

  _RoadPainter({
    required this.w,
    required this.h,
    required this.roadT,
    required this.speed,
    required this.playerColor,
  });

  static const double _hz = 0.32; // horizon ratio

  @override
  void paint(Canvas canvas, Size size) {
    final hy = h * _hz; // horizon y
    final cx = w / 2; // center x

    // ── SKY ──
    final skyGrad = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B0E1A), Color(0xFF1A1040), Color(0xFF1B2838)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyGrad);

    // ── STARS (fixed) ──
    final starP = Paint()..color = Colors.white;
    final rng = math.Random(77);
    for (int i = 0; i < 50; i++) {
      final sx = rng.nextDouble() * w;
      final sy = rng.nextDouble() * hy * 0.85;
      final sr = 0.4 + rng.nextDouble() * 1.2;
      starP.color = Colors.white.withValues(
        alpha: 0.3 + rng.nextDouble() * 0.5,
      );
      canvas.drawCircle(Offset(sx, sy), sr, starP);
    }

    // ── MOUNTAINS (silhouette, static) ──
    final mtP = Paint()..color = const Color(0xFF14192B);
    final mp = Path();
    mp.moveTo(0, hy);
    for (double x = 0; x <= w; x += w / 5) {
      mp.lineTo(x, hy - 15 - rng.nextDouble() * 35);
      mp.lineTo(x + w / 10, hy - 5 - rng.nextDouble() * 15);
    }
    mp.lineTo(w, hy);
    mp.close();
    canvas.drawPath(mp, mtP);

    // ── GROUND / TERRAIN strip behind road ──
    final groundP = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B2838), Color(0xFF0F1923)],
      ).createShader(Rect.fromLTWH(0, hy, w, h - hy));
    canvas.drawRect(Rect.fromLTWH(0, hy, w, h - hy), groundP);

    // ── ROAD TRAPEZOID ──
    final rwBot = w * 0.88;
    final rwTop = w * 0.07;
    final roadPath = Path()
      ..moveTo(cx - rwTop / 2, hy)
      ..lineTo(cx + rwTop / 2, hy)
      ..lineTo(cx + rwBot / 2, h)
      ..lineTo(cx - rwBot / 2, h)
      ..close();

    final roadP = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E2530), Color(0xFF263240)],
      ).createShader(Rect.fromLTWH(0, hy, w, h - hy));
    canvas.drawPath(roadPath, roadP);

    // ── ROAD EDGES (bright glow!) ──
    final edgeP = Paint()
      ..color = playerColor.withValues(alpha: 0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx - rwTop / 2, hy),
      Offset(cx - rwBot / 2, h),
      edgeP,
    );
    canvas.drawLine(
      Offset(cx + rwTop / 2, hy),
      Offset(cx + rwBot / 2, h),
      edgeP,
    );

    // Neon Lights alongside road
    final neonP = Paint()
      ..color = playerColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (int i = 0; i < 4; i++) {
      double t = (i / 4 + roadT) % 1.0;
      double pt = t * t;
      double y = hy + (h - hy) * pt;
      double rwL = rwTop + (rwBot - rwTop) * pt;
      canvas.drawCircle(Offset(cx - rwL / 2 - 10, y), 4 * pt, neonP);
      canvas.drawCircle(Offset(cx + rwL / 2 + 10, y), 4 * pt, neonP);
    }

    // softer inner glow
    final edgeGlow = Paint()
      ..color = playerColor.withValues(alpha: 0.15)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset(cx - rwTop / 2, hy),
      Offset(cx - rwBot / 2, h),
      edgeGlow,
    );
    canvas.drawLine(
      Offset(cx + rwTop / 2, hy),
      Offset(cx + rwBot / 2, h),
      edgeGlow,
    );

    // ── LANE DIVIDERS ──
    final laneP = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (final f in [-0.333, 0.333]) {
      final tx = cx + f * rwTop / 2;
      final bx = cx + f * rwBot / 2;
      canvas.drawLine(Offset(tx, hy), Offset(bx, h), laneP);
    }

    // ── SCROLLING CENTER DASHES (few, smooth) ──
    final dashP = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      double t = (i / 5 + roadT) % 1.0;
      double pt = t * t;
      double y = hy + (h - hy) * pt;
      double dl = 3 + 14 * pt;
      if (y > hy + 4 && y < h - 4) {
        dashP.strokeWidth = 1 + 2 * pt;
        canvas.drawLine(Offset(cx, y - dl / 2), Offset(cx, y + dl / 2), dashP);
      }
    }

    // ── VANISHING POINT GLOW ──
    final vpP = Paint()
      ..shader = RadialGradient(
        colors: [playerColor.withValues(alpha: 0.2), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, hy), radius: 60));
    canvas.drawCircle(Offset(cx, hy), 60, vpP);

    // ── SIDE BUILDINGS (tall, perspective) ──
    final bldP = Paint()..color = const Color(0xFF111825);
    final bldA = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      double t = (i / 6 + roadT * 0.3) % 1.0;
      double pt = t * t;
      double y = hy + (h - hy) * pt;
      double bw = 3 + 25 * pt;
      double bh = 8 + 70 * pt;
      double rw2 = rwTop + (rwBot - rwTop) * pt;
      double xl = cx - rw2 / 2 - bw - 2;
      double xr = cx + rw2 / 2 + 2;
      if (y > hy + 3) {
        canvas.drawRect(Rect.fromLTWH(xl, y - bh, bw, bh), bldP);
        canvas.drawRect(Rect.fromLTWH(xr, y - bh, bw, bh), bldP);
        canvas.drawRect(Rect.fromLTWH(xl, y - bh, bw, bh), bldA);
        canvas.drawRect(Rect.fromLTWH(xr, y - bh, bw, bh), bldA);

        // tiny "windows"
        final winP = Paint()
          ..color = const Color(0xFF2A3A4A).withValues(alpha: 0.6);
        if (bw > 10) {
          for (int j = 1; j < 3; j++) {
            double wy = y - bh + bh * j / 3;
            double ws = bw * 0.3;
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset(xl + bw / 2, wy),
                width: ws,
                height: ws * 0.6,
              ),
              winP,
            );
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset(xr + bw / 2, wy),
                width: ws,
                height: ws * 0.6,
              ),
              winP,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.roadT != roadT ||
      old.speed != speed ||
      old.playerColor != playerColor;
}
