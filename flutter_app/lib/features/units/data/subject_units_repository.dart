import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/subject_unit_record.dart';

const _subjectUnitsStorageKey = 'subject_units_v1';

abstract class SubjectUnitsRepository {
  Future<List<SubjectUnitRecord>> loadUnits();
  Future<void> saveUnits(List<SubjectUnitRecord> units);
  Future<void> upsertUnit(SubjectUnitRecord unit);
  Future<void> deleteUnit(String id);
}

final subjectUnitsRepositoryProvider = Provider<SubjectUnitsRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesSubjectUnitsRepository();
  }
  return SqliteSubjectUnitsRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesSubjectUnitsRepository implements SubjectUnitsRepository {
  @override
  Future<List<SubjectUnitRecord>> loadUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_subjectUnitsStorageKey) ?? const [];
    return raw.map(SubjectUnitRecord.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<void> saveUnits(List<SubjectUnitRecord> units) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _subjectUnitsStorageKey,
      units.map((unit) => unit.toJson()).toList(),
    );
  }

  @override
  Future<void> upsertUnit(SubjectUnitRecord unit) async {
    final units = await loadUnits();
    final updated = [
      for (final item in units)
        if (item.id != unit.id) item,
      unit,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await saveUnits(updated);
  }

  @override
  Future<void> deleteUnit(String id) async {
    final units = await loadUnits();
    await saveUnits(units.where((item) => item.id != id).toList());
  }
}

class SqliteSubjectUnitsRepository implements SubjectUnitsRepository {
  SqliteSubjectUnitsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<SubjectUnitRecord>> loadUnits() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('subject_units');
    return rows
        .map(
          (row) => SubjectUnitRecord(
            id: row['id']! as String,
            subjectId: row['subject_id']! as String,
            name: row['name']! as String,
            description: (row['description'] as String?) ?? '',
            createdAt: DateTime.parse(row['created_at']! as String),
            updatedAt: DateTime.parse(row['updated_at']! as String),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<void> saveUnits(List<SubjectUnitRecord> units) async {
    final db = await _appDatabase.instance;
    await db.transaction((txn) async {
      final existingRows = await txn.query('subject_units', columns: ['id']);
      final existingIds = existingRows.map((row) => row['id']! as String).toSet();
      final incomingIds = units.map((unit) => unit.id).toSet();

      for (final id in existingIds.difference(incomingIds)) {
        await txn.delete('subject_units', where: 'id = ?', whereArgs: [id]);
      }

      for (final unit in units) {
        final values = {
          'id': unit.id,
          'subject_id': unit.subjectId,
          'name': unit.name,
          'description': unit.description,
          'created_at': unit.createdAt.toIso8601String(),
          'updated_at': unit.updatedAt.toIso8601String(),
        };
        final updatedCount = await txn.update(
          'subject_units',
          values,
          where: 'id = ?',
          whereArgs: [unit.id],
        );
        if (updatedCount == 0) {
          await txn.insert('subject_units', values);
        }
      }
    });
  }

  @override
  Future<void> upsertUnit(SubjectUnitRecord unit) async {
    final db = await _appDatabase.instance;
    await db.insert('subject_units', {
      'id': unit.id,
      'subject_id': unit.subjectId,
      'name': unit.name,
      'description': unit.description,
      'created_at': unit.createdAt.toIso8601String(),
      'updated_at': unit.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteUnit(String id) async {
    final db = await _appDatabase.instance;
    await db.delete('subject_units', where: 'id = ?', whereArgs: [id]);
  }
}
