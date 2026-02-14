import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/music_track.dart';
import '../../../data/providers/music_provider.dart';
import '../../../core/services/music_service.dart';
import 'now_playing_screen.dart';
import 'playlist_screen.dart';

/// Full Spotify-style music library screen
class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({super.key});

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, music, _) {
        return Scaffold(
          body: Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.primary.withValues(alpha: 0.15),
                      context.scaffoldBackground,
                      context.scaffoldBackground,
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(music),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAllTracks(music),
                          _buildLikedTracks(music),
                          _buildPlaylists(music),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Mini player at bottom
              if (music.currentTrack != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildMiniPlayer(music),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(MusicProvider music) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Back button
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
                  Icons.arrow_back_rounded,
                  color: context.primary,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          if (!_showSearch) ...[
            Icon(Icons.library_music_rounded, color: context.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Music Library',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],

          if (_showSearch)
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search tracks...',
                    hintStyle: TextStyle(color: context.textTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
            ),

          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _showSearch ? Icons.close_rounded : Icons.search_rounded,
                  color: context.primary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: context.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.primary.withValues(alpha: 0.1)),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.primary,
                context.primary.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          dividerHeight: 0,
          labelColor: context.onPrimary,
          unselectedLabelColor: context.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'All Tracks'),
            Tab(text: 'Liked ❤️'),
            Tab(text: 'Playlists'),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }

  Widget _buildAllTracks(MusicProvider music) {
    List<MusicTrack> tracks = music.allTracks;
    if (_searchQuery.isNotEmpty) {
      tracks = tracks
          .where((t) => t.title.toLowerCase().contains(_searchQuery))
          .toList();
    }

    return _buildTrackList(tracks, music);
  }

  Widget _buildLikedTracks(MusicProvider music) {
    List<MusicTrack> tracks = music.likedTracks;
    if (_searchQuery.isNotEmpty) {
      tracks = tracks
          .where((t) => t.title.toLowerCase().contains(_searchQuery))
          .toList();
    }

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 64,
              color: context.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No liked tracks yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the heart on any track to add it here',
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ],
        ),
      );
    }

    return _buildTrackList(tracks, music);
  }

  Widget _buildPlaylists(MusicProvider music) {
    return Column(
      children: [
        // Create playlist button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showCreatePlaylistDialog(music),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.primary.withValues(alpha: 0.12),
                      context.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: context.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Create New Playlist',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.primary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: context.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

        // Playlist list
        Expanded(
          child: music.playlists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 64,
                        color: context.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No playlists yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create one to organize your music',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    music.currentTrack != null ? 100 : 20,
                  ),
                  itemCount: music.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = music.playlists[index];
                    return _buildPlaylistTile(playlist, music, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistTile(
    MusicPlaylist playlist,
    MusicProvider music,
    int index,
  ) {
    final trackCount = playlist.trackIds.length;
    // Use first track's gradient or primary color
    Color gradientStart = context.primary.withValues(alpha: 0.3);
    Color gradientEnd = context.primary.withValues(alpha: 0.1);

    if (playlist.trackIds.isNotEmpty) {
      final firstTrack = music.allTracks.firstWhere(
        (t) => t.id == playlist.trackIds.first,
        orElse: () => music.allTracks.first,
      );
      gradientStart = firstTrack.primaryColor.withValues(alpha: 0.4);
      gradientEnd = firstTrack.secondaryColor.withValues(alpha: 0.15);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaylistScreen(playlistId: playlist.id),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradientStart, gradientEnd],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                // Playlist icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gradientStart.withValues(alpha: 0.8),
                        gradientEnd.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.queue_music_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Play button
                if (trackCount > 0)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => music.playPlaylist(playlist.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: context.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                // Delete button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showDeletePlaylistDialog(playlist, music),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.more_vert_rounded,
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
      duration: 300.ms,
      delay: Duration(milliseconds: 50 * index),
    );
  }

  Widget _buildTrackList(List<MusicTrack> tracks, MusicProvider music) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        music.currentTrack != null ? 100 : 20,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrentTrack = music.currentTrack?.id == track.id;

        return _buildTrackTile(track, music, isCurrentTrack, index);
      },
    );
  }

  Widget _buildTrackTile(
    MusicTrack track,
    MusicProvider music,
    bool isCurrentTrack,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => music.playTrack(track),
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
                // Album art gradient
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [track.primaryColor, track.secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: track.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isCurrentTrack && music.isPlaying
                        ? Icon(
                            Icons.equalizer_rounded,
                            color: Colors.white.withValues(alpha: 0.95),
                            size: 22,
                          )
                        : Icon(
                            Icons.music_note_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title and artist
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
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            track.artist,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (music.getLikeCount(track.id) > 0) ...[
                            Text(
                              '  •  ',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                            Icon(
                              Icons.favorite_rounded,
                              size: 11,
                              color: context.error,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${music.getLikeCount(track.id)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Like button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => music.toggleLike(track.id),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        music.isLiked(track.id)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: music.isLiked(track.id)
                            ? context.error
                            : context.textTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Add to playlist
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showAddToPlaylistSheet(track, music),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.playlist_add_rounded,
                        color: context.textTertiary,
                        size: 22,
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
      delay: Duration(milliseconds: 30 * (index % 15)),
    );
  }

  Widget _buildMiniPlayer(MusicProvider music) {
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
            // Album mini art
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

            // Play/pause
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

            // Skip next
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
    ).animate().slideY(
      begin: 1,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }

  void _showCreatePlaylistDialog(MusicProvider music) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Playlist',
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
            hintText: 'Playlist name',
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
                music.createPlaylist(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog(MusicPlaylist playlist, MusicProvider music) {
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
                _showRenamePlaylistDialog(playlist, music);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: context.error),
              title: Text('Delete', style: TextStyle(color: context.error)),
              onTap: () {
                Navigator.pop(ctx);
                music.deletePlaylist(playlist.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenamePlaylistDialog(MusicPlaylist playlist, MusicProvider music) {
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

  void _showAddToPlaylistSheet(MusicTrack track, MusicProvider music) {
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
              'Add "${track.title}" to:',
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
                  child: Column(
                    children: [
                      Text(
                        'No playlists yet',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCreatePlaylistDialog(music);
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Playlist'),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
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
                  subtitle: Text(
                    '${playlist.trackIds.length} tracks',
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
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
