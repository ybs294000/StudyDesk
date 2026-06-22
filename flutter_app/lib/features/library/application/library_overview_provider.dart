import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/data/cards_repository.dart';
import '../../cards/domain/card_record.dart';
import '../../decks/data/decks_repository.dart';
import '../../decks/domain/deck_record.dart';
import '../../study/data/study_sessions_repository.dart';
import '../../study/domain/study_session_record.dart';
import '../../subjects/data/subjects_repository.dart';
import '../../subjects/domain/subject_record.dart';

final libraryOverviewProvider = FutureProvider<LibraryOverview>((ref) async {
  final subjects = await ref.read(subjectsRepositoryProvider).loadSubjects();
  final decks = await ref.read(decksRepositoryProvider).loadDecks();
  final cards = await ref.read(cardsRepositoryProvider).loadCards();
  final sessions = await ref.read(studySessionsRepositoryProvider).loadSessions();

  return LibraryOverview.fromData(
    subjects: subjects,
    decks: decks,
    cards: cards,
    sessions: sessions,
  );
});

class LibraryOverview {
  const LibraryOverview({
    required this.subjects,
    required this.deckSummaries,
    required this.totalDeckCount,
    required this.totalCardCount,
    required this.totalDueCount,
    required this.totalStudiedToday,
  });

  final List<SubjectRecord> subjects;
  final List<LibraryDeckSummary> deckSummaries;
  final int totalDeckCount;
  final int totalCardCount;
  final int totalDueCount;
  final int totalStudiedToday;

  factory LibraryOverview.fromData({
    required List<SubjectRecord> subjects,
    required List<DeckRecord> decks,
    required List<CardRecord> cards,
    required List<StudySessionRecord> sessions,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final subjectById = {for (final subject in subjects) subject.id: subject};
    final cardsByDeck = <String, List<CardRecord>>{};
    final sessionsByDeck = <String, List<StudySessionRecord>>{};

    for (final card in cards) {
      cardsByDeck.putIfAbsent(card.deckId, () => []).add(card);
    }
    for (final session in sessions) {
      final deckId = session.deckId;
      if (deckId == null) {
        continue;
      }
      sessionsByDeck.putIfAbsent(deckId, () => []).add(session);
    }

    var totalDueCount = 0;
    var totalStudiedToday = 0;
    final deckSummaries = <LibraryDeckSummary>[];

    for (final session in sessions) {
      final day = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      if (day == today) {
        totalStudiedToday += session.reviewedCount;
      }
    }

    for (final deck in decks) {
      final subject = subjectById[deck.subjectId];
      if (subject == null) {
        continue;
      }
      final deckCards = cardsByDeck[deck.id] ?? const <CardRecord>[];
      final dueCount = deckCards
          .where((card) => card.dueAt == null || !card.dueAt!.isAfter(now))
          .length;
      final newCount = deckCards.where((card) => card.reviewCount == 0).length;
      final learningCount = deckCards
          .where((card) => card.state == 'learning')
          .length;
      final reviewedCount = deckCards.where((card) => card.reviewCount > 0).length;
      final latestSession = _latestSession(sessionsByDeck[deck.id] ?? const []);

      totalDueCount += dueCount;
      deckSummaries.add(
        LibraryDeckSummary(
          subject: subject,
          deck: deck,
          cardCount: deckCards.length,
          dueCount: dueCount,
          newCount: newCount,
          learningCount: learningCount,
          reviewedCount: reviewedCount,
          lastStudiedAt: latestSession?.startedAt,
        ),
      );
    }

    deckSummaries.sort((a, b) {
      final dueCompare = b.dueCount.compareTo(a.dueCount);
      if (dueCompare != 0) {
        return dueCompare;
      }
      return b.deck.updatedAt.compareTo(a.deck.updatedAt);
    });

    return LibraryOverview(
      subjects: subjects,
      deckSummaries: deckSummaries,
      totalDeckCount: deckSummaries.length,
      totalCardCount: deckSummaries.fold(0, (sum, item) => sum + item.cardCount),
      totalDueCount: totalDueCount,
      totalStudiedToday: totalStudiedToday,
    );
  }

  static StudySessionRecord? _latestSession(List<StudySessionRecord> sessions) {
    if (sessions.isEmpty) {
      return null;
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions.first;
  }
}

class LibraryDeckSummary {
  const LibraryDeckSummary({
    required this.subject,
    required this.deck,
    required this.cardCount,
    required this.dueCount,
    required this.newCount,
    required this.learningCount,
    required this.reviewedCount,
    required this.lastStudiedAt,
  });

  final SubjectRecord subject;
  final DeckRecord deck;
  final int cardCount;
  final int dueCount;
  final int newCount;
  final int learningCount;
  final int reviewedCount;
  final DateTime? lastStudiedAt;
}
