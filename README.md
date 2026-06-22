# StudyDesk

<p align="center">
  <a>
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white&labelColor=2D3748" alt="Flutter 3.x" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/State-Riverpod-40C4FF?style=for-the-badge&logo=flutter&logoColor=white&labelColor=2D3748" alt="State: Riverpod" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/Routing-GoRouter-0F766E?style=for-the-badge&logo=flutter&logoColor=white&labelColor=2D3748" alt="Routing: GoRouter" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/Storage-SQLite%20%7C%20SharedPreferences-003B57?style=for-the-badge&logo=sqlite&logoColor=white&labelColor=2D3748" alt="Storage: SQLite and SharedPreferences" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/Content-Markdown%20%7C%20LaTeX-1F2937?style=for-the-badge&labelColor=2D3748" alt="Content: Markdown and LaTeX" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/Platform-Web%20%7C%20Windows%20%7C%20Android-1F2937?style=for-the-badge&labelColor=2D3748" alt="Platform: Web, Windows, and Android" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/version-0.5.0-blue?style=for-the-badge&labelColor=2D3748" alt="Version: 0.5.0" />
  </a>
</p>

<p align="center">
  <a>
    <img src="https://img.shields.io/badge/Status-Active%20Alpha-F59E0B?style=flat-square&labelColor=2D3748" alt="Status: Active Alpha" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/License-MIT-6C5CE7?style=flat-square&labelColor=2D3748" alt="License: MIT" />
  </a>
  <a>
    <img src="https://img.shields.io/badge/Docs-Repo%20Maintained-0F766E?style=flat-square&labelColor=2D3748" alt="Docs: Repo Maintained" />
  </a>
</p>

> Offline-first Flutter study workspace for notes, flashcards, quizzes, keyword-graded Q&A practice, and local analytics across web, Windows, and Android.

