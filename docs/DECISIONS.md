# Decisions

Last updated: 2026-06-20

This log captures the product and engineering decisions that currently define StudyDesk.

## Core Product Decisions

### Local-first is non-negotiable

Decision: `Accepted`

- Core studying must work without an internet connection
- User study data should remain on-device by default
- Cloud accounts are not part of the current product scope

### StudyDesk is a structured study tool, not a generic notes app

Decision: `Accepted`

- The product is centered on study content and review workflows
- Notes-style richness is useful only where it supports concrete study actions

### No fake completion

Decision: `Accepted`

- Placeholder screens may exist temporarily during development
- Features should not be presented as shipped unless the workflow is truly usable

## Architecture Decisions

### Flutter remains the app framework

Decision: `Accepted`

Reason:

- Shared codebase across Android, desktop, and web testing
- Good fit for offline UI and product iteration

### Riverpod is the primary state-management layer

Decision: `Accepted`

Reason:

- Clear mutation flows
- Good separation between UI, application logic, and repositories

### SQLite is the native persistence direction

Decision: `Accepted`

Reason:

- The data is relational
- It supports future analytics and migrations cleanly

Current note:

- The repository currently uses direct SQLite access on native rather than Drift
- Drift remains a possible future refinement, but it is not the current implementation

### Web persistence uses a fallback path for now

Decision: `Accepted as transitional`

Reason:

- The app needed a browser-safe path during active development
- Native SQLite-only assumptions were breaking web testing

Follow-up:

- Revisit long-term storage abstraction once more modules are implemented

## Study Engine Decisions

### Scheduling fields should support future algorithm evolution

Decision: `Accepted`

Reason:

- Even before a full FSRS implementation, the data model should not be boxed into a simplistic shape

### Current scheduler is a baseline, not the final algorithm

Decision: `Accepted`

Reason:

- A concrete working review loop is more valuable than waiting for a perfect final scheduler
- The current app already stores the fields needed for later improvement

## Scope Decisions

### Include in core roadmap

Decision: `Accepted`

- Flashcards
- Quizzes
- Sheets and rehearsal mode
- Q&A practice
- Analytics
- Import/export
- Settings/profile
- Reminders
- Link box

### Explicitly out of current scope

Decision: `Rejected for now`

- User accounts
- Cloud sync
- Shared deck marketplace
- Real-time collaboration
- In-app AI chatbot
- Built-in TTS
- Backend-owned AI proxy

## AI Decisions

### AI is optional

Decision: `Accepted`

- The app must remain useful without AI
- AI should be opt-in and user-initiated

### BYOK is the intended direction

Decision: `Accepted`

- If AI is added, user-provided credentials are the safe early product path
- App-owned secrets should not be embedded in the client

## Documentation Decisions

### Docs must reflect the actual repo, not only the target vision

Decision: `Accepted`

- High-level roadmap docs are useful
- Public repo docs must also reflect what is already implemented and what is not
