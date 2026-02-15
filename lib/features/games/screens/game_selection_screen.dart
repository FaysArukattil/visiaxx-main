import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/game_provider.dart';
import '../../../core/utils/snackbar_utils.dart';

class GameSelectionScreen extends StatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  State<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends State<GameSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        context.read<GameProvider>().loadAllProgress(userId);
        // Fetch leaderboards for all games
        context.read<GameProvider>().fetchLeaderboard('brick_ball');
        context.read<GameProvider>().fetchLeaderboard('eye_quest');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                _buildAppBar(),
                Expanded(child: _buildGameList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
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
          Icon(Icons.sports_esports_rounded, color: context.primary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Eye Therapy Games',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildGameList() {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildDashboardCard(provider),
            const SizedBox(height: 20),
            _buildGameCard(
              id: 'brick_ball',
              title: 'Brick & Ball',
              description:
                  'Improve hand-eye coordination by catching falling balls with matching colors.',
              icon: Icons.grid_view_rounded,
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(context, '/brick-ball-game'),
            ),
            const SizedBox(height: 16),
            _buildGameCard(
              id: 'eye_quest',
              title: 'Eye Quest',
              description:
                  'Test your knowledge of eye anatomy and vision concepts with 100+ levels.',
              icon: Icons.spellcheck_rounded,
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/eye-quest-game'),
            ),
            const SizedBox(height: 16),
            _buildComingSoonCard(
              title: 'Eye Tracker',
              description:
                  'Follow the target as it moves across the screen to exercise eye muscles.',
              color: Colors.blue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardCard(GameProvider provider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDashboard(provider),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.primary, context.primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: context.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DASHBOARD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View World Rankings & My Progress',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0);
  }

  void _showDashboard(GameProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) =>
            _buildDashboardSheet(provider, scrollController),
      ),
    );
  }

  Widget _buildDashboardSheet(
    GameProvider provider,
    ScrollController scrollController,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: context.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    dividerColor: Colors.transparent,
                    indicatorColor: context.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    tabs: const [
                      Tab(text: 'MY PROGRESS'),
                      Tab(text: 'WORLD RANKING'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildMyProgressTab(provider),
                        _buildLeaderboardTab(provider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        final progress = provider.getProgress(id);
        final level = progress?.currentLevel ?? 1;
        final cleared = progress?.clearedLevels.length ?? 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.primary.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatistic('Level', '$level'),
                              const SizedBox(width: 16),
                              _buildStatistic('Cleared', '$cleared'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: context.primary,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComingSoonCard({
    required String title,
    required String description,
    required Color color,
  }) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.dividerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.lock_rounded,
                color: context.textTertiary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: context.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: context.primary,
                      ),
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

  Widget _buildStatistic(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.textTertiary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMyProgressTab(GameProvider provider) {
    if (provider.gameProgress.isEmpty) {
      return const Center(
        child: Text(
          'Play a game to see your progress!',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...provider.gameProgress.values.map((p) {
          final String title = p.gameId == 'brick_ball'
              ? 'Brick & Ball'
              : 'Eye Quest';
          final double progress = (p.clearedLevels.length / 10).clamp(0.0, 1.0);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    p.gameId == 'brick_ball'
                        ? Icons.sports_esports_rounded
                        : Icons.spellcheck_rounded,
                    color: context.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Score: ${p.totalScore}',
                            style: TextStyle(
                              color: context.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation(context.primary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LEVEL ${p.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton(
          onPressed: () => _showResetConfirmDialog(context, provider),
          child: const Text(
            'RESET ALL PROGRESS',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTab(GameProvider provider) {
    // Combine leaderboards for a global feel or just show brick_ball by default
    final brickBallLeaderboard = provider.leaderboards['brick_ball'] ?? [];
    final eyeQuestLeaderboard = provider.leaderboards['eye_quest'] ?? [];

    // Filter for only 'user' role as requested
    final allScores = [
      ...brickBallLeaderboard,
      ...eyeQuestLeaderboard,
    ].where((s) => s.userRole == 'user').toList();

    allScores.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    // Only show if the current user has played (score > 0)
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final hasPlayed = provider.gameProgress.values.any((p) => p.totalScore > 0);

    if (!hasPlayed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text(
                'Play a game to unlock the leaderboard!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final topScores = allScores.take(20).toList();

    if (topScores.isEmpty) {
      return const Center(
        child: Text(
          'Leaderboard empty. Be the first!',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: topScores.length,
      itemBuilder: (context, index) {
        final score = topScores[index];
        final isMe = score.userId == myUid;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? context.primary.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe
                  ? context.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(
                '#${index + 1}',
                style: TextStyle(
                  color: index < 3 ? Colors.amber : Colors.white24,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 14,
                backgroundColor: context.primary.withValues(alpha: 0.2),
                child: Text(
                  score.userName.isNotEmpty
                      ? score.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 10,
                    color: context.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      score.gameId == 'brick_ball'
                          ? 'Brick & Ball'
                          : 'Eye Quest',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${score.totalScore}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.amber,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResetConfirmDialog(BuildContext context, GameProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text(
          'Are you sure you want to reset all game progress? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId != null) {
                for (var gameId in provider.gameProgress.keys) {
                  await provider.resetProgress(userId, gameId);
                }
                if (mounted) {
                  Navigator.pop(context);
                  SnackbarUtils.showSuccess(
                    context,
                    'Progress reset successfully',
                  );
                }
              }
            },
            child: Text('Reset', style: TextStyle(color: context.error)),
          ),
        ],
      ),
    );
  }
}
