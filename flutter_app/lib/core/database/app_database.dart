import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/cards/domain/card_record.dart';
import '../../features/decks/domain/deck_record.dart';
import '../../features/notes/domain/note_record.dart';
import '../../features/qa/domain/qa_item_record.dart';
import '../../features/qa/domain/qa_review_record.dart';
import '../../features/quizzes/domain/quiz_attempt_session_record.dart';
import '../../features/quizzes/domain/quiz_models.dart';
import '../../features/study/domain/study_session_record.dart';
import '../../features/subjects/domain/subject_record.dart';
import '../../features/units/domain/subject_unit_record.dart';

const _legacySubjectsStorageKey = 'subjects_v1';
const _legacyDecksStorageKey = 'decks_v1';
const _legacyCardsStorageKey = 'cards_v1';
const _legacyQuizzesStorageKey = 'quizzes_v1';
const _legacyNotesStorageKey = 'notes_v1';
const _legacyQaItemsStorageKey = 'qa_items_v1';
const _legacyQaReviewStatesStorageKey = 'qa_review_states_v1';
const _legacySubjectUnitsStorageKey = 'subject_units_v1';
const _legacyStudySessionsStorageKey = 'study_sessions_v1';
const _legacyQuizAttemptsStorageKey = 'quiz_attempt_sessions_v1';
const _migrationFlagKey = 'sqlite_content_migrated_v1';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

class AppDatabase {
  Database? _database;
  Future<Database>? _openingFuture;

  Future<Database> get instance async {
    if (_database != null) {
      return _database!;
    }
    _openingFuture ??= _open();
    _database = await _openingFuture!;
    return _database!;
  }

  Future<void> ensureReady() async {
    await instance;
  }

  Future<DatabaseAuditReport> auditConsistency() async {
    final db = await instance;
    final quickCheck = await db.rawQuery('PRAGMA quick_check');
    final foreignKeyIssues = await db.rawQuery('PRAGMA foreign_key_check');
    return DatabaseAuditReport(
      quickCheckPassed:
          quickCheck.isNotEmpty && quickCheck.first.values.first == 'ok',
      foreignKeyViolations: foreignKeyIssues.length,
    );
  }

