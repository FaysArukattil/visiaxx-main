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
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.help_outline,
                      color: context.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.question,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.textPrimary,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Text(
                        item.answer,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
