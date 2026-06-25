import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../dashboard/application/dashboard_summary_provider.dart';
import '../gamification/application/gamification_summary_provider.dart';
import '../library/application/library_overview_provider.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(libraryOverviewProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final gamification = ref.watch(gamificationSummaryProvider);

    return overview.when(
      data: (library) => summary.when(
        data: (dashboard) => gamification.when(
          data: (game) {
          final estimatedMinutes = (dashboard.totalDueCards * 1) +
              (dashboard.totalDueNotes * 4) +
              (dashboard.totalDueQa * 3) +
              (dashboard.totalDueQuizzes * 8);
          final focusBlocks = estimatedMinutes == 0
              ? 0
              : ((estimatedMinutes / 25).ceil());
          final dueDecks = library.deckSummaries
              .where((deck) => deck.dueCount > 0)
              .toList()
            ..sort((a, b) => b.dueCount.compareTo(a.dueCount));
          final suggestedDecks = dueDecks.isNotEmpty
              ? dueDecks
              : library.deckSummaries.take(6).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _StudyHero(
                dueCount: dashboard.totalDueItems,
                studiedToday: dashboard.studiedTodayCount,
                streak: dashboard.currentStreak,
                dailyGoalLabel: '${game.todayMinutes}/${game.dailyGoalMinutes} min goal',
                dailyGoalProgress: game.dailyGoalProgress,
                weeklyXp: game.totalXp,
                todayPomodoros: game.todayPomodoroCount,
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _QueueChip(label: '${dashboard.totalDueCards} flashcards'),
                      _QueueChip(label: '${dashboard.totalDueNotes} notes'),
                      _QueueChip(label: '${dashboard.totalDueQa} Q&A'),
                      _QueueChip(label: '${dashboard.totalDueQuizzes} quizzes'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Planner',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        estimatedMinutes == 0
                            ? 'Your due queue is light right now. This is a good moment to write notes, import new material, or do a short maintenance review.'
                            : 'Your current queue is roughly $estimatedMinutes minutes of focused work, which is about $focusBlocks Pomodoro block${focusBlocks == 1 ? '' : 's'}. Start with the heaviest-due deck first, then move to notes and Q&A prompts.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                dueDecks.isEmpty ? 'Suggested Decks' : 'Due Right Now',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (suggestedDecks.isEmpty)
                const _EmptyStudyState()
              else
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final deck in suggestedDecks)
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width > 1200
                            ? 360
                            : MediaQuery.sizeOf(context).width > 820
                                ? 320
                                : double.infinity,
                        child: _StudyDeckCard(deck: deck),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Advice',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        dueDecks.isEmpty
                            ? 'No cards are currently due, so this is a good time to preview a deck, add cards, or do a light recall session.'
                            : 'Start with the highest-due deck first. Keep sessions short, rate honestly, and use the timer chip only to pace yourself instead of rushing.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('Failed to load progress: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Failed to load study data: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load study data: $error')),
    );
  }
}

class _StudyHero extends StatelessWidget {
  const _StudyHero({
    required this.dueCount,
    required this.studiedToday,
    required this.streak,
    required this.dailyGoalLabel,
    required this.dailyGoalProgress,
    required this.weeklyXp,
    required this.todayPomodoros,
  });

  final int dueCount;
  final int studiedToday;
  final int streak;
  final String dailyGoalLabel;
  final double dailyGoalProgress;
  final int weeklyXp;
  final int todayPomodoros;

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
            'Study Focus',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$dueCount due now • $studiedToday reviewed today • $streak day streak',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$dailyGoalLabel • $todayPomodoros Pomodoros today • $weeklyXp XP earned',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: dailyGoalProgress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyDeckCard extends StatelessWidget {
  const _StudyDeckCard({required this.deck});

  final LibraryDeckSummary deck;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(deck.subject.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.deck.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        deck.subject.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${deck.dueCount} due • ${deck.cardCount} cards • ${deck.learningCount} learning',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: deck.cardCount == 0
                        ? null
                        : () => context.push(
                              '/subjects/${deck.subject.id}/decks/${deck.deck.id}/study?deckName=${Uri.encodeComponent(deck.deck.name)}',
                            ),
                    child: const Text('Start Study'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(
                    '/subjects/${deck.subject.id}/decks/${deck.deck.id}',
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueChip extends StatelessWidget {
  const _QueueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _EmptyStudyState extends StatelessWidget {
  const _EmptyStudyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.hourglass_empty_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nothing queued yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create a subject or import a sample deck so StudyDesk can start surfacing real review work here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
