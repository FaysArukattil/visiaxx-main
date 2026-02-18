import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crash-proof audio service with audio-focus disabled on SFX players.
///
/// Root cause of previous hangs: each AudioPlayer requests Android audio focus
/// on play(), causing O(n²) onAudioFocusChange callbacks that overwhelm the
/// main thread (233 frames skipped → 30s timeout). Fix: set
/// AndroidAudioFocus.none on all SFX players so they never fight for focus.
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();

  // 3 SFX players — focus disabled, so no cascade
  final List<AudioPlayer> _players = List.generate(3, (_) => AudioPlayer());
  int _nextPlayer = 0;

  // Throttle: prevent same sound spamming
  final Map<String, int> _lastPlayTime = {};
  static const int _minIntervalMs = 150;

  bool _isSoundEnabled = true;
  bool get isSoundEnabled => _isSoundEnabled;

  bool _isInitialized = false;

  static const String _soundEnabledKey = 'game_sound_enabled';

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isSoundEnabled = prefs.getBool(_soundEnabledKey) ?? true;

      _bgmPlayer.setReleaseMode(ReleaseMode.loop);

      // KEY FIX: Disable audio focus on SFX players to prevent the N²
      // onAudioFocusChange cascade that causes hangs and TimeoutExceptions.
      final noFocusContext = AudioContext(
        android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
      );

      for (var p in _players) {
        await p.setReleaseMode(ReleaseMode.release);
        await p.setAudioContext(noFocusContext);
      }
    } catch (e) {
      debugPrint('[AudioService] Init error (ignored): $e');
    }
  }

  Future<void> toggleSound() async {
    _isSoundEnabled = !_isSoundEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _isSoundEnabled);
    } catch (_) {}

    if (!_isSoundEnabled) {
      try {
        await _bgmPlayer.stop();
      } catch (_) {}
      for (var p in _players) {
        try {
          await p.stop();
        } catch (_) {}
      }
    }
  }

  // --- BGM Methods ---

  Future<void> playBGM(String assetPath) async {
    if (!_isSoundEnabled) return;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource(assetPath));
      await _bgmPlayer.setVolume(0.4);
    } catch (e) {
      debugPrint('[AudioService] Error playing BGM: $e');
    }
  }

  Future<void> stopBGM() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> pauseBGM() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeBGM() async {
    if (!_isSoundEnabled) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  // ===== BRICK & BALL GAME SFX =====

  void playBrickSmash() => playSFX('sounds/brick_ball/brick_smash.mp3');
  void playPaddleBounce() => playSFX('sounds/brick_ball/paddle_bounce.mp3');
  void playBallMultiply() => playSFX('sounds/brick_ball/ball_multiply.mp3');
  void playLifeLost() => playSFX('sounds/brick_ball/life_lost_subtle.mp3');
  void playBallOut() => playSFX('sounds/brick_ball/ball_out_subtle.mp3');
  void playBallSpawn() => playSFX('sounds/brick_ball/ball_spawn.mp3');

  // ===== WORD PUZZLE / EYE QUEST SFX =====

  void playKeyTap() => playSFX('sounds/word_puzzle/key_tap.mp3');
  void playWordCorrect() => playSFX('sounds/word_puzzle/word_correct.mp3');
  void playWordPartial() => playSFX('sounds/word_puzzle/word_partial.mp3');
  void playKeyDelete() => playSFX('sounds/word_puzzle/key_delete.mp3');
  void playPuzzleGameOver() => playSFX('sounds/snake/snake_gameover.mp3');
  void playPuzzleLevelUp() => playSFX('sounds/word_puzzle/puzzle_levelup.mp3');

  // ===== OCULAR SNAKE SFX =====

  void playSnakeEat() => playSFX('sounds/snake/snake_eat_subtle.mp3');
  void playSnakeCrash() => playSFX('sounds/snake/snake_crash.mp3');
  void playSnakeGameOver() => playSFX('sounds/snake/snake_gameover.mp3');
  void playSnakeLevelUp() => playSFX('sounds/snake/snake_levelup.mp3');

  // ===== COLOR RUSH SFX =====

  void playCoinCollect() => playSFX('sounds/snake/snake_eat_subtle.mp3');
  void playColorSwitch() => playSFX('sounds/click.mp3');
  void playWrongCoin() => playSFX('sounds/brick_ball/life_lost.mp3');

  // ===== LEGACY / GENERAL =====

  void playClick() => playSFX('sounds/click.mp3');
  void playAction() => playSFX('sounds/hit.mp3');
  void playSuccess() => playSFX('sounds/success.mp3');
  void playGameOver() => playSFX('sounds/snake/snake_gameover.mp3');
  void playWelcome() => playSFX('sounds/click.mp3');

  // ===== CORE SFX ENGINE =====
  void playSFX(String assetPath) {
    if (!_isSoundEnabled) return;

    // Throttle
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastPlayTime[assetPath] ?? 0;
    if (now - lastTime < _minIntervalMs) return;
    _lastPlayTime[assetPath] = now;

    // Round-robin across 3 focus-free players
    final player = _players[_nextPlayer % _players.length];
    _nextPlayer++;

    // Stop → play, swallow all errors
    try {
      final source = assetPath.startsWith('http')
          ? UrlSource(assetPath)
          : AssetSource(assetPath);
      player
          .stop()
          .then((_) {
            player.play(source).catchError((e) {
              debugPrint('[AudioService] SFX play error (ignored): $e');
              return;
            });
          })
          .catchError((e) {
            player.play(source).catchError((e2) {
              debugPrint('[AudioService] SFX fallback error (ignored): $e2');
              return;
            });
          });
    } catch (e) {
      debugPrint('[AudioService] SFX sync error (ignored): $e');
    }
  }

  void stopAllSFX() {
    for (var p in _players) {
      try {
        p.stop();
      } catch (_) {}
    }
  }

  void dispose() {
    _bgmPlayer.dispose();
    for (var p in _players) {
      try {
        p.dispose();
      } catch (_) {}
    }
  }
}
