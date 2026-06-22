import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/card_record.dart';

const _cardsStorageKey = 'cards_v1';

abstract class CardsRepository {
  Future<List<CardRecord>> loadCards();
  Future<void> saveCards(List<CardRecord> cards);
}

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesCardsRepository();
  }
  return SqliteCardsRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesCardsRepository implements CardsRepository {
  @override
  Future<List<CardRecord>> loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCards = prefs.getStringList(_cardsStorageKey) ?? [];
    return rawCards.map(CardRecord.fromJson).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt) * -1);
  }

  @override
  Future<void> saveCards(List<CardRecord> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = cards.map((card) => card.toJson()).toList();
    await prefs.setStringList(_cardsStorageKey, payload);
  }
}

class SqliteCardsRepository implements CardsRepository {
  SqliteCardsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<CardRecord>> loadCards() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('cards');
    return rows
        .map(
          (row) => CardRecord(
            id: row['id']! as String,
            deckId: row['deck_id']! as String,
            front: row['front']! as String,
            back: row['back']! as String,
            hint: row['hint']! as String,
            schedulerVersion:
                (row['scheduler_version'] as String?) ?? 'adaptive_memory_v2',
            state: (row['study_state'] as String?) ?? 'new',
            reviewCount: (row['review_count'] as int?) ?? 0,
            lapseCount: (row['lapse_count'] as int?) ?? 0,
            intervalDays: (row['interval_days'] as int?) ?? 0,
            ease: ((row['ease'] as num?) ?? 2.5).toDouble(),
            stability: ((row['stability'] as num?) ?? 0.2).toDouble(),
            difficulty: ((row['difficulty'] as num?) ?? 5.0).toDouble(),
            dueAt: row['due_at'] == null
                ? null
                : DateTime.parse(row['due_at']! as String),
            lastReviewedAt: row['last_reviewed_at'] == null
                ? null
                : DateTime.parse(row['last_reviewed_at']! as String),
            createdAt: DateTime.parse(row['created_at']! as String),
            updatedAt: DateTime.parse(row['updated_at']! as String),
          ),
        )
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt) * -1);
  }

  @override
  Future<void> saveCards(List<CardRecord> cards) async {
    final db = await _appDatabase.instance;
    await db.transaction((txn) async {
      final existingRows = await txn.query('cards', columns: ['id']);
      final existingIds = existingRows.map((row) => row['id']! as String).toSet();
      final incomingIds = cards.map((card) => card.id).toSet();

      for (final id in existingIds.difference(incomingIds)) {
        await txn.delete('cards', where: 'id = ?', whereArgs: [id]);
      }

      for (final card in cards) {
        final values = {
          'id': card.id,
          'deck_id': card.deckId,
          'front': card.front,
          'back': card.back,
          'hint': card.hint,
          'scheduler_version': card.schedulerVersion,
          'study_state': card.state,
          'review_count': card.reviewCount,
          'lapse_count': card.lapseCount,
          'interval_days': card.intervalDays,
          'ease': card.ease,
          'stability': card.stability,
          'difficulty': card.difficulty,
          'due_at': card.dueAt?.toIso8601String(),
          'last_reviewed_at': card.lastReviewedAt?.toIso8601String(),
          'created_at': card.createdAt.toIso8601String(),
          'updated_at': card.updatedAt.toIso8601String(),
        };
        final updatedCount = await txn.update(
          'cards',
          values,
          where: 'id = ?',
          whereArgs: [card.id],
        );
        if (updatedCount == 0) {
          await txn.insert('cards', values);
        }
      }
    });
  }
}
