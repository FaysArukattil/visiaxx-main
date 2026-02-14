import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/music_track.dart';
import '../../../data/providers/music_provider.dart';
import '../../../core/services/music_service.dart';
import 'now_playing_screen.dart';

/// Playlist detail screen showing tracks in a playlist
class PlaylistScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, music, _) {
        final playlist = music.playlists.firstWhere(
          (p) => p.id == playlistId,
          orElse: () => MusicPlaylist(
            id: '',
            name: 'Unknown',
            trackIds: [],
            createdAt: DateTime.now(),
          ),
        );
        final tracks = music.getPlaylistTracks(playlistId);

        // Get gradient from first track or use primary
        Color gradStart = context.primary;
        Color gradEnd = context.primary.withValues(alpha: 0.5);
        if (tracks.isNotEmpty) {
          gradStart = tracks.first.primaryColor;
          gradEnd = tracks.first.secondaryColor;
        }

        return Scaffold(
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            gradStart.withValues(alpha: 0.4),
                            context.scaffoldBackground,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            // App bar
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: Row(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Navigator.pop(context),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.arrow_back_rounded,
                                          color: context.textPrimary,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showPlaylistOptions(
                                        context,
                                        playlist,
                                        music,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.more_horiz_rounded,
                                          color: context.textPrimary,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Playlist art
                            Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [gradStart, gradEnd],
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradStart.withValues(alpha: 0.4),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.queue_music_rounded,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 56,
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .scaleXY(begin: 0.9, end: 1.0),

                            const SizedBox(height: 20),

                            // Playlist name
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Text(
                                playlist.name,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 6),
                            Text(
                              '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Play / Shuffle buttons
                            if (tracks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Play all
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () =>
                                              music.playPlaylist(playlistId),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  context.primary,
                                                  context.primary.withValues(
                                                    alpha: 0.85,
                                                  ),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: context.primary
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: context.onPrimary,
                                                  size: 22,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Play All',
                                                  style: TextStyle(
                                                    color: context.onPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Shuffle
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => music.playPlaylist(
                                            playlistId,
                                            shuffled: true,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.primary.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: context.primary
                                                    .withValues(alpha: 0.2),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.shuffle_rounded,
                                                  color: context.primary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Shuffle',
                                                  style: TextStyle(
                                                    color: context.primary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(
                                duration: 300.ms,
                                delay: 200.ms,
                              ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Track list
                  tracks.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.music_off_rounded,
                                  size: 56,
                                  color: context.textTertiary,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No tracks yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Add tracks from the library',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            music.currentTrack != null ? 100 : 20,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final track = tracks[index];
                              final isCurrentTrack =
                                  music.currentTrack?.id == track.id;
                              return _buildTrackTile(
                                context,
                                track,
                                music,
                                isCurrentTrack,
                                index,
                                tracks,
                              );
                            }, childCount: tracks.length),
                          ),
                        ),
                ],
              ),

              // Mini player
              if (music.currentTrack != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildMiniPlayer(context, music),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    MusicTrack track,
    MusicProvider music,
    bool isCurrentTrack,
    int index,
    List<MusicTrack> playQueue,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => music.playTrack(track, playQueue: playQueue),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrentTrack
                  ? context.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isCurrentTrack
                  ? Border.all(color: context.primary.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              children: [
                // Track number or album art
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [track.primaryColor, track.secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isCurrentTrack && music.isPlaying
                        ? Icon(
                            Icons.equalizer_rounded,
                            color: Colors.white.withValues(alpha: 0.95),
                            size: 20,
                          )
                        : Icon(
                            Icons.music_note_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrentTrack
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isCurrentTrack
                              ? context.primary
                              : context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Remove from playlist
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => music.removeFromPlaylist(playlistId, track.id),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: context.textTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
      duration: 200.ms,
      delay: Duration(milliseconds: 50 * (index % 10)),
    );
  }

  Widget _buildMiniPlayer(BuildContext context, MusicProvider music) {
    final track = music.currentTrack!;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const NowPlayingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              track.primaryColor.withValues(alpha: 0.85),
              track.secondaryColor.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: track.primaryColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => music.togglePlayPause(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    music.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => music.skipNext(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistOptions(
    BuildContext context,
    MusicPlaylist playlist,
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
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              playlist.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: context.primary),
              title: Text(
                'Rename',
                style: TextStyle(color: context.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, playlist, music);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: context.error),
              title: Text(
                'Delete Playlist',
                style: TextStyle(color: context.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                music.deletePlaylist(playlist.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    MusicPlaylist playlist,
    MusicProvider music,
  ) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename Playlist',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'New name',
            hintStyle: TextStyle(color: context.textTertiary),
            filled: true,
            fillColor: context.primary.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.primary.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.primary.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                music.renamePlaylist(playlist.id, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
