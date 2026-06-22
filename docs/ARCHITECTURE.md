# Architecture

Last updated: 2026-06-21

This document describes the architecture currently present in the StudyDesk repository and the implementation direction the project follows.

## Overview

StudyDesk uses a feature-first Flutter structure with Riverpod for state management, GoRouter for navigation, and repository-backed local persistence.

The current product focus is:

- local-first study workflows
- platform-aware persistence
- explicit content portability
- concrete feature modules instead of generic placeholder shells

## Core Stack

- Flutter for the application framework
- Riverpod for application state and feature controllers
- GoRouter for navigation
- SQLite-backed persistence on native platforms
- SharedPreferences-backed repository fallback on web

## Current Folder Structure

```text
flutter_app/lib/
├── app/
│   ├── router/
│   └── studydesk_app.dart
├── core/
│   ├── bootstrap/
│   ├── database/
│   ├── settings/
│   └── widgets/
├── features/
│   ├── analytics/
│   ├── cards/
│   ├── dashboard/
│   ├── decks/
│   ├── library/
│   ├── quizzes/
│   ├── settings/
│   ├── study/
│   └── subjects/
├── services/
└── theme/
```

## Layering Model

Each feature generally follows this structure:

- `domain/` for app-facing models and records
- `data/` for storage repositories
- `application/` for Riverpod controllers and feature services
- `presentation/` for screens and widgets

This keeps persistence concerns, feature rules, and UI composition separated while still remaining lightweight enough for a single-app repository.

## Navigation

Navigation is defined in `flutter_app/lib/app/router/app_router.dart` and rendered inside a shared app shell.

Current top-level routes:

- `/` Home
- `/library`
- `/study`
- `/analytics`
- `/settings`

Current nested content routes:

- `/subjects/:subjectId`
- `/subjects/:subjectId/decks/:deckId`
- `/subjects/:subjectId/decks/:deckId/study`
- `/subjects/:subjectId/quizzes/:quizId`
- `/subjects/:subjectId/quizzes/:quizId/session`

## State Management

StudyDesk uses Riverpod providers with a clear split between mutation, read models, and shared services.

Common patterns in the current codebase:

- `AsyncNotifier` and family notifiers for repository-backed CRUD features
- `Provider` for repositories and shared services
- `FutureProvider` for aggregated dashboard and bootstrap flows

This keeps write paths explicit and allows screens to remain thin.

## Persistence Design

### Native Platforms

Native persistence uses SQLite-backed repositories for structured study data such as:

- subjects
- decks
- cards
- quizzes
- study sessions

### Web

Web currently uses repository fallback implementations backed by `SharedPreferences`.

This exists to support browser-based testing without relying on native SQLite assumptions. The web persistence layer is real, but it is intentionally simpler than the native path and remains local to the browser profile and origin.

## Bootstrap and Starter Content

On a clean first run, the app uses `core/bootstrap/app_bootstrap_service.dart` to seed starter content.

Bootstrap responsibilities:

- detect whether the app already contains local content
- create a starter subject when appropriate
- import bundled sample decks and quizzes
- avoid reseeding after local content is already present

This makes the repository immediately testable without requiring manual content entry.

## Content Portability

StudyDesk currently supports structured JSON import for:

- decks
- quizzes

Deck export is also implemented.

Import responsibilities are centralized in `services/content_portability_service.dart`, which:

- validates wrapper structure and implemented content types
- routes imports to the correct domain path
- enforces short-answer grading requirements for quiz imports

## Quiz and Q&A Architecture

The quiz module is implemented as a first-class feature area rather than a thin extension of flashcards.

Current responsibilities include:

- quiz metadata and question persistence
- question authoring UI
- timed quiz sessions
- question-type-specific input rendering
- scoring and result review
- keyword-based grading for Q&A-style short answers

Keyword grading is separated into `features/quizzes/application/quiz_grading_service.dart` so the grading logic is reusable, testable, and not embedded directly into screen code.

## Theming and Shared UI

Shared visual primitives live under `theme/` and `core/widgets/`.

Current shared UI responsibilities include:

- app shell and navigation frame
- markdown rendering
- web drag-and-drop JSON import surface
- common spacing and color definitions

## Architectural Constraints

The repository currently follows a few practical constraints:

- core study flows must remain usable without sign-in
- local storage remains the default source of truth
- public documentation should reflect implemented behavior accurately
- future expansion points may exist in the structure, but they should not be documented as shipped features unless they are actually usable
