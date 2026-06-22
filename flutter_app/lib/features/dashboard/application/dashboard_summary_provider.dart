import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/data/cards_repository.dart';
import '../../cards/domain/card_record.dart';
import '../../decks/data/decks_repository.dart';
import '../../study/data/study_sessions_repository.dart';
import '../../study/domain/study_session_record.dart';
import '../../subjects/data/subjects_repository.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final subjects = await ref.read(subjectsRepositoryProvider).loadSubjects();
  final decks = await ref.read(decksRepositoryProvider).loadDecks();
  final cards = await ref.read(cardsRepositoryProvider).loadCards();
  final sessions = await ref.read(studySessionsRepositoryProvider).loadSessions();

  return DashboardSummary.fromData(
    subjects: subjects.map((subject) => subject.id).toList(),
    decks: decks.map((deck) => (id: deck.id, subjectId: deck.subjectId)).toList(),
    cards: cards,
    sessions: sessions,
  );
});

class DashboardSummary {
  const DashboardSummary({
    required this.totalDueCards,
    required this.totalCards,
    required this.studiedTodayCount,
    required this.currentStreak,
    required this.subjectMetrics,
    required this.recentSessions,
    required this.activityLast7Days,
    required this.dueForecast,
    required this.sessionTypeCounts,
    required this.sevenDayReviewedCount,
    required this.sevenDayQuizAccuracyRate,
    required this.hasSevenDayQuizData,
  });

  final int totalDueCards;
  final int totalCards;
  final int studiedTodayCount;
  final int currentStreak;
  final Map<String, SubjectStudyMetrics> subjectMetrics;
  final List<StudySessionRecord> recentSessions;
  final List<DailyStudyActivity> activityLast7Days;
  final DueForecast dueForecast;
  final Map<String, int> sessionTypeCounts;
  final int sevenDayReviewedCount;
  final double sevenDayQuizAccuracyRate;
  final bool hasSevenDayQuizData;

