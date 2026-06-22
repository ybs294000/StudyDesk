# Features

Last updated: 2026-06-21

This document tracks the StudyDesk product surface and marks which features are implemented, partial, or planned.

Legend:

- `Implemented`
- `Partial`
- `Planned`

## 1. Subjects and Organization

### Subjects

Status: `Implemented`

- Create, edit, and delete subjects
- Subjects carry name, emoji, color, and timestamps
- Subject cards expose study-related summary signals

### Subject Workspaces

Status: `Implemented`

- Subject detail screens list decks and quizzes
- Subject-level sample import is available
- Subject-level JSON import is available
- Web drag-and-drop JSON import is available

## 2. Decks and Flashcards

### Deck Management

Status: `Implemented`

- Create, edit, and delete decks within a subject
- Import bundled sample decks
- Export decks as JSON

### Flashcard Authoring

Status: `Implemented`

- Create, edit, and delete flashcards
- Cards support `front`, `back`, and `hint`
- Markdown content is supported in study views

### Flashcard Study Sessions

Status: `Implemented`

- Due-first queueing
- Again / Hard / Good / Easy rating flow
- Session completion summary
- Session logging for dashboard metrics

### Rich Card Content

Status: `Partial`

- Markdown rendering is implemented
- Additional attachments and richer media handling are not yet implemented

## 3. Quiz Engine

### Quiz Management

Status: `Implemented`

- Create quizzes from within the app
- Edit quiz metadata
- Persist quiz settings and question lists

### Question Authoring

Status: `Implemented`

- MCQ
- True / False
- Fill in the Blank
- Question & Answer

### Quiz Sessions

Status: `Implemented`

- Timed quiz flow
- Optional negative marking
- Result review and explanations
- Score calculation and pass/fail threshold support

### Q&A Grading

Status: `Implemented`

- Model answers
- Required keywords
- Supporting keywords
- Keyword thresholds
- Word targets
- Optional partial credit

## 4. Sheets and Rehearsal Mode

Status: `Planned`

Target scope:

- Markdown-based sheets
- Toggle/reveal rehearsal blocks
- Reading-focused study surfaces

## 5. Dashboard and Analytics

### Home Dashboard

Status: `Implemented`

- Due count
- Reviewed today
- Streak
- Recent sessions
- Subject-level rollups

### Dedicated Analytics Screens

Status: `Partial`

- Analytics views are implemented
- Deeper historical and comparative analysis can still expand further

## 6. Import / Export

### Deck Import / Export

Status: `Implemented`

- Deck import
- Deck export

### Quiz Import

Status: `Implemented`

- Quiz JSON import
- Validation for implemented question types
- Validation for keyword-graded Q&A configuration

### Broader Portability

Status: `Partial`

- File-picker import is implemented
- Web drag-and-drop import is implemented
- Subject backup/export and full app backup are not yet implemented

## 7. Settings and Profile

Status: `Partial`

Implemented:

- Display name
- Daily study goal
- Theme mode
- Shell layout preferences
- Schema-related preference controls

Planned:

- Data management controls
- Broader validation tooling
- Expanded operational settings

## 8. Reminders

Status: `Planned`

- Exam dates
- Study reminders
- Subject-linked events

## 9. Resource Link Box

Status: `Planned`

- Resource links
- Subject association
- Lightweight bookmark management
