import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/subject_record.dart';

class SubjectCard extends StatelessWidget {
  const SubjectCard({
    required this.subject,
    required this.dueCount,
    required this.deckCount,
    required this.cardsCount,
    required this.reviewedToday,
    required this.masteryPercent,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final SubjectRecord subject;
  final int dueCount;
  final int deckCount;
  final int cardsCount;
  final int reviewedToday;
  final int masteryPercent;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.colorValue);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 88,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.micro),
                              Text(
                                '$deckCount deck${deckCount == 1 ? '' : 's'} • $cardsCount card${cardsCount == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<_SubjectCardAction>(
                          onSelected: (action) {
                            switch (action) {
                              case _SubjectCardAction.edit:
                                onEdit();
                                break;
                              case _SubjectCardAction.delete:
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _SubjectCardAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _SubjectCardAction.delete,
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MetaChip(
                          icon: Icons.lock_rounded,
                          label: 'Due $dueCount',
                          color: color.withValues(alpha: 0.12),
                        ),
                        _MetaChip(
                          icon: Icons.shield_outlined,
                          label: 'Today $reviewedToday',
                          color: color.withValues(alpha: 0.12),
                        ),
                        _MetaChip(
                          icon: Icons.emoji_events_outlined,
                          label: 'Mastery $masteryPercent%',
                          color: color.withValues(alpha: 0.12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SubjectCardAction { edit, delete }

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: AppSpacing.micro),
          Text(label),
        ],
      ),
    );
  }
}
