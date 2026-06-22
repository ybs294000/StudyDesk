# Database Schema

Last updated: 2026-06-20

This document describes the database schema that currently exists in the app and the most likely expansion direction.

## Current Reality

StudyDesk currently persists four main entities in SQLite on native platforms:

- `subjects`
- `decks`
- `cards`
- `study_sessions`

Web does not use this SQLite schema yet. It uses repository fallbacks backed by `SharedPreferences`.

## Current Native Tables

### subjects

```sql
CREATE TABLE subjects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  color_value INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

### decks

```sql
CREATE TABLE decks (
  id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
);
```

### cards

```sql
CREATE TABLE cards (
  id TEXT PRIMARY KEY,
  deck_id TEXT NOT NULL,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  hint TEXT NOT NULL,
  scheduler_version TEXT NOT NULL DEFAULT 'baseline_v1',
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
);
```

### study_sessions

```sql
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
);
```

## Current Indexes

- `idx_decks_subject_id`
- `idx_cards_deck_id`
- `idx_cards_due_at`
- `idx_study_sessions_started_at`
- `idx_study_sessions_subject_id`

## Current Migration Level

The current database version in code is `3`.

Notable migration history:

- V2 introduced richer scheduling fields to cards
- V3 introduced `study_sessions`

## Planned Expansion

Future schema growth is expected to add first-class tables for:

- quizzes
- quiz questions
- sheets
- Q&A sets
- reminders
- links

Those tables are not implemented yet and should not be described as live storage until the app ships them.