StudyDesk is a local-first study application built for structured learning workflows. Subjects can hold notes, flashcard decks, quizzes, and optional units such as chapters or modules. Content and progress remain on the device by default, with Markdown and LaTeX support for authored material and JSON-based import flows for study packs.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Question Types and Grading](#question-types-and-grading)
- [Import and Portability](#import-and-portability)
- [Starter Content](#starter-content)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Platform Compatibility](#platform-compatibility)
- [Usage](#usage)
- [Technologies Used](#technologies-used)
- [Security and Data Handling](#security-and-data-handling)
- [Current Limitations](#current-limitations)
- [Documentation](#documentation)
- [License](#license)

---

## Overview

StudyDesk currently supports a complete local study workflow with the following capabilities:

- Subject-based organization for notes, decks, and quizzes
- Optional unit grouping inside a subject for chapters, modules, or topics
- Tag-based organization for decks, quizzes, and notes
- Flashcard study with adaptive spaced repetition and review logging
- Quiz authoring with timed sessions, negative marking, and multiple question types
- Keyword-graded Q&A practice with model answers and threshold-based scoring
- Markdown and LaTeX rendering in notes, flashcards, and quiz content
- Local analytics covering activity, streaks, due load, and subject-level progress
- Local-only persistence across web, Windows, and Android

Persistence is platform-specific but remains local-first:

- Web uses browser-local persistence
- Windows uses local SQLite-backed persistence
- Android uses local SQLite-backed persistence

---

## Features

### Subjects and Library

- Create, edit, and delete subjects
- Keep multiple notes, decks, and quizzes inside a single subject
- Create optional units to group content by chapter or module
- Leave content uncategorized when unit grouping is unnecessary
- Apply tags to notes, decks, and quizzes for lightweight organization
- Import bundled sample content into a selected subject
- Import custom JSON files into a selected subject
- Use drag-and-drop JSON import on the web target

### Notes

- Create, edit, and delete Markdown notes inside a subject
- Live Markdown preview with LaTeX rendering
- Wiki links between notes and backlink discovery
- Outline extraction from headings
- Search notes by title, content, and tags
- Import Markdown files into a subject
- Export notes as Markdown files
- Create flashcard drafts from selected note content

### Flashcards

- Create, edit, and delete decks
- Assign decks to optional units
- Add tags to decks
- Create, edit, and delete cards inside decks
- Use front, back, and hint fields per card
- Render Markdown in card content
- Review cards with adaptive scheduling based on stability and difficulty
- Log review sessions for analytics
- Export decks as JSON

### Quizzes

- Create quizzes from scratch inside the app
- Assign quizzes to optional units
- Add tags to quizzes
- Configure timer mode, shuffle behavior, passing score, and marking rules
- Add, edit, and delete questions inside each quiz
- Run timed quiz sessions with local scoring and review output
- Use negative marking and skipped-answer handling when needed
- Support structured Q&A practice alongside objective questions

### Analytics

- Due-now and reviewed-today summaries
- Recent activity timeline
- Session type breakdown
- Subject-level study metrics
- Due forecast buckets
- Seven-day activity visualization
- Streak tracking

### Settings and App Controls

- Theme selection
- Profile and display preferences
- Shell layout controls including left-pane behavior
- About information inside the app

---

## Question Types and Grading

StudyDesk currently supports these quiz question types:

- MCQ
- True / False
- Fill in the Blank
- Question & Answer

The Q&A flow is implemented as a structured grading mode. Current support includes:

- Required keywords
- Supporting keywords
- Configurable minimum keyword matches
- Configurable keyword-score thresholds
- Minimum and maximum word targets
- Optional partial credit from keyword coverage
- Model answer display in review mode
- Result feedback showing matched keywords, missing keywords, keyword match percentage, and word-count status

This makes short-answer practice auditable and reviewable rather than a plain free-response field.

---

## Import and Portability

StudyDesk currently supports:

- Deck JSON import
- Deck JSON export
- Quiz JSON import
- Subject-level sample import from bundled assets
- Browser file-picker import
- Web drag-and-drop JSON import
- Markdown note import
- Markdown note export

Implemented content portability is documented in [docs/JSON_FORMAT_SPEC.md](./docs/JSON_FORMAT_SPEC.md).

Current import behavior:

- Deck JSON files create a new deck inside the selected subject
- Quiz JSON files create a new quiz inside the selected subject
- Markdown files create notes inside the selected subject
- Import validation rejects malformed deck or quiz structures before persistence
- Short-answer quiz imports validate keyword-grading requirements before save

Sample study assets are stored in:

```text
flutter_app/assets/sample_data/
```

---

## Starter Content

On a clean first launch, StudyDesk seeds local starter content so the app is immediately testable.

Default seeded content includes:

- starter subject content
- sample deck assets
- practice quiz assets
- short-answer quiz content for keyword grading

The starter set is intended to exercise:

- subject organization
- unit grouping
- flashcard review flows
- timed quiz sessions
- negative-marking quiz rules
- keyword-graded Q&A behavior
- JSON import verification

---

## Project Structure

```text
StudyDesk/
├── flutter_app/
├── docs/
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE
└── README.md
```

Primary Flutter application structure:

```text
flutter_app/lib/
├── app/
├── core/
├── features/
├── services/
├── theme/
└── main.dart
```

Feature areas currently present in the app include:

- `features/subjects`
- `features/units`
- `features/decks`
- `features/cards`
- `features/notes`
- `features/study`
- `features/quizzes`
- `features/analytics`
- `features/library`
- `features/settings`
- `features/dashboard`

---

## Installation

### Prerequisites

- Flutter SDK 3.x
- Dart SDK compatible with the installed Flutter SDK
- Chrome for web testing
- Android Studio with Android SDK for Android builds
- Windows Developer Mode for plugin-enabled Windows desktop builds

### Web

From the Flutter project directory:

```powershell
cd flutter_app
flutter pub get
powershell -ExecutionPolicy Bypass -File .\run_web_studydesk.ps1
```

### Windows Desktop

```powershell
cd flutter_app
flutter pub get
flutter run -d windows
```

If Windows desktop reports a symlink or plugin support issue, enable Developer Mode first and retry.

### Android

```powershell
cd flutter_app
flutter pub get
flutter run -d android
```

For distributable Android outputs:

```powershell
cd flutter_app
flutter build apk
flutter build appbundle
```

### Windows Portable Zip

To build and package a portable Windows zip:

```powershell
cd flutter_app
powershell -ExecutionPolicy Bypass -File .\build_and_package_windows_portable.ps1 -Configuration Release
```

The packaging script resets stale Flutter Windows plugin symlinks before building so repeat packaging runs do not fail on leftover desktop build artifacts.

---

## Platform Compatibility

### Web

- Supported as an active testing target
- Uses browser-local persistence
- Supports JSON import through file picking and drag-and-drop

### Windows

- Supported as a local desktop target
- Uses local persistence suitable for offline study sessions
- Supports portable packaging through the included PowerShell script

### Android

- Supported as a local mobile target
- Uses local SQLite-backed persistence
- Supports file-picker JSON import
- Requires Android Studio, Android SDK, and a connected device or emulator

---

## Usage

### First Run

1. Launch the app.
2. Let the bootstrap seed starter content if no local data exists yet.
3. Open the starter subject to explore notes, decks, and quizzes.

### Notes

1. Open a subject.
2. Optionally create a unit such as a chapter or module.
3. Open the notes workspace or create a quick note.
4. Write in Markdown, use LaTeX where needed, and connect notes with wiki links.
5. Export the note as Markdown or turn selected content into flashcards.

### Flashcards

1. Open a subject.
2. Optionally organize by unit.
3. Create a deck or import sample content.
4. Add cards or create them from note selections.
5. Start a study session and review cards.

### Quizzes

1. Open a subject.
2. Optionally assign the quiz to a unit.
3. Create a quiz or import a quiz JSON file.
4. Add questions through the quiz detail screen.
5. Start the quiz and review the results locally.

### Import Testing

1. Open a subject.
2. Use `Import JSON` to load a local deck or quiz file.
3. On web, drag and drop a JSON file into the subject import zone if preferred.
4. On Windows and Android, use the same import button with the platform file picker.
5. Confirm the imported content appears under the expected subject and unit.

---

## Technologies Used

| Category | Technology |
|---|---|
| App Framework | Flutter |
| State Management | Riverpod |
| Routing | GoRouter |
| Local Storage | SQLite, SharedPreferences |
| Content Rendering | flutter_markdown_plus, flutter_markdown_plus_latex, flutter_math_fork |
| File Import | file_picker, flutter_dropzone |
| Platforms in Active Use | Web, Windows, Android |
| Language | Dart |

---

## Security and Data Handling

- StudyDesk is local-first by default
- Core study data stays on-device or in browser-local storage during normal use
- No account is required for the current core learning flows
- Import validation is enforced for structured deck and quiz content before persistence
- Notes, decks, quizzes, and progress remain local unless the user explicitly exports content

More detail is available in [SECURITY.md](./SECURITY.md).

---

## Current Limitations

- Quiz export is not yet implemented
- Study data sync across devices is not part of the current local-first build
- Web persistence is tied to the browser profile and origin
- Web has drag-and-drop import in addition to file-picker import, while Windows and Android currently use file-picker import only
- The app is still in active alpha, so schema evolution and content-portability workflows are still being hardened
- Broader platform support beyond the current web, Windows, and Android focus is not yet documented here

---

## Documentation

Detailed project documentation is available in the `docs/` directory:

| Document | Description |
|---|---|
| [`PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) | Current implementation snapshot and status notes |
| [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Application structure, architectural boundaries, and design direction |
| [`FEATURES.md`](docs/FEATURES.md) | Feature inventory and product-scope reference |
| [`VISION.md`](docs/VISION.md) | Product direction and long-term intent |
| [`DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md) | Data model and storage-layer notes |
| [`JSON_FORMAT_SPEC.md`](docs/JSON_FORMAT_SPEC.md) | Implemented and planned content portability formats |
| [`DECISIONS.md`](docs/DECISIONS.md) | Decision log and implementation rationale |
| [`IMPLEMENTATION_ROADMAP_2026.md`](docs/IMPLEMENTATION_ROADMAP_2026.md) | Ongoing roadmap and milestone planning |
| [`UI_UX_GUIDE.md`](docs/UI_UX_GUIDE.md) | UI and UX direction for the app |
| [`AI_INTEGRATION_GUIDE.md`](docs/AI_INTEGRATION_GUIDE.md) | AI-related integration planning and guidance |
| [`WEB_RESEARCH_COMPETITIVE_ANALYSIS_2026.md`](docs/WEB_RESEARCH_COMPETITIVE_ANALYSIS_2026.md) | Competitive product research record |
| [`WEB_RESEARCH_STUDY_PREFERENCES_AND_EXAM_RULES_2026.md`](docs/WEB_RESEARCH_STUDY_PREFERENCES_AND_EXAM_RULES_2026.md) | Research on study preferences, question formats, and exam conventions |

Flutter-app-specific notes live in [flutter_app/README.md](./flutter_app/README.md).

---

## License

This project is licensed under the MIT License.

See the [LICENSE](./LICENSE) file for full details.
