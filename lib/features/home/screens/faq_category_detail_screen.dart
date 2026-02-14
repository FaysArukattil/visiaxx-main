import 'package:flutter/material.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/models/faq_model.dart';

class FAQCategoryDetailScreen extends StatelessWidget {
  final FAQCategory category;

  const FAQCategoryDetailScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          category.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: context.surface,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: category.items.length,
            itemBuilder: (context, index) {
              final item = category.items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.help_center_rounded,
                        color: context.primary,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      item.question,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    iconColor: context.primary,
                    collapsedIconColor: context.textTertiary,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1, thickness: 0.5),
                            const SizedBox(height: 16),
                            Text(
                              item.answer,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondary,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
