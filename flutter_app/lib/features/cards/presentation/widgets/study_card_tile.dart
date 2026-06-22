import 'package:flutter/material.dart';

import '../../../../core/widgets/markdown_content.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/card_record.dart';

class StudyCardTile extends StatelessWidget {
  const StudyCardTile({
    required this.card,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final CardRecord card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hintForeground = AppColors.onColor(AppColors.primarySoft);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MarkdownContent(
                    data: card.front,
                    baseTextStyle: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<_CardAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _CardAction.edit:
                        onEdit();
                        break;
                      case _CardAction.delete:
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _CardAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: _CardAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            MarkdownContent(
              data: card.back,
              baseTextStyle: Theme.of(context).textTheme.bodyMedium,
            ),
            if (card.hint.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: hintForeground,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: MarkdownContent(
                        data: card.hint,
                        baseTextStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              color: hintForeground,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CardAction { edit, delete }
