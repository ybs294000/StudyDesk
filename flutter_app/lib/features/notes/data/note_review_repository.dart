import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/note_review_record.dart';

const _noteReviewStorageKey = 'note_review_states_v1';

abstract class NoteReviewRepository {
  Future<List<NoteReviewRecord>> loadReviews();
  Future<NoteReviewRecord?> loadReview(String noteId);
  Future<void> upsertReview(NoteReviewRecord review);
  Future<void> deleteReview(String noteId);
}

final noteReviewRepositoryProvider = Provider<NoteReviewRepository>((ref) {
  if (kIsWeb) {
    return SharedPreferencesNoteReviewRepository();
  }
  return SqliteNoteReviewRepository(ref.read(appDatabaseProvider));
});

class SharedPreferencesNoteReviewRepository implements NoteReviewRepository {
  @override
  Future<void> deleteReview(String noteId) async {
    final reviews = await loadReviews();
    await _save(
      reviews.where((item) => item.noteId != noteId).toList(),
    );
  }

  @override
  Future<NoteReviewRecord?> loadReview(String noteId) async {
    final reviews = await loadReviews();
    for (final review in reviews) {
      if (review.noteId == noteId) {
        return review;
      }
    }
    return null;
  }

  @override
  Future<List<NoteReviewRecord>> loadReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_noteReviewStorageKey) ?? const [];
    return raw.map(NoteReviewRecord.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> upsertReview(NoteReviewRecord review) async {
    final reviews = await loadReviews();
    final updated = [
      for (final item in reviews)
        if (item.noteId != review.noteId) item,
      review,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _save(updated);
  }

  Future<void> _save(List<NoteReviewRecord> reviews) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _noteReviewStorageKey,
      reviews.map((item) => item.toJson()).toList(),
    );
  }
}

class SqliteNoteReviewRepository implements NoteReviewRepository {
  SqliteNoteReviewRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> deleteReview(String noteId) async {
    final db = await _appDatabase.instance;
    await db.delete(
      'note_review_states',
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  @override
  Future<NoteReviewRecord?> loadReview(String noteId) async {
    final db = await _appDatabase.instance;
    final rows = await db.query(
      'note_review_states',
      where: 'note_id = ?',
      whereArgs: [noteId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  @override
  Future<List<NoteReviewRecord>> loadReviews() async {
    final db = await _appDatabase.instance;
    final rows = await db.query(
      'note_review_states',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsertReview(NoteReviewRecord review) async {
    final db = await _appDatabase.instance;
    await db.insert(
      'note_review_states',
      {
        'note_id': review.noteId,
        'subject_id': review.subjectId,
        'unit_id': review.unitId,
        'review_count': review.reviewCount,
        'last_read_at': review.lastReadAt?.toIso8601String(),
        'due_at': review.dueAt?.toIso8601String(),
        'last_rating': review.lastRating?.storageValue,
        'pending_self_note': review.pendingSelfNote,
        'pending_self_note_created_at':
            review.pendingSelfNoteCreatedAt?.toIso8601String(),
        'archived_self_notes_json':
            jsonEncode(review.archivedSelfNotes.map((item) => item.toMap()).toList()),
        'section_annotations_json': jsonEncode(review.sectionAnnotations),
        'updated_at': review.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  NoteReviewRecord _fromRow(Map<String, Object?> row) {
    return NoteReviewRecord(
      noteId: row['note_id']! as String,
      subjectId: row['subject_id']! as String,
      unitId: row['unit_id'] as String?,
      reviewCount: (row['review_count']! as int?) ?? 0,
      lastReadAt: row['last_read_at'] == null
          ? null
          : DateTime.parse(row['last_read_at']! as String),
      dueAt: row['due_at'] == null
          ? null
          : DateTime.parse(row['due_at']! as String),
      lastRating: row['last_rating'] == null
          ? null
          : NoteRecallRatingX.fromStorage(row['last_rating']! as String),
      pendingSelfNote: row['pending_self_note'] as String?,
      pendingSelfNoteCreatedAt: row['pending_self_note_created_at'] == null
          ? null
          : DateTime.parse(row['pending_self_note_created_at']! as String),
      archivedSelfNotes:
          ((jsonDecode((row['archived_self_notes_json'] as String?) ?? '[]') as List))
              .map((item) => NoteArchivedPrompt.fromMap((item as Map).cast<String, dynamic>()))
              .toList(),
      sectionAnnotations:
          ((jsonDecode((row['section_annotations_json'] as String?) ?? '{}') as Map))
              .map((key, value) => MapEntry(key.toString(), value.toString())),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
