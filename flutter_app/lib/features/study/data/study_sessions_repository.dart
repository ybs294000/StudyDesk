import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/study_session_record.dart';

const _studySessionsStorageKey = 'study_sessions_v1';

abstract class StudySessionsRepository {
  Future<List<StudySessionRecord>> loadSessions();
  Future<void> addSession(StudySessionRecord session);
}

final studySessionsRepositoryProvider = Provider<StudySessionsRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesStudySessionsRepository();
  }
  return SqliteStudySessionsRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesStudySessionsRepository
    implements StudySessionsRepository {
  @override
  Future<void> addSession(StudySessionRecord session) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_studySessionsStorageKey) ?? [];
    await prefs.setStringList(
      _studySessionsStorageKey,
      [...current, session.toJson()],
    );
  }

  @override
  Future<List<StudySessionRecord>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_studySessionsStorageKey) ?? [];
    final sessions = raw.map(StudySessionRecord.fromJson).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }
}

class SqliteStudySessionsRepository implements StudySessionsRepository {
  SqliteStudySessionsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> addSession(StudySessionRecord session) async {
    final db = await _appDatabase.instance;
    await db.insert('study_sessions', {
      'id': session.id,
      'subject_id': session.subjectId,
      'deck_id': session.deckId,
      'session_type': session.sessionType,
      'started_at': session.startedAt.toIso8601String(),
      'ended_at': session.endedAt.toIso8601String(),
      'reviewed_count': session.reviewedCount,
      'completed_count': session.completedCount,
      'again_count': session.againCount,
      'due_count': session.dueCount,
    });
  }

  @override
  Future<List<StudySessionRecord>> loadSessions() async {
    final db = await _appDatabase.instance;
    final rows = await db.query(
      'study_sessions',
      orderBy: 'started_at DESC',
    );
    return rows
        .map(
          (row) => StudySessionRecord(
            id: row['id']! as String,
            subjectId: row['subject_id'] as String?,
            deckId: row['deck_id'] as String?,
            sessionType: row['session_type']! as String,
            startedAt: DateTime.parse(row['started_at']! as String),
            endedAt: DateTime.parse(row['ended_at']! as String),
            reviewedCount: row['reviewed_count']! as int,
            completedCount: row['completed_count']! as int,
            againCount: row['again_count']! as int,
            dueCount: row['due_count']! as int,
          ),
        )
        .toList();
  }
}
