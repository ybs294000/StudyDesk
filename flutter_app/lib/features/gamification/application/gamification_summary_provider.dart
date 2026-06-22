import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/profile_settings_controller.dart';
import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../study/data/study_sessions_repository.dart';
import '../../study/domain/study_session_record.dart';

final gamificationSummaryProvider = FutureProvider<GamificationSummary>((ref) async {
  final dashboard = await ref.watch(dashboardSummaryProvider.future);
  final sessions = await ref.read(studySessionsRepositoryProvider).loadSessions();
  final settings = ref.watch(profileSettingsControllerProvider);

  return GamificationSummary.fromData(
    dashboard: dashboard,
    sessions: sessions,
    dailyGoalMinutes: settings.dailyGoalMinutes,
  );
});

class GamificationSummary {
  const GamificationSummary({
    required this.totalXp,
    required this.currentLevel,
    required this.levelStartXp,
    required this.nextLevelXp,
    required this.todayMinutes,
    required this.dailyGoalMinutes,
    required this.goalStreakDays,
    required this.weeklyMinutes,
    required this.weeklyReviewedCount,
    required this.weeklySessionCount,
    required this.weeklyQuizAccuracyRate,
    required this.hasWeeklyQuizData,
    required this.unlockedMilestones,
    required this.nextMilestone,
    required this.totalReviewedCount,
    required this.totalSessionCount,
  });

  final int totalXp;
  final int currentLevel;
  final int levelStartXp;
  final int nextLevelXp;
  final int todayMinutes;
  final int dailyGoalMinutes;
  final int goalStreakDays;
  final int weeklyMinutes;
  final int weeklyReviewedCount;
  final int weeklySessionCount;
  final double weeklyQuizAccuracyRate;
  final bool hasWeeklyQuizData;
  final List<GamificationMilestone> unlockedMilestones;
  final GamificationMilestone? nextMilestone;
  final int totalReviewedCount;
  final int totalSessionCount;

  double get levelProgress {
    final span = max(1, nextLevelXp - levelStartXp);
    return ((totalXp - levelStartXp) / span).clamp(0.0, 1.0);
  }

  double get dailyGoalProgress {
    if (dailyGoalMinutes <= 0) {
      return 1;
    }
    return (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);
  }

  bool get goalReachedToday => dailyGoalMinutes > 0 && todayMinutes >= dailyGoalMinutes;

