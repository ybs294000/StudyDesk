import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/decks_repository.dart';
import '../domain/deck_record.dart';
import '../../notes/application/note_markdown_utils.dart';

final subjectDecksControllerProvider = AsyncNotifierProviderFamily<
    SubjectDecksController, List<DeckRecord>, String>(SubjectDecksController.new);

class SubjectDecksController extends FamilyAsyncNotifier<List<DeckRecord>, String> {
  DecksRepository get _repository => ref.read(decksRepositoryProvider);

  @override
  Future<List<DeckRecord>> build(String arg) async {
    final decks = await _repository.loadDecks();
    return _forSubject(decks, arg);
  }

  Future<DeckRecord> addDeck({
    required String subjectId,
    required String name,
    required String description,
    String? unitId,
    List<String> tags = const [],
  }) async {
    final allDecks = await _repository.loadDecks();
    final now = DateTime.now();
    final deck = DeckRecord(
      id: now.microsecondsSinceEpoch.toString(),
      subjectId: subjectId,
      unitId: unitId,
      name: name.trim(),
      description: description.trim(),
      tags: normalizeTags(tags),
      createdAt: now,
      updatedAt: now,
    );
    final updated = [
      ...allDecks,
      deck,
    ];
    await _repository.upsertDeck(deck);
    state = AsyncData(_forSubject(updated, subjectId));
    return deck;
  }

  Future<void> updateDeck(DeckRecord deck) async {
    final allDecks = await _repository.loadDecks();
    final normalized = deck.copyWith(
      name: deck.name.trim(),
      description: deck.description.trim(),
      tags: normalizeTags(deck.tags),
      updatedAt: DateTime.now(),
    );
    final updated = allDecks
        .map((item) => item.id == normalized.id ? normalized : item)
        .toList();
    await _repository.upsertDeck(normalized);
    state = AsyncData(_forSubject(updated, arg));
  }

  Future<void> deleteDeck(String deckId) async {
    final allDecks = await _repository.loadDecks();
    final updated = allDecks.where((item) => item.id != deckId).toList();
    await _repository.deleteDeck(deckId);
    state = AsyncData(_forSubject(updated, arg));
  }

  List<DeckRecord> _forSubject(List<DeckRecord> decks, String subjectId) {
    final filtered = decks.where((deck) => deck.subjectId == subjectId).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt) * -1);
    return filtered;
  }
}
