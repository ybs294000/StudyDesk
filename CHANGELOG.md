# Changelog

All notable changes to this project will be documented in this file.

This changelog follows the spirit of Keep a Changelog and uses semantic-style release sections where practical. Early entries in this repository are partly reconstructed from the current workspace state, so they should be treated as a best-effort project history rather than a strict release ledger.

## [Unreleased]

### Added

- Keyword-graded Q&A support for quiz short-answer questions
- Dedicated quiz grading service for reusable scoring logic
- Subject-level JSON import through file picker and web drag-and-drop
- Science Q&A sample quiz for testing short-answer grading flows

### Changed

- Root README expanded to reflect the current shipped repository state
- Core engineering docs rewritten in a repository-facing tone and aligned with current implementation
- Public docs now avoid internal workflow language and stale product-positioning notes
- Internal reference material and local-only helper files removed from version control

### Planned

- Sheets and rehearsal mode
- Reminder and link-management modules
- Broader automated test coverage

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
