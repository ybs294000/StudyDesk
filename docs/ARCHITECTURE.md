# Architecture

Last updated: 2026-06-26

This document describes the current application architecture used in StudyDesk.

## Overview

StudyDesk uses a feature-first Flutter structure with Riverpod for state management, GoRouter for navigation, and repository-backed local persistence.

The architecture is intentionally local-first:

- study workflows do not require sign-in
- persistence is device-local by default
- import and export flows are explicit product features rather than hidden implementation details

## Core Stack

- Flutter for the application framework
- Riverpod for providers, controllers, and app services
- GoRouter for navigation
- SQLite on native targets
- SharedPreferences-backed persistence on web

## Directory Layout

```text
flutter_app/lib/
├── app/
│   └── router/
├── core/
│   ├── database/
│   ├── navigation/
│   ├── security/
│   ├── settings/
│   └── widgets/
├── features/
│   ├── analytics/
│   ├── cards/
│   ├── dashboard/
│   ├── decks/
│   ├── gamification/
│   ├── library/
│   ├── notes/
│   ├── pomodoro/
│   ├── qa/
│   ├── quizzes/
│   ├── settings/
│   ├── study/
│   ├── subjects/
│   └── units/
├── services/
└── theme/
```

## Layering Pattern

Most feature areas follow a lightweight internal split:

- `domain/` for app-facing records and value types
- `data/` for persistence repositories
- `application/` for controllers and feature services
- `presentation/` for screens and widgets

This keeps storage, business rules, and UI composition separate without forcing excessive ceremony into a single-app repository.

## Navigation

Top-level app navigation is routed through a shared shell.

Primary destinations:

- home
- library
- study
- analytics
- settings

Nested routes are used for subject workspaces, note editing, deck detail, flashcard study, quiz detail, quiz sessions, and Q&A sessions.

## Persistence Design

### Native targets

Native targets use SQLite-backed repositories. The database layer is responsible for:

- schema creation and migration
- startup integrity checks
- legacy data migration
- stable local persistence for study content and progress

### Web

The web target uses a SharedPreferences-backed local path. This keeps browser testing functional without assuming native SQLite support.

## Content Portability

Import and export logic is centralized under `services/`.

Current responsibilities include:

- deck import and export
- quiz import and export
- subject bundle export
- analytics and session export
- safety snapshot generation
- validation and sanitization of imported file content before persistence

## Security-Oriented Architecture Notes

Security-sensitive concerns are handled close to the boundaries where they matter:

- file ingress is validated before parsing
- imported text is sanitized before persistence
- export filenames are normalized before file-save operations
- database startup performs integrity checks before ordinary repository use

This keeps the application ready for a future bring-your-own-key AI layer without assuming that local-only study data can be treated casually.
