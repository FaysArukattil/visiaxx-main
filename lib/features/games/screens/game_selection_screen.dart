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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<GameProvider>().loadAllProgress(user.uid);
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
                _buildProgressSection(),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
        _buildComingSoonCard(
          title: 'Eye Tracker',
          description:
              'Follow the target as it moves across the screen to exercise eye muscles.',
          color: Colors.blue,
        ),
      ],
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

  Widget _buildProgressSection() {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        if (provider.gameProgress.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overall Progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => _showResetConfirmDialog(context, provider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset All'),
                    style: TextButton.styleFrom(foregroundColor: context.error),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...provider.gameProgress.values.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p.gameId == 'brick_ball' ? 'Brick & Ball' : p.gameId,
                  ),
                  trailing: Text(
                    'Level ${p.currentLevel}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: LinearProgressIndicator(
                    value: (p.clearedLevels.length / 10).clamp(
                      0.0,
                      1.0,
                    ), // Assuming 10 levels for progress bar
                    backgroundColor: context.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ).animate().slideY(begin: 1.0, end: 0, duration: 400.ms);
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
