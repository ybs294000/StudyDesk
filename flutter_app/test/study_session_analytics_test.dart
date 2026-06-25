import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/features/cards/domain/card_record.dart';
import 'package:studydesk/features/dashboard/application/dashboard_summary_provider.dart';
import 'package:studydesk/features/decks/domain/deck_record.dart';
import 'package:studydesk/features/library/application/library_overview_provider.dart';
import 'package:studydesk/features/notes/domain/note_record.dart';
import 'package:studydesk/features/notes/domain/note_review_record.dart';
import 'package:studydesk/features/quizzes/domain/quiz_attempt_session_record.dart';
import 'package:studydesk/features/quizzes/domain/quiz_models.dart';
import 'package:studydesk/features/study/domain/study_session_record.dart';
import 'package:studydesk/features/subjects/domain/subject_record.dart';

void main() {
  final now = DateTime(2026, 6, 21, 18, 0);

  SubjectRecord subject() => SubjectRecord(
        id: 'subject_1',
        name: 'Science',
        emoji: '🧪',
        colorValue: 0xFF009688,
        createdAt: now,
        updatedAt: now,
      );

  DeckRecord deck() => DeckRecord(
        id: 'deck_1',
        subjectId: 'subject_1',
        unitId: null,
        name: 'Core Cards',
        description: '',
        tags: const [],
        createdAt: now,
        updatedAt: now,
      );

  CardRecord card() => CardRecord(
        id: 'card_1',
        deckId: 'deck_1',
        front: 'Q',
        back: 'A',
        hint: '',
        schedulerVersion: CardRecord.defaultSchedulerVersion,
        state: 'review',
        reviewCount: 1,
        lapseCount: 0,
        intervalDays: 2,
        ease: 2.5,
        stability: 0.5,
        difficulty: 4,
        dueAt: now.subtract(const Duration(hours: 1)),
        lastReviewedAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );

  test('quiz sessions without deck ids still contribute to dashboard analytics', () {
    final summary = DashboardSummary.fromData(
      subjects: const ['subject_1'],
      decks: const [(id: 'deck_1', subjectId: 'subject_1')],
      cards: [card()],
      notes: const <NoteRecord>[],
      noteReviews: const <NoteReviewRecord>[],
      qaItems: const [],
      qaReviews: const [],
      quizzes: const <QuizRecord>[],
      quizAttempts: const <QuizAttemptSessionRecord>[],
      sessions: [
        StudySessionRecord(
          id: 'quiz_session_1',
          subjectId: 'subject_1',
          deckId: null,
          sessionType: 'quiz',
          startedAt: now.subtract(const Duration(hours: 2)),
          endedAt: now.subtract(const Duration(hours: 1, minutes: 40)),
          reviewedCount: 5,
          completedCount: 4,
          againCount: 1,
          dueCount: 5,
        ),
      ],
      flashcardsEnabled: true,
      notesEnabled: true,
      qaEnabled: true,
      quizzesEnabled: true,
    );

    expect(summary.studiedTodayCount, 5);
    expect(summary.sessionTypeCounts['quiz'], 1);
    expect(summary.sevenDayReviewedCount, 5);
    expect(summary.hasSevenDayQuizData, isTrue);
    expect(summary.sevenDayQuizAccuracyRate, closeTo(0.8, 0.0001));
    expect(summary.subjectMetrics['subject_1']?.reviewedToday, 5);
    expect(summary.dueForecast.total, greaterThanOrEqualTo(1));
  });

  test('library overview ignores quiz sessions without deck ids for deck-level history', () {
    final overview = LibraryOverview.fromData(
      subjects: [subject()],
      decks: [deck()],
      cards: [card()],
      sessions: [
        StudySessionRecord(
          id: 'quiz_session_1',
          subjectId: 'subject_1',
          deckId: null,
          sessionType: 'quiz',
          startedAt: now.subtract(const Duration(hours: 2)),
          endedAt: now.subtract(const Duration(hours: 1, minutes: 40)),
          reviewedCount: 5,
          completedCount: 4,
          againCount: 1,
          dueCount: 5,
        ),
      ],
    );

    expect(overview.totalStudiedToday, 5);
    expect(overview.deckSummaries, hasLength(1));
    expect(overview.deckSummaries.single.lastStudiedAt, isNull);
  });
}
