import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../study/domain/study_session_record.dart';
import '../dashboard/application/dashboard_summary_provider.dart';
import '../gamification/application/gamification_summary_provider.dart';
import '../library/application/library_overview_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final metricsCrossAxisCount = width >= 960
        ? 3
        : width >= 640
            ? 2
            : 2;
    final summary = ref.watch(dashboardSummaryProvider);
    final overview = ref.watch(libraryOverviewProvider);
    final gamification = ref.watch(gamificationSummaryProvider);

    return summary.when(
      data: (dashboard) => overview.when(
        data: (library) => gamification.when(
          data: (game) {
          final totalLearning = library.deckSummaries.fold<int>(
            0,
            (sum, deck) => sum + deck.learningCount,
          );
          final totalNew = library.deckSummaries.fold<int>(
            0,
            (sum, deck) => sum + deck.newCount,
          );
          final totalReviewed = library.deckSummaries.fold<int>(
            0,
            (sum, deck) => sum + deck.reviewedCount,
          );
          final metricCards = <Widget>[
            _MetricCard(
              title: 'Level',
              value: '${game.currentLevel}',
              subtitle: '${game.totalXp} XP earned',
              color: AppColors.primary,
            ),
            _MetricCard(
              title: 'Due Now',
              value: '${dashboard.totalDueItems}',
              subtitle:
                  '${dashboard.totalDueCards} cards • ${dashboard.totalDueNotes} notes • ${dashboard.totalDueQa} Q&A • ${dashboard.totalDueQuizzes} quizzes',
              color: AppColors.accent,
            ),
            _MetricCard(
              title: '7-Day Reviewed',
              value: '${dashboard.sevenDayReviewedCount}',
              subtitle: 'items reviewed',
              color: AppColors.primary,
            ),
            _MetricCard(
              title: '7-Day Accuracy',
              value: dashboard.hasSevenDayQuizData
                  ? '${(dashboard.sevenDayQuizAccuracyRate * 100).toStringAsFixed(0)}%'
                  : 'N/A',
              subtitle: dashboard.hasSevenDayQuizData
                  ? 'correct / total'
                  : 'no quiz attempts yet',
              color: AppColors.info,
            ),
            _MetricCard(
              title: 'Streak',
              value: '${dashboard.currentStreak}',
              subtitle: 'days with study activity',
              color: AppColors.success,
            ),
            _MetricCard(
              title: 'Daily Goal',
              value: '${game.todayMinutes}/${game.dailyGoalMinutes}',
              subtitle: game.goalReachedToday
                  ? 'goal reached today'
                  : '${game.goalStreakDays} day goal streak',
              color: AppColors.info,
            ),
            _MetricCard(
              title: 'Pomodoros',
              value: '${game.weeklyPomodoroCount}',
              subtitle: '${game.todayPomodoroCount} completed today',
              color: AppColors.warning,
            ),
          ];

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              GridView.count(
                crossAxisCount: metricsCrossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: width < 420 ? 1.22 : 1.35,
                children: metricCards,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChartCard(
                title: 'Progress Engine',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${game.currentLevel} progress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: game.levelProgress,
                        minHeight: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Daily goal progress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: game.dailyGoalProgress,
                        minHeight: 12,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '7-day report',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${game.weeklyMinutes} min focused • ${game.weeklyPomodoroCount} Pomodoros • ${game.weeklyReviewedCount} items reviewed • ${game.weeklySessionCount} sessions',
                    ),
                    Text(
                      game.hasWeeklyQuizData
                          ? 'Quiz accuracy: ${(game.weeklyQuizAccuracyRate * 100).toStringAsFixed(0)}%'
                          : 'Quiz accuracy: no quiz data this week',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChartCard(
                title: '7-Day Study Activity',
                child: _SevenDayActivityChart(
                  data: dashboard.activityLast7Days,
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
                        'Milestones',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (game.unlockedMilestones.isEmpty)
                        Text(
                          'Complete a few sessions and your first milestone will unlock here.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        for (final milestone in game.unlockedMilestones.take(4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _MilestoneTile(milestone: milestone, unlocked: true),
                          ),
                      if (game.nextMilestone != null) ...[
                        const Divider(),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Up next',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MilestoneTile(
                          milestone: game.nextMilestone!,
                          unlocked: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChartCard(
                title: 'Due Forecast',
                child: _DueForecastChart(forecast: dashboard.dueForecast),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card State Mix',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _StateBar(
                        label: 'New',
                        value: totalNew,
                        total: totalNew + totalLearning + totalReviewed,
                        color: AppColors.info,
                      ),
                      _StateBar(
                        label: 'Learning',
                        value: totalLearning,
                        total: totalNew + totalLearning + totalReviewed,
                        color: AppColors.warning,
                      ),
                      _StateBar(
                        label: 'Reviewed',
                        value: totalReviewed,
                        total: totalNew + totalLearning + totalReviewed,
                        color: AppColors.success,
                      ),
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
                        'Session Types',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (dashboard.sessionTypeCounts.isEmpty)
                        Text(
                          'No sessions recorded yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        for (final entry in dashboard.sessionTypeCounts.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _SessionTypeRow(
                              label: entry.key,
                              count: entry.value,
                              total: dashboard.sessionTypeCounts.values.fold(
                                0,
                                (sum, item) => sum + item,
                              ),
                            ),
                          ),
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
                        'By Subject',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final subject in library.subjects)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _SubjectMetricRow(
                            emoji: subject.emoji,
                            name: subject.name,
                            metrics: dashboard.subjectMetrics[subject.id],
                          ),
                        ),
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
                        'Recent Sessions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (dashboard.recentSessions.isEmpty)
                        Text(
                          'No study sessions logged yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        for (final session in dashboard.recentSessions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Text(
                              _sessionSummary(session),
                            ),
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
            Center(child: Text('Failed to load analytics: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load analytics: $error')),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.unlocked,
  });

  final GamificationMilestone milestone;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.flag_outlined,
              color: unlocked ? AppColors.warning : AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                milestone.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(milestone.progressLabel),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          milestone.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: milestone.progress,
            minHeight: 8,
            color: unlocked ? AppColors.warning : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _SevenDayActivityChart extends StatelessWidget {
  const _SevenDayActivityChart({required this.data});

  final List<DailyStudyActivity> data;

  @override
  Widget build(BuildContext context) {
    final maxReviewed = data.fold<int>(
      1,
      (maxValue, item) => max(maxValue, item.reviewedCount),
    );

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${point.reviewedCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: point.reviewedCount / maxReviewed.toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primaryStrong, AppColors.primary],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _dayLabel(point.day),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${point.sessionCount} sess',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[date.weekday - 1];
  }
}

class _DueForecastChart extends StatelessWidget {
  const _DueForecastChart({required this.forecast});

  final DueForecast forecast;

  @override
  Widget build(BuildContext context) {
    final total = max(1, forecast.total);

    return Column(
      children: [
        _ForecastBar(
          label: 'Overdue',
          count: forecast.overdue,
          total: total,
          color: AppColors.error,
        ),
        _ForecastBar(
          label: 'Unscheduled',
          count: forecast.unscheduled,
          total: total,
          color: AppColors.info,
        ),
        _ForecastBar(
          label: 'Today',
          count: forecast.dueToday,
          total: total,
          color: AppColors.warning,
        ),
        _ForecastBar(
          label: 'Next 7 Days',
          count: forecast.dueThisWeek,
          total: total,
          color: AppColors.primary,
        ),
        _ForecastBar(
          label: 'Later',
          count: forecast.dueLater,
          total: total,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _ForecastBar extends StatelessWidget {
  const _ForecastBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label • $count'),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: count / total.toDouble(),
              color: color,
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBar extends StatelessWidget {
  const _StateBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : value / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label • $value'),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: fraction,
              color: color,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTypeRow extends StatelessWidget {
  const _SessionTypeRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label • $count'),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: total == 0 ? 0.0 : count / total.toDouble(),
            minHeight: 10,
            color: label == 'quiz' ? AppColors.accent : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SubjectMetricRow extends StatelessWidget {
  const _SubjectMetricRow({
    required this.emoji,
    required this.name,
    required this.metrics,
  });

  final String emoji;
  final String name;
  final SubjectStudyMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final dueCount = metrics?.dueCount ?? 0;
    final deckCount = metrics?.deckCount ?? 0;
    final cardCount = metrics?.cardsCount ?? 0;
    final noteCount = metrics?.notesCount ?? 0;
    final qaCount = metrics?.qaCount ?? 0;
    final quizCount = metrics?.quizCount ?? 0;
    final reviewedToday = metrics?.reviewedToday ?? 0;
    final mastery =
        ((metrics?.masteryRatio ?? 0) * 100).clamp(0, 100).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '$deckCount decks • $cardCount cards • $noteCount notes • $qaCount Q&A • $quizCount quizzes • $dueCount due • $reviewedToday today',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${mastery.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'reviewed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: mastery / 100,
            minHeight: 8,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

String _sessionSummary(StudySessionRecord session) {
  final dateLabel = '${session.startedAt.day}/${session.startedAt.month}';
  return switch (session.sessionType) {
    'quiz' =>
      '$dateLabel • ${session.completedCount}/${session.dueCount} correct • quiz',
    'flashcard' =>
      '$dateLabel • ${session.reviewedCount} reviewed • ${session.againCount} again • flashcard',
    'note' =>
      '$dateLabel • ${session.reviewedCount} sections read • note review',
    'pomodoro' =>
      '$dateLabel • ${session.endedAt.difference(session.startedAt).inMinutes} min focus block • pomodoro',
    _ =>
      '$dateLabel • ${session.reviewedCount} reviewed • ${session.sessionType}',
  };
}
