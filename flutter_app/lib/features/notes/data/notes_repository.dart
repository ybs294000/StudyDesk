import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/note_record.dart';

const _notesStorageKey = 'notes_v1';

abstract class NotesRepository {
  Future<List<NoteRecord>> loadNotes();
  Future<void> saveNotes(List<NoteRecord> notes);
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesNotesRepository();
  }
  return SqliteNotesRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesNotesRepository implements NotesRepository {
  @override
  Future<List<NoteRecord>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final rawNotes = prefs.getStringList(_notesStorageKey) ?? const [];
    return rawNotes.map(NoteRecord.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> saveNotes(List<NoteRecord> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = notes.map((note) => note.toJson()).toList();
    await prefs.setStringList(_notesStorageKey, payload);
  }
}

class SqliteNotesRepository implements NotesRepository {
  SqliteNotesRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<NoteRecord>> loadNotes() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('notes');
    return rows
        .map(
          (row) => NoteRecord(
            id: row['id']! as String,
            subjectId: row['subject_id']! as String,
            unitId: row['unit_id'] as String?,
            title: row['title']! as String,
            bodyMarkdown: row['body_markdown']! as String,
            tags: ((jsonDecode((row['tags_json'] as String?) ?? '[]') as List))
                .cast<String>(),
            createdAt: DateTime.parse(row['created_at']! as String),
            updatedAt: DateTime.parse(row['updated_at']! as String),
          ),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> saveNotes(List<NoteRecord> notes) async {
    final db = await _appDatabase.instance;
    await db.transaction((txn) async {
      final existingRows = await txn.query('notes', columns: ['id']);
      final existingIds = existingRows.map((row) => row['id']! as String).toSet();
      final incomingIds = notes.map((note) => note.id).toSet();

      for (final id in existingIds.difference(incomingIds)) {
        await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
      }

      for (final note in notes) {
        final values = {
          'id': note.id,
          'subject_id': note.subjectId,
          'unit_id': note.unitId,
          'title': note.title,
          'body_markdown': note.bodyMarkdown,
          'tags_json': jsonEncode(note.tags),
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': note.updatedAt.toIso8601String(),
        };
        final updatedCount = await txn.update(
          'notes',
          values,
          where: 'id = ?',
          whereArgs: [note.id],
        );
        if (updatedCount == 0) {
          await txn.insert('notes', values);
        }
      }
    });
  }
}