  factory DashboardSummary.fromData({
    required List<String> subjects,
    required List<({String id, String subjectId})> decks,
    required List<CardRecord> cards,
    required List<StudySessionRecord> sessions,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final subjectByDeck = <String, String>{
      for (final deck in decks) deck.id: deck.subjectId,
    };
    final metrics = <String, SubjectStudyMetrics>{
      for (final subjectId in subjects)
        subjectId: const SubjectStudyMetrics(
          dueCount: 0,
          deckCount: 0,
          cardsCount: 0,
          reviewedToday: 0,
          masteryRatio: 0,
        ),
    };

    for (final deck in decks) {
      final current = metrics[deck.subjectId];
      if (current != null) {
        metrics[deck.subjectId] = current.copyWith(
          deckCount: current.deckCount + 1,
        );
      }
    }

    var totalDueCards = 0;
    var overdueCards = 0;
    var unscheduledCards = 0;
    var dueTodayCards = 0;
    var dueThisWeekCards = 0;
    var dueLaterCards = 0;
    final reviewedCardsBySubject = <String, int>{};

    for (final card in cards) {
      final subjectId = subjectByDeck[card.deckId];
      if (subjectId == null) {
        continue;
      }
      final current = metrics[subjectId];
      if (current == null) {
        continue;
      }

      final dueAt = card.dueAt;
      final dueNow = dueAt == null || !dueAt.isAfter(now);
      if (dueNow) {
        totalDueCards += 1;
      }
      if (card.reviewCount > 0) {
        reviewedCardsBySubject.update(
          subjectId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      if (dueAt == null) {
        unscheduledCards += 1;
      } else {
        final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
        if (dueDay.isBefore(today)) {
          overdueCards += 1;
        } else if (dueDay == today) {
          dueTodayCards += 1;
        } else if (!dueDay.isAfter(today.add(const Duration(days: 7)))) {
          dueThisWeekCards += 1;
        } else {
          dueLaterCards += 1;
        }
      }

      metrics[subjectId] = current.copyWith(
        dueCount: current.dueCount + (dueNow ? 1 : 0),
        cardsCount: current.cardsCount + 1,
      );
    }

    final sessionsSorted = [...sessions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    var studiedTodayCount = 0;
    final studyDays = <DateTime>{};
    final activityByDay = <DateTime, DailyStudyActivity>{};
    final sessionTypeCounts = <String, int>{};
    var sevenDayReviewedCount = 0;
    var sevenDayQuizCorrectCount = 0;
    var sevenDayQuizQuestionCount = 0;

    for (var offset = 6; offset >= 0; offset -= 1) {
      final day = today.subtract(Duration(days: offset));
      activityByDay[day] = DailyStudyActivity(
        day: day,
        reviewedCount: 0,
        sessionCount: 0,
      );
    }

    for (final session in sessionsSorted) {
      final day = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      studyDays.add(day);
      sessionTypeCounts.update(
        session.sessionType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      if (day == today) {
        studiedTodayCount += session.reviewedCount;
        if (session.subjectId != null && metrics.containsKey(session.subjectId)) {
          final current = metrics[session.subjectId]!;
          metrics[session.subjectId!] = current.copyWith(
            reviewedToday: current.reviewedToday + session.reviewedCount,
          );
        }
      }

      if (activityByDay.containsKey(day)) {
        final current = activityByDay[day]!;
        activityByDay[day] = DailyStudyActivity(
          day: day,
          reviewedCount: current.reviewedCount + session.reviewedCount,
          sessionCount: current.sessionCount + 1,
        );
        sevenDayReviewedCount += session.reviewedCount;
        if (session.sessionType == 'quiz') {
          sevenDayQuizCorrectCount += session.completedCount;
          sevenDayQuizQuestionCount += session.dueCount;
        }
      }
    }

    for (final entry in reviewedCardsBySubject.entries) {
      final current = metrics[entry.key];
      if (current == null) {
        continue;
      }
      final ratio = current.cardsCount == 0 ? 0.0 : entry.value / current.cardsCount;
      metrics[entry.key] = current.copyWith(masteryRatio: ratio);
    }

    var currentStreak = 0;
    var cursor = today;
    while (studyDays.contains(cursor)) {
      currentStreak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return DashboardSummary(
      totalDueCards: totalDueCards,
      totalCards: cards.length,
      studiedTodayCount: studiedTodayCount,
      currentStreak: currentStreak,
      subjectMetrics: metrics,
      recentSessions: sessionsSorted.take(5).toList(),
      activityLast7Days: activityByDay.values.toList()
        ..sort((a, b) => a.day.compareTo(b.day)),
      dueForecast: DueForecast(
        overdue: overdueCards,
        unscheduled: unscheduledCards,
        dueToday: dueTodayCards,
        dueThisWeek: dueThisWeekCards,
        dueLater: dueLaterCards,
      ),
      sessionTypeCounts: sessionTypeCounts,
      sevenDayReviewedCount: sevenDayReviewedCount,
      sevenDayQuizAccuracyRate: sevenDayQuizQuestionCount == 0
          ? 0
          : sevenDayQuizCorrectCount / sevenDayQuizQuestionCount,
      hasSevenDayQuizData: sevenDayQuizQuestionCount > 0,
    );
  }
}

class SubjectStudyMetrics {
  const SubjectStudyMetrics({
    required this.dueCount,
    required this.deckCount,
    required this.cardsCount,
    required this.reviewedToday,
    required this.masteryRatio,
  });

  final int dueCount;
  final int deckCount;
  final int cardsCount;
  final int reviewedToday;
  final double masteryRatio;

  SubjectStudyMetrics copyWith({
    int? dueCount,
    int? deckCount,
    int? cardsCount,
    int? reviewedToday,
    double? masteryRatio,
  }) {
    return SubjectStudyMetrics(
      dueCount: dueCount ?? this.dueCount,
      deckCount: deckCount ?? this.deckCount,
      cardsCount: cardsCount ?? this.cardsCount,
      reviewedToday: reviewedToday ?? this.reviewedToday,
      masteryRatio: masteryRatio ?? this.masteryRatio,
    );
  }
}

class DailyStudyActivity {
  const DailyStudyActivity({
    required this.day,
    required this.reviewedCount,
    required this.sessionCount,
  });

  final DateTime day;
  final int reviewedCount;
  final int sessionCount;
}

class DueForecast {
  const DueForecast({
    required this.overdue,
    required this.unscheduled,
    required this.dueToday,
    required this.dueThisWeek,
    required this.dueLater,
  });

  final int overdue;
  final int unscheduled;
  final int dueToday;
  final int dueThisWeek;
  final int dueLater;

  int get total => overdue + unscheduled + dueToday + dueThisWeek + dueLater;
}
