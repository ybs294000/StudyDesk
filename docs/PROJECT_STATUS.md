# Project Status

Last updated: 2026-06-26

This document summarizes the current implementation state of StudyDesk in the repository.

## Summary

StudyDesk is a local-first study workspace built with Flutter for web, Windows, Android, and Linux. The current codebase supports notes, flashcards, quizzes, Q&A recall practice, analytics, exports, and platform-aware persistence.

The repository is beyond the initial prototype stage. Core study workflows are implemented and testable, but the project is still evolving toward a more production-ready 1.x baseline.

## Implemented

### Core App Foundation

- Flutter application shell with top-level navigation
- Riverpod-based state management
- theme and profile preference persistence
- platform-aware layout for mobile and desktop-class targets

### Subjects and Units

- subject CRUD
- optional unit or chapter grouping inside subjects
- uncategorized content support inside a subject

### Notes

- Markdown note editing
- LaTeX rendering in note content
- note import from Markdown files
- note export as Markdown
- wiki-link style note references and backlink discovery
- reading mode and section recall mode
- note review scheduling and note-review persistence

### Flashcards

- deck CRUD
- card CRUD
- FSRS-based review metadata on cards
- flashcard study sessions with review logging
- deck JSON export
- CSV and JSON deck import

### Quizzes and Q&A

- quiz CRUD
- multiple quiz question types: MCQ, true/false, fill-in-the-blank, short answer
- practice mode and exam mode
- timer support
- negative marking and section-based quiz rules
- latest-attempt export and retry-from-wrong-answers flow
- subject-level Q&A bank with review scheduling

### Analytics and Progress

- due-now summaries across cards, notes, Q&A, and quizzes
- streaks and recent activity
- seven-day review and accuracy summaries
- subject-level progress views
- gamification metrics such as XP, milestones, and goal tracking
- Pomodoro-linked progress tracking

### Portability and Safety

- subject bundle export
- entire-library export
- analytics and session export
- wrong-question and weak-topic export flows
- user-selected backup directory support on native platforms
- automatic safety snapshots before imports when enabled

## Current Technical Baseline

- native persistence uses SQLite
- web persistence uses a local SharedPreferences-backed path
- JSON, CSV, and Markdown imports are validated before persistence
- native database startup runs integrity and foreign-key checks
- export filenames are sanitized before save operations

## Known Gaps

- secure storage for future AI provider credentials is not implemented yet
- automated test coverage is smaller than the feature surface area
- web persistence remains intentionally simpler than the native persistence path
- image-based study content and Anki import are not implemented

## Next Major Focus

The next security-sensitive milestone is bring-your-own-key AI integration. Before that work begins, the repository should continue tightening:

1. secure secret storage strategy by platform
2. malformed-import regression tests
3. release-oriented Android and desktop hardening
4. documented privacy boundaries for off-device AI requests
