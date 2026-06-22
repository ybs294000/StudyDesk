# Project Status

Last updated: 2026-06-21

This document describes the current implementation state of StudyDesk in the repository.

## Snapshot

StudyDesk is in active alpha development, but the repository already contains a real local study workflow across subjects, flashcards, quizzes, Q&A grading, analytics, and content portability.

The app is no longer limited to flashcard-only foundations. Quiz authoring, quiz sessions, and keyword-graded short-answer practice are implemented in the Flutter application.

## Implemented

### App Foundation

- Flutter app shell with persistent navigation
- Riverpod-based state management
- Theme mode persistence
- Profile and display preference persistence
- Feature-first folder structure

### Subjects and Library

- Subject CRUD
- Subject detail workspaces
- Deck and quiz grouping under a subject
- Sample import into a selected subject
- JSON import into a selected subject
- Web drag-and-drop JSON import

### Flashcards

- Deck CRUD
- Card CRUD
- Flashcard study sessions
- Again / Hard / Good / Easy rating flow
- Local scheduling metadata persistence
- Study-session logging
- Deck export to JSON

### Quizzes and Q&A

- Quiz CRUD
- Quiz metadata editing
- Question authoring for MCQ, true/false, fill-in-the-blank, and Q&A
- Timed quiz sessions
- Negative-marking support
- Post-attempt review
- Keyword-based grading for short-answer questions
- Model answers, keyword thresholds, and partial-credit support

### Analytics

- Due counts
- Reviewed-today summary
- Streak tracking
- Recent activity
- Subject-level study summaries
- Session distribution views

### Persistence

- Native SQLite-backed persistence path
- SharedPreferences-backed web fallback repositories
- Starter-content bootstrap on clean local installs

## Partially Implemented

### Scheduling

- Card models already carry scheduling fields designed for more advanced evolution
- The current review engine is usable, but it is still a baseline local scheduler rather than a finalized long-term algorithm implementation

### Web Persistence

- Web persistence is implemented and usable
- The long-term production storage path for web remains simpler than the native path and may evolve further

### Settings and Data Controls

- Profile, layout, theme, and schema-related preferences are present
- Broader validation, backup/export management, and future AI-related controls remain incomplete

## Not Yet Implemented

- Sheets and rehearsal mode
- Reminder and event features
- Resource link box
- Cross-device sync
- Full backup/export flows across the entire app
- Quiz export

## Known Gaps

- Automated test coverage is still limited relative to the feature surface
- Some docs still describe future-facing architecture extensions that are not yet implemented
- Native and web persistence share the same product behavior but not the same storage implementation

## Recommended Next Priorities

1. Expand automated test coverage for study and quiz flows
2. Add quiz export and broader backup/export support
3. Implement sheets and rehearsal mode
4. Expand analytics depth and history views
5. Harden persistence and portability workflows across platforms