  factory GamificationSummary.fromData({
    required DashboardSummary dashboard,
    required List<StudySessionRecord> sessions,
    required int dailyGoalMinutes,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDayStart = today.subtract(const Duration(days: 6));

    var totalXp = 0;
    var totalReviewedCount = 0;
    var todayMinutes = 0;
    var weeklyMinutes = 0;
    var weeklyReviewedCount = 0;
    var weeklySessionCount = 0;
    var weeklyQuizCorrect = 0;
    var weeklyQuizTotal = 0;
    final minutesByDay = <DateTime, int>{};

    for (final session in sessions) {
      final sessionDay = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      final durationMinutes = _sessionDurationMinutes(session);
      final xp = _xpForSession(session, durationMinutes);

      totalXp += xp;
      totalReviewedCount += session.reviewedCount;
      minutesByDay.update(
        sessionDay,
        (value) => value + durationMinutes,
        ifAbsent: () => durationMinutes,
      );

      if (sessionDay == today) {
        todayMinutes += durationMinutes;
      }
      if (!sessionDay.isBefore(sevenDayStart)) {
        weeklyMinutes += durationMinutes;
        weeklyReviewedCount += session.reviewedCount;
        weeklySessionCount += 1;
        if (session.sessionType == 'quiz') {
          weeklyQuizCorrect += session.completedCount;
          weeklyQuizTotal += session.dueCount;
        }
      }
    }

    final currentLevel = _levelForXp(totalXp);
    final levelStartXp = _levelStartXp(currentLevel);
    final nextLevelXp = _levelStartXp(currentLevel + 1);
    final goalStreakDays = _goalStreakDays(
      today: today,
      dailyGoalMinutes: dailyGoalMinutes,
      minutesByDay: minutesByDay,
    );

    final milestoneCandidates = _buildMilestones(
      dashboard: dashboard,
      totalReviewedCount: totalReviewedCount,
      totalSessionCount: sessions.length,
      totalXp: totalXp,
      goalStreakDays: goalStreakDays,
      hasWeeklyQuizData: weeklyQuizTotal > 0,
      weeklyQuizAccuracyRate: weeklyQuizTotal == 0
          ? 0
          : weeklyQuizCorrect / weeklyQuizTotal,
    );

    return GamificationSummary(
      totalXp: totalXp,
      currentLevel: currentLevel,
      levelStartXp: levelStartXp,
      nextLevelXp: nextLevelXp,
      todayMinutes: todayMinutes,
      dailyGoalMinutes: dailyGoalMinutes,
      goalStreakDays: goalStreakDays,
      weeklyMinutes: weeklyMinutes,
      weeklyReviewedCount: weeklyReviewedCount,
      weeklySessionCount: weeklySessionCount,
      weeklyQuizAccuracyRate: weeklyQuizTotal == 0
          ? 0
          : weeklyQuizCorrect / weeklyQuizTotal,
      hasWeeklyQuizData: weeklyQuizTotal > 0,
      unlockedMilestones: milestoneCandidates.where((item) => item.unlocked).toList(),
      nextMilestone: milestoneCandidates.where((item) => !item.unlocked).firstOrNull,
      totalReviewedCount: totalReviewedCount,
      totalSessionCount: sessions.length,
    );
  }

  static int _sessionDurationMinutes(StudySessionRecord session) {
    final rawMinutes = session.endedAt.difference(session.startedAt).inMinutes;
    return max(1, rawMinutes);
  }

  static int _xpForSession(StudySessionRecord session, int durationMinutes) {
    return switch (session.sessionType) {
      'quiz' => (session.completedCount * 4) +
          session.reviewedCount +
          min(durationMinutes, 45),
      'flashcard' => (session.reviewedCount * 2) +
          session.completedCount +
          min(durationMinutes, 30),
      _ => (session.reviewedCount * 2) + min(durationMinutes, 20),
    };
  }

  static int _levelForXp(int xp) {
    var level = 1;
    while (xp >= _levelStartXp(level + 1)) {
      level += 1;
    }
    return level;
  }

  static int _levelStartXp(int level) {
    if (level <= 1) {
      return 0;
    }
    var total = 0;
    for (var current = 1; current < level; current += 1) {
      total += 100 + ((current - 1) * 50);
    }
    return total;
  }

  static int _goalStreakDays({
    required DateTime today,
    required int dailyGoalMinutes,
    required Map<DateTime, int> minutesByDay,
  }) {
    if (dailyGoalMinutes <= 0) {
      return 0;
    }

    var streak = 0;
    var cursor = today;
    while ((minutesByDay[cursor] ?? 0) >= dailyGoalMinutes) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static List<GamificationMilestone> _buildMilestones({
    required DashboardSummary dashboard,
    required int totalReviewedCount,
    required int totalSessionCount,
    required int totalXp,
    required int goalStreakDays,
    required bool hasWeeklyQuizData,
    required double weeklyQuizAccuracyRate,
  }) {
    final milestones = <GamificationMilestone>[
      GamificationMilestone.fromCount(
        title: 'First Session',
        description: 'Finish your first complete study or quiz session.',
        current: totalSessionCount,
        target: 1,
      ),
      GamificationMilestone.fromCount(
        title: '100 Reviewed',
        description: 'Review 100 study items across flashcards and quizzes.',
        current: totalReviewedCount,
        target: 100,
      ),
      GamificationMilestone.fromCount(
        title: '500 Reviewed',
        description: 'Reach 500 reviewed items in total.',
        current: totalReviewedCount,
        target: 500,
      ),
      GamificationMilestone.fromCount(
        title: 'Level 5',
        description: 'Earn enough XP to reach level 5.',
        current: totalXp,
        target: _levelStartXp(5),
      ),
      GamificationMilestone.fromCount(
        title: '3-Day Streak',
        description: 'Study on three consecutive days.',
        current: dashboard.currentStreak,
        target: 3,
      ),
      GamificationMilestone.fromCount(
        title: '7-Day Streak',
        description: 'Keep your study streak alive for a full week.',
        current: dashboard.currentStreak,
        target: 7,
      ),
      GamificationMilestone.fromCount(
        title: 'Goal Keeper',
        description: 'Hit your daily study goal for seven days in a row.',
        current: goalStreakDays,
        target: 7,
      ),
      GamificationMilestone.fromPercent(
        title: '85% Quiz Week',
        description: 'Hold at least 85% quiz accuracy over the last 7 days.',
        current: hasWeeklyQuizData ? weeklyQuizAccuracyRate : 0,
        target: 0.85,
        available: hasWeeklyQuizData,
      ),
    ];

    milestones.sort((a, b) {
      if (a.unlocked != b.unlocked) {
        return a.unlocked ? -1 : 1;
      }
      return b.progress.compareTo(a.progress);
    });
    return milestones;
  }
}

class GamificationMilestone {
  const GamificationMilestone({
    required this.title,
    required this.description,
    required this.progress,
    required this.unlocked,
    required this.progressLabel,
  });

  final String title;
  final String description;
  final double progress;
  final bool unlocked;
  final String progressLabel;

  factory GamificationMilestone.fromCount({
    required String title,
    required String description,
    required int current,
    required int target,
  }) {
    final progress = target == 0 ? 1.0 : (current / target).clamp(0.0, 1.0);
    return GamificationMilestone(
      title: title,
      description: description,
      progress: progress,
      unlocked: current >= target,
      progressLabel: '$current / $target',
    );
  }

  factory GamificationMilestone.fromPercent({
    required String title,
    required String description,
    required double current,
    required double target,
    required bool available,
  }) {
    final progress = available ? (current / target).clamp(0.0, 1.0) : 0.0;
    return GamificationMilestone(
      title: title,
      description: description,
      progress: progress,
      unlocked: available && current >= target,
      progressLabel: available
          ? '${(current * 100).toStringAsFixed(0)}% / ${(target * 100).toStringAsFixed(0)}%'
          : 'No quiz data yet',
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
