import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/music_track.dart';
import '../../core/services/music_service.dart';

/// Playback repeat mode
enum RepeatMode { off, all, one }

/// Central provider for music playback, likes, and playlists
class MusicProvider extends ChangeNotifier {
  final MusicService _service = MusicService();
  final AudioPlayer _player = AudioPlayer();

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  List<MusicTrack> _allTracks = [];
  List<MusicTrack> get allTracks => _allTracks;

  // Playback
  MusicTrack? _currentTrack;
  MusicTrack? get currentTrack => _currentTrack;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  bool _shuffle = false;
  bool get shuffle => _shuffle;

  RepeatMode _repeatMode = RepeatMode.off;
  RepeatMode get repeatMode => _repeatMode;

  List<MusicTrack> _queue = [];
  List<MusicTrack> get queue => _queue;

  int _queueIndex = -1;

  // Likes
  Set<String> _likedTrackIds = {};
  Set<String> get likedTrackIds => _likedTrackIds;
  Map<String, int> _likeCounts = {};
  Map<String, int> get likeCounts => _likeCounts;

  List<MusicTrack> get likedTracks =>
      _allTracks.where((t) => _likedTrackIds.contains(t.id)).toList();

  // Playlists
  List<MusicPlaylist> _playlists = [];
  List<MusicPlaylist> get playlists => _playlists;

  // User
  String? _userId;
  bool _initialized = false;

  // ═══════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════

