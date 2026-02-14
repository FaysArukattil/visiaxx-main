import 'package:flutter/material.dart';

/// Represents a single music track in the Visiaxx music library
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String assetPath;
  final Color primaryColor;
  final Color secondaryColor;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.assetPath,
    required this.primaryColor,
    required this.secondaryColor,
  });

  /// Generate a display-friendly duration string
  static String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// All available music tracks in the Visiaxx library
class MusicLibrary {
  static const String _basePath = 'assets/music/visiaxx _music_';

  // Curated gradient color pairs for unique album art per track
  static const List<List<Color>> _gradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)], // 1 - Indigo/Purple
    [Color(0xFFf093fb), Color(0xFFf5576c)], // 2 - Pink/Rose
    [Color(0xFF4facfe), Color(0xFF00f2fe)], // 3 - Sky/Cyan
    [Color(0xFF43e97b), Color(0xFF38f9d7)], // 4 - Emerald/Teal
    [Color(0xFFfa709a), Color(0xFFfee140)], // 5 - Rose/Gold
    [Color(0xFF30cfd0), Color(0xFF330867)], // 6 - Cyan/Navy
    [Color(0xFFa18cd1), Color(0xFFfbc2eb)], // 7 - Lavender/Blush
    [Color(0xFFffecd2), Color(0xFFfcb69f)], // 8 - Peach/Coral
    [Color(0xFF89f7fe), Color(0xFF66a6ff)], // 9 - Ice/Azure
    [Color(0xFFfddb92), Color(0xFFd1fdff)], // 10 - Sand/Frost
    [Color(0xFF9890e3), Color(0xFFb1f4cf)], // 11 - Violet/Mint
    [Color(0xFFf6d365), Color(0xFFfda085)], // 12 - Amber/Salmon
    [Color(0xFFfbc2eb), Color(0xFFa6c1ee)], // 13 - Blush/Periwinkle
    [Color(0xFF84fab0), Color(0xFF8fd3f4)], // 14 - Mint/Sky
    [Color(0xFFcfd9df), Color(0xFFe2ebf0)], // 15 - Silver/Cloud
    [Color(0xFFa1c4fd), Color(0xFFc2e9fb)], // 16 - Blue/Frost
    [Color(0xFFd4fc79), Color(0xFF96e6a1)], // 17 - Lime/Green
    [Color(0xFFfccb90), Color(0xFFd57eeb)], // 18 - Peach/Purple
    [Color(0xFFe0c3fc), Color(0xFF8ec5fc)], // 19 - Lilac/Azure
    [Color(0xFFf093fb), Color(0xFFf5576c)], // 20 - Pink/Rose
    [Color(0xFF4facfe), Color(0xFF00f2fe)], // 21 - Sky/Cyan
    [Color(0xFFa8edea), Color(0xFFfed6e3)], // 22 - Aqua/Blush
    [Color(0xFFd299c2), Color(0xFFfef9d7)], // 23 - Mauve/Cream
    [Color(0xFF667eea), Color(0xFF764ba2)], // 24 - Indigo/Purple
    [Color(0xFF43e97b), Color(0xFF38f9d7)], // 25 - Emerald/Teal
    [Color(0xFFfa709a), Color(0xFFfee140)], // 26 - Rose/Gold
    [Color(0xFFfeada6), Color(0xFFf5efef)], // 27 - Blush/Snow
    [Color(0xFF13547a), Color(0xFF80d0c7)], // 28 - Deep Teal
    [Color(0xFFff9a9e), Color(0xFFfecfef)], // 29 - Rose/Pink
    [Color(0xFFa8caba), Color(0xFF5d4157)], // 30 - Sage/Plum
    [Color(0xFFf794a4), Color(0xFFfdd6bd)], // 31 - Coral/Peach
    [Color(0xFF64b3f4), Color(0xFFc2e59c)], // 32 - Ocean/Lime
    [Color(0xFFc471f5), Color(0xFFfa71cd)], // 33 - Purple/Pink
    [Color(0xFF48c6ef), Color(0xFF6f86d6)], // 34 - Azure/Slate
    [Color(0xFFfeada6), Color(0xFFf5efef)], // 35 - Blush/Snow
    [Color(0xFFe6b980), Color(0xFFeacda3)], // 36 - Gold/Sand
    [Color(0xFF1e3c72), Color(0xFF2a5298)], // 37 - Navy/Royal
  ];

  static const List<String> _titles = [
    'Calm Horizons',
    'Gentle Focus',
    'Clear Vision',
    'Soft Reflections',
    'Healing Light',
    'Deep Clarity',
    'Peaceful Gaze',
    'Warm Comfort',
    'Crystal Waters',
    'Morning Calm',
    'Inner Peace',
    'Golden Hour',
    'Soft Bloom',
    'Fresh Perspective',
    'Silver Lining',
    'Blue Serenity',
    'Nature\'s Touch',
    'Sunset Glow',
    'Dreamy Skies',
    'Pink Harmony',
    'Ocean Breeze',
    'Aqua Dreams',
    'Velvet Dusk',
    'Starlight Path',
    'Forest Whisper',
    'Rose Garden',
    'Gentle Tide',
    'Deep Sea Calm',
    'Cherry Blossom',
    'Autumn Trail',
    'Coral Sunset',
    'Meadow Song',
    'Purple Rain',
    'Sky Journey',
    'Snow Drift',
    'Golden Sand',
    'Royal Night',
  ];

  static List<MusicTrack> get allTracks {
    return List.generate(37, (i) {
      final trackNumber = i + 1;
      final gradient = _gradients[i];
      return MusicTrack(
        id: 'track_$trackNumber',
        title: _titles[i],
        artist: 'Visiaxx',
        assetPath: '$_basePath$trackNumber.mp3',
        primaryColor: gradient[0],
        secondaryColor: gradient[1],
      );
    });
  }
}
