# Changelog

All notable changes to this project will be documented in this file.

This changelog follows the spirit of Keep a Changelog and uses semantic-style release sections where practical. Early entries in this repository are partly reconstructed from the current workspace state, so they should be treated as a best-effort project history rather than a strict release ledger.

## [Unreleased]

### Changed

- Documentation refreshed to stay aligned with the current 1.0.0 local-first application state
- Theme catalog expanded with a monochrome workspace preset inspired by popular black-and-white knowledge-work interfaces

## [1.0.0] - 2026-06-25

### Added

- Subject-level notes workspace with Markdown, LaTeX, linking, search, reading mode, and section recall
- Subject-level Q&A bank with generation from note headings, recall sessions, and scheduled review
- Flashcard CSV import alongside JSON deck import and export
- Quiz practice mode and exam mode selection
- Per-question quiz timer support and richer local quiz attempt exports
- Local analytics dashboards with due forecasts, streaks, session summaries, mastery indicators, and weekly progress
- Gamification summaries including XP, milestones, and daily goal tracking
- Persistent Pomodoro timer integrated with session logging and analytics
- User-configurable spaced-repetition toggles for flashcards, notes, Q&A, and quiz practice
- Native backup-folder safety snapshots and expanded local export flows
- Linux desktop target scaffolding and packaging scripts
- Android, Windows, and Linux artifact packaging scripts for repeatable local testing
- Additional built-in sample content for decks, quizzes, notes, and structured recall flows
- Keyword-graded Q&A support for quiz short-answer questions
- Dedicated quiz grading service for reusable scoring logic
- Subject-level JSON import through file picker and web drag-and-drop
- Science Q&A sample quiz for testing short-answer grading flows

### Changed

- Root README expanded to reflect the shipped repository state and current platform workflows
- Core engineering docs rewritten in a repository-facing tone and aligned with the implemented app structure
- Public docs now avoid internal workflow language and stale product-positioning notes
- Theme system refined with calmer defaults and a new monochrome workspace preset
- Windows packaging scripts hardened against stale plugin-symlink build failures
- Repository packaging helpers now stage build artifacts into predictable `artifacts/` folders

## [0.1.0-alpha] - 2026-06-20

### Added

- Feature-first Flutter app structure under `flutter_app/lib`
- App shell with navigation for Home, Library, Study, Analytics, and Settings
- Subject CRUD flow with local persistence
- Deck CRUD flow with local persistence
- Flashcard CRUD flow with local persistence
- Study session screen with review ratings and queue progression
- Session history logging and dashboard summary aggregation
- Sample JSON assets for manual testing
- Settings screen with display name, daily goal, theme mode, and schema template persistence
- Native SQLite persistence path and migration scaffolding
- Web-safe repository fallback using `SharedPreferences`
- Initial documentation set for architecture, features, JSON format, and roadmap

### Changed

- Project naming aligned to `StudyDesk`
- Repo documentation rewritten to reflect current implementation status instead of generic Flutter scaffolding
- Import/export service renamed and narrowed around current deck portability support

### Fixed

- Web runtime path no longer depends on native SQLite-only repositories
- Study data repositories now choose storage implementation per platform

### Known Gaps

- Several top-level tabs still need real feature implementations
- Test coverage is still minimal
- Some roadmap targets remain architectural intent rather than shipped functionality