  Future<void> initialize(String userId) async {
    if (_initialized && _userId == userId) return;
    _userId = userId;
    _allTracks = MusicLibrary.allTracks;

    // Setup audio player listeners
    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _player.onPlayerComplete.listen((_) {
      _onTrackComplete();
    });

    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    // Load user data from Firestore
    await _loadUserData();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    if (_userId == null) return;
    try {
      final results = await Future.wait([
        _service.getUserLikedTrackIds(_userId!),
        _service.getAllLikeCounts(),
        _service.getUserPlaylists(_userId!),
      ]);
      _likedTrackIds = results[0] as Set<String>;
      _likeCounts = results[1] as Map<String, int>;
      _playlists = results[2] as List<MusicPlaylist>;
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicProvider] Error loading user data: $e');
    }
  }

  // ═══════════════════════════════════════════
  // PLAYBACK
  // ═══════════════════════════════════════════

  /// Play a specific track
  Future<void> playTrack(
    MusicTrack track, {
    List<MusicTrack>? playQueue,
  }) async {
    try {
      _currentTrack = track;

      if (playQueue != null) {
        _queue = List.from(playQueue);
        _queueIndex = _queue.indexWhere((t) => t.id == track.id);
      } else if (_queue.isEmpty) {
        _queue = List.from(_allTracks);
        _queueIndex = _queue.indexWhere((t) => t.id == track.id);
      } else {
        _queueIndex = _queue.indexWhere((t) => t.id == track.id);
        if (_queueIndex == -1) {
          _queue = List.from(_allTracks);
          _queueIndex = _queue.indexWhere((t) => t.id == track.id);
        }
      }

      await _player.stop();
      await _player.play(
        AssetSource(track.assetPath.replaceFirst('assets/', '')),
      );
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicProvider] Error playing track: $e');
    }
  }

  /// Stop playback and clear current track status
  Future<void> stopAndClear() async {
    try {
      await _player.stop();
      _currentTrack = null;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicProvider] Error stopping and clearing: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_currentTrack == null) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.resume();
      }
    } catch (e) {
      debugPrint('[MusicProvider] Error toggling playback: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[MusicProvider] Error pausing: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[MusicProvider] Error seeking: $e');
    }
  }

  /// Skip to next track
  Future<void> skipNext() async {
    if (_queue.isEmpty) return;

    if (_shuffle) {
      final random = Random();
      int newIndex;
      do {
        newIndex = random.nextInt(_queue.length);
      } while (newIndex == _queueIndex && _queue.length > 1);
      _queueIndex = newIndex;
    } else {
      _queueIndex = (_queueIndex + 1) % _queue.length;
    }

    await playTrack(_queue[_queueIndex]);
  }

  /// Skip to previous track
  Future<void> skipPrevious() async {
    if (_queue.isEmpty) return;

    // If more than 3 seconds in, restart current track
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_shuffle) {
      final random = Random();
      int newIndex;
      do {
        newIndex = random.nextInt(_queue.length);
      } while (newIndex == _queueIndex && _queue.length > 1);
      _queueIndex = newIndex;
    } else {
      _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
    }

    await playTrack(_queue[_queueIndex]);
  }

  /// Handle track completion
  void _onTrackComplete() {
    switch (_repeatMode) {
      case RepeatMode.one:
        if (_currentTrack != null) playTrack(_currentTrack!);
        break;
      case RepeatMode.all:
        skipNext();
        break;
      case RepeatMode.off:
        if (_queueIndex < _queue.length - 1) {
          skipNext();
        } else {
          _isPlaying = false;
          notifyListeners();
        }
        break;
    }
  }

  /// Toggle shuffle
  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  /// Cycle repeat mode
  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        break;
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // LIKES
  // ═══════════════════════════════════════════

  bool isLiked(String trackId) => _likedTrackIds.contains(trackId);

  int getLikeCount(String trackId) => _likeCounts[trackId] ?? 0;

  /// Toggle like with optimistic update
  Future<void> toggleLike(String trackId) async {
    if (_userId == null) return;

    // Optimistic update
    final wasLiked = _likedTrackIds.contains(trackId);
    if (wasLiked) {
      _likedTrackIds.remove(trackId);
      _likeCounts[trackId] = (_likeCounts[trackId] ?? 1) - 1;
    } else {
      _likedTrackIds.add(trackId);
      _likeCounts[trackId] = (_likeCounts[trackId] ?? 0) + 1;
    }
    notifyListeners();

    // Sync to Firestore
    try {
      await _service.toggleLike(trackId, _userId!);
    } catch (e) {
      // Revert on error
      if (wasLiked) {
        _likedTrackIds.add(trackId);
        _likeCounts[trackId] = (_likeCounts[trackId] ?? 0) + 1;
      } else {
        _likedTrackIds.remove(trackId);
        _likeCounts[trackId] = (_likeCounts[trackId] ?? 1) - 1;
      }
      notifyListeners();
      debugPrint('[MusicProvider] Error toggling like: $e');
    }
  }

  // ═══════════════════════════════════════════
  // PLAYLISTS
  // ═══════════════════════════════════════════

  /// Create a new playlist
  Future<void> createPlaylist(
    String name, {
    List<String> trackIds = const [],
  }) async {
    if (_userId == null) return;
    try {
      final id = await _service.createPlaylist(
        _userId!,
        name,
        trackIds: trackIds,
      );
      if (id != null) {
        _playlists.insert(
          0,
          MusicPlaylist(
            id: id,
            name: name,
            trackIds: trackIds,
            createdAt: DateTime.now(),
          ),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MusicProvider] Error creating playlist: $e');
    }
  }

  /// Add track to a playlist
  Future<void> addToPlaylist(String playlistId, String trackId) async {
    if (_userId == null) return;
    try {
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final updated = _playlists[idx].copyWith(
          trackIds: [..._playlists[idx].trackIds, trackId],
        );
        _playlists[idx] = updated;
        notifyListeners();
        await _service.addToPlaylist(_userId!, playlistId, trackId);
      }
    } catch (e) {
      debugPrint('[MusicProvider] Error adding to playlist: $e');
    }
  }

  /// Remove track from playlist
  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    if (_userId == null) return;
    try {
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        final updated = _playlists[idx].copyWith(
          trackIds: _playlists[idx].trackIds
              .where((id) => id != trackId)
              .toList(),
        );
        _playlists[idx] = updated;
        notifyListeners();
        await _service.removeFromPlaylist(_userId!, playlistId, trackId);
      }
    } catch (e) {
      debugPrint('[MusicProvider] Error removing from playlist: $e');
    }
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String playlistId) async {
    if (_userId == null) return;
    try {
      _playlists.removeWhere((p) => p.id == playlistId);
      notifyListeners();
      await _service.deletePlaylist(_userId!, playlistId);
    } catch (e) {
      debugPrint('[MusicProvider] Error deleting playlist: $e');
    }
  }

  /// Rename a playlist
  Future<void> renamePlaylist(String playlistId, String newName) async {
    if (_userId == null) return;
    try {
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx != -1) {
        _playlists[idx] = _playlists[idx].copyWith(name: newName);
        notifyListeners();
        await _service.renamePlaylist(_userId!, playlistId, newName);
      }
    } catch (e) {
      debugPrint('[MusicProvider] Error renaming playlist: $e');
    }
  }

  /// Get tracks for a playlist
  List<MusicTrack> getPlaylistTracks(String playlistId) {
    final playlist = _playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => MusicPlaylist(
        id: '',
        name: '',
        trackIds: [],
        createdAt: DateTime.now(),
      ),
    );
    return playlist.trackIds
        .map(
          (id) => _allTracks.firstWhere(
            (t) => t.id == id,
            orElse: () => _allTracks.first,
          ),
        )
        .toList();
  }

  /// Play all tracks in a playlist
  Future<void> playPlaylist(String playlistId, {bool shuffled = false}) async {
    final tracks = getPlaylistTracks(playlistId);
    if (tracks.isEmpty) return;

    if (shuffled) {
      final shuffledTracks = List<MusicTrack>.from(tracks)..shuffle();
      await playTrack(shuffledTracks.first, playQueue: shuffledTracks);
    } else {
      await playTrack(tracks.first, playQueue: tracks);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
