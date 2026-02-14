import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/music_track.dart';
import '../../../data/providers/music_provider.dart';

/// Full-screen now-playing music interface
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, music, _) {
        if (music.currentTrack == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'No track playing',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
          );
        }

        final track = music.currentTrack!;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  track.primaryColor.withValues(alpha: 0.3),
                  context.scaffoldBackground,
                  context.scaffoldBackground,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // App bar
                  _buildAppBar(context, track),
                  const Spacer(flex: 1),
                  // Album art
                  _buildAlbumArt(context, track, music),
                  const Spacer(flex: 1),
                  // Track info
                  _buildTrackInfo(context, track, music),
                  const SizedBox(height: 28),
                  // Seek bar
                  _buildSeekBar(context, music),
                  const SizedBox(height: 24),
                  // Controls
                  _buildControls(context, music),
                  const SizedBox(height: 24),
                  // Bottom actions
                  _buildBottomActions(context, music, track),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, MusicTrack track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Swipe down indicator
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: context.primary,
                  size: 24,
                ),
              ),
            ),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: context.primary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildAlbumArt(
    BuildContext context,
    MusicTrack track,
    MusicProvider music,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = screenWidth * 0.7;

    return Center(
          child: Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [track.primaryColor, track.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: track.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 5,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: track.secondaryColor.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(-10, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative large icon
                Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Colors.white.withValues(alpha: 0.15),
                    size: artSize * 0.5,
                  ),
                ),
                // Animated equalizer when playing
                if (music.isPlaying)
                  Center(
                    child:
                        Icon(
                              Icons.equalizer_rounded,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 48,
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .scaleXY(
                              begin: 0.9,
                              end: 1.1,
                              duration: 800.ms,
                              curve: Curves.easeInOut,
                            )
                            .then()
                            .scaleXY(
                              begin: 1.1,
                              end: 0.9,
                              duration: 800.ms,
                              curve: Curves.easeInOut,
                            ),
                  ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .scaleXY(begin: 0.9, end: 1.0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildTrackInfo(
    BuildContext context,
    MusicTrack track,
    MusicProvider music,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            track.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            track.artist,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildSeekBar(BuildContext context, MusicProvider music) {
    final pos = music.position;
    final dur = music.duration;
    final progress = dur.inMilliseconds > 0
        ? pos.inMilliseconds / dur.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: context.primary,
              inactiveTrackColor: context.primary.withValues(alpha: 0.15),
              thumbColor: context.primary,
              overlayColor: context.primary.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (val) {
                if (dur.inMilliseconds > 0) {
                  final newPos = Duration(
                    milliseconds: (val * dur.inMilliseconds).round(),
                  );
                  music.seek(newPos);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  MusicTrack.formatDuration(pos),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textTertiary,
                  ),
                ),
                Text(
                  MusicTrack.formatDuration(dur),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildControls(BuildContext context, MusicProvider music) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => music.toggleShuffle(),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.shuffle_rounded,
                  color: music.shuffle ? context.primary : context.textTertiary,
                  size: 24,
                ),
              ),
            ),
          ),

          // Previous
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => music.skipPrevious(),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.skip_previous_rounded,
                  color: context.textPrimary,
                  size: 34,
                ),
              ),
            ),
          ),

          // Play/Pause
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => music.togglePlayPause(),
              borderRadius: BorderRadius.circular(36),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.primary,
                      context.primary.withValues(alpha: 0.85),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  music.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: context.onPrimary,
                  size: 36,
                ),
              ),
            ),
          ),

          // Next
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => music.skipNext(),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.skip_next_rounded,
                  color: context.textPrimary,
                  size: 34,
                ),
              ),
            ),
          ),

          // Repeat
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => music.cycleRepeatMode(),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  music.repeatMode == RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: music.repeatMode != RepeatMode.off
                      ? context.primary
                      : context.textTertiary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 350.ms);
  }

  Widget _buildBottomActions(
    BuildContext context,
    MusicProvider music,
    MusicTrack track,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Like
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => music.toggleLike(track.id),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      music.isLiked(track.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: music.isLiked(track.id)
                          ? context.error
                          : context.textTertiary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${music.getLikeCount(track.id)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Add to playlist
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAddToPlaylistSheet(context, track, music),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.playlist_add_rounded,
                      color: context.textTertiary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Queue
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      color: context.textTertiary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Queue',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  void _showAddToPlaylistSheet(
    BuildContext context,
    MusicTrack track,
    MusicProvider music,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add "${track.title}" to playlist:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (music.playlists.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No playlists yet. Create one from the library.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              ...music.playlists.map((playlist) {
                final alreadyIn = playlist.trackIds.contains(track.id);
                return ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: context.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    playlist.name,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: alreadyIn
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.success,
                          size: 22,
                        )
                      : null,
                  onTap: alreadyIn
                      ? null
                      : () {
                          music.addToPlaylist(playlist.id, track.id);
                          Navigator.pop(ctx);
                        },
                );
              }),
          ],
        ),
      ),
    );
  }
}
