# Database Schema

Last updated: 2026-06-26

This document describes the persistence model currently implemented in StudyDesk.

## Persistence Model

### Native platforms

Windows, Android, Linux, and other native targets use SQLite-backed repositories for structured study data.

### Web

The web target uses a local SharedPreferences-backed repository path. It mirrors the product behavior of the native app, but it does not currently use the same SQLite storage backend.

## Current Database Version

The current native database version in code is `10`.

## Startup Integrity Checks

On native platforms, database startup currently performs:

- `PRAGMA foreign_keys = ON`
- `PRAGMA journal_mode = WAL`
- `PRAGMA busy_timeout = 5000`
- `PRAGMA secure_delete = ON`
- `PRAGMA quick_check`
- `PRAGMA foreign_key_check`

If startup integrity checks fail, the database is treated as unhealthy and normal startup is stopped rather than continuing silently with corrupted state.

## Main Tables

StudyDesk currently persists the following main entities on native targets:

- `subjects`
- `subject_units`
- `decks`
- `cards`
- `quizzes`
- `study_sessions`
- `notes`
- `note_review_states`
- `qa_items`
- `qa_review_states`
- `quiz_attempt_sessions`

## Relationship Model

- a subject owns many decks, quizzes, notes, Q&A items, units, and study sessions
- a deck owns many cards
- note review state is keyed by note id
- Q&A review state is keyed by Q&A item id

Most core content relationships use foreign keys with cascade or set-null behavior.

`quiz_attempt_sessions` intentionally stores historical attempt data without strict live foreign-key enforcement to preserve exports and history even if a related quiz, subject, or unit is later removed.

## Index Coverage

The schema currently includes indexes for:

- subject ownership lookups
- unit ownership lookups
- due-date lookups for cards, notes, and Q&A
- study-session timeline queries
- quiz-attempt timeline and subject lookups

This keeps the common dashboards, due queues, and history views fast on local devices.

## Legacy Migration Support

The repository still contains a migration path from earlier SharedPreferences-backed data stores into SQLite on native platforms.

That migration runs only when:

- the SQLite database is empty
- the legacy storage keys still contain data
- the migration flag has not already been written

## Backup and Recovery

Before native database open, StudyDesk creates a pre-open copy of the current database file if one exists and a backup for the current timestamp has not already been created.

Separately, the app can also create export-based safety snapshots before imports when that option is enabled in settings.
