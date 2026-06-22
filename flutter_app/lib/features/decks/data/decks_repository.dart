import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/deck_record.dart';

const _decksStorageKey = 'decks_v1';

abstract class DecksRepository {
  Future<List<DeckRecord>> loadDecks();
  Future<void> saveDecks(List<DeckRecord> decks);
}

final decksRepositoryProvider = Provider<DecksRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesDecksRepository();
  }
  return SqliteDecksRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesDecksRepository implements DecksRepository {
  @override
  Future<List<DeckRecord>> loadDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDecks = prefs.getStringList(_decksStorageKey) ?? [];
    return rawDecks.map(DeckRecord.fromJson).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt) * -1);
  }

  @override
  Future<void> saveDecks(List<DeckRecord> decks) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = decks.map((deck) => deck.toJson()).toList();
    await prefs.setStringList(_decksStorageKey, payload);
  }
}

class SqliteDecksRepository implements DecksRepository {
  SqliteDecksRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<DeckRecord>> loadDecks() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('decks');
    return rows
        .map(
          (row) => DeckRecord(
            id: row['id']! as String,
            subjectId: row['subject_id']! as String,
            unitId: row['unit_id'] as String?,
            name: row['name']! as String,
            description: row['description']! as String,
            tags: ((jsonDecode((row['tags_json'] as String?) ?? '[]') as List))
                .cast<String>(),
            createdAt: DateTime.parse(row['created_at']! as String),
            updatedAt: DateTime.parse(row['updated_at']! as String),
          ),
        )
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt) * -1);
  }

  @override
  Future<void> saveDecks(List<DeckRecord> decks) async {
    final db = await _appDatabase.instance;
    await db.transaction((txn) async {
      final existingRows = await txn.query('decks', columns: ['id']);
      final existingIds = existingRows.map((row) => row['id']! as String).toSet();
      final incomingIds = decks.map((deck) => deck.id).toSet();

      for (final id in existingIds.difference(incomingIds)) {
        await txn.delete('decks', where: 'id = ?', whereArgs: [id]);
      }

      for (final deck in decks) {
        final values = {
          'id': deck.id,
          'subject_id': deck.subjectId,
          'unit_id': deck.unitId,
          'name': deck.name,
          'description': deck.description,
          'tags_json': jsonEncode(deck.tags),
          'created_at': deck.createdAt.toIso8601String(),
          'updated_at': deck.updatedAt.toIso8601String(),
        };
        final updatedCount = await txn.update(
          'decks',
          values,
          where: 'id = ?',
          whereArgs: [deck.id],
        );
        if (updatedCount == 0) {
          await txn.insert('decks', values);
        }
      }
    });
  }
}
