import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/quiz_attempt_session_record.dart';

const _quizAttemptsStorageKey = 'quiz_attempt_sessions_v1';

abstract class QuizAttemptsRepository {
  Future<List<QuizAttemptSessionRecord>> loadAttempts();
  Future<void> addAttempt(QuizAttemptSessionRecord attempt);
}

final quizAttemptsRepositoryProvider = Provider<QuizAttemptsRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesQuizAttemptsRepository();
  }
  return SqliteQuizAttemptsRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesQuizAttemptsRepository implements QuizAttemptsRepository {
  @override
  Future<List<QuizAttemptSessionRecord>> loadAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_quizAttemptsStorageKey) ?? const [];
    return raw.map(QuizAttemptSessionRecord.fromJson).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<void> addAttempt(QuizAttemptSessionRecord attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_quizAttemptsStorageKey) ?? const [];
    final updated = <String>[attempt.toJson(), ...current];
    await prefs.setStringList(_quizAttemptsStorageKey, updated);
  }
}

class SqliteQuizAttemptsRepository implements QuizAttemptsRepository {
  SqliteQuizAttemptsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<QuizAttemptSessionRecord>> loadAttempts() async {
    final db = await _appDatabase.instance;
    final rows = await db.query(
      'quiz_attempt_sessions',
      orderBy: 'started_at DESC',
    );
    return rows
        .map(
          (row) => QuizAttemptSessionRecord.fromMap({
            'id': row['id'],
            'quizId': row['quiz_id'],
            'subjectId': row['subject_id'],
            'unitId': row['unit_id'],
            'quizName': row['quiz_name'],
            'quizDescription': row['quiz_description'],
            'quizTags': ((jsonDecode((row['quiz_tags_json'] as String?) ?? '[]') as List))
                .cast<String>(),
            'startedAt': row['started_at'],
            'endedAt': row['ended_at'],
            'mode': row['mode'],
            'totalQuestions': row['total_questions'],
            'attemptedQuestions': row['attempted_questions'],
            'correctCount': row['correct_count'],
            'wrongCount': row['wrong_count'],
            'skippedCount': row['skipped_count'],
            'rawScore': row['raw_score'],
            'maxScore': row['max_score'],
            'scorePercent': row['score_percent'],
            'passingScorePercent': row['passing_score_percent'],
            'passed': (row['passed'] as int?) == null
                ? null
                : (row['passed'] as int) == 1,
            'weakTags': ((jsonDecode((row['weak_tags_json'] as String?) ?? '[]') as List))
                .cast<String>(),
            'strongTags': ((jsonDecode((row['strong_tags_json'] as String?) ?? '[]') as List))
                .cast<String>(),
            'items': ((jsonDecode(row['items_json']! as String) as List))
                .cast<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList(),
          }),
        )
        .toList();
  }

  @override
  Future<void> addAttempt(QuizAttemptSessionRecord attempt) async {
    final db = await _appDatabase.instance;
    await db.insert('quiz_attempt_sessions', {
      'id': attempt.id,
      'quiz_id': attempt.quizId,
      'subject_id': attempt.subjectId,
      'unit_id': attempt.unitId,
      'quiz_name': attempt.quizName,
      'quiz_description': attempt.quizDescription,
      'quiz_tags_json': jsonEncode(attempt.quizTags),
      'started_at': attempt.startedAt.toIso8601String(),
      'ended_at': attempt.endedAt.toIso8601String(),
      'mode': attempt.mode,
      'total_questions': attempt.totalQuestions,
      'attempted_questions': attempt.attemptedQuestions,
      'correct_count': attempt.correctCount,
      'wrong_count': attempt.wrongCount,
      'skipped_count': attempt.skippedCount,
      'raw_score': attempt.rawScore,
      'max_score': attempt.maxScore,
      'score_percent': attempt.scorePercent,
      'passing_score_percent': attempt.passingScorePercent,
      'passed': attempt.passed == null ? null : (attempt.passed! ? 1 : 0),
      'weak_tags_json': jsonEncode(attempt.weakTags),
      'strong_tags_json': jsonEncode(attempt.strongTags),
      'items_json': jsonEncode(attempt.items.map((item) => item.toMap()).toList()),
    });
  }
}
