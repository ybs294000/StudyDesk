import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/quiz_models.dart';

const _quizzesStorageKey = 'quizzes_v1';

abstract class QuizzesRepository {
  Future<List<QuizRecord>> loadQuizzes();
  Future<void> saveQuizzes(List<QuizRecord> quizzes);
}

final quizzesRepositoryProvider = Provider<QuizzesRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesQuizzesRepository();
  }
  return SqliteQuizzesRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesQuizzesRepository implements QuizzesRepository {
  @override
  Future<List<QuizRecord>> loadQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_quizzesStorageKey) ?? [];
    return raw.map(QuizRecord.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> saveQuizzes(List<QuizRecord> quizzes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _quizzesStorageKey,
      quizzes.map((quiz) => quiz.toJson()).toList(),
    );
  }
}

class SqliteQuizzesRepository implements QuizzesRepository {
  SqliteQuizzesRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<QuizRecord>> loadQuizzes() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('quizzes');
    return rows
        .map((row) {
          final map = <String, dynamic>{
            'id': row['id']! as String,
            'subjectId': row['subject_id']! as String,
            'unitId': row['unit_id'] as String?,
            'name': row['name']! as String,
            'description': row['description']! as String,
            'tags': row['tags_json'] == null
                ? <String>[]
                : (jsonDecode(row['tags_json']! as String) as List).cast<String>(),
            'settings': jsonDecode(row['settings_json']! as String)
                as Map<String, dynamic>,
            'questions': (jsonDecode(row['questions_json']! as String) as List)
                .cast<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList(),
            'createdAt': row['created_at']! as String,
            'updatedAt': row['updated_at']! as String,
          };
          return QuizRecord.fromMap(map);
        })
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> saveQuizzes(List<QuizRecord> quizzes) async {
    final db = await _appDatabase.instance;
    await db.transaction((txn) async {
      final existingRows = await txn.query('quizzes', columns: ['id']);
      final existingIds = existingRows.map((row) => row['id']! as String).toSet();
      final incomingIds = quizzes.map((quiz) => quiz.id).toSet();

      for (final id in existingIds.difference(incomingIds)) {
        await txn.delete('quizzes', where: 'id = ?', whereArgs: [id]);
      }

      for (final quiz in quizzes) {
        final values = {
          'id': quiz.id,
          'subject_id': quiz.subjectId,
          'unit_id': quiz.unitId,
          'name': quiz.name,
          'description': quiz.description,
          'tags_json': jsonEncode(quiz.tags),
          'settings_json': jsonEncode(quiz.settings.toMap()),
          'questions_json': jsonEncode(
            quiz.questions.map((q) => q.toMap()).toList(),
          ),
          'created_at': quiz.createdAt.toIso8601String(),
          'updated_at': quiz.updatedAt.toIso8601String(),
        };
        final updatedCount = await txn.update(
          'quizzes',
          values,
          where: 'id = ?',
          whereArgs: [quiz.id],
        );
        if (updatedCount == 0) {
          await txn.insert('quizzes', values);
        }
      }
    });
  }
}
