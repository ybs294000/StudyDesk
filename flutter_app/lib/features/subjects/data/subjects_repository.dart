import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/subject_record.dart';

const _subjectsStorageKey = 'subjects_v1';

abstract class SubjectsRepository {
  Future<List<SubjectRecord>> loadSubjects();
  Future<void> saveSubjects(List<SubjectRecord> subjects);
}

final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesSubjectsRepository();
  }
  return SqliteSubjectsRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesSubjectsRepository implements SubjectsRepository {
  @override
  Future<List<SubjectRecord>> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSubjects = prefs.getStringList(_subjectsStorageKey) ?? [];
    return rawSubjects.map(SubjectRecord.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<void> saveSubjects(List<SubjectRecord> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = subjects.map((subject) => subject.toJson()).toList();
    await prefs.setStringList(_subjectsStorageKey, payload);
  }
}

class SqliteSubjectsRepository implements SubjectsRepository {
  SqliteSubjectsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<SubjectRecord>> loadSubjects() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('subjects');
    return rows
        .map(
          (row) => SubjectRecord(
            id: row['id']! as String,
            name: row['name']! as String,
            emoji: row['emoji']! as String,
            colorValue: row['color_value']! as int,
            createdAt: DateTime.parse(row['created_at']! as String),
            updatedAt: DateTime.parse(row['updated_at']! as String),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<void> saveSubjects(List<SubjectRecord> subjects) async {
    final db = await _appDatabase.instance;
    await db.transaction((txn) async {
      final existingRows = await txn.query('subjects', columns: ['id']);
      final existingIds = existingRows
          .map((row) => row['id']! as String)
          .toSet();
      final incomingIds = subjects.map((subject) => subject.id).toSet();

      for (final id in existingIds.difference(incomingIds)) {
        await txn.delete('subjects', where: 'id = ?', whereArgs: [id]);
      }

      for (final subject in subjects) {
        final values = {
          'id': subject.id,
          'name': subject.name,
          'emoji': subject.emoji,
          'color_value': subject.colorValue,
          'created_at': subject.createdAt.toIso8601String(),
          'updated_at': subject.updatedAt.toIso8601String(),
        };
        final updatedCount = await txn.update(
          'subjects',
          values,
          where: 'id = ?',
          whereArgs: [subject.id],
        );
        if (updatedCount == 0) {
          await txn.insert('subjects', values);
        }
      }
    });
  }
}
