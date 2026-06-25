import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../gamification/application/gamification_summary_provider.dart';
import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../study/domain/study_session_record.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../application/subjects_controller.dart';
import '../domain/subject_record.dart';
import 'widgets/subject_card.dart';
import 'widgets/subject_editor_sheet.dart';

class SubjectsHomeScreen extends ConsumerWidget {
  const SubjectsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsControllerProvider);

    return subjects.when(
      data: (items) => _SubjectsHomeContent(subjects: items),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'StudyDesk could not load your subjects.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SubjectsHomeContent extends ConsumerWidget {
  const _SubjectsHomeContent({required this.subjects});

  final List<SubjectRecord> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossAxisCount = switch (MediaQuery.sizeOf(context).width) {
      > 1280 => 3,
      > 760 => 2,
      _ => 1,
    };
    final summary = ref.watch(dashboardSummaryProvider);
    final gamification = ref.watch(gamificationSummaryProvider);

    return summary.when(
      data: (dashboard) => gamification.when(
        data: (game) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: _SummaryCard(
                  subjectCount: subjects.length,
                  dueCount: dashboard.totalDueItems,
                  studiedTodayCount: dashboard.studiedTodayCount,
                  streak: dashboard.currentStreak,
                  totalXp: game.totalXp,
                  currentLevel: game.currentLevel,
                  dailyGoalProgress: game.dailyGoalProgress,
                  dailyGoalLabel:
                      '${game.todayMinutes}/${game.dailyGoalMinutes} min goal',
                  nextMilestoneTitle: game.nextMilestone?.title,
                  onCreate: () => _openCreateSheet(context, ref),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: _RecentSessionsCard(sessions: dashboard.recentSessions),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              sliver: subjects.isEmpty
                  ? SliverToBoxAdapter(
                      child: _EmptySubjectsState(
                        onCreate: () => _openCreateSheet(context, ref),
                      ),
                    )
                  : SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisExtent: 180,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final subject = subjects[index];
                          final metrics = dashboard.subjectMetrics[subject.id];
                          final rawMasteryPercent =
                              ((metrics?.masteryRatio ?? 0) * 100).round();
                          final masteryPercent = rawMasteryPercent < 0
                              ? 0
                              : rawMasteryPercent > 100
                              ? 100
                              : rawMasteryPercent;
                          return SubjectCard(
                            masteryPercent: masteryPercent,
                            subject: subject,
                            dueCount: metrics?.dueCount ?? 0,
                            deckCount: metrics?.deckCount ?? 0,
                            cardsCount: metrics?.cardsCount ?? 0,
                            reviewedToday: metrics?.reviewedToday ?? 0,
                            onOpen: () => context.push('/subjects/${subject.id}'),
                            onEdit: () => _openEditSheet(context, ref, subject),
                            onDelete: () => _confirmDelete(context, ref, subject),
                          );
                        },
                        childCount: subjects.length,
                      ),
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Failed to load progress: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load dashboard: $error')),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<SubjectDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const SubjectEditorSheet(),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(subjectsControllerProvider.notifier)
          .addSubject(
            name: draft.name,
            emoji: draft.emoji,
            colorValue: draft.colorValue,
          );
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject created.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create subject: $error')),
        );
      }
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    SubjectRecord subject,
  ) async {
    final draft = await showModalBottomSheet<SubjectDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SubjectEditorSheet(initialSubject: subject),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(subjectsControllerProvider.notifier)
          .updateSubject(
            subject.copyWith(
              name: draft.name,
              emoji: draft.emoji,
              colorValue: draft.colorValue,
              updatedAt: DateTime.now(),
            ),
          );
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject updated.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update subject: $error')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SubjectRecord subject,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text(
          'Delete ${subject.name}? Future deck, quiz, and sheet data under this subject will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(subjectsControllerProvider.notifier).deleteSubject(subject.id);
      ref.invalidate(dashboardSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${subject.name} deleted.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete subject: $error')),
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.subjectCount,
    required this.dueCount,
    required this.studiedTodayCount,
    required this.streak,
    required this.totalXp,
    required this.currentLevel,
    required this.dailyGoalProgress,
    required this.dailyGoalLabel,
    required this.nextMilestoneTitle,
    required this.onCreate,
  });

  final int subjectCount;
  final int dueCount;
  final int studiedTodayCount;
  final int streak;
  final int totalXp;
  final int currentLevel;
  final double dailyGoalProgress;
  final String dailyGoalLabel;
  final String? nextMilestoneTitle;
  final VoidCallback onCreate;

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
            'Build Your Study System',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subjectCount == 0
                ? 'Create your first subject and keep its data local to this device.'
                : '$dueCount due now • $studiedTodayCount reviewed today • $streak day streak',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _HeroChip(label: 'Level $currentLevel'),
              _HeroChip(label: '$totalXp XP'),
              _HeroChip(label: dailyGoalLabel),
              if (nextMilestoneTitle != null)
                _HeroChip(label: 'Next: $nextMilestoneTitle'),
            ],
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
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryStrong,
            ),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Add Subject'),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecentSessionsCard extends StatelessWidget {
  const _RecentSessionsCard({required this.sessions});

  final List<StudySessionRecord> sessions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (sessions.isEmpty)
              Text(
                'Complete a review session and your recent study history will appear here.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final session in sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _sessionSummary(session),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month} $hour:$minute $suffix';
  }

  String _sessionSummary(StudySessionRecord session) {
    final dateLabel = _formatDateTime(session.startedAt);
    return switch (session.sessionType) {
      'quiz' => '$dateLabel • ${session.completedCount}/${session.dueCount} correct',
      'flashcard' =>
        '$dateLabel • ${session.reviewedCount} reviewed • ${session.againCount} again',
      'note' => '$dateLabel • ${session.reviewedCount} sections read • note review',
      'qa' => '$dateLabel • ${session.reviewedCount} prompt${session.reviewedCount == 1 ? '' : 's'} reviewed • long-form recall',
      _ => '$dateLabel • ${session.reviewedCount} reviewed',
    };
  }
}

class _EmptySubjectsState extends StatelessWidget {
  const _EmptySubjectsState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded, size: 52),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No subjects yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start with a subject like Chemistry, DSA, or History. StudyDesk will persist it locally so we can build real decks and sessions on top of it next.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Subject'),
            ),
          ],
        ),
      ),
    );
  }
}
