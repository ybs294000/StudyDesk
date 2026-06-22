# Web Research: Study Preferences and Exam Rules

Last updated: 2026-06-20

This note focuses on two questions:

1. What do students tend to benefit from or look for in flashcard and MCQ study tools?
2. What scoring and timing patterns should a serious quiz format support?

## 1. Flashcard Learning Preferences

### Strong signal: active recall and spaced review matter

Across learning literature and flashcard software practice, the strongest recurring pattern is that flashcards are most useful when they are not just static note cards, but are tied to:

- active recall
- spaced repetition
- repeated testing over time

Useful source-backed references:

- The Learning Scientists on retrieval practice: https://www.learningscientists.org/retrieval-practice
- The Learning Scientists on spaced practice: https://www.learningscientists.org/spaced-practice
- Anki official site emphasizing spaced review and urgency-based repetition: https://apps.ankiweb.net/

### Practical product inference

Students may say they want “flashcards”, but the higher-value request is usually:

- tell me what to review now
- help me remember over time
- do not make setup painful
- support images, formulas, and structured answers

## 2. What Students Typically Want In MCQ Practice

From current exam-practice ecosystems and mainstream study tools, the expected basics are usually:

- timed practice
- immediate or delayed feedback
- per-question explanation
- shuffling
- pass/fail or score percentage
- review mode after submission

For more serious exam prep, students also need:

- negative marking support
- different scoring rules per section
- skipped-question handling
- no-distraction timer behavior
- optional reattempt of wrong questions

## 3. Why Negative Marking Support Matters

Not all exams use the same scoring logic.

Common patterns across standardized and competitive practice include:

- no penalty for wrong answers
- fixed negative marking for wrong MCQs
- no negative marking in certain sections
- different point weights per question
- section-specific rules

This means a serious quiz schema should not hardcode only:

- `correct = +1`
- `wrong = 0`

It should support:

- positive marks
- negative marks
- skipped marks
- per-section overrides
- per-question overrides

## 4. Timer Expectations

Students typically need a timer that helps self-discipline without becoming the visual focus of the screen.

Good timer traits:

- visible but compact
- one-second precision is enough
- pause/resume
- reset
- does not trigger large rebuilds
- does not animate aggressively

This is especially important on web, where heavy UI updates make the app feel cheap faster than on native.

## 5. Product Implications For StudyDesk

### Flashcards

StudyDesk should prioritize:

- strong markdown rendering
- formula support
- hints
- scheduling
- low-friction review

### MCQs / Quizzes

StudyDesk should support:

- exam-style scoring
- optional negative marking
- section rules
- stable timers
- review/explanation flow

### Schema

The built-in default schema should demonstrate those capabilities clearly, even before every feature is fully implemented in UI.

## Sources

- The Learning Scientists retrieval practice: https://www.learningscientists.org/retrieval-practice
- The Learning Scientists spaced practice: https://www.learningscientists.org/spaced-practice
- Anki official site: https://apps.ankiweb.net/
- NotebookLM Help center: https://support.google.com/notebooklm
