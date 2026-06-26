import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/studydesk_security.dart';
import '../data/cards_repository.dart';
import '../domain/card_record.dart';

final deckCardsControllerProvider =
    AsyncNotifierProviderFamily<DeckCardsController, List<CardRecord>, String>(
      DeckCardsController.new,
    );

class DeckCardsController extends FamilyAsyncNotifier<List<CardRecord>, String> {
  CardsRepository get _repository => ref.read(cardsRepositoryProvider);

  @override
  Future<List<CardRecord>> build(String arg) async {
    final cards = await _repository.loadCards();
    return _forDeck(cards, arg);
  }

  Future<void> addCard({
    required String deckId,
    required String front,
    required String back,
    required String hint,
  }) async {
    final allCards = await _repository.loadCards();
    final now = DateTime.now();
    final updated = [
      ...allCards,
      CardRecord(
        id: now.microsecondsSinceEpoch.toString(),
        deckId: deckId,
        front: StudyDeskSecurity.sanitizeMultiline(
          front,
          field: 'Card front',
          maxLength: StudyDeskSecurity.maxCardFaceLength,
          allowEmpty: false,
        ),
        back: StudyDeskSecurity.sanitizeMultiline(
          back,
          field: 'Card back',
          maxLength: StudyDeskSecurity.maxCardFaceLength,
          allowEmpty: false,
        ),
        hint: StudyDeskSecurity.sanitizeMultiline(
          hint,
          field: 'Card hint',
          maxLength: StudyDeskSecurity.maxCardHintLength,
        ),
        schedulerVersion: CardRecord.defaultSchedulerVersion,
        state: 'new',
        reviewCount: 0,
        lapseCount: 0,
        intervalDays: 0,
        ease: 2.5,
        stability: 0.1,
        difficulty: 5,
        dueAt: null,
        lastReviewedAt: null,
        createdAt: now,
        updatedAt: now,
        ),
    ];
    await _repository.upsertCard(updated.last);
    state = AsyncData(_forDeck(updated, deckId));
  }

  Future<void> updateCard(CardRecord card) async {
    final allCards = await _repository.loadCards();
    final normalized = card.copyWith(
      front: StudyDeskSecurity.sanitizeMultiline(
        card.front,
        field: 'Card front',
        maxLength: StudyDeskSecurity.maxCardFaceLength,
        allowEmpty: false,
      ),
      back: StudyDeskSecurity.sanitizeMultiline(
        card.back,
        field: 'Card back',
        maxLength: StudyDeskSecurity.maxCardFaceLength,
        allowEmpty: false,
      ),
      hint: StudyDeskSecurity.sanitizeMultiline(
        card.hint,
        field: 'Card hint',
        maxLength: StudyDeskSecurity.maxCardHintLength,
      ),
      updatedAt: DateTime.now(),
    );
    final updated = allCards
        .map((item) => item.id == normalized.id ? normalized : item)
        .toList();
    await _repository.upsertCard(normalized);
    state = AsyncData(_forDeck(updated, arg));
  }

  Future<void> deleteCard(String cardId) async {
    final allCards = await _repository.loadCards();
    final updated = allCards.where((item) => item.id != cardId).toList();
    await _repository.deleteCard(cardId);
    state = AsyncData(_forDeck(updated, arg));
  }

  List<CardRecord> _forDeck(List<CardRecord> cards, String deckId) {
    final filtered = cards.where((card) => card.deckId == deckId).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt) * -1);
    return filtered;
  }
}
