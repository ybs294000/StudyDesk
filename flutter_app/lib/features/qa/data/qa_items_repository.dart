import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/qa_item_record.dart';

const _qaItemsStorageKey = 'qa_items_v1';

abstract class QaItemsRepository {
  Future<List<QaItemRecord>> loadItems();
  Future<void> upsertItem(QaItemRecord item);
  Future<void> deleteItem(String id);
}

final qaItemsRepositoryProvider = Provider<QaItemsRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesQaItemsRepository();
  }
  return SqliteQaItemsRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesQaItemsRepository implements QaItemsRepository {
  @override
  Future<void> deleteItem(String id) async {
    final items = await loadItems();
    await _save(items.where((item) => item.id != id).toList());
  }

  @override
  Future<List<QaItemRecord>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_qaItemsStorageKey) ?? const [];
    return raw.map(QaItemRecord.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> upsertItem(QaItemRecord item) async {
    final items = await loadItems();
    final updated = [
      for (final current in items)
        if (current.id != item.id) current,
      item,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _save(updated);
  }

  Future<void> _save(List<QaItemRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _qaItemsStorageKey,
      items.map((item) => item.toJson()).toList(),
    );
  }
}

class SqliteQaItemsRepository implements QaItemsRepository {
  SqliteQaItemsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> deleteItem(String id) async {
    final db = await _appDatabase.instance;
    await db.delete('qa_items', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<QaItemRecord>> loadItems() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('qa_items', orderBy: 'updated_at DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsertItem(QaItemRecord item) async {
    final db = await _appDatabase.instance;
    await db.insert(
      'qa_items',
      {
        'id': item.id,
        'subject_id': item.subjectId,
        'unit_id': item.unitId,
        'question': item.question,
        'answer_markdown': item.answerMarkdown,
        'tags_json': jsonEncode(item.tags),
        'created_at': item.createdAt.toIso8601String(),
        'updated_at': item.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  QaItemRecord _fromRow(Map<String, Object?> row) {
    return QaItemRecord(
      id: row['id']! as String,
      subjectId: row['subject_id']! as String,
      unitId: row['unit_id'] as String?,
      question: row['question']! as String,
      answerMarkdown: row['answer_markdown']! as String,
      tags: ((jsonDecode((row['tags_json'] as String?) ?? '[]') as List))
          .map((item) => item.toString())
          .toList(),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
