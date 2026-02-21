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
import '../../../data/providers/game_provider.dart';
import '../widgets/game_menus.dart';

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
  bool _started = false;
  bool _disposed = false;
  int _score = 0;
  int _lives = 3;
  int _combo = 0;
  int _maxCombo = 0;
  bool _isInvulnerable = false;
  bool _hitPulse = false;
  double _invulnFlicker = 1.0;
  bool _showComboPopup = false;
  int _comboPopupValue = 0;

  // ══════════ POWER-UPS ══════════
  bool _hasShield = false;
  bool _hasMagnet = false;
  int _magnetTimer = 0;
  int _shieldTimer = 0;

  // ══════════ PLAYER ══════════
  bool _isGreen = true;
  bool _colorSwitchGrace = false; // FIX #3: grace period after color switch
  int _lane = 1;
  double _smoothLane = 1.0;

  // ══════════ JUMP / SLIDE ══════════
  bool _jumping = false;
  bool _sliding = false;
  double _jumpY = 0;
  double _jumpVel = 0;
  int _slideTimer = 0;

  bool _jumpBuffer = false;
  bool _slideBuffer = false;
  int _jumpBufferFrames = 0;
  int _slideBufferFrames = 0;
  static const int _bufferWindow = 12;

  static const double _gravity = -0.60;
  static const double _jumpPow = 13.0;

  // ══════════ RUNNER ANIMATION ══════════
  double _runFrame = 0.0;
  double _tiltAngle = 0.0;
  int _prevLane = 1;

  // ══════════ ROAD ══════════
  double _speed = 2.2;
  double _roadT = 0;
  double _distance = 0;
  int _coins = 0;

  // ══════════ ENV ══════════
  double _envT = 0;
  final List<_Particle> _particles = [];

  // ══════════ OBJECTS ══════════
  final List<_Obj> _objs = [];
  final _rng = math.Random();
  static const _maxObjs = 16;

  // ══════════ TIMERS ══════════
  Timer? _tick;
  Timer? _spawn;
  Timer? _colorSwitch;
  Timer? _flickerTimer;

  // ══════════ ANIM CONTROLLERS ══════════
  late final AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late final AnimationController _flashCtrl;
  late final AnimationController _colorPulseCtrl;
  late final AnimationController _bgCtrl;

  double _w = 0, _h = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    AudioService().init();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 0).animate(_shakeCtrl);

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _colorPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<GameProvider>().getProgress('color_rush');
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      _pause();
    }
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
    _flickerTimer?.cancel();
    _shakeCtrl.dispose();
    _flashCtrl.dispose();
    _colorPulseCtrl.dispose();
    _bgCtrl.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ─── START ───────────────────────────────────────────────────────
  void _start() {
    if (_disposed || !mounted) return;
    setState(() {
      _playing = true;
      _gameOver = false;
      _started = true;
      _score = 0;
      _lives = 3;
      _coins = 0;
      _combo = 0;
      _maxCombo = 0;
      _distance = 0;
      _lane = 1;
      _smoothLane = 1.0;
      _prevLane = 1;
      _isGreen = true;
      _colorSwitchGrace = false;
      _speed = 2.2;
      _roadT = 0;
      _envT = 0;
      _jumpY = 0;
      _jumping = false;
      _sliding = false;
      _jumpVel = 0;
      _slideTimer = 0;
      _runFrame = 0;
      _tiltAngle = 0;
      _hasShield = false;
      _hasMagnet = false;
      _magnetTimer = 0;
      _shieldTimer = 0;
      _jumpBuffer = false;
      _slideBuffer = false;
      _jumpBufferFrames = 0;
      _slideBufferFrames = 0;
      _isInvulnerable = false;
      _invulnFlicker = 1.0;
      _objs.clear();
      _particles.clear();
    });
    AudioService().playClick();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 16), (_) => _update());
    _spawn?.cancel();
    _spawn = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _spawnObj(),
    );
    _scheduleColorSwitch();
  }

  // FIX #3: Color switch with 1.5s grace period
  void _scheduleColorSwitch() {
    _colorSwitch?.cancel();
    _colorSwitch = Timer(Duration(milliseconds: 3500 + _rng.nextInt(2500)), () {
      if (_disposed || !mounted || !_playing) return;
      setState(() {
        _isGreen = !_isGreen;
        _colorSwitchGrace = true;
      });
      AudioService().playWordCorrect();
      _flashCtrl.forward(from: 0);

      // Grace period: player is safe for 1.5s after color switch
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _colorSwitchGrace = false);
      });

      _scheduleColorSwitch();
    });
  }

  // ─── SPAWN ───────────────────────────────────────────────────────
  void _spawnObj() {
    if (!_playing || _disposed || !mounted || _objs.length >= _maxObjs) return;
    final lane = _rng.nextInt(3);
    final roll = _rng.nextDouble();
    if (roll < 0.13) {
      _objs.add(_Obj(lane: lane, z: 1.0, green: false, type: _ObjType.barrier));
    } else if (roll < 0.24) {
      _objs.add(_Obj(lane: lane, z: 1.0, green: false, type: _ObjType.hurdle));
    } else if (roll < 0.30) {
      _objs.add(_Obj(lane: lane, z: 1.0, green: true, type: _ObjType.shield));
    } else if (roll < 0.36) {
      _objs.add(_Obj(lane: lane, z: 1.0, green: true, type: _ObjType.magnet));
    } else {
      final coinLane = _rng.nextInt(3);
      final isG = _rng.nextBool();
      for (int i = 0; i < 3; i++) {
        _objs.add(
          _Obj(
            lane: coinLane,
            z: 1.0 + i * 0.08,
            green: isG,
            type: _ObjType.coin,
          ),
        );
      }
    }
  }

  // ─── GAME LOOP ───────────────────────────────────────────────────
  void _update() {
    if (!_playing || _disposed || !mounted) return;
    setState(() {
      // Lane lerp + tilt
      _smoothLane += (_lane - _smoothLane) * 0.18;
      if (_lane != _prevLane) {
        _tiltAngle = (_lane - _prevLane) * 0.18;
        _prevLane = _lane;
      } else {
        _tiltAngle *= 0.80;
      }

      _roadT = (_roadT + _speed * 0.0065) % 1.0;
      _envT = (_envT + _speed * 0.0022) % 1.0;
      _runFrame += _speed * 0.09;
      if (_runFrame > math.pi * 2) _runFrame -= math.pi * 2;

      // Input buffers
      if (_jumpBuffer) {
        _jumpBufferFrames++;
        if (!_jumping && !_sliding) {
          _jumping = true;
          _jumpVel = _jumpPow;
          _jumpBuffer = false;
          _jumpBufferFrames = 0;
          HapticFeedback.mediumImpact();
        } else if (_jumpBufferFrames > _bufferWindow) {
          _jumpBuffer = false;
          _jumpBufferFrames = 0;
        }
      }
      if (_slideBuffer) {
        _slideBufferFrames++;
        if (!_jumping && !_sliding) {
          _sliding = true;
          _slideTimer = 48;
          _slideBuffer = false;
          _slideBufferFrames = 0;
          HapticFeedback.mediumImpact();
        } else if (_slideBufferFrames > _bufferWindow) {
          _slideBuffer = false;
          _slideBufferFrames = 0;
        }
      }

      if (_sliding) {
        _slideTimer--;
        if (_slideTimer <= 0) _sliding = false;
      }

      if (_jumping) {
        _jumpY += _jumpVel;
        _jumpVel += _gravity;
        if (_jumpY <= 0) {
          _jumpY = 0;
          _jumping = false;
          _jumpVel = 0;
        }
      }

      if (_magnetTimer > 0) {
        _magnetTimer--;
        if (_magnetTimer == 0) _hasMagnet = false;
      }
      if (_shieldTimer > 0) {
        _shieldTimer--;
        if (_shieldTimer == 0) _hasShield = false;
      }

      _distance += _speed * 0.014;
      final mult = 1.0 + (_combo ~/ 5) * 0.5;
      _score = (_distance * 10 * mult).toInt() + _coins * 20;
      _speed = (2.2 + _distance * 0.004).clamp(2.2, 8.0);

      // FIX #2: Magnet only attracts coins matching current player color
      if (_hasMagnet) {
        for (final o in _objs) {
          if (o.type == _ObjType.coin && o.z < 0.55 && o.green == _isGreen) {
            o.lane = _lane;
          }
        }
      }

      // Foot particles
      if (!_jumping && !_sliding && _rng.nextDouble() < 0.2) {
        _particles.add(
          _Particle(
            laneX: _smoothLane / 2,
            life: 1.0,
            vx: (_rng.nextDouble() - 0.5) * 0.012,
            vy: 0.012 + _rng.nextDouble() * 0.01,
            size: 2.0 + _rng.nextDouble() * 2.5,
            color: _isGreen ? const Color(0xFF00E676) : const Color(0xFFFF5252),
          ),
        );
      }
      for (final p in _particles) {
        p.life -= 0.055;
      }
      _particles.removeWhere((p) => p.life <= 0);

      // Collision
      final remove = <_Obj>[];
      for (final o in _objs) {
        o.z -= _speed * 0.0042;

        if (o.z <= 0.10 && o.z >= -0.05) {
          final ld = (o.lane - _smoothLane).abs();
          if (ld < 0.72) {
            if (!_isInvulnerable) {
              switch (o.type) {
                case _ObjType.coin:
                  if (o.green == _isGreen) {
                    _coins++;
                    _combo++;
                    if (_combo > _maxCombo) _maxCombo = _combo;
                    if (_combo % 5 == 0) _triggerComboPopup(_combo);
                    remove.add(o);
                    HapticFeedback.lightImpact();
                    AudioService().playClick();
                    _spawnBurst(o);
                  } else {
                    // FIX #3: Grace period — wrong coins are safe during switch
                    if (_jumpY > 20 || _colorSwitchGrace) {
                      remove.add(o);
                    } else {
                      _combo = 0;
                      _lives--;
                      remove.add(o);
                      AudioService().playWrongCoin();
                      _triggerHit();
                      if (_lives <= 0) {
                        _end();
                        return;
                      }
                    }
                  }
                  break;
                case _ObjType.hurdle:
                  if (_jumpY > 14) {
                    remove.add(o);
                  } else if (_hasShield) {
                    _hasShield = false;
                    _shieldTimer = 0;
                    remove.add(o);
                    _flashCtrl.forward(from: 0);
                  } else {
                    _combo = 0;
                    _lives--;
                    remove.add(o);
                    _triggerHit();
                    if (_lives <= 0) {
                      _end();
                      return;
                    }
                  }
                  break;
                case _ObjType.barrier:
                  if (_sliding) {
                    remove.add(o);
                  } else if (_hasShield) {
                    _hasShield = false;
                    _shieldTimer = 0;
                    remove.add(o);
                    _flashCtrl.forward(from: 0);
                  } else {
                    _combo = 0;
                    _lives--;
                    remove.add(o);
                    _triggerHit();
                    if (_lives <= 0) {
                      _end();
                      return;
                    }
                  }
                  break;
                case _ObjType.shield:
                  _hasShield = true;
                  _shieldTimer = 360;
                  remove.add(o);
                  HapticFeedback.mediumImpact();
                  AudioService().playSuccess();
                  break;
                case _ObjType.magnet:
                  _hasMagnet = true;
                  _magnetTimer = 280;
                  remove.add(o);
                  HapticFeedback.mediumImpact();
                  AudioService().playSuccess();
                  break;
              }
            } else {
              if (o.type == _ObjType.coin && o.green == _isGreen) {
                _coins++;
                _combo++;
                remove.add(o);
                HapticFeedback.lightImpact();
                AudioService().playClick();
              }
            }
          }
        }
        if (o.z < -0.16) remove.add(o);
      }
      _objs.removeWhere(remove.contains);
    });
  }

  void _spawnBurst(_Obj o) {
    for (int i = 0; i < 8; i++) {
      _particles.add(
        _Particle(
          laneX: o.lane / 2.0,
          life: 1.0,
          vx: (_rng.nextDouble() - 0.5) * 0.04,
          vy: -(0.02 + _rng.nextDouble() * 0.03),
          size: 3.0 + _rng.nextDouble() * 5.0,
          color: o.green ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
        ),
      );
    }
  }

  void _triggerComboPopup(int c) {
    setState(() {
      _showComboPopup = true;
      _comboPopupValue = c;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showComboPopup = false);
    });
  }

  void _triggerHit() {
    if (!mounted) return;
    setState(() {
      _isInvulnerable = true;
      _hitPulse = true;
      _invulnFlicker = 1.0;
    });
    HapticFeedback.heavyImpact();
    _shake(18);
    AudioService().playCrash();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _hitPulse = false);
    });

    _flickerTimer?.cancel();
    int flickerCount = 0;
    _flickerTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted || !_isInvulnerable) {
        t.cancel();
        if (mounted) setState(() => _invulnFlicker = 1.0);
        return;
      }
      flickerCount++;
      setState(() => _invulnFlicker = flickerCount.isEven ? 1.0 : 0.3);
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      _flickerTimer?.cancel();
      if (mounted) {
        setState(() {
          _isInvulnerable = false;
          _invulnFlicker = 1.0;
        });
      }
    });
  }

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

  // ─── CONTROLS ─────────────────────────────────────────────────────
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
    if (!_playing || !mounted) return;
    if (!_jumping && !_sliding) {
      setState(() {
        _jumping = true;
        _jumpVel = _jumpPow;
      });
      HapticFeedback.mediumImpact();
    } else {
      setState(() {
        _jumpBuffer = true;
        _jumpBufferFrames = 0;
      });
    }
  }

  void _slide() {
    if (!_playing || !mounted) return;
    if (!_jumping && !_sliding) {
      setState(() {
        _sliding = true;
        _slideTimer = 48;
      });
      HapticFeedback.mediumImpact();
    } else {
      setState(() {
        _slideBuffer = true;
        _slideBufferFrames = 0;
      });
    }
  }

  // ─── GAME OVER ─────────────────────────────────────────────────────
  void _end() {
    _tick?.cancel();
    _spawn?.cancel();
    _colorSwitch?.cancel();
    _flickerTimer?.cancel();
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
          _statWidget('COINS', '$_coins', Colors.greenAccent),
          const SizedBox(width: 18),
          _statWidget('COMBO', 'x$_maxCombo', Colors.amberAccent),
          const SizedBox(width: 18),
          _statWidget(
            'DIST',
            '${_distance.toStringAsFixed(0)}m',
            Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  Widget _statWidget(String l, String v, Color c) => Column(
    children: [
      Text(
        l,
        style: TextStyle(
          color: c.withOpacity(0.7),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      Text(
        v,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
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

  // ─── PAUSE ─────────────────────────────────────────────────────────
  void _pause() {
    if (!_playing || !mounted) return;
    _tick?.cancel();
    _spawn?.cancel();
    _colorSwitch?.cancel();
    _flickerTimer?.cancel();
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
            const Duration(milliseconds: 700),
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

  // ══════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_playing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_playing) {
          _pause();
        } else if (!_started) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020408),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            if (_started) _gameLayer(),
            if (!_started) _introScreen(),
            if (!_playing && _started && !_gameOver)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── INTRO ─────────────────────────────────────────────────────────
  Widget _introScreen() {
    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF020408), Color(0xFF060D20), Color(0xFF020408)],
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _bgCtrl,
              builder: (context, child) => CustomPaint(
                painter: _GridPainter(
                  t: _bgCtrl.value,
                  color: const Color(0xFF00E676),
                ),
                size: Size(
                  _w.isFinite && _w > 0 ? _w : 400,
                  _h.isFinite && _h > 0 ? _h : 800,
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _neonText('COLOR', const Color(0xFF00E676), 52),
                    _neonText('RUSH', const Color(0xFFFF5252), 52),
                    const SizedBox(height: 4),
                    Text(
                      'NEON ENDLESS RUNNER',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.22),
                        fontSize: 10,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _controlCard(
                      Icons.swap_horiz_rounded,
                      'SWIPE LEFT / RIGHT',
                      'Switch lanes',
                      const Color(0xFF00B0FF),
                    ),
                    const SizedBox(height: 7),
                    _controlCard(
                      Icons.arrow_upward_rounded,
                      'SWIPE UP',
                      'Jump over hurdles and coins',
                      const Color(0xFF69F0AE),
                    ),
                    const SizedBox(height: 7),
                    _controlCard(
                      Icons.arrow_downward_rounded,
                      'SWIPE DOWN',
                      'Slide under barriers',
                      const Color(0xFFFFD740),
                    ),
                    const SizedBox(height: 7),
                    _controlCard(
                      Icons.palette_rounded,
                      'MATCH COLORS',
                      'Collect orbs matching your colour dot',
                      const Color(0xFFFF5252),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _powerCard(
                            '🛡️',
                            'SHIELD',
                            'Absorbs 1 hit',
                            const Color(0xFF00B0FF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _powerCard(
                            '🧲',
                            'MAGNET',
                            'Pulls matching coins',
                            const Color(0xFFFFD740),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _powerCard(
                            '🔥',
                            'COMBO',
                            'Score multiplier',
                            const Color(0xFFFF5252),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: _start,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.45),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 30,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'RUN!',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Back to Games',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _neonText(String text, Color color, double size) => Stack(
    alignment: Alignment.center,
    children: [
      Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = color.withOpacity(0.22),
        ),
      ),
      Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          color: color,
          shadows: [
            Shadow(color: color, blurRadius: 24),
            Shadow(color: color, blurRadius: 50),
          ],
        ),
      ),
    ],
  ).animate().fadeIn(duration: 500.ms);

  Widget _controlCard(IconData icon, String title, String sub, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.32),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _powerCard(String emoji, String label, String desc, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.28),
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  //  GAME LAYER
  // ══════════════════════════════════════════════════════════════════
  Widget _gameLayer() {
    return LayoutBuilder(
      builder: (ctx, box) {
        _w = box.maxWidth;
        _h = box.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (d) {
            if (!_playing) return;
            final v = d.primaryVelocity ?? 0;
            if (v < -110) _jump();
            if (v > 110) _slide();
          },
          onHorizontalDragEnd: (d) {
            if (!_playing) return;
            final v = d.primaryVelocity ?? 0;
            if (v < -110) _left();
            if (v > 110) _right();
          },
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // ── World ──
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _bgCtrl,
                      builder: (context, child) => CustomPaint(
                        painter: _WorldPainter(
                          w: _w,
                          h: _h,
                          roadT: _roadT,
                          envT: _envT,
                          speed: _speed,
                          playerColor: _isGreen
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF5252),
                          bgT: _bgCtrl.value,
                        ),
                      ),
                    ),
                  ),

                  // ── Particles ──
                  ..._particles.map(_particleWidget),

                  // ── Objects ──
                  ..._objs.map(_objWidget),

                  // ── Player ──
                  _playerWidget(),

                  // ── Colour flash ──
                  AnimatedBuilder(
                    animation: _flashCtrl,
                    builder: (context, child) {
                      final a = (1.0 - _flashCtrl.value).clamp(0.0, 0.18);
                      final col = _isGreen
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF5252);
                      return IgnorePointer(
                        child: Container(
                          width: _w,
                          height: _h,
                          color: col.withOpacity(a),
                        ),
                      );
                    },
                  ),

                  // ── Hit pulse ──
                  if (_hitPulse)
                    IgnorePointer(
                      child: Container(
                        width: _w,
                        height: _h,
                        color: Colors.red.withOpacity(0.28),
                      ),
                    ),

                  // ── Grace period overlay ──
                  if (_colorSwitchGrace)
                    IgnorePointer(
                      child: Container(
                        width: _w,
                        height: _h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                (_isGreen
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFFFF5252))
                                    .withOpacity(0.45),
                            width: 12,
                          ),
                        ),
                      ),
                    ),

                  // ── Combo popup ──
                  if (_showComboPopup)
                    Positioned(
                      top: _h * 0.27,
                      child: IgnorePointer(
                        child:
                            Text(
                                  '🔥 COMBO x$_comboPopupValue!',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        color: Colors.amber,
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 180.ms)
                                .slideY(begin: 0.2, end: -0.1, duration: 800.ms)
                                .then()
                                .fadeOut(duration: 400.ms),
                      ),
                    ),

                  // ── HUD ──
                  Positioned(top: 0, left: 0, right: 0, child: _hud()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── PERSPECTIVE ───────────────────────────────────────────────────
  static const double _horizon = 0.28;

  _Pos _pos(double z, double lane) {
    final hy = _h * _horizon;
    final py = _h * 0.86;
    final y = hy + (py - hy) * (1.0 - z);
    final rwP = _w * 0.92;
    final rwH = _w * 0.055;
    final rw = rwH + (rwP - rwH) * (1.0 - z);
    final x = _w / 2 + (lane - 1) * (rw / 3);
    final sc = (1.0 - z * 0.82).clamp(0.07, 1.0);
    return _Pos(x, y, sc);
  }

  // ─── PARTICLE WIDGET ───────────────────────────────────────────────
  Widget _particleWidget(_Particle p) {
    final base = _pos(0.0, _smoothLane);
    final px = base.x + p.vx * _w * 6 + (p.laneX - 0.5) * 40;
    final py = base.y - p.life * 28;
    final opacity = p.life.clamp(0.0, 1.0);
    return Positioned(
      left: px - p.size / 2,
      top: py - p.size / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: p.size,
            height: p.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.color,
              boxShadow: [
                BoxShadow(
                  color: p.color.withOpacity(0.6),
                  blurRadius: p.size * 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── OBJECT WIDGET ──────────────────────────────────────────────────
  Widget _objWidget(_Obj o) {
    if (o.z <= 0 || o.z > 1.0) return const SizedBox.shrink();
    final p = _pos(o.z, o.lane.toDouble());
    switch (o.type) {
      case _ObjType.coin:
        final c1 = o.green ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80);
        final c2 = o.green ? const Color(0xFF00C853) : const Color(0xFFFF1744);
        final sz = 34.0 * p.s;
        return Positioned(
          left: p.x - sz / 2,
          top: p.y - sz - 2,
          child: Container(
            width: sz,
            height: sz,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [c1, c2],
                focal: const Alignment(-0.3, -0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: c2.withOpacity(0.85),
                  blurRadius: 14 * p.s,
                  spreadRadius: p.s,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                o.green ? Icons.brightness_1 : Icons.change_history_rounded,
                color: Colors.white.withOpacity(0.9),
                size: sz * 0.46,
              ),
            ),
          ),
        );

      case _ObjType.hurdle:
        final sz = 44.0 * p.s;
        final w2 = sz * 3.4;
        return Positioned(
          left: p.x - w2 / 2,
          top: p.y - sz * 0.7,
          child: SizedBox(
            width: w2,
            height: sz,
            child: CustomPaint(painter: _HurdlePainter(scale: p.s)),
          ),
        );

      case _ObjType.barrier:
        final sz = 72.0 * p.s;
        final w2 = sz * 1.9;
        return Positioned(
          left: p.x - w2 / 2,
          top: p.y - sz,
          child: SizedBox(
            width: w2,
            height: sz,
            child: CustomPaint(painter: _BarrierPainter(scale: p.s)),
          ),
        );

      case _ObjType.shield:
        final sz = 40.0 * p.s;
        return Positioned(
          left: p.x - sz / 2,
          top: p.y - sz,
          child: _powerOrb(sz, '🛡️', const Color(0xFF00B0FF)),
        );

      case _ObjType.magnet:
        final sz = 40.0 * p.s;
        return Positioned(
          left: p.x - sz / 2,
          top: p.y - sz,
          child: _powerOrb(sz, '🧲', const Color(0xFFFFD740)),
        );
    }
  }

  Widget _powerOrb(double sz, String emoji, Color color) => Container(
    width: sz,
    height: sz,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(0.18),
      border: Border.all(color: color, width: 2),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 18),
      ],
    ),
    child: Center(
      child: Text(emoji, style: TextStyle(fontSize: sz * 0.5)),
    ),
  );

  // ─── PLAYER WIDGET ───────────────────────────────────────────────────
  Widget _playerWidget() {
    final p = _pos(0.0, _smoothLane);
    const baseH = 82.0;
    final figH = _sliding ? baseH * 0.52 : baseH;
    final figW = baseH * 0.70;
    final color = _isGreen ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final shadowS = (1.0 - (_jumpY / 115)).clamp(0.2, 1.0);
    final opacity = _invulnFlicker.clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Shadow
        Positioned(
          left: p.x - figW * 0.5 * shadowS,
          top: p.y - 5,
          child: Container(
            width: figW * shadowS,
            height: 7 * shadowS,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55 * shadowS),
              borderRadius: BorderRadius.all(Radius.elliptical(figW * 0.5, 4)),
            ),
          ),
        ),
        // Figure
        Positioned(
          left: p.x - figW / 2,
          top: p.y - figH - 4 - _jumpY,
          child: Transform.rotate(
            angle: _tiltAngle,
            child: Opacity(
              opacity: opacity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shield ring
                  if (_hasShield)
                    Container(
                      width: figW * 1.75,
                      height: figH * 1.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: const Color(
                            0xFF00B0FF,
                          ).withValues(alpha: 0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00B0FF,
                            ).withValues(alpha: 0.22),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  // Magnet ring
                  if (_hasMagnet)
                    Container(
                      width: figW * 1.35,
                      height: figH * 1.2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(
                            0xFFFFD740,
                          ).withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                    ),
                  // Colour aura
                  Container(
                    width: figW * 1.08,
                    height: figH * 1.04,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  // Runner
                  SizedBox(
                    width: figW,
                    height: figH,
                    child: CustomPaint(
                      painter: _RunnerPainter(
                        color: color,
                        runFrame: _runFrame,
                        isSliding: _sliding,
                        isJumping: _jumping,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── HUD ─────────────────────────────────────────────────────────────
  Widget _hud() {
    final col = _isGreen ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final mult = 1.0 + (_combo ~/ 5) * 0.5;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _glassPill(
                  child: GestureDetector(
                    onTap: _playing ? _pause : null,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.pause_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                _glassPill(
                  px: 14,
                  py: 9,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Colors.amberAccent,
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_combo >= 5) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: Colors.amberAccent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'x${mult.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _glassPill(
                  px: 10,
                  py: 9,
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
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // FIX #3: HUD pill shows grace period "SWITCHING..." state
                AnimatedBuilder(
                  animation: _colorPulseCtrl,
                  builder: (context, child) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _colorSwitchGrace
                          ? Colors.white.withValues(alpha: 0.18)
                          : col.withValues(
                              alpha: 0.14 + 0.06 * _colorPulseCtrl.value,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _colorSwitchGrace
                            ? Colors.white.withValues(alpha: 0.60)
                            : col.withValues(
                                alpha: 0.35 + 0.2 * _colorPulseCtrl.value,
                              ),
                        width: _colorSwitchGrace ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _colorSwitchGrace
                              ? Colors.white.withValues(alpha: 0.20)
                              : col.withValues(alpha: 0.12),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _colorSwitchGrace ? Colors.white : col,
                            boxShadow: [
                              BoxShadow(
                                color: _colorSwitchGrace ? Colors.white : col,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _colorSwitchGrace
                              ? '✦ SWITCHING...'
                              : (_isGreen ? 'COLLECT GREEN' : 'COLLECT RED'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_hasShield) ...[
                  const SizedBox(width: 8),
                  _timerBadge(
                    '🛡️',
                    _shieldTimer / 360,
                    const Color(0xFF00B0FF),
                  ),
                ],
                if (_hasMagnet) ...[
                  const SizedBox(width: 8),
                  _timerBadge(
                    '🧲',
                    _magnetTimer / 280,
                    const Color(0xFFFFD740),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SPD',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.17),
                    fontSize: 8,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 54,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ((_speed - 2.2) / 5.8).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation(
                        col.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timerBadge(String emoji, double frac, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        SizedBox(
          width: 26,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: frac.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _glassPill({Widget? child, double px = 10, double py = 10}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: child,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════════════
enum _ObjType { coin, hurdle, barrier, shield, magnet }

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

class _Particle {
  double laneX, life, vx, vy, size;
  Color color;
  _Particle({
    required this.laneX,
    required this.life,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });
}

// ══════════════════════════════════════════════════════════════════
//  RUNNER PAINTER — FIX #4: Improved front-facing Subway Surfers style
//  with shoes, fist dots, helmet shine, torso stripe, better limb physics
// ══════════════════════════════════════════════════════════════════
class _RunnerPainter extends CustomPainter {
  final Color color;
  final double runFrame;
  final bool isSliding;
  final bool isJumping;

  const _RunnerPainter({
    required this.color,
    required this.runFrame,
    required this.isSliding,
    required this.isJumping,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    final s = sz.width / 48.0;

    final glow = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..strokeWidth = 8 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s);

    final body = Paint()
      ..color = color
      ..strokeWidth = 4.2 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final limb = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..strokeWidth = 3.5 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final accent = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()..color = color;
    final whiteFill = Paint()..color = Colors.white;

    if (isSliding) {
      _drawSlide(canvas, sz, s, glow, body, limb, fillPaint, accent);
    } else if (isJumping) {
      _drawJump(canvas, sz, s, glow, body, limb, fillPaint, accent);
    } else {
      _drawRun(canvas, sz, s, glow, body, limb, fillPaint, accent, whiteFill);
    }
  }

  void _drawRun(
    Canvas c,
    Size sz,
    double s,
    Paint glow,
    Paint body,
    Paint limb,
    Paint fill,
    Paint accent,
    Paint whiteFill,
  ) {
    final cx = sz.width * 0.5;
    final H = sz.height;

    final cycle = runFrame;
    final bob = math.sin(cycle * 2) * 1.8 * s;
    final sway = math.sin(cycle) * 0.6 * s;

    // ── HEAD ──
    final headR = 7.2 * s;
    final headCy = H * 0.10 + bob;
    final headCx = cx + sway;

    // Head glow
    c.drawCircle(
      Offset(headCx, headCy),
      headR * 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * s),
    );
    // Head fill
    c.drawCircle(Offset(headCx, headCy), headR, fill);
    // Helmet shine arc
    c.drawArc(
      Rect.fromCircle(
        center: Offset(headCx - 1.5 * s, headCy - 1.5 * s),
        radius: headR * 0.7,
      ),
      -math.pi * 0.9,
      math.pi * 0.5,
      false,
      accent,
    );
    // Face visor
    c.drawArc(
      Rect.fromCircle(
        center: Offset(headCx, headCy + 1.5 * s),
        radius: headR * 0.6,
      ),
      math.pi * 0.05,
      math.pi * 0.9,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s,
    );

    // ── NECK / SHOULDER ──
    final neckY = headCy + headR + 1.5 * s;
    final shoulderY = neckY + 3.5 * s;
    final shoulderW = 11 * s;

    // ── TORSO ──
    final hipY = shoulderY + 16 * s + bob * 0.3;
    final hipCx = headCx + 1.0 * s;

    _ln(c, headCx, shoulderY, hipCx, hipY, glow);
    _ln(c, headCx, shoulderY, hipCx, hipY, body);
    // Torso stripe (Subway Surfers style)
    _ln(
      c,
      headCx,
      shoulderY + 4 * s,
      hipCx,
      hipY - 3 * s,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..strokeWidth = 1.2 * s
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Shoulder line
    _ln(c, headCx - shoulderW, shoulderY, headCx + shoulderW, shoulderY, body);

    // ── ARMS ──
    final armPhaseL = math.sin(cycle + math.pi);
    final armPhaseR = math.sin(cycle);
    const uaL = 10.0;
    const faL = 8.5;

    // LEFT arm
    final lShX = headCx - shoulderW;
    final lElbowX = lShX - uaL * s * math.sin(armPhaseL * 0.5);
    final lElbowY = shoulderY + uaL * s * math.cos(armPhaseL.abs() * 0.4);
    _ln(c, lShX, shoulderY, lElbowX, lElbowY, glow);
    _ln(c, lShX, shoulderY, lElbowX, lElbowY, body);
    final lHandX = lElbowX - faL * s * math.sin(armPhaseL * 0.3);
    final lHandY = lElbowY + faL * s * 0.88;
    _ln(c, lElbowX, lElbowY, lHandX, lHandY, limb);
    c.drawCircle(Offset(lHandX, lHandY), 2.5 * s, fill);

    // RIGHT arm
    final rShX = headCx + shoulderW;
    final rElbowX = rShX + uaL * s * math.sin(armPhaseR * 0.5);
    final rElbowY = shoulderY + uaL * s * math.cos(armPhaseR.abs() * 0.4);
    _ln(c, rShX, shoulderY, rElbowX, rElbowY, glow);
    _ln(c, rShX, shoulderY, rElbowX, rElbowY, body);
    final rHandX = rElbowX + faL * s * math.sin(armPhaseR * 0.3);
    final rHandY = rElbowY + faL * s * 0.88;
    _ln(c, rElbowX, rElbowY, rHandX, rHandY, limb);
    c.drawCircle(Offset(rHandX, rHandY), 2.5 * s, fill);

    // ── LEGS ──
    const thighL = 15.0;
    const shinL = 13.5;
    final hipW = 7.5 * s;

    final phase = math.sin(cycle);
    final kneeRaise = phase.abs();
    final isLeftFwd = phase > 0;

    // LEFT leg
    final lHipX = hipCx - hipW;
    if (isLeftFwd) {
      final lKneeX = lHipX - 4.5 * s * kneeRaise;
      final lKneeY = hipY + thighL * s * (1.0 - kneeRaise * 0.60);
      _ln(c, lHipX, hipY, lKneeX, lKneeY, glow);
      _ln(c, lHipX, hipY, lKneeX, lKneeY, body);
      final lFootX = lKneeX + 5.0 * s * kneeRaise;
      final lFootY = lKneeY + shinL * s * (0.45 + kneeRaise * 0.35);
      _ln(c, lKneeX, lKneeY, lFootX, lFootY, limb);
      _drawShoe(c, lFootX, lFootY, -1, s, fill, accent);
    } else {
      final lKneeX = lHipX + 2.5 * s * kneeRaise;
      final lKneeY = hipY + thighL * s;
      _ln(c, lHipX, hipY, lKneeX, lKneeY, glow);
      _ln(c, lHipX, hipY, lKneeX, lKneeY, body);
      final lFootX = lKneeX + 1.5 * s;
      final lFootY = lKneeY + shinL * s;
      _ln(c, lKneeX, lKneeY, lFootX, lFootY, limb);
      _drawShoe(c, lFootX, lFootY, -1, s, fill, accent);
    }

    // RIGHT leg
    final rHipX = hipCx + hipW;
    if (!isLeftFwd) {
      final rKneeX = rHipX + 4.5 * s * kneeRaise;
      final rKneeY = hipY + thighL * s * (1.0 - kneeRaise * 0.60);
      _ln(c, rHipX, hipY, rKneeX, rKneeY, glow);
      _ln(c, rHipX, hipY, rKneeX, rKneeY, body);
      final rFootX = rKneeX - 5.0 * s * kneeRaise;
      final rFootY = rKneeY + shinL * s * (0.45 + kneeRaise * 0.35);
      _ln(c, rKneeX, rKneeY, rFootX, rFootY, limb);
      _drawShoe(c, rFootX, rFootY, 1, s, fill, accent);
    } else {
      final rKneeX = rHipX - 2.5 * s * kneeRaise;
      final rKneeY = hipY + thighL * s;
      _ln(c, rHipX, hipY, rKneeX, rKneeY, glow);
      _ln(c, rHipX, hipY, rKneeX, rKneeY, body);
      final rFootX = rKneeX - 1.5 * s;
      final rFootY = rKneeY + shinL * s;
      _ln(c, rKneeX, rKneeY, rFootX, rFootY, limb);
      _drawShoe(c, rFootX, rFootY, 1, s, fill, accent);
    }

    // ── MOTION STREAKS ──
    final streak = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = 1.2 * s
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final ly = hipY - 2 * s + i * 7 * s;
      final len = (8 - i * 1.5) * s;
      c.drawLine(
        Offset(cx - 22 * s, ly),
        Offset(cx - 22 * s + len, ly),
        streak,
      );
      c.drawLine(
        Offset(cx + 22 * s - len, ly),
        Offset(cx + 22 * s, ly),
        streak,
      );
    }
  }

  void _drawShoe(
    Canvas c,
    double x,
    double y,
    double dir,
    double s,
    Paint fill,
    Paint accent,
  ) {
    final path = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x + dir * 7 * s, y, x + dir * 8 * s, y + 3 * s)
      ..lineTo(x - dir * 2 * s, y + 3 * s)
      ..close();
    c.drawPath(path, fill);
    c.drawPath(path, accent);
  }

  void _drawJump(
    Canvas c,
    Size sz,
    double s,
    Paint glow,
    Paint body,
    Paint limb,
    Paint fill,
    Paint accent,
  ) {
    final cx = sz.width * 0.5;
    final H = sz.height;

    final headR = 7.2 * s;
    final headCy = H * 0.08;

    c.drawCircle(
      Offset(cx, headCy),
      headR * 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * s),
    );
    c.drawCircle(Offset(cx, headCy), headR, fill);
    c.drawArc(
      Rect.fromCircle(
        center: Offset(cx - 1.5 * s, headCy - 1.5 * s),
        radius: headR * 0.7,
      ),
      -math.pi * 0.9,
      math.pi * 0.5,
      false,
      accent,
    );

    final nY = headCy + headR + 2 * s;
    _ln(c, cx - 11 * s, nY, cx + 11 * s, nY, body);
    _ln(c, cx, nY, cx, nY + 13 * s, glow);
    _ln(c, cx, nY, cx, nY + 13 * s, body);
    final hY = nY + 13 * s;

    // Arms spread for balance
    _ln(c, cx - 11 * s, nY, cx - 22 * s, nY + 8 * s, glow);
    _ln(c, cx - 11 * s, nY, cx - 22 * s, nY + 8 * s, body);
    _ln(c, cx - 22 * s, nY + 8 * s, cx - 16 * s, nY + 17 * s, limb);
    c.drawCircle(Offset(cx - 16 * s, nY + 17 * s), 2.5 * s, fill);

    _ln(c, cx + 11 * s, nY, cx + 22 * s, nY + 8 * s, glow);
    _ln(c, cx + 11 * s, nY, cx + 22 * s, nY + 8 * s, body);
    _ln(c, cx + 22 * s, nY + 8 * s, cx + 16 * s, nY + 17 * s, limb);
    c.drawCircle(Offset(cx + 16 * s, nY + 17 * s), 2.5 * s, fill);

    // Knees tucked
    _ln(c, cx - 7 * s, hY, cx - 15 * s, hY + 12 * s, glow);
    _ln(c, cx - 7 * s, hY, cx - 15 * s, hY + 12 * s, body);
    _ln(c, cx - 15 * s, hY + 12 * s, cx - 10 * s, hY + 23 * s, limb);
    _drawShoe(c, cx - 10 * s, hY + 23 * s, -1, s, fill, accent);

    _ln(c, cx + 7 * s, hY, cx + 15 * s, hY + 12 * s, glow);
    _ln(c, cx + 7 * s, hY, cx + 15 * s, hY + 12 * s, body);
    _ln(c, cx + 15 * s, hY + 12 * s, cx + 10 * s, hY + 23 * s, limb);
    _drawShoe(c, cx + 10 * s, hY + 23 * s, 1, s, fill, accent);

    // Air trail
    final trail = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1.3 * s
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final ly = H * 0.65 + i * 5.5 * s;
      c.drawLine(
        Offset(cx - 9 * s - i * 2.5 * s, ly),
        Offset(cx - 17 * s - i * 2.5 * s, ly),
        trail,
      );
      c.drawLine(
        Offset(cx + 9 * s + i * 2.5 * s, ly),
        Offset(cx + 17 * s + i * 2.5 * s, ly),
        trail,
      );
    }
  }

  void _drawSlide(
    Canvas c,
    Size sz,
    double s,
    Paint glow,
    Paint body,
    Paint limb,
    Paint fill,
    Paint accent,
  ) {
    final cx = sz.width * 0.5;
    final H = sz.height;
    final cy = H * 0.58;

    final headR = 7.2 * s;
    c.drawCircle(
      Offset(cx, cy - 17 * s),
      headR * 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * s),
    );
    c.drawCircle(Offset(cx, cy - 17 * s), headR, fill);
    c.drawArc(
      Rect.fromCircle(
        center: Offset(cx - 1.5 * s, cy - 18.5 * s),
        radius: headR * 0.7,
      ),
      -math.pi * 0.9,
      math.pi * 0.5,
      false,
      accent,
    );

    // Torso crouched
    _ln(c, cx, cy - 10 * s, cx + 3 * s, cy - 2 * s, glow);
    _ln(c, cx, cy - 10 * s, cx + 3 * s, cy - 2 * s, body);
    _ln(c, cx - 11 * s, cy - 10 * s, cx + 11 * s, cy - 10 * s, body);

    // Arms swept back
    _ln(c, cx - 11 * s, cy - 10 * s, cx - 20 * s, cy - 4 * s, glow);
    _ln(c, cx - 11 * s, cy - 10 * s, cx - 20 * s, cy - 4 * s, body);
    _ln(c, cx + 11 * s, cy - 10 * s, cx + 20 * s, cy - 4 * s, glow);
    _ln(c, cx + 11 * s, cy - 10 * s, cx + 20 * s, cy - 4 * s, body);

    // Legs wide, low slide
    _ln(c, cx - 7 * s, cy - 2 * s, cx - 19 * s, cy + 8 * s, glow);
    _ln(c, cx - 7 * s, cy - 2 * s, cx - 19 * s, cy + 8 * s, body);
    _ln(c, cx - 19 * s, cy + 8 * s, cx - 15 * s, cy + 15 * s, limb);
    _drawShoe(c, cx - 15 * s, cy + 15 * s, -1, s, fill, accent);

    _ln(c, cx + 7 * s, cy - 2 * s, cx + 19 * s, cy + 8 * s, glow);
    _ln(c, cx + 7 * s, cy - 2 * s, cx + 19 * s, cy + 8 * s, body);
    _ln(c, cx + 19 * s, cy + 8 * s, cx + 15 * s, cy + 15 * s, limb);
    _drawShoe(c, cx + 15 * s, cy + 15 * s, 1, s, fill, accent);

    // Dust clouds
    final dust = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s);
    for (int i = 1; i <= 4; i++) {
      c.drawCircle(
        Offset(cx - 18 * s - i * 5 * s, cy + 16 * s),
        (5 - i) * 1.6 * s,
        dust,
      );
      c.drawCircle(
        Offset(cx + 18 * s + i * 5 * s, cy + 16 * s),
        (5 - i) * 1.6 * s,
        dust,
      );
    }
  }

  void _ln(Canvas c, double x1, double y1, double x2, double y2, Paint p) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), p);

  @override
  bool shouldRepaint(covariant _RunnerPainter old) =>
      old.runFrame != runFrame ||
      old.color != color ||
      old.isSliding != isSliding ||
      old.isJumping != isJumping;
}

// ══════════════════════════════════════════════════════════════════
//  HURDLE PAINTER
// ══════════════════════════════════════════════════════════════════
class _HurdlePainter extends CustomPainter {
  final double scale;
  _HurdlePainter({required this.scale});
  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height * 0.44;
    canvas.drawLine(
      Offset(size.width * 0.06, mid),
      Offset(size.width * 0.94, mid),
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.5)
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawLine(
      Offset(size.width * 0.06, mid),
      Offset(size.width * 0.94, mid),
      Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    final post = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.1, mid),
      Offset(size.width * 0.1, size.height * 0.92),
      post,
    );
    canvas.drawLine(
      Offset(size.width * 0.9, mid),
      Offset(size.width * 0.9, size.height * 0.92),
      post,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '↑ JUMP',
        style: TextStyle(
          color: Colors.cyanAccent,
          fontSize: 9.5 * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, 0));
  }

  @override
  bool shouldRepaint(CustomPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════
//  BARRIER PAINTER
// ══════════════════════════════════════════════════════════════════
class _BarrierPainter extends CustomPainter {
  final double scale;
  _BarrierPainter({required this.scale});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(5),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF2D1B4E)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    final sw = size.width / 7;
    for (int i = 0; i < 7; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * sw, 0, sw, size.height),
        Paint()
          ..color = (i.isEven ? Colors.red : Colors.yellow).withValues(
            alpha: 0.60,
          ),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(5),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(5),
      ),
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '↓ SLIDE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.32));
  }

  @override
  bool shouldRepaint(CustomPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════
//  WORLD PAINTER — FIX #1: Subway Surfers-style cinematic visuals
// ══════════════════════════════════════════════════════════════════
class _WorldPainter extends CustomPainter {
  final double w, h, roadT, envT, speed, bgT;
  final Color playerColor;

  const _WorldPainter({
    required this.w,
    required this.h,
    required this.roadT,
    required this.envT,
    required this.speed,
    required this.bgT,
    required this.playerColor,
  });

  static const double _hz = 0.28;

  @override
  void paint(Canvas canvas, Size _) {
    final hy = h * _hz;
    final cx = w / 2;
    final rwB = w * 0.92;
    final rwT = w * 0.055;

    // ── DEEP SPACE SKY ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000308),
            Color(0xFF020A1A),
            Color(0xFF061020),
            Color(0xFF0A0818),
          ],
          stops: [0.0, 0.2, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── STARS ──
    final sr = math.Random(42);
    for (int i = 0; i < 110; i++) {
      final sx = sr.nextDouble() * w;
      final sy = sr.nextDouble() * hy * 0.92;
      final base = 0.1 + sr.nextDouble() * 0.6;
      final twinkle = (base + 0.3 * math.sin(bgT * math.pi * 2 + i * 1.3))
          .clamp(0.04, 1.0);
      final sz2 = 0.4 + sr.nextDouble() * 1.6;
      canvas.drawCircle(
        Offset(sx, sy),
        sz2,
        Paint()..color = Colors.white.withValues(alpha: twinkle),
      );
      if (i % 7 == 0) {
        canvas.drawCircle(
          Offset(sx, sy),
          sz2 * 3,
          Paint()
            ..color = Colors.white.withValues(alpha: twinkle * 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // ── MOON with halo ──
    canvas.drawCircle(
      Offset(w * 0.80, hy * 0.22),
      36,
      Paint()
        ..color = const Color(0xFFE8E5CC).withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    canvas.drawCircle(
      Offset(w * 0.80, hy * 0.22),
      21,
      Paint()..color = const Color(0xFFEEEBD5).withValues(alpha: 0.90),
    );
    canvas.drawCircle(
      Offset(w * 0.84, hy * 0.18),
      18,
      Paint()..color = const Color(0xFF050D1E),
    );

    // ── CITYSCAPE SILHOUETTE ──
    final rng = math.Random(99);
    for (int i = 0; i < 28; i++) {
      final bx = rng.nextDouble() * w;
      final bh = hy * (0.20 + rng.nextDouble() * 0.75);
      final bw = 12.0 + rng.nextDouble() * 38;
      canvas.drawRect(
        Rect.fromLTWH(bx - bw / 2, hy - bh, bw, bh + 1),
        Paint()..color = const Color(0xFF060D1A),
      );
      final wCols = (bw / 7).floor().clamp(1, 6);
      final wRows = (bh / 9).floor().clamp(1, 9);
      for (int row = 0; row < wRows; row++) {
        for (int col = 0; col < wCols; col++) {
          if (rng.nextDouble() > 0.52) {
            final winHue = [
              const Color(0xFF1A3A60),
              const Color(0xFF1A2030),
              const Color(0xFF301A40),
              const Color(0xFF102840),
            ][rng.nextInt(4)];
            canvas.drawRect(
              Rect.fromLTWH(
                bx - bw / 2 + col * (bw / wCols) + 1.2,
                hy - bh + row * (bh / wRows) + 2,
                bw / wCols - 2.4,
                bh / wRows - 3.5,
              ),
              Paint()
                ..color = winHue.withValues(
                  alpha: 0.12 + rng.nextDouble() * 0.20,
                ),
            );
          }
        }
      }
      // Antenna
      if (bw > 14 && rng.nextDouble() > 0.5) {
        canvas.drawLine(
          Offset(bx + bw * 0.5, hy - bh),
          Offset(bx + bw * 0.5, hy - bh - 14),
          Paint()
            ..color = Colors.blueGrey.withValues(alpha: 0.5)
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          Offset(bx + bw * 0.5, hy - bh - 14),
          2.5,
          Paint()..color = Colors.redAccent.withValues(alpha: 0.7),
        );
      }
    }

    // ── GROUND ──
    canvas.drawRect(
      Rect.fromLTWH(0, hy, w, h - hy),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF080F18), const Color(0xFF020508)],
        ).createShader(Rect.fromLTWH(0, hy, w, h - hy)),
    );

    // ── ROAD TRAPEZOID ──
    final roadPath = Path()
      ..moveTo(cx - rwT / 2, hy)
      ..lineTo(cx + rwT / 2, hy)
      ..lineTo(cx + rwB / 2, h)
      ..lineTo(cx - rwB / 2, h)
      ..close();
    canvas.drawPath(
      roadPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF0D1828), const Color(0xFF0A1220)],
        ).createShader(Rect.fromLTWH(0, hy, w, h - hy)),
    );

    // ── ROAD SURFACE TEXTURE ──
    for (int i = 0; i < 14; i++) {
      final t = (i / 14 + roadT * 0.5) % 1.0;
      final pt = t * t;
      final y = hy + (h - hy) * pt;
      final rw = rwT + (rwB - rwT) * pt;
      canvas.drawLine(
        Offset(cx - rw / 2, y),
        Offset(cx + rw / 2, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.012 * pt)
          ..strokeWidth = 0.5,
      );
    }

    // ── LANE DASHES ──
    for (final f in [-0.333, 0.333]) {
      for (int i = 0; i < 12; i++) {
        final t = (i / 12 + roadT) % 1.0;
        final pt = t * t;
        final y = hy + (h - hy) * pt;
        final rw = rwT + (rwB - rwT) * pt;
        final dl = 5 + 26 * pt;
        if (y > hy + 6 && y < h - 5) {
          canvas.drawLine(
            Offset(cx + f * rw / 2, y - dl / 2),
            Offset(cx + f * rw / 2, y + dl / 2),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.048 + 0.06 * pt)
              ..strokeWidth = 0.9 + 2.4 * pt
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // ── NEON ROAD EDGES (triple-layer: wide glow + medium + white core) ──
    for (final side in [-1.0, 1.0]) {
      // Wide soft glow
      canvas.drawLine(
        Offset(cx + side * rwT / 2, hy),
        Offset(cx + side * rwB / 2, h),
        Paint()
          ..color = playerColor.withValues(alpha: 0.25)
          ..strokeWidth = 14
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      // Medium glow
      canvas.drawLine(
        Offset(cx + side * rwT / 2, hy),
        Offset(cx + side * rwB / 2, h),
        Paint()
          ..color = playerColor.withValues(alpha: 0.45)
          ..strokeWidth = 4,
      );
      // Core white line
      canvas.drawLine(
        Offset(cx + side * rwT / 2, hy),
        Offset(cx + side * rwB / 2, h),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 1.2,
      );
    }

    // ── CENTER LANE GLOW ──
    for (int i = 0; i < 10; i++) {
      final t = (i / 10 + roadT * 1.2) % 1.0;
      final pt = t * t;
      final y = hy + (h - hy) * pt;
      final dl = 8 + 20 * pt;
      if (y > hy + 6 && y < h - 5) {
        canvas.drawLine(
          Offset(cx, y - dl / 2),
          Offset(cx, y + dl / 2),
          Paint()
            ..color = playerColor.withValues(alpha: 0.06 + 0.10 * pt)
            ..strokeWidth = 1.0 + 1.5 * pt
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── EDGE GLOW DOTS ──
    final dotP = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (int i = 0; i < 9; i++) {
      final t = (i / 9 + roadT) % 1.0;
      final pt = t * t;
      final y = hy + (h - hy) * pt;
      final rw = rwT + (rwB - rwT) * pt;
      dotP.color = playerColor.withValues(
        alpha: (0.25 + 0.75 * pt).clamp(0.0, 0.9),
      );
      canvas.drawCircle(Offset(cx - rw / 2 - 6, y), 2.5 * pt + 0.8, dotP);
      canvas.drawCircle(Offset(cx + rw / 2 + 6, y), 2.5 * pt + 0.8, dotP);
    }

    // ── SIDE BUILDINGS (parallax) ──
    final bldRng = math.Random(55);
    final glowColors = [
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.blueAccent,
      playerColor,
    ];
    for (int i = 0; i < 14; i++) {
      final t = (i / 14 + envT * 0.40) % 1.0;
      final pt = t * t;
      final y = hy + (h - hy) * pt;
      final bw = 12 + 52 * pt;
      final bh = 30 + 160 * pt;
      final rw = rwT + (rwB - rwT) * pt;
      final side = i < 7 ? -1.0 : 1.0;
      final bx = side < 0 ? cx - rw / 2 - bw - 6 : cx + rw / 2 + 6;
      if (y < hy + 5) continue;

      canvas.drawRect(
        Rect.fromLTWH(bx, y - bh, bw, bh),
        Paint()..color = const Color(0xFF060C18),
      );
      if (bw > 16) {
        final gc = glowColors[bldRng.nextInt(4)];
        for (int row = 1; row <= 5; row++) {
          if (bldRng.nextDouble() > 0.42) {
            canvas.drawRect(
              Rect.fromLTWH(
                bx + bw * 0.12,
                y - bh * row / 5.2,
                bw * 0.76,
                bh * 0.048,
              ),
              Paint()
                ..color = gc.withValues(
                  alpha: (0.06 + 0.18 * pt).clamp(0.0, 0.35),
                )
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
          }
        }
      }
    }

    // ── VANISHING POINT GLOW ──
    canvas.drawCircle(
      Offset(cx, hy),
      90,
      Paint()
        ..shader = RadialGradient(
          colors: [playerColor.withValues(alpha: 0.28), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(cx, hy), radius: 90)),
    );

    // ── HORIZON FOG BAND ──
    canvas.drawRect(
      Rect.fromLTWH(0, hy - 18, w, 36),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            playerColor.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, hy - 18, w, 36)),
    );

    // ── SPEED LINES ──
    if (speed > 4.0) {
      final intensity = ((speed - 4.0) / 4.0).clamp(0.0, 1.0);
      final slRng = math.Random(77);
      for (int i = 0; i < 10; i++) {
        final t = slRng.nextDouble();
        final pt = t * t;
        final y = hy + (h - hy) * pt;
        final rw = rwT + (rwB - rwT) * pt;
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(cx + side * rw * 0.32, y),
            Offset(cx + side * rw * 0.44, y + 18 * pt),
            Paint()
              ..color = playerColor.withValues(alpha: 0.08 * intensity * pt)
              ..strokeWidth = 1.4 * pt,
          );
        }
      }
    }

    // ── CINEMATIC VIGNETTE ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) =>
      old.roadT != roadT ||
      old.envT != envT ||
      old.playerColor != playerColor ||
      old.bgT != bgT;
}

// ══════════════════════════════════════════════════════════════════
//  GRID PAINTER — intro animated grid
// ══════════════════════════════════════════════════════════════════
class _GridPainter extends CustomPainter {
  final double t;
  final Color color;
  const _GridPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const sp = 44.0;
    final off = (t * sp) % sp;
    for (double x = 0; x < size.width; x += sp) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = -sp + off; y < size.height; y += sp) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.t != t;
}