  Future<Database> _open() async {
    if (kIsWeb) {
      throw StateError(
        'AppDatabase should not open on web. StudyDesk uses SharedPreferences-backed repositories for the web target.',
      );
    }

    final factory = _createDatabaseFactory();
    final databasesPath = await _resolveDatabaseDirectory(factory);
    final path = p.join(databasesPath, 'studydesk.db');
    await _createPreflightBackupIfNeeded(path);
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 10,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA busy_timeout = 5000');
          await db.execute('PRAGMA secure_delete = ON');
          try {
            await db.execute('PRAGMA trusted_schema = OFF');
          } catch (_) {
            // Older SQLite builds may not support trusted_schema.
          }
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _upgradeToV2(db);
          }
          if (oldVersion < 3) {
            await _upgradeToV3(db);
          }
          if (oldVersion < 4) {
            await _upgradeToV4(db);
          }
          if (oldVersion < 5) {
            await _upgradeToV5(db);
          }
          if (oldVersion < 6) {
            await _upgradeToV6(db);
          }
          if (oldVersion < 7) {
            await _upgradeToV7(db);
          }
          if (oldVersion < 8) {
            await _upgradeToV8(db);
          }
          if (oldVersion < 9) {
            await _upgradeToV9(db);
          }
          if (oldVersion < 10) {
            await _upgradeToV10(db);
          }
        },
      ),
    );

    await _migrateLegacySharedPreferences(database);
    await _runPostOpenIntegrityChecks(database);
    return database;
  }

  Future<void> _runPostOpenIntegrityChecks(Database db) async {
    final quickCheck = await db.rawQuery('PRAGMA quick_check');
    final quickResult = quickCheck.isEmpty ? null : quickCheck.first.values.first;
    if (quickResult != 'ok') {
      throw StateError(
        'StudyDesk detected a database integrity problem during startup.',
      );
    }

    final foreignKeyIssues = await db.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeyIssues.isNotEmpty) {
      throw StateError(
        'StudyDesk detected a relational integrity problem during startup.',
      );
    }
  }

  Future<String> _resolveDatabaseDirectory(DatabaseFactory factory) async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final appSupportDirectory = await getApplicationSupportDirectory();
      final databaseDirectory = Directory(
        p.join(appSupportDirectory.path, 'database'),
      );
      if (!databaseDirectory.existsSync()) {
        databaseDirectory.createSync(recursive: true);
      }
      await _migrateDesktopLegacyDatabaseIfNeeded(databaseDirectory.path);
      return databaseDirectory.path;
    }
    return factory.getDatabasesPath();
  }

  Future<void> _migrateDesktopLegacyDatabaseIfNeeded(String newDirectory) async {
    final legacyDirectory = Directory(
      p.absolute(p.join('.dart_tool', 'sqflite_common_ffi', 'databases')),
    );
    final legacyPath = p.join(legacyDirectory.path, 'studydesk.db');
    final newPath = p.join(newDirectory, 'studydesk.db');
    final legacyFile = File(legacyPath);
    final newFile = File(newPath);

    if (!legacyFile.existsSync() || newFile.existsSync()) {
      return;
    }

    if (!Directory(newDirectory).existsSync()) {
      Directory(newDirectory).createSync(recursive: true);
    }
    await legacyFile.copy(newPath);
  }

  Future<void> _createPreflightBackupIfNeeded(String databasePath) async {
    final databaseFile = File(databasePath);
    if (!databaseFile.existsSync()) {
      return;
    }

    final lastModified = databaseFile.lastModifiedSync().millisecondsSinceEpoch;
    final backupsDirectory = Directory(p.join(p.dirname(databasePath), 'backups'));
    if (!backupsDirectory.existsSync()) {
      backupsDirectory.createSync(recursive: true);
    }

    final backupFile = File(
      p.join(backupsDirectory.path, 'studydesk-preopen-$lastModified.db'),
    );
    if (backupFile.existsSync()) {
      return;
    }

    await databaseFile.copy(backupFile.path);
  }

  DatabaseFactory _createDatabaseFactory() {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE decks (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id TEXT PRIMARY KEY,
        deck_id TEXT NOT NULL,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        hint TEXT NOT NULL,
        scheduler_version TEXT NOT NULL DEFAULT 'fsrs_v6',
        study_state TEXT NOT NULL DEFAULT 'new',
        review_count INTEGER NOT NULL DEFAULT 0,
        lapse_count INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER NOT NULL DEFAULT 0,
        ease REAL NOT NULL DEFAULT 2.5,
        stability REAL NOT NULL DEFAULT 0.1,
        difficulty REAL NOT NULL DEFAULT 5.0,
        due_at TEXT,
        last_reviewed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_sessions (
        id TEXT PRIMARY KEY,
        subject_id TEXT,
        deck_id TEXT,
        session_type TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        reviewed_count INTEGER NOT NULL DEFAULT 0,
        completed_count INTEGER NOT NULL DEFAULT 0,
        again_count INTEGER NOT NULL DEFAULT 0,
        due_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL,
        FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE quizzes (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        tags_json TEXT,
        settings_json TEXT NOT NULL,
        questions_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        title TEXT NOT NULL,
        body_markdown TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE note_review_states (
        note_id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        review_count INTEGER NOT NULL DEFAULT 0,
        last_read_at TEXT,
        due_at TEXT,
        last_rating TEXT,
        pending_self_note TEXT,
        pending_self_note_created_at TEXT,
        archived_self_notes_json TEXT NOT NULL DEFAULT '[]',
        section_annotations_json TEXT NOT NULL DEFAULT '{}',
        updated_at TEXT NOT NULL,
        FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subject_units (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE qa_items (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        question TEXT NOT NULL,
        answer_markdown TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE qa_review_states (
        prompt_id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        review_count INTEGER NOT NULL DEFAULT 0,
        lapse_count INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER NOT NULL DEFAULT 0,
        study_state TEXT NOT NULL DEFAULT 'new',
        stability REAL NOT NULL DEFAULT 0.1,
        difficulty REAL NOT NULL DEFAULT 5.0,
        due_at TEXT,
        last_reviewed_at TEXT,
        last_rating TEXT,
        last_answer_snippet TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(prompt_id) REFERENCES qa_items(id) ON DELETE CASCADE,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_decks_subject_id ON decks(subject_id)');
    await db.execute('CREATE INDEX idx_decks_unit_id ON decks(unit_id)');
    await db.execute('CREATE INDEX idx_cards_deck_id ON cards(deck_id)');
    await db.execute('CREATE INDEX idx_cards_due_at ON cards(due_at)');
    await db.execute('CREATE INDEX idx_quizzes_subject_id ON quizzes(subject_id)');
    await db.execute('CREATE INDEX idx_quizzes_unit_id ON quizzes(unit_id)');
    await db.execute('CREATE INDEX idx_notes_subject_id ON notes(subject_id)');
    await db.execute('CREATE INDEX idx_notes_unit_id ON notes(unit_id)');
    await db.execute('CREATE INDEX idx_note_review_states_subject_id ON note_review_states(subject_id)');
    await db.execute('CREATE INDEX idx_note_review_states_due_at ON note_review_states(due_at)');
    await db.execute('CREATE INDEX idx_qa_items_subject_id ON qa_items(subject_id)');
    await db.execute('CREATE INDEX idx_qa_items_unit_id ON qa_items(unit_id)');
    await db.execute('CREATE INDEX idx_qa_review_states_subject_id ON qa_review_states(subject_id)');
    await db.execute('CREATE INDEX idx_qa_review_states_due_at ON qa_review_states(due_at)');
    await db.execute('CREATE INDEX idx_subject_units_subject_id ON subject_units(subject_id)');
    await db.execute(
      'CREATE INDEX idx_study_sessions_started_at ON study_sessions(started_at)',
    );
    await db.execute(
      'CREATE INDEX idx_study_sessions_subject_id ON study_sessions(subject_id)',
    );
    await db.execute('''
      CREATE TABLE quiz_attempt_sessions (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        quiz_name TEXT NOT NULL,
        quiz_description TEXT NOT NULL DEFAULT '',
        quiz_tags_json TEXT NOT NULL DEFAULT '[]',
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        mode TEXT NOT NULL DEFAULT 'practice',
        total_questions INTEGER NOT NULL,
        attempted_questions INTEGER NOT NULL,
        correct_count INTEGER NOT NULL,
        wrong_count INTEGER NOT NULL,
        skipped_count INTEGER NOT NULL,
        raw_score REAL NOT NULL,
        max_score REAL NOT NULL,
        score_percent REAL NOT NULL,
        passing_score_percent INTEGER,
        passed INTEGER,
        weak_tags_json TEXT NOT NULL DEFAULT '[]',
        strong_tags_json TEXT NOT NULL DEFAULT '[]',
        items_json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_quiz_attempt_sessions_quiz_id ON quiz_attempt_sessions(quiz_id)',
    );
    await db.execute(
      'CREATE INDEX idx_quiz_attempt_sessions_subject_id ON quiz_attempt_sessions(subject_id)',
    );
    await db.execute(
      'CREATE INDEX idx_quiz_attempt_sessions_started_at ON quiz_attempt_sessions(started_at)',
    );
  }

  Future<void> _upgradeToV2(Database db) async {
    await db.execute(
      "ALTER TABLE cards ADD COLUMN scheduler_version TEXT NOT NULL DEFAULT 'fsrs_v6'",
    );
    await db.execute(
      "ALTER TABLE cards ADD COLUMN study_state TEXT NOT NULL DEFAULT 'new'",
    );
    await db.execute(
      'ALTER TABLE cards ADD COLUMN review_count INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE cards ADD COLUMN lapse_count INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE cards ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE cards ADD COLUMN ease REAL NOT NULL DEFAULT 2.5',
    );
    await db.execute(
      'ALTER TABLE cards ADD COLUMN stability REAL NOT NULL DEFAULT 0.1',
    );
    await db.execute(
      'ALTER TABLE cards ADD COLUMN difficulty REAL NOT NULL DEFAULT 5.0',
    );
    await db.execute('ALTER TABLE cards ADD COLUMN due_at TEXT');
    await db.execute('ALTER TABLE cards ADD COLUMN last_reviewed_at TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cards_due_at ON cards(due_at)',
    );
  }

  Future<void> _upgradeToV3(Database db) async {
    await db.execute('''
      CREATE TABLE study_sessions (
        id TEXT PRIMARY KEY,
        subject_id TEXT,
        deck_id TEXT,
        session_type TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        reviewed_count INTEGER NOT NULL DEFAULT 0,
        completed_count INTEGER NOT NULL DEFAULT 0,
        again_count INTEGER NOT NULL DEFAULT 0,
        due_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL,
        FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_sessions_started_at ON study_sessions(started_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_sessions_subject_id ON study_sessions(subject_id)',
    );
  }

  Future<void> _upgradeToV4(Database db) async {
    await db.execute('''
      CREATE TABLE quizzes (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        tags_json TEXT,
        settings_json TEXT NOT NULL,
        questions_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quizzes_subject_id ON quizzes(subject_id)',
    );
  }

  Future<void> _upgradeToV5(Database db) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body_markdown TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_subject_id ON notes(subject_id)',
    );
  }

  Future<void> _upgradeToV6(Database db) async {
    await db.execute('''
      CREATE TABLE subject_units (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('ALTER TABLE decks ADD COLUMN unit_id TEXT');
    await db.execute(
      "ALTER TABLE decks ADD COLUMN tags_json TEXT NOT NULL DEFAULT '[]'",
    );
    await db.execute('ALTER TABLE quizzes ADD COLUMN unit_id TEXT');
    await db.execute('ALTER TABLE notes ADD COLUMN unit_id TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subject_units_subject_id ON subject_units(subject_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_decks_unit_id ON decks(unit_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quizzes_unit_id ON quizzes(unit_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_unit_id ON notes(unit_id)',
    );
  }

  Future<void> _upgradeToV7(Database db) async {
    await db.execute('''
      CREATE TABLE quiz_attempt_sessions (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        quiz_name TEXT NOT NULL,
        quiz_description TEXT NOT NULL DEFAULT '',
        quiz_tags_json TEXT NOT NULL DEFAULT '[]',
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        mode TEXT NOT NULL DEFAULT 'practice',
        total_questions INTEGER NOT NULL,
        attempted_questions INTEGER NOT NULL,
        correct_count INTEGER NOT NULL,
        wrong_count INTEGER NOT NULL,
        skipped_count INTEGER NOT NULL,
        raw_score REAL NOT NULL,
        max_score REAL NOT NULL,
        score_percent REAL NOT NULL,
        passing_score_percent INTEGER,
        passed INTEGER,
        weak_tags_json TEXT NOT NULL DEFAULT '[]',
        strong_tags_json TEXT NOT NULL DEFAULT '[]',
        items_json TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempt_sessions_quiz_id ON quiz_attempt_sessions(quiz_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempt_sessions_subject_id ON quiz_attempt_sessions(subject_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempt_sessions_started_at ON quiz_attempt_sessions(started_at)',
    );
  }

  Future<void> _upgradeToV8(Database db) async {
    await db.execute('''
      CREATE TABLE note_review_states (
        note_id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        review_count INTEGER NOT NULL DEFAULT 0,
        last_read_at TEXT,
        due_at TEXT,
        last_rating TEXT,
        pending_self_note TEXT,
        pending_self_note_created_at TEXT,
        archived_self_notes_json TEXT NOT NULL DEFAULT '[]',
        section_annotations_json TEXT NOT NULL DEFAULT '{}',
        updated_at TEXT NOT NULL,
        FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_note_review_states_subject_id ON note_review_states(subject_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_note_review_states_due_at ON note_review_states(due_at)',
    );
  }

  Future<void> _upgradeToV9(Database db) async {
    await db.execute('''
      CREATE TABLE qa_items (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        question TEXT NOT NULL,
        answer_markdown TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE qa_review_states (
        prompt_id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        review_count INTEGER NOT NULL DEFAULT 0,
        lapse_count INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER NOT NULL DEFAULT 0,
        study_state TEXT NOT NULL DEFAULT 'new',
        stability REAL NOT NULL DEFAULT 0.1,
        difficulty REAL NOT NULL DEFAULT 5.0,
        due_at TEXT,
        last_reviewed_at TEXT,
        last_rating TEXT,
        last_answer_snippet TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(prompt_id) REFERENCES qa_items(id) ON DELETE CASCADE,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(unit_id) REFERENCES subject_units(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_qa_items_subject_id ON qa_items(subject_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_qa_items_unit_id ON qa_items(unit_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_qa_review_states_subject_id ON qa_review_states(subject_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_qa_review_states_due_at ON qa_review_states(due_at)',
    );
  }

  Future<void> _upgradeToV10(Database db) async {
    await db.execute('ALTER TABLE quiz_attempt_sessions RENAME TO quiz_attempt_sessions_old');
    await db.execute('''
      CREATE TABLE quiz_attempt_sessions (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        unit_id TEXT,
        quiz_name TEXT NOT NULL,
        quiz_description TEXT NOT NULL DEFAULT '',
        quiz_tags_json TEXT NOT NULL DEFAULT '[]',
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        mode TEXT NOT NULL DEFAULT 'practice',
        total_questions INTEGER NOT NULL,
        attempted_questions INTEGER NOT NULL,
        correct_count INTEGER NOT NULL,
        wrong_count INTEGER NOT NULL,
        skipped_count INTEGER NOT NULL,
        raw_score REAL NOT NULL,
        max_score REAL NOT NULL,
        score_percent REAL NOT NULL,
        passing_score_percent INTEGER,
        passed INTEGER,
        weak_tags_json TEXT NOT NULL DEFAULT '[]',
        strong_tags_json TEXT NOT NULL DEFAULT '[]',
        items_json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO quiz_attempt_sessions (
        id,
        quiz_id,
        subject_id,
        unit_id,
        quiz_name,
        quiz_description,
        quiz_tags_json,
        started_at,
        ended_at,
        mode,
        total_questions,
        attempted_questions,
        correct_count,
        wrong_count,
        skipped_count,
        raw_score,
        max_score,
        score_percent,
        passing_score_percent,
        passed,
        weak_tags_json,
        strong_tags_json,
        items_json
      )
      SELECT
        id,
        quiz_id,
        subject_id,
        unit_id,
        quiz_name,
        quiz_description,
        quiz_tags_json,
        started_at,
        ended_at,
        mode,
        total_questions,
        attempted_questions,
        correct_count,
        wrong_count,
        skipped_count,
        raw_score,
        max_score,
        score_percent,
        passing_score_percent,
        passed,
        weak_tags_json,
        strong_tags_json,
        items_json
      FROM quiz_attempt_sessions_old
    ''');
    await db.execute('DROP TABLE quiz_attempt_sessions_old');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempt_sessions_quiz_id ON quiz_attempt_sessions(quiz_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempt_sessions_subject_id ON quiz_attempt_sessions(subject_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempt_sessions_started_at ON quiz_attempt_sessions(started_at)',
    );
  }

  Future<void> _migrateLegacySharedPreferences(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    final didMigrate = prefs.getBool(_migrationFlagKey) ?? false;
    final existingSubjects =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM subjects')) ??
            0;
    final existingDecks =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM decks')) ?? 0;
    final existingCards =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cards')) ?? 0;
    final existingQuizzes =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM quizzes')) ?? 0;
    final existingNotes =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM notes')) ?? 0;
    final existingQaItems =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM qa_items')) ?? 0;
    final existingUnits =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM subject_units')) ?? 0;
    final existingSessions =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM study_sessions')) ?? 0;
    final existingAttempts = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM quiz_attempt_sessions'),
        ) ??
        0;
    final databaseHasContent =
        existingSubjects > 0 ||
        existingDecks > 0 ||
        existingCards > 0 ||
        existingQuizzes > 0 ||
        existingNotes > 0 ||
        existingQaItems > 0 ||
        existingUnits > 0 ||
        existingSessions > 0 ||
        existingAttempts > 0;

    if (didMigrate || databaseHasContent) {
      return;
    }

    final rawSubjects = prefs.getStringList(_legacySubjectsStorageKey) ?? const [];
    final rawDecks = prefs.getStringList(_legacyDecksStorageKey) ?? const [];
    final rawCards = prefs.getStringList(_legacyCardsStorageKey) ?? const [];
    final rawQuizzes = prefs.getStringList(_legacyQuizzesStorageKey) ?? const [];
    final rawNotes = prefs.getStringList(_legacyNotesStorageKey) ?? const [];
    final rawQaItems = prefs.getStringList(_legacyQaItemsStorageKey) ?? const [];
    final rawQaReviewStates = prefs.getStringList(_legacyQaReviewStatesStorageKey) ?? const [];
    final rawUnits = prefs.getStringList(_legacySubjectUnitsStorageKey) ?? const [];
    final rawSessions = prefs.getStringList(_legacyStudySessionsStorageKey) ?? const [];
    final rawAttempts = prefs.getStringList(_legacyQuizAttemptsStorageKey) ?? const [];

    final subjects = rawSubjects.map(SubjectRecord.fromJson).toList();
    final decks = rawDecks.map(DeckRecord.fromJson).toList();
    final cards = rawCards.map(CardRecord.fromJson).toList();
    final quizzes = rawQuizzes.map(QuizRecord.fromJson).toList();
    final notes = rawNotes.map(NoteRecord.fromJson).toList();
    final qaItems = rawQaItems.map(QaItemRecord.fromJson).toList();
    final qaReviews = rawQaReviewStates.map(QaReviewRecord.fromJson).toList();
    final units = rawUnits.map(SubjectUnitRecord.fromJson).toList();
    final sessions = rawSessions.map(StudySessionRecord.fromJson).toList();
    final attempts = rawAttempts.map(QuizAttemptSessionRecord.fromJson).toList();

    await db.transaction((txn) async {
      for (final subject in subjects) {
        await txn.insert('subjects', {
          'id': subject.id,
          'name': subject.name,
          'emoji': subject.emoji,
          'color_value': subject.colorValue,
          'created_at': subject.createdAt.toIso8601String(),
          'updated_at': subject.updatedAt.toIso8601String(),
        });
      }

      for (final deck in decks) {
        await txn.insert('decks', {
          'id': deck.id,
          'subject_id': deck.subjectId,
          'unit_id': deck.unitId,
          'name': deck.name,
          'description': deck.description,
          'tags_json': jsonEncode(deck.tags),
          'created_at': deck.createdAt.toIso8601String(),
          'updated_at': deck.updatedAt.toIso8601String(),
        });
      }

      for (final card in cards) {
        await txn.insert('cards', {
          'id': card.id,
          'deck_id': card.deckId,
          'front': card.front,
          'back': card.back,
          'hint': card.hint,
          'scheduler_version': card.schedulerVersion,
          'study_state': card.state,
          'review_count': card.reviewCount,
          'lapse_count': card.lapseCount,
          'interval_days': card.intervalDays,
          'ease': card.ease,
          'stability': card.stability,
          'difficulty': card.difficulty,
          'due_at': card.dueAt?.toIso8601String(),
          'last_reviewed_at': card.lastReviewedAt?.toIso8601String(),
          'created_at': card.createdAt.toIso8601String(),
          'updated_at': card.updatedAt.toIso8601String(),
        });
      }

      for (final unit in units) {
        await txn.insert('subject_units', {
          'id': unit.id,
          'subject_id': unit.subjectId,
          'name': unit.name,
          'description': unit.description,
          'created_at': unit.createdAt.toIso8601String(),
          'updated_at': unit.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final note in notes) {
        await txn.insert('notes', {
          'id': note.id,
          'subject_id': note.subjectId,
          'unit_id': note.unitId,
          'title': note.title,
          'body_markdown': note.bodyMarkdown,
          'tags_json': jsonEncode(note.tags),
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': note.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final prompt in qaItems) {
        await txn.insert('qa_items', {
          'id': prompt.id,
          'subject_id': prompt.subjectId,
          'unit_id': prompt.unitId,
          'question': prompt.question,
          'answer_markdown': prompt.answerMarkdown,
          'tags_json': jsonEncode(prompt.tags),
          'created_at': prompt.createdAt.toIso8601String(),
          'updated_at': prompt.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final review in qaReviews) {
        await txn.insert('qa_review_states', {
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
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final quiz in quizzes) {
        await txn.insert('quizzes', {
          'id': quiz.id,
          'subject_id': quiz.subjectId,
          'unit_id': quiz.unitId,
          'name': quiz.name,
          'description': quiz.description,
          'tags_json': jsonEncode(quiz.tags),
          'settings_json': jsonEncode(quiz.settings.toMap()),
          'questions_json': jsonEncode(quiz.questions.map((item) => item.toMap()).toList()),
          'created_at': quiz.createdAt.toIso8601String(),
          'updated_at': quiz.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final session in sessions) {
        await txn.insert('study_sessions', {
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
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final attempt in attempts) {
        await txn.insert('quiz_attempt_sessions', {
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
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });

    await prefs.setBool(_migrationFlagKey, true);
  }
}

class DatabaseAuditReport {
  const DatabaseAuditReport({
    required this.quickCheckPassed,
    required this.foreignKeyViolations,
  });

  final bool quickCheckPassed;
  final int foreignKeyViolations;

  bool get isHealthy => quickCheckPassed && foreignKeyViolations == 0;
}
