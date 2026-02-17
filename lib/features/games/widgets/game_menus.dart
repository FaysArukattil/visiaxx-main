import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/audio_service.dart';

class GamePauseDialog extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final String gameTitle;

  const GamePauseDialog({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
    required this.gameTitle,
  });

  @override
  State<GamePauseDialog> createState() => _GamePauseDialogState();
}

class _GamePauseDialogState extends State<GamePauseDialog> {
  bool _isResuming = false;

  void _handleResume() {
    if (_isResuming) return;
    setState(() => _isResuming = true);
    widget.onResume();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isResuming,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleResume();
      },
      child: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.cardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.primary,
                            context.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.primary.withValues(alpha: 0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.pause_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'PAUSED',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.gameTitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildMenuButton(
                      context,
                      label: 'RESUME',
                      icon: Icons.play_arrow_rounded,
                      color: context.primary,
                      onTap: _handleResume,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuButton(
                      context,
                      label: 'RESTART',
                      icon: Icons.refresh_rounded,
                      color: Colors.amber,
                      onTap: widget.onRestart,
                    ),
                    const SizedBox(height: 12),
                    _buildSoundToggle(context),
                    const SizedBox(height: 12),
                    _buildMenuButton(
                      context,
                      label: 'MAIN MENU',
                      icon: Icons.home_rounded,
                      color: context.error,
                      onTap: widget.onExit,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundToggle(BuildContext context) {
    final audio = AudioService();
    return StatefulBuilder(
      builder: (context, setState) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await audio.toggleSound();
              setState(() {});
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    audio.isSoundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: context.textPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    audio.isSoundEnabled ? 'SOUND: ON' : 'SOUND: OFF',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GameExitConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const GameExitConfirmationDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Exit Game?',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
      content: const Text(
        'Are you sure you want to leave? Your current progress in this session will be saved.',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: context.textTertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'EXIT',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class GameOverDialog extends StatelessWidget {
  final String gameTitle;
  final int score;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final List<Widget>? additionalStats;

  const GameOverDialog({
    super.key,
    required this.gameTitle,
    required this.score,
    required this.onRestart,
    required this.onExit,
    this.additionalStats,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Blur
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: context.cardColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.1),
                    blurRadius: 50,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red, Colors.red.shade700],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.heart_broken_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ).animate().shake(duration: 500.ms, hz: 4),
                  const SizedBox(height: 24),
                  Text(
                    'GAME OVER',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gameTitle.toUpperCase(),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Score Display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: context.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'FINAL SCORE',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '$score',
                          style: TextStyle(
                            color: context.primary,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (additionalStats != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: additionalStats!,
                    ),
                  ],
                  const SizedBox(height: 40),
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context,
                          label: 'RETRY',
                          icon: Icons.refresh_rounded,
                          color: context.primary,
                          onTap: onRestart,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context,
                          label: 'MAIN MENU',
                          icon: Icons.home_rounded,
                          color: context.textSecondary,
                          onTap: onExit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
