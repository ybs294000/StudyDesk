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
import '../../features/subjects/domain/subject_record.dart';

const _legacySubjectsStorageKey = 'subjects_v1';
const _legacyDecksStorageKey = 'decks_v1';
const _legacyCardsStorageKey = 'cards_v1';
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

  Future<Database> _open() async {
    if (kIsWeb) {
      throw StateError(
        'AppDatabase should not open on web. StudyDesk uses SharedPreferences-backed repositories for the web target.',
      );
    }

    final factory = _createDatabaseFactory();
    final databasesPath = await _resolveDatabaseDirectory(factory);
    final path = p.join(databasesPath, 'studydesk.db');
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
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
        },
      ),
    );

    await _migrateLegacySharedPreferences(database);
    return database;
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
        scheduler_version TEXT NOT NULL DEFAULT 'adaptive_memory_v2',
        study_state TEXT NOT NULL DEFAULT 'new',
        review_count INTEGER NOT NULL DEFAULT 0,
        lapse_count INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER NOT NULL DEFAULT 0,
        ease REAL NOT NULL DEFAULT 2.5,
        stability REAL NOT NULL DEFAULT 0.2,
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

    await db.execute('CREATE INDEX idx_decks_subject_id ON decks(subject_id)');
    await db.execute('CREATE INDEX idx_decks_unit_id ON decks(unit_id)');
    await db.execute('CREATE INDEX idx_cards_deck_id ON cards(deck_id)');
    await db.execute('CREATE INDEX idx_cards_due_at ON cards(due_at)');
    await db.execute('CREATE INDEX idx_quizzes_subject_id ON quizzes(subject_id)');
    await db.execute('CREATE INDEX idx_quizzes_unit_id ON quizzes(unit_id)');
    await db.execute('CREATE INDEX idx_notes_subject_id ON notes(subject_id)');
    await db.execute('CREATE INDEX idx_notes_unit_id ON notes(unit_id)');
    await db.execute('CREATE INDEX idx_subject_units_subject_id ON subject_units(subject_id)');
    await db.execute(
      'CREATE INDEX idx_study_sessions_started_at ON study_sessions(started_at)',
    );
    await db.execute(
      'CREATE INDEX idx_study_sessions_subject_id ON study_sessions(subject_id)',
    );
  }

  Future<void> _upgradeToV2(Database db) async {
    await db.execute(
      "ALTER TABLE cards ADD COLUMN scheduler_version TEXT NOT NULL DEFAULT 'adaptive_memory_v2'",
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
      'ALTER TABLE cards ADD COLUMN stability REAL NOT NULL DEFAULT 0.2',
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
    final databaseHasContent =
        existingSubjects > 0 || existingDecks > 0 || existingCards > 0;

    if (didMigrate || databaseHasContent) {
      return;
    }

    final rawSubjects = prefs.getStringList(_legacySubjectsStorageKey) ?? const [];
    final rawDecks = prefs.getStringList(_legacyDecksStorageKey) ?? const [];
    final rawCards = prefs.getStringList(_legacyCardsStorageKey) ?? const [];

    final subjects = rawSubjects.map(SubjectRecord.fromJson).toList();
    final decks = rawDecks.map(DeckRecord.fromJson).toList();
    final cards = rawCards.map(CardRecord.fromJson).toList();

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
          'name': deck.name,
          'description': deck.description,
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
    });

    await prefs.setBool(_migrationFlagKey, true);
  }
}
