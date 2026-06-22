import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../../services/content_portability_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../cards/application/deck_cards_controller.dart';
import '../../cards/domain/card_record.dart';
import '../../cards/presentation/widgets/card_editor_sheet.dart';
import '../../cards/presentation/widgets/study_card_tile.dart';
import '../../decks/application/subject_decks_controller.dart';
import '../../decks/domain/deck_record.dart';

class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({
    required this.subjectId,
    required this.deckId,
    super.key,
  });

  final String subjectId;
  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(subjectDecksControllerProvider(subjectId));

    return decks.when(
      data: (items) {
        DeckRecord? deck;
        for (final item in items) {
          if (item.id == deckId) {
            deck = item;
            break;
          }
        }
        if (deck == null) {
          return const _MissingDeckView();
        }
        return _DeckDetailContent(
          subjectId: subjectId,
          deck: deck,
        );
      },
      error: (error, stackTrace) => Center(child: Text('Failed to load deck: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DeckDetailContent extends ConsumerWidget {
  const _DeckDetailContent({
    required this.subjectId,
    required this.deck,
  });

  final String subjectId;
  final DeckRecord deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(deckCardsControllerProvider(deck.id));

    return cards.when(
      data: (items) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: _DeckHero(
                deck: deck,
                cardCount: items.length,
                onCreateCard: () => _openCreateCard(context, ref),
                onExportDeck: () => _showExportJson(context, ref, items),
                onStartStudy: items.isEmpty
                    ? null
                    : () => context.go(
                          '/subjects/$subjectId/decks/${deck.id}/study?deckName=${Uri.encodeComponent(deck.name)}',
                        ),
                dueCount: _dueCount(items),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: items.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptyCardsState(
                      onCreateCard: () => _openCreateCard(context, ref),
                    ),
                  )
                : SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final card = items[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == items.length - 1 ? 0 : AppSpacing.md,
                        ),
                        child: StudyCardTile(
                          card: card,
                          onEdit: () => _openEditCard(context, ref, card),
                          onDelete: () => _confirmDeleteCard(context, ref, card),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      error: (error, stackTrace) => Center(child: Text('Failed to load cards: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  int _dueCount(List<CardRecord> cards) {
    final now = DateTime.now();
    final due = cards.where((card) => card.dueAt == null || !card.dueAt!.isAfter(now));
    return due.length;
  }

  Future<void> _openCreateCard(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<CardDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const CardEditorSheet(),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(deckCardsControllerProvider(deck.id).notifier).addCard(
            deckId: deck.id,
            front: draft.front,
            back: draft.back,
            hint: draft.hint,
          );
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card created.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create card: $error')),
        );
      }
    }
  }

  Future<void> _openEditCard(
    BuildContext context,
    WidgetRef ref,
    CardRecord card,
  ) async {
    final draft = await showModalBottomSheet<CardDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CardEditorSheet(initialCard: card),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(deckCardsControllerProvider(deck.id).notifier).updateCard(
            card.copyWith(
              front: draft.front,
              back: draft.back,
              hint: draft.hint,
              updatedAt: DateTime.now(),
            ),
          );
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card updated.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update card: $error')),
        );
      }
    }
  }

  Future<void> _confirmDeleteCard(
    BuildContext context,
    WidgetRef ref,
    CardRecord card,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: const Text(
          'Delete this flashcard from the deck? Existing review history for this card will no longer appear in future analytics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(deckCardsControllerProvider(deck.id).notifier).deleteCard(card.id);
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card deleted.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete card: $error')),
        );
      }
    }
  }

  Future<void> _showExportJson(
    BuildContext context,
    WidgetRef ref,
    List<CardRecord> cards,
  ) async {
    try {
      final json = await ref.read(contentPortabilityServiceProvider).exportDeckJson(
        deck: deck,
        cards: cards,
      );
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Deck JSON'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: SelectableText(json),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deck JSON copied to clipboard.')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not copy JSON: $error')),
                    );
                  }
                }
              },
              child: const Text('Copy JSON'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export deck JSON: $error')),
        );
      }
    }
  }
}

class _DeckHero extends StatelessWidget {
  const _DeckHero({
    required this.deck,
    required this.cardCount,
    required this.onCreateCard,
    required this.onExportDeck,
    required this.onStartStudy,
    required this.dueCount,
  });

  final DeckRecord deck;
  final int cardCount;
  final VoidCallback onCreateCard;
  final VoidCallback onExportDeck;
  final VoidCallback? onStartStudy;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryStrong, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deck.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            deck.description.isEmpty
                ? 'Build a focused flashcard deck for spaced review, quiz prep, and long-term recall.'
                : deck.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$cardCount card${cardCount == 1 ? '' : 's'} stored locally',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$dueCount due now',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onStartStudy,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryStrong,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Study Now'),
              ),
              FilledButton.tonalIcon(
                onPressed: onCreateCard,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.note_add_rounded),
                label: const Text('Add Card'),
              ),
              FilledButton.tonalIcon(
                onPressed: onExportDeck,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Export JSON'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  const _EmptyCardsState({required this.onCreateCard});

  final VoidCallback onCreateCard;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.style_rounded, size: 52),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No cards yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add front, back, and optional hint content to begin studying this deck with spaced repetition.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreateCard,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Card'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingDeckView extends StatelessWidget {
  const _MissingDeckView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 44),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Deck not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'It may have been removed locally.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
