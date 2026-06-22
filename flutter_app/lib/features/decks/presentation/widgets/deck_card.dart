import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/deck_record.dart';

class DeckCard extends StatelessWidget {
  const DeckCard({
    required this.deck,
    required this.unitName,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final DeckRecord deck;
  final String? unitName;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deck.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  PopupMenuButton<_DeckAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _DeckAction.edit:
                          onEdit();
                          break;
                        case _DeckAction.delete:
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _DeckAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _DeckAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                deck.description.isEmpty
                    ? 'Ready for cards, due logic, and study sessions.'
                    : deck.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  const _DeckMetaChip(icon: Icons.offline_bolt_rounded, label: 'Local'),
                  const _DeckMetaChip(icon: Icons.layers_rounded, label: 'Deck'),
                  if (unitName != null)
                    _DeckMetaChip(
                      icon: Icons.folder_copy_outlined,
                      label: unitName!,
                    ),
                  for (final tag in deck.tags.take(3))
                    _DeckMetaChip(
                      icon: Icons.sell_outlined,
                      label: '#$tag',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DeckAction { edit, delete }

class _DeckMetaChip extends StatelessWidget {
  const _DeckMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final chipForeground = AppColors.onColor(AppColors.primarySoft);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipForeground),
          const SizedBox(width: AppSpacing.micro),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: chipForeground,
            ),
          ),
        ],
      ),
    );
  }
}
