# JSON Format Specification

Last updated: 2026-06-26

This document describes the import and export formats currently supported by StudyDesk.

## Wrapper Format

StudyDesk import payloads use a top-level JSON object.

```json
{
  "studydesk_version": "1.0",
  "export_date": "2026-06-26T00:00:00Z",
  "type": "deck",
  "content": {}
}
```

For backward compatibility, import still accepts the legacy `studyforge_version` field in place of `studydesk_version`.

## Implemented Import Types

StudyDesk currently imports:

- `deck`
- `quiz`

Notes are imported as Markdown files rather than JSON payloads.

## Deck Format

```json
{
  "studydesk_version": "1.0",
  "export_date": "2026-06-26T00:00:00Z",
  "type": "deck",
  "content": {
    "name": "Functional Groups",
    "description": "Common organic chemistry prompts",
    "tags": ["chemistry", "flashcards"],
    "cards": [
      {
        "id": "card_001",
        "front": "What is the functional group of an alcohol?",
        "back": "Hydroxyl group: -OH",
        "hint": "Think of water with one hydrogen replaced"
      }
    ]
  }
}
```

### Required fields

- `type`
- `content.name`
- `content.cards`
- non-empty `front` and `back` for every card

## Quiz Format

```json
{
  "studydesk_version": "1.0",
  "export_date": "2026-06-26T00:00:00Z",
  "type": "quiz",
  "content": {
    "name": "Competitive Practice Set",
    "description": "Timed objective practice",
    "tags": ["mcq", "exam-prep"],
    "settings": {
      "shuffle_questions": true,
      "shuffle_options": true,
      "timer_mode": "per_quiz",
      "timer_seconds": 3600,
      "show_feedback": "after_quiz",
      "passing_score_percent": 40,
      "marking": {
        "correct_points": 4,
        "wrong_points": -1,
        "skipped_points": 0,
        "negative_marking": true,
        "partial_credit": false
      }
    },
    "questions": [
      {
        "id": "q_001",
        "type": "mcq",
        "question": "Question text",
        "options": ["A", "B", "C", "D"],
        "correct_index": 0,
        "explanation": "Why the correct option is right",
        "points": 4
      }
    ]
  }
}
```

### Supported question types

- `mcq`
- `true_false`
- `fill_blank`
- `short_answer`

### Short-answer support

Short-answer questions can include:

- `model_answer`
- `keywords`
- `keyword_rules`
- `minimum_keyword_matches`
- `minimum_keyword_score_percent`
- `allow_partial_credit`
- `min_words`
- `max_words`

## Validation Rules

Current import validation checks:

1. the payload is valid UTF-8 text
2. the payload is valid JSON
3. the top-level JSON value is an object
4. the wrapper `type` is supported
5. required content fields are present
6. card and question counts remain within StudyDesk safety limits
7. quiz questions use valid structures for their declared type
8. imported strings stay within StudyDesk field-length limits

## Markdown Note Import

Notes are imported as Markdown files.

Recommended structure:

```md
---
section-level: h2
---

## Topic
Study content here.

## Another Topic
More study content here.
```

This format works well with the note reading and section-recall flows already implemented in the app.

## AI-Assisted Content Generation

StudyDesk exposes a built-in AI prompt and schema bundle in `Settings -> Schema Editor`.

Recommended workflow:

1. copy `AI Prompt` or `Prompt + Schema`
2. paste it into an external AI tool
3. ask for exactly one output mode at a time
4. import the resulting deck JSON, quiz JSON, or Markdown note

If the returned payload follows the schema exactly, the import should work without manual cleanup.
