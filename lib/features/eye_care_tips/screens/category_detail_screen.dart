import 'package:flutter/material.dart';
import '../models/eye_care_tip_model.dart';
import '../widgets/eye_care_tip_card.dart';
import '../../../core/constants/app_colors.dart';

/// Detail screen showing all tips for a specific category
class CategoryDetailScreen extends StatelessWidget {
  final EyeCareTipCategory category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Styled App Bar with gradient
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: category.color,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textOnPrimary,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                category.title,
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      category.color,
                      category.color.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textOnPrimary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textOnPrimary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // Emoji center
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 30),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.textOnPrimary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 56),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tips count header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: category.color.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates, color: category.color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${category.tips.length} Expert Tips',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: category.color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Scroll for more',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_downward,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Tips list - 3 cards per row visible, scroll for more
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final tip = category.tips[index];
                return EyeCareTipCard(tip: tip, categoryColor: category.color);
              }, childCount: category.tips.length),
            ),
          ),
        ],
      ),
    );
  }
}
