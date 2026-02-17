import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sound_library/sound_library.dart'; // Removed unreliable remote library

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _isSoundEnabled = true;
  bool get isSoundEnabled => _isSoundEnabled;

  static const String _soundEnabledKey = 'game_sound_enabled';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool(_soundEnabledKey) ?? true;

    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> toggleSound() async {
    _isSoundEnabled = !_isSoundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, _isSoundEnabled);

    if (!_isSoundEnabled) {
      await _bgmPlayer.stop();
      await _sfxPlayer.stop();
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

  // Generic fallback if needed
  Future<void> playSFX(String assetPath) async {
    if (!_isSoundEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('[AudioService] Error playing SFX: $e');
    }
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
