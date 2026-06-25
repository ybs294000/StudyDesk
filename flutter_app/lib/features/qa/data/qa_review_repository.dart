import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/qa_review_record.dart';

const _qaReviewStorageKey = 'qa_review_states_v1';

abstract class QaReviewRepository {
  Future<List<QaReviewRecord>> loadReviews();
  Future<QaReviewRecord?> loadReview(String promptId);
  Future<void> upsertReview(QaReviewRecord review);
  Future<void> deleteReview(String promptId);
}

final qaReviewRepositoryProvider = Provider<QaReviewRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesQaReviewRepository();
  }
  return SqliteQaReviewRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesQaReviewRepository implements QaReviewRepository {
  @override
  Future<void> deleteReview(String promptId) async {
    final reviews = await loadReviews();
    await _save(reviews.where((item) => item.promptId != promptId).toList());
  }

  @override
  Future<QaReviewRecord?> loadReview(String promptId) async {
    final reviews = await loadReviews();
    for (final review in reviews) {
      if (review.promptId == promptId) {
        return review;
      }
    }
    return null;
  }

  @override
  Future<List<QaReviewRecord>> loadReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_qaReviewStorageKey) ?? const [];
    return raw.map(QaReviewRecord.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> upsertReview(QaReviewRecord review) async {
    final reviews = await loadReviews();
    final updated = [
      for (final item in reviews)
        if (item.promptId != review.promptId) item,
      review,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _save(updated);
  }

  Future<void> _save(List<QaReviewRecord> reviews) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _qaReviewStorageKey,
      reviews.map((item) => item.toJson()).toList(),
    );
  }
}

class SqliteQaReviewRepository implements QaReviewRepository {
  SqliteQaReviewRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> deleteReview(String promptId) async {
    final db = await _appDatabase.instance;
    await db.delete('qa_review_states', where: 'prompt_id = ?', whereArgs: [promptId]);
  }

  @override
  Future<QaReviewRecord?> loadReview(String promptId) async {
    final db = await _appDatabase.instance;
    final rows = await db.query(
      'qa_review_states',
      where: 'prompt_id = ?',
      whereArgs: [promptId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  @override
  Future<List<QaReviewRecord>> loadReviews() async {
    final db = await _appDatabase.instance;
    final rows = await db.query('qa_review_states', orderBy: 'updated_at DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsertReview(QaReviewRecord review) async {
    final db = await _appDatabase.instance;
    await db.insert(
      'qa_review_states',
      {
        'prompt_id': review.promptId,
        'subject_id': review.subjectId,
        'unit_id': review.unitId,
        'review_count': review.reviewCount,
        'lapse_count': review.lapseCount,
        'interval_days': review.intervalDays,
        'study_state': review.state,
        'stability': review.stability,
        'difficulty': review.difficulty,
        'due_at': review.dueAt?.toIso8601String(),
        'last_reviewed_at': review.lastReviewedAt?.toIso8601String(),
        'last_rating': review.lastRating?.storageValue,
        'last_answer_snippet': review.lastAnswerSnippet,
        'updated_at': review.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  QaReviewRecord _fromRow(Map<String, Object?> row) {
    return QaReviewRecord(
      promptId: row['prompt_id']! as String,
      subjectId: row['subject_id']! as String,
      unitId: row['unit_id'] as String?,
      reviewCount: (row['review_count'] as int?) ?? 0,
      lapseCount: (row['lapse_count'] as int?) ?? 0,
      intervalDays: (row['interval_days'] as int?) ?? 0,
      state: (row['study_state'] as String?) ?? 'new',
      stability: ((row['stability'] as num?) ?? 0.1).toDouble(),
      difficulty: ((row['difficulty'] as num?) ?? 5.0).toDouble(),
      dueAt: row['due_at'] == null ? null : DateTime.parse(row['due_at']! as String),
      lastReviewedAt: row['last_reviewed_at'] == null
          ? null
          : DateTime.parse(row['last_reviewed_at']! as String),
      lastRating: row['last_rating'] == null
          ? null
          : QaRecallRatingX.fromStorage(row['last_rating']! as String?),
      lastAnswerSnippet: row['last_answer_snippet'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
