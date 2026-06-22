# StudyDesk Implementation Roadmap

Last updated: 2026-06-21

This roadmap tracks the current implementation direction for StudyDesk based on the repository state as of June 2026.

## Current Focus

StudyDesk is being developed as a structured local-first Flutter application with the following priorities:

- reliable study workflows
- platform-aware persistence
- explicit content portability
- maintainable feature boundaries
- public documentation that matches the codebase

## Current Repository State

The repository already includes:

- subject organization
- deck and flashcard workflows
- quiz authoring and quiz sessions
- keyword-graded Q&A support
- local analytics
- starter-content bootstrap
- JSON import for decks and quizzes

## Active Workstreams

### 1. Study Engine Hardening

Goals:

- improve review scheduling robustness
- increase automated test coverage for flashcard and quiz flows
- continue tightening validation across authoring and import paths

### 2. Portability and Data Management

Goals:

- preserve clear JSON-based import contracts
- add broader export and backup coverage
- improve duplicate handling and user-facing import validation

### 3. Analytics Expansion

Goals:

- extend beyond current summary views
- improve longer-range study history visibility
- add clearer performance breakdowns across subjects and content types

### 4. Additional Study Formats

Goals:

- implement sheets and rehearsal mode
- add study-friendly reference content flows
- keep future formats aligned with the existing subject model

### 5. Operational Readiness

Goals:

- keep platform behavior explicit
- continue documenting implemented versus planned functionality clearly
- reduce drift between code, docs, and roadmap statements

## Architectural Direction

StudyDesk continues to follow these accepted directions:

- Flutter remains the application framework
- Riverpod remains the primary state-management layer
- local persistence remains the default operating model
- repositories remain the source of truth for feature data
- public docs should describe implemented behavior accurately

## Near-Term Milestones

### Milestone A: Study Workflow Consolidation

- strengthen test coverage around quiz grading and study progression
- review and refine local scheduling behavior
- improve result review surfaces where needed

### Milestone B: Portability Expansion

- add quiz export
- add subject-level backup/export paths
- improve import diagnostics and user guidance

### Milestone C: New Content Surfaces

- implement sheets and rehearsal mode
- integrate them into subject workspaces and analytics

### Milestone D: Documentation and Repo Hygiene

- keep engineering docs synchronized with shipped functionality
- keep internal-only working notes out of the public repository
- continue reducing stale architectural assumptions in older docs
