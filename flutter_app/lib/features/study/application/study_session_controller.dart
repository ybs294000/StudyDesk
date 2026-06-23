import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/application/deck_cards_controller.dart';
import '../../cards/data/cards_repository.dart';
import '../../cards/domain/card_record.dart';
import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../decks/data/decks_repository.dart';
import '../data/study_sessions_repository.dart';
import '../domain/study_rating.dart';
import '../domain/study_session_record.dart';
import 'spaced_repetition_service.dart';

final spacedRepetitionServiceProvider = Provider<SpacedRepetitionService>((ref) {
  return const SpacedRepetitionService();
});

final studySessionControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    StudySessionController, StudySessionState, String>(StudySessionController.new);

class StudySessionController
    extends AutoDisposeFamilyAsyncNotifier<StudySessionState, String> {
  CardsRepository get _cardsRepository => ref.read(cardsRepositoryProvider);
  DecksRepository get _decksRepository => ref.read(decksRepositoryProvider);
  StudySessionsRepository get _sessionsRepository =>
      ref.read(studySessionsRepositoryProvider);
  SpacedRepetitionService get _scheduler =>
      ref.read(spacedRepetitionServiceProvider);

  @override
  Future<StudySessionState> build(String deckId) async {
    final allCards = await _cardsRepository.loadCards();
    final allDecks = await _decksRepository.loadDecks();
    final deckCards = allCards.where((card) => card.deckId == deckId).toList();

    String? subjectId;
    for (final deck in allDecks) {
      if (deck.id == deckId) {
        subjectId = deck.subjectId;
        break;
      }
    }

    final now = DateTime.now();
    final dueCards = deckCards
        .where((card) => card.dueAt == null || !card.dueAt!.isAfter(now))
        .toList();
    final sessionCards = dueCards.isNotEmpty ? dueCards : deckCards;

    sessionCards.sort((a, b) {
      final aDue = a.dueAt ?? a.createdAt;
      final bDue = b.dueAt ?? b.createdAt;
      return aDue.compareTo(bDue);
    });

    return StudySessionState(
      deckId: deckId,
      subjectId: subjectId,
      startedAt: now,
      queue: sessionCards,
      originalCount: sessionCards.length,
      dueCount: dueCards.isNotEmpty ? dueCards.length : sessionCards.length,
      currentIndex: 0,
      isShowingAnswer: false,
      reviewedCount: 0,
      completedCount: 0,
      againCount: 0,
      isComplete: sessionCards.isEmpty,
    );
  }

  Future<void> revealAnswer() async {
    final current = await future;
    state = AsyncData(current.copyWith(isShowingAnswer: true));
  }

  Future<void> rateCurrent(StudyRating rating) async {
    final current = await future;
    if (current.queue.isEmpty || current.currentCard == null) {
      return;
    }

    final reviewedAt = DateTime.now();
    final updatedCard = _scheduler.applyRating(
      card: current.currentCard!,
      rating: rating,
      reviewedAt: reviewedAt,
    );

    await _cardsRepository.upsertCard(updatedCard);
    ref.invalidate(deckCardsControllerProvider(arg));

    final remaining = [...current.queue]..removeAt(current.currentIndex);
    if (rating == StudyRating.again) {
      remaining.add(updatedCard);
    }

    final nextState = current.copyWith(
      queue: remaining,
      currentIndex: 0,
      isShowingAnswer: false,
      reviewedCount: current.reviewedCount + 1,
      completedCount:
          current.completedCount + (rating == StudyRating.again ? 0 : 1),
      againCount: current.againCount + (rating == StudyRating.again ? 1 : 0),
      isComplete: remaining.isEmpty,
    );

    if (nextState.isComplete) {
      await _sessionsRepository.addSession(
        StudySessionRecord(
          id: reviewedAt.microsecondsSinceEpoch.toString(),
          subjectId: nextState.subjectId,
          deckId: nextState.deckId,
          sessionType: 'flashcard',
          startedAt: nextState.startedAt,
          endedAt: reviewedAt,
          reviewedCount: nextState.reviewedCount,
          completedCount: nextState.completedCount,
          againCount: nextState.againCount,
          dueCount: nextState.dueCount,
        ),
      );
      ref.invalidate(dashboardSummaryProvider);
    }

    state = AsyncData(nextState);
  }
}

class StudySessionState {
  const StudySessionState({
    required this.deckId,
    required this.subjectId,
    required this.startedAt,
    required this.queue,
    required this.originalCount,
    required this.dueCount,
    required this.currentIndex,
    required this.isShowingAnswer,
    required this.reviewedCount,
    required this.completedCount,
    required this.againCount,
    required this.isComplete,
  });

  final String deckId;
  final String? subjectId;
  final DateTime startedAt;
  final List<CardRecord> queue;
  final int originalCount;
  final int dueCount;
  final int currentIndex;
  final bool isShowingAnswer;
  final int reviewedCount;
  final int completedCount;
  final int againCount;
  final bool isComplete;

  CardRecord? get currentCard => queue.isEmpty ? null : queue[currentIndex];

  double get progress {
    if (originalCount == 0) {
      return 1;
    }
    return completedCount / originalCount;
  }

  StudySessionState copyWith({
    String? deckId,
    Object? subjectId = _studySentinel,
    DateTime? startedAt,
    List<CardRecord>? queue,
    int? originalCount,
    int? dueCount,
    int? currentIndex,
    bool? isShowingAnswer,
    int? reviewedCount,
    int? completedCount,
    int? againCount,
    bool? isComplete,
  }) {
    return StudySessionState(
      deckId: deckId ?? this.deckId,
      subjectId: identical(subjectId, _studySentinel)
          ? this.subjectId
          : subjectId as String?,
      startedAt: startedAt ?? this.startedAt,
      queue: queue ?? this.queue,
      originalCount: originalCount ?? this.originalCount,
      dueCount: dueCount ?? this.dueCount,
      currentIndex: currentIndex ?? this.currentIndex,
      isShowingAnswer: isShowingAnswer ?? this.isShowingAnswer,
      reviewedCount: reviewedCount ?? this.reviewedCount,
      completedCount: completedCount ?? this.completedCount,
      againCount: againCount ?? this.againCount,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

const _studySentinel = Object();
