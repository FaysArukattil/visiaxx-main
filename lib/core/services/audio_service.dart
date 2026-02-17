import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sound_library/sound_library.dart'; // Removed unreliable remote library

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();

  // Larger pool for heavy concurrent playback (prevents timeouts and lag)
  final List<AudioPlayer> _sfxPlayerPool = List.generate(
    10,
    (_) => AudioPlayer(),
  );
  int _currentPlayerIndex = 0;

  bool _isSoundEnabled = true;
  bool get isSoundEnabled => _isSoundEnabled;

  static const String _soundEnabledKey = 'game_sound_enabled';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool(_soundEnabledKey) ?? true;

    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    // Initialize all SFX players with auto-cleanup
    for (var player in _sfxPlayerPool) {
      player.setReleaseMode(ReleaseMode.release);
      player.setVolume(0.7); // Slightly lower to reduce processing load

      // Auto-stop on complete to free up resources immediately
      player.onPlayerComplete.listen((_) {
        player.stop();
      });
    }
  }

  Future<void> toggleSound() async {
    _isSoundEnabled = !_isSoundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, _isSoundEnabled);

    if (!_isSoundEnabled) {
      await _bgmPlayer.stop();
      for (var player in _sfxPlayerPool) {
        await player.stop();
      }
    }
  }

  // --- BGM Methods (Used in non-game areas or titles) ---

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
    await _bgmPlayer.stop();
  }

  Future<void> pauseBGM() async {
    await _bgmPlayer.pause();
  }

  Future<void> resumeBGM() async {
    if (!_isSoundEnabled) return;
    await _bgmPlayer.resume();
  }

  // ===== BRICK & BALL GAME SFX =====

  void playBrickSmash() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/brick_ball/brick_smash.mp3');
  }

  void playPaddleBounce() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/brick_ball/paddle_bounce.mp3');
  }

  void playBallMultiply() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/brick_ball/ball_multiply.mp3');
  }

  void playLifeLost() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/brick_ball/life_lost.mp3');
  }

  void playBallSpawn() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/brick_ball/ball_spawn.mp3');
  }

  // ===== WORD PUZZLE / EYE QUEST SFX =====

  void playKeyTap() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/word_puzzle/key_tap.mp3');
  }

  void playWordCorrect() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/word_puzzle/word_correct.mp3');
  }

  void playWordPartial() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/word_puzzle/word_partial.mp3');
  }

  void playKeyDelete() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/word_puzzle/key_delete.mp3');
  }

  void playPuzzleGameOver() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/word_puzzle/puzzle_gameover.mp3');
  }

  void playPuzzleLevelUp() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/word_puzzle/puzzle_levelup.mp3');
  }

  // ===== OCULAR SNAKE SFX =====

  void playSnakeEat() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/snake/snake_eat.mp3');
  }

  void playSnakeCrash() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/snake/snake_crash.mp3');
  }

  void playSnakeGameOver() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/snake/snake_gameover.mp3');
  }

  void playSnakeLevelUp() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/snake/snake_levelup.mp3');
  }

  // ===== LEGACY / GENERAL SFX (Kept for backward compatibility) =====

  void playClick() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/click.mp3');
  }

  void playAction() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/hit.mp3');
  }

  void playSuccess() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/success.mp3');
  }

  void playGameOver() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/game_over.mp3');
  }

  void playWelcome() {
    if (!_isSoundEnabled) return;
    playSFX('sounds/click.mp3');
  }

  // Generic SFX player - NON-BLOCKING fire-and-forget for performance
  void playSFX(String assetPath) {
    if (!_isSoundEnabled) return;
    try {
      // Get next player in pool (circular)
      final player = _sfxPlayerPool[_currentPlayerIndex];
      _currentPlayerIndex = (_currentPlayerIndex + 1) % _sfxPlayerPool.length;

      // Stop any currently playing sound on this player
      player.stop();

      // Fire-and-forget play (NO await to prevent blocking/timeouts)
      player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('[AudioService] Error playing SFX: $e');
    }
  }

  void dispose() {
    _bgmPlayer.dispose();
    for (var player in _sfxPlayerPool) {
      player.dispose();
    }
  }
}
