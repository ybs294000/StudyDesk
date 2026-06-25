# JSON Format Specification

Last updated: 2026-06-20

This document describes the StudyDesk JSON direction.

Implemented today:

- Deck import
- Deck export
- Quiz import, including MCQ, true/false, fill-in-the-blank, and keyword-graded Q&A

Still forward-looking:

- Quiz export
- sheet
- qa_set as a standalone top-level type
- subject backup
- full-backup

## Top-Level Wrapper

StudyDesk currently accepts either `studydesk_version` or the legacy `studyforge_version` field on import.

```json
{
  "studydesk_version": "1.0",
  "export_date": "2026-06-20T00:00:00Z",
  "type": "deck",
  "content": {}
}
```

Legacy compatibility example:

```json
{
  "studyforge_version": "1.0",
  "export_date": "2026-06-20T00:00:00Z",
  "type": "deck",
  "content": {}
}
```

## Implemented Format: Deck

This is the format the current app can actually import and export.

```json
{
  "studydesk_version": "1.0",
  "export_date": "2026-06-20T00:00:00Z",
  "type": "deck",
  "content": {
    "name": "Functional Groups",
    "description": "Common organic functional groups and their properties",
    "cards": [
      {
        "id": "card_001",
        "front": "What is the functional group of an alcohol?",
        "back": "Hydroxyl group: -OH",
        "hint": "Think of water with one H replaced"
      }
    ]
  }
}
```

### Required Fields

- top-level version field
- `type`
- `content.name`
- `content.cards`
- each card must have non-empty `front` and `back`

### Currently Ignored or Not Yet Persisted

The sample JSON may contain fields like:

- `front_image`
- `back_image`
- `tags`

These are part of the intended format direction, but the current flashcard implementation does not yet persist or use them.

## Forward-Looking Formats

These remain documented targets, not current import/export guarantees:

- `subject`
- `quiz`
- `sheet`
- `qa_set`
- `backup`

They should not be treated as implemented until the app ships the corresponding domain models and flows.

## Implemented Quiz Import Format

StudyDesk imports common exam-style quiz rules, including cases where wrong answers reduce the score.

```json
{
  "studydesk_version": "1.0",
  "type": "quiz",
  "content": {
    "name": "Competitive Practice Set",
    "description": "Timed practice with mixed marking rules",
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
      },
      "section_rules": [
        {
          "section_id": "part_a",
          "name": "MCQ",
          "question_types": ["mcq", "true_false"],
          "negative_marking": true,
          "wrong_points": -1
        },
        {
          "section_id": "part_b",
          "name": "Numerical",
          "question_types": ["fill_blank"],
          "negative_marking": false,
          "wrong_points": 0
        }
      ]
    },
    "questions": [
      {
        "id": "q_001",
        "type": "mcq",
        "question": "Question text",
        "options": ["A", "B", "C", "D"],
        "correct_index": 0,
        "points": 4,
        "grading": {
          "negative_marking": true,
          "wrong_points": -1
        }
      }
    ]
  }
}
```

### Quiz Grading Fields

- `correct_points`
- `wrong_points`
- `skipped_points`
- `negative_marking`
- `partial_credit`
- `section_rules`
- per-question `points`
- per-question `grading` override
- short-answer `keyword_rules`
- short-answer `minimum_keyword_matches`
- short-answer `minimum_keyword_score_percent`
- short-answer `allow_partial_credit`

This is intentionally broader than a simple classroom quiz because many exam-style practice systems need to model standard MCQ marking, no-negative-marking sections, and keyword-based written responses.

### Short-Answer / Q&A Example

```json
{
  "id": "q_qa_001",
  "type": "short_answer",
  "question": "Why are mitochondria called the powerhouse of the cell?",
  "model_answer": "They produce ATP through cellular respiration, supplying usable energy.",
  "keywords": ["ATP", "energy", "cellular respiration"],
  "keyword_rules": [
    {
      "term": "ATP",
      "aliases": ["adenosine triphosphate"],
      "required": true,
      "weight": 1.2
    },
    {
      "term": "energy",
      "aliases": ["usable energy"],
      "required": true,
      "weight": 1.0
    },
    {
      "term": "cellular respiration",
      "aliases": ["respiration"],
      "required": false,
      "weight": 0.8
    }
  ],
  "min_words": 10,
  "max_words": 50,
  "minimum_keyword_matches": 2,
  "minimum_keyword_score_percent": 0.6,
  "allow_partial_credit": true,
  "grading_mode": "keywords",
  "points": 4
}
```

In current StudyDesk builds:

- `keywords` is still accepted for compatibility
- `keyword_rules` is preferred when you want required vs supporting concepts
- `minimum_keyword_matches` lets authors demand a minimum count of matched concepts
- `minimum_keyword_score_percent` sets the pass threshold for full credit
- `allow_partial_credit` lets the grader award proportional credit from keyword coverage

## Validation Rules

Current import validation must ensure:

1. A version field exists
2. `type` is a supported implemented type
3. `content.name` is present and non-empty
4. Deck imports contain non-empty `content.cards`
5. Quiz imports contain non-empty `content.questions`
6. Every deck card contains non-empty `front` and `back`
7. Every short-answer quiz question intended for keyword grading contains at least one required keyword concept

## AI Generation Workflow

StudyDesk exposes a built-in AI handoff bundle in `Settings -> Schema Editor`.

Recommended usage:

1. Copy `AI Prompt` or `Prompt + Schema`
2. Paste it into your AI tool
3. Ask for exactly one output mode at a time
4. Import the returned file into the relevant subject

Current supported AI output targets are:

- `deck` JSON
- `quiz` JSON
- raw Markdown note content

Important constraints:

- Return JSON only for deck and quiz output
- Do not wrap JSON in markdown fences
- Keep field names exactly as documented
- Use only implemented question types
- For Markdown notes, return raw Markdown only

### Example Deck Prompt

```text
Create a StudyDesk deck JSON file about [TOPIC].
Return valid JSON only.
Use the exact StudyDesk deck schema.
Include at least 10 cards with clear front and back text.
```

### Example Quiz Prompt

```text
Create a StudyDesk quiz JSON file about [TOPIC].
Return valid JSON only.
Use the exact StudyDesk quiz schema.
Choose only supported question types and include all required grading fields.
```

### Example Note Prompt

```text
Create a StudyDesk Markdown note about [TOPIC].
Return raw Markdown only.
Use ## headings for major sections and keep the structure study-ready.
```
