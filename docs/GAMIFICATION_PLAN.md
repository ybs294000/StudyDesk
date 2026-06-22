# Gamification Plan

## Direction

StudyDesk uses light-touch gamification designed to reinforce studying rather than distract from it. The system prioritizes visible progress, daily consistency, constructive feedback, and milestone moments over competitive mechanics.

## Product Principles

- Keep learning outcomes ahead of entertainment loops.
- Reward real study work already captured by the app.
- Avoid public competition, spammy reminders, and manipulative pressure.
- Keep all logic deterministic and local-first.

## Research Signals

- Learners consistently prefer progress-oriented mechanics such as progress bars, immediate feedback, and achievement moments when those mechanics directly support the learning task.
- Research on education software also warns that points, badges, and competition can harm motivation when they become the main focus instead of the study process.
- Daily streaks can be motivating, but they should be implemented carefully so they support routine without creating anxiety or compulsive behavior.

## Implemented Foundation

The current gamification layer is built on top of existing local session data.

- XP is awarded from completed study activity, not taps or UI interactions.
- Levels are derived from cumulative XP with deterministic thresholds.
- Daily goal progress is tied to actual session minutes.
- Goal streaks are computed from consecutive days meeting the configured study goal.
- Milestones are derived from real progress such as session count, reviewed items, streaks, XP, and weekly quiz accuracy.
- Analytics now includes progress cards, level progress, daily goal progress, a 7-day report, and milestone tracking.
- Home and Study surfaces now expose progress state directly so users do not need to visit Analytics to understand momentum.

## Current XP Model

- Flashcard sessions: review volume, successful completions, and time spent contribute XP.
- Quiz sessions: correct answers, attempts, and time spent contribute XP.
- Extremely long sessions are capped to avoid inflating XP through idle time.

## Current Milestones

- First completed session
- 100 reviewed items
- 500 reviewed items
- Level 5
- 3-day streak
- 7-day streak
- 7-day daily-goal streak
- 85% weekly quiz accuracy

## Next Implementation Steps

### Phase 1

- Add subject-level mastery highlights on more screens.
- Add a focused weekly summary card on Home.
- Add milestone unlock timestamps and history.

### Phase 2

- Add stronger mastery scoring by combining review history and quiz performance.
- Add daily-goal completion summaries after study sessions.
- Add per-subject momentum indicators for weaker and stronger areas.

### Phase 3

- Add optional weekly recap export.
- Add gentle notification hooks for goal reminders once notifications are implemented.
- Add richer milestone categories for notes, quizzes, and long-term consistency.

## Explicit Non-Goals

- No leaderboards
- No social pressure features
- No pay-to-progress mechanics
- No noisy animations or sounds that interrupt study flow
