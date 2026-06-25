import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/profile_settings_controller.dart';
import '../../cards/data/cards_repository.dart';
import '../../cards/domain/card_record.dart';
import '../../decks/data/decks_repository.dart';
import '../../notes/data/note_review_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_record.dart';
import '../../notes/domain/note_review_record.dart';
import '../../qa/data/qa_items_repository.dart';
import '../../qa/data/qa_review_repository.dart';
import '../../qa/domain/qa_item_record.dart';
import '../../qa/domain/qa_review_record.dart';
import '../../quizzes/data/quiz_attempts_repository.dart';
import '../../quizzes/data/quizzes_repository.dart';
import '../../quizzes/domain/quiz_attempt_session_record.dart';
import '../../quizzes/domain/quiz_models.dart';
import '../../study/data/study_sessions_repository.dart';
import '../../study/domain/study_session_record.dart';
import '../../subjects/data/subjects_repository.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final subjects = await ref.read(subjectsRepositoryProvider).loadSubjects();
  final decks = await ref.read(decksRepositoryProvider).loadDecks();
  final cards = await ref.read(cardsRepositoryProvider).loadCards();
  final notes = await ref.read(notesRepositoryProvider).loadNotes();
  final noteReviews = await ref.read(noteReviewRepositoryProvider).loadReviews();
  final qaItems = await ref.read(qaItemsRepositoryProvider).loadItems();
  final qaReviews = await ref.read(qaReviewRepositoryProvider).loadReviews();
  final quizzes = await ref.read(quizzesRepositoryProvider).loadQuizzes();
  final quizAttempts = await ref.read(quizAttemptsRepositoryProvider).loadAttempts();
  final sessions = await ref.read(studySessionsRepositoryProvider).loadSessions();
  final settings = ref.read(profileSettingsControllerProvider);

  return DashboardSummary.fromData(
    subjects: subjects.map((subject) => subject.id).toList(),
    decks: decks.map((deck) => (id: deck.id, subjectId: deck.subjectId)).toList(),
    cards: cards,
    notes: notes,
    noteReviews: noteReviews,
    qaItems: qaItems,
    qaReviews: qaReviews,
    quizzes: quizzes,
    quizAttempts: quizAttempts,
    sessions: sessions,
    flashcardsEnabled: settings.flashcardSpacedRepetitionEnabled,
    notesEnabled: settings.noteSpacedRepetitionEnabled,
    qaEnabled: settings.qaSpacedRepetitionEnabled,
    quizzesEnabled: settings.quizPracticeSchedulingEnabled,
  );
});

class DashboardSummary {
  const DashboardSummary({
    required this.totalDueCards,
    required this.totalDueNotes,
    required this.totalDueQa,
    required this.totalDueQuizzes,
    required this.totalDueItems,
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
  final int totalDueNotes;
  final int totalDueQa;
  final int totalDueQuizzes;
  final int totalDueItems;
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
    required List<NoteRecord> notes,
    required List<NoteReviewRecord> noteReviews,
    required List<QaItemRecord> qaItems,
    required List<QaReviewRecord> qaReviews,
    required List<QuizRecord> quizzes,
    required List<QuizAttemptSessionRecord> quizAttempts,
    required List<StudySessionRecord> sessions,
    required bool flashcardsEnabled,
    required bool notesEnabled,
    required bool qaEnabled,
    required bool quizzesEnabled,
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
          notesCount: 0,
          qaCount: 0,
          quizCount: 0,
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
    var totalDueNotes = 0;
    var totalDueQa = 0;
    var totalDueQuizzes = 0;
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
      if (dueNow && flashcardsEnabled) {
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
        dueCount: current.dueCount + (flashcardsEnabled && dueNow ? 1 : 0),
        cardsCount: current.cardsCount + 1,
      );
    }

    final reviewByNoteId = <String, NoteReviewRecord>{
      for (final review in noteReviews) review.noteId: review,
    };

    for (final note in notes) {
      final current = metrics[note.subjectId];
      if (current == null) {
        continue;
      }
      final review = reviewByNoteId[note.id];
      final dueNow = review == null || review.dueAt == null || !review.dueAt!.isAfter(now);
      metrics[note.subjectId] = current.copyWith(
        notesCount: current.notesCount + 1,
        dueCount: current.dueCount + (notesEnabled && dueNow ? 1 : 0),
      );
      if (notesEnabled && dueNow) {
        totalDueNotes += 1;
      }
    }

    final reviewByPromptId = <String, QaReviewRecord>{
      for (final review in qaReviews) review.promptId: review,
    };

    for (final prompt in qaItems) {
      final current = metrics[prompt.subjectId];
      if (current == null) {
        continue;
      }
      final review = reviewByPromptId[prompt.id];
      final dueNow = review == null || review.dueAt == null || !review.dueAt!.isAfter(now);
      metrics[prompt.subjectId] = current.copyWith(
        qaCount: current.qaCount + 1,
        dueCount: current.dueCount + (qaEnabled && dueNow ? 1 : 0),
      );
      if (qaEnabled && dueNow) {
        totalDueQa += 1;
      }
    }

    final latestAttemptByQuiz = <String, QuizAttemptSessionRecord>{};
    for (final attempt in quizAttempts) {
      final existing = latestAttemptByQuiz[attempt.quizId];
      if (existing == null || attempt.endedAt.isAfter(existing.endedAt)) {
        latestAttemptByQuiz[attempt.quizId] = attempt;
      }
    }

    for (final quiz in quizzes) {
      final current = metrics[quiz.subjectId];
      if (current == null) {
        continue;
      }
      final dueAt = _recommendedQuizDueAt(latestAttemptByQuiz[quiz.id]);
      final dueNow = dueAt == null || !dueAt.isAfter(now);
      metrics[quiz.subjectId] = current.copyWith(
        quizCount: current.quizCount + 1,
        dueCount: current.dueCount + (quizzesEnabled && dueNow ? 1 : 0),
      );
      if (quizzesEnabled && dueNow) {
        totalDueQuizzes += 1;
      }
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
      totalDueNotes: totalDueNotes,
      totalDueQa: totalDueQa,
      totalDueQuizzes: totalDueQuizzes,
      totalDueItems: totalDueCards + totalDueNotes + totalDueQa + totalDueQuizzes,
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
    required this.notesCount,
    required this.qaCount,
    required this.quizCount,
    required this.reviewedToday,
    required this.masteryRatio,
  });

  final int dueCount;
  final int deckCount;
  final int cardsCount;
  final int notesCount;
  final int qaCount;
  final int quizCount;
  final int reviewedToday;
  final double masteryRatio;

  SubjectStudyMetrics copyWith({
    int? dueCount,
    int? deckCount,
    int? cardsCount,
    int? notesCount,
    int? qaCount,
    int? quizCount,
    int? reviewedToday,
    double? masteryRatio,
  }) {
    return SubjectStudyMetrics(
      dueCount: dueCount ?? this.dueCount,
      deckCount: deckCount ?? this.deckCount,
      cardsCount: cardsCount ?? this.cardsCount,
      notesCount: notesCount ?? this.notesCount,
      qaCount: qaCount ?? this.qaCount,
      quizCount: quizCount ?? this.quizCount,
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

DateTime? _recommendedQuizDueAt(QuizAttemptSessionRecord? latestAttempt) {
  if (latestAttempt == null) {
    return null;
  }

  final score = latestAttempt.scorePercent;
  final intervalDays = switch (score) {
    < 50 => 1,
    < 70 => 3,
    < 90 => 7,
    _ => 14,
  };
  return latestAttempt.endedAt.add(Duration(days: intervalDays));
}
