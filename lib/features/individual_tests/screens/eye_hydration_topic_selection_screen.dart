import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/eye_hydration_provider.dart';

class EyeHydrationTopicSelectionScreen extends StatelessWidget {
  const EyeHydrationTopicSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EyeHydrationProvider>();
    final topics = provider.availableTopics;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Select Reading Topic',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: context.cardColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            return Column(
              children: [
                if (!isLandscape)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pick something to read',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a topic that interests you for the eye hydration test.',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isLandscape)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Select Reading Topic',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Pick one and begin',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: isLandscape
                      ? GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 4.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: topics.length,
                          itemBuilder: (context, index) => _buildTopicItem(
                            context,
                            provider,
                            topics[index],
                            index,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          itemCount: topics.length,
                          itemBuilder: (context, index) => _buildTopicItem(
                            context,
                            provider,
                            topics[index],
                            index,
                          ),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 16.0 : 24.0,
                    vertical: isLandscape ? 8.0 : 24.0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: isLandscape ? 40 : 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/eye-hydration-test',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Begin Test',
                        style: TextStyle(
                          fontSize: isLandscape ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopicItem(
    BuildContext context,
    EyeHydrationProvider provider,
    String topic,
    int index,
  ) {
    final isSelected = provider.selectedTopic == topic;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _TopicCard(
        title: topic,
        isSelected: isSelected,
        onTap: () => provider.setTopic(topic),
        icon: _getIconForTopic(topic),
        description: _getDescriptionForTopic(topic),
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
  }

  IconData _getIconForTopic(String topic) {
    switch (topic) {
      case 'Zero to One':
        return Icons.rocket_launch_rounded;
      case 'Talk to Anyone':
        return Icons.record_voice_over_rounded;
      case 'Influence Others':
        return Icons.groups_rounded;
      case 'Think & Grow Rich':
        return Icons.psychology_rounded;
      case 'Lean Startup':
        return Icons.trending_up_rounded;
      case 'Biz Adventures':
        return Icons.business_center_rounded;
      case 'Intelligent Investor':
        return Icons.pie_chart_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  String _getDescriptionForTopic(String topic) {
    switch (topic) {
      case 'Zero to One':
        return 'Build the future from 0 to 1.';
      case 'Talk to Anyone':
        return 'Success in social relationships.';
      case 'Influence Others':
        return 'The first book on human relations.';
      case 'Think & Grow Rich':
        return 'The classic on personal achievement.';
      case 'Lean Startup':
        return 'Build sustainable businesses.';
      case 'Biz Adventures':
        return 'Bill Gates\' favorite business book.';
      case 'Intelligent Investor':
        return 'The definitive book on value investing.';
      default:
        return 'Importance of blinking.';
    }
  }
}

class _TopicCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopicCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.primary.withValues(alpha: 0.1)
              : context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.primary
                : context.dividerColor.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.primary
                    : context.dividerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : context.textPrimary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: context.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
