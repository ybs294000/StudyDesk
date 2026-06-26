import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _displayNameKey = 'profile_display_name';
const _dailyGoalKey = 'profile_daily_goal_minutes';
const _customSchemaTemplateKey = 'custom_schema_template_v1';
const _schemaPresetKey = 'schema_preset_v1';
const _backupDirectoryPathKey = 'backup_directory_path_v1';
const _autoBackupImportsKey = 'auto_backup_imports_v1';
const _gamificationEnabledKey = 'gamification_enabled_v1';
const _flashcardSpacedRepetitionKey = 'flashcard_spaced_repetition_v1';
const _noteSpacedRepetitionKey = 'note_spaced_repetition_v1';
const _qaSpacedRepetitionKey = 'qa_spaced_repetition_v1';
const _quizPracticeSchedulingKey = 'quiz_practice_scheduling_v1';
const _pomodoroEnabledKey = 'pomodoro_enabled_v1';
const _pomodoroWorkMinutesKey = 'pomodoro_work_minutes_v1';
const _pomodoroBreakMinutesKey = 'pomodoro_break_minutes_v1';

final profileSettingsControllerProvider =
    NotifierProvider<ProfileSettingsController, ProfileSettingsState>(
      ProfileSettingsController.new,
    );

class ProfileSettingsController extends Notifier<ProfileSettingsState> {
  @override
  ProfileSettingsState build() {
    _load();
    return ProfileSettingsState.defaults();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ProfileSettingsState(
      displayName: prefs.getString(_displayNameKey) ?? 'Student',
      dailyGoalMinutes: prefs.getInt(_dailyGoalKey) ?? 45,
      selectedSchemaPreset: SchemaPresetX.fromStorage(
        prefs.getString(_schemaPresetKey),
      ),
      backupDirectoryPath: prefs.getString(_backupDirectoryPathKey),
      autoBackupBeforeImports: prefs.getBool(_autoBackupImportsKey) ?? true,
      gamificationEnabled: prefs.getBool(_gamificationEnabledKey) ?? true,
      flashcardSpacedRepetitionEnabled:
          prefs.getBool(_flashcardSpacedRepetitionKey) ?? true,
      noteSpacedRepetitionEnabled:
          prefs.getBool(_noteSpacedRepetitionKey) ?? true,
      qaSpacedRepetitionEnabled:
          prefs.getBool(_qaSpacedRepetitionKey) ?? true,
      quizPracticeSchedulingEnabled:
          prefs.getBool(_quizPracticeSchedulingKey) ?? true,
      pomodoroEnabled: prefs.getBool(_pomodoroEnabledKey) ?? true,
      pomodoroWorkMinutes: prefs.getInt(_pomodoroWorkMinutesKey) ?? 25,
      pomodoroBreakMinutes: prefs.getInt(_pomodoroBreakMinutesKey) ?? 5,
      customSchemaTemplate:
          prefs.getString(_customSchemaTemplateKey) ??
          ProfileSettingsState.defaultCustomSchemaTemplate,
    );
  }

  Future<void> save({
    required String displayName,
    required int dailyGoalMinutes,
    required SchemaPreset selectedSchemaPreset,
    required String customSchemaTemplate,
    required String? backupDirectoryPath,
    required bool autoBackupBeforeImports,
    required bool gamificationEnabled,
    required bool flashcardSpacedRepetitionEnabled,
    required bool noteSpacedRepetitionEnabled,
    required bool qaSpacedRepetitionEnabled,
    required bool quizPracticeSchedulingEnabled,
    required bool pomodoroEnabled,
    required int pomodoroWorkMinutes,
    required int pomodoroBreakMinutes,
  }) async {
    state = ProfileSettingsState(
      displayName: displayName,
      dailyGoalMinutes: dailyGoalMinutes,
      selectedSchemaPreset: selectedSchemaPreset,
      customSchemaTemplate: customSchemaTemplate,
      backupDirectoryPath: backupDirectoryPath,
      autoBackupBeforeImports: autoBackupBeforeImports,
      gamificationEnabled: gamificationEnabled,
      flashcardSpacedRepetitionEnabled: flashcardSpacedRepetitionEnabled,
      noteSpacedRepetitionEnabled: noteSpacedRepetitionEnabled,
      qaSpacedRepetitionEnabled: qaSpacedRepetitionEnabled,
      quizPracticeSchedulingEnabled: quizPracticeSchedulingEnabled,
      pomodoroEnabled: pomodoroEnabled,
      pomodoroWorkMinutes: pomodoroWorkMinutes,
      pomodoroBreakMinutes: pomodoroBreakMinutes,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, displayName);
    await prefs.setInt(_dailyGoalKey, dailyGoalMinutes);
    await prefs.setString(_schemaPresetKey, selectedSchemaPreset.storageValue);
    await prefs.setString(_customSchemaTemplateKey, customSchemaTemplate);
    if (backupDirectoryPath == null || backupDirectoryPath.trim().isEmpty) {
      await prefs.remove(_backupDirectoryPathKey);
    } else {
      await prefs.setString(_backupDirectoryPathKey, backupDirectoryPath.trim());
    }
    await prefs.setBool(_autoBackupImportsKey, autoBackupBeforeImports);
    await prefs.setBool(_gamificationEnabledKey, gamificationEnabled);
    await prefs.setBool(
      _flashcardSpacedRepetitionKey,
      flashcardSpacedRepetitionEnabled,
    );
    await prefs.setBool(
      _noteSpacedRepetitionKey,
      noteSpacedRepetitionEnabled,
    );
    await prefs.setBool(
      _qaSpacedRepetitionKey,
      qaSpacedRepetitionEnabled,
    );
    await prefs.setBool(
      _quizPracticeSchedulingKey,
      quizPracticeSchedulingEnabled,
    );
    await prefs.setBool(_pomodoroEnabledKey, pomodoroEnabled);
    await prefs.setInt(_pomodoroWorkMinutesKey, pomodoroWorkMinutes);
    await prefs.setInt(_pomodoroBreakMinutesKey, pomodoroBreakMinutes);
  }
}

class ProfileSettingsState {
  const ProfileSettingsState({
    required this.displayName,
    required this.dailyGoalMinutes,
    required this.selectedSchemaPreset,
    required this.customSchemaTemplate,
    required this.backupDirectoryPath,
    required this.autoBackupBeforeImports,
    required this.gamificationEnabled,
    required this.flashcardSpacedRepetitionEnabled,
    required this.noteSpacedRepetitionEnabled,
    required this.qaSpacedRepetitionEnabled,
    required this.quizPracticeSchedulingEnabled,
    required this.pomodoroEnabled,
    required this.pomodoroWorkMinutes,
    required this.pomodoroBreakMinutes,
  });

  final String displayName;
  final int dailyGoalMinutes;
  final SchemaPreset selectedSchemaPreset;
  final String customSchemaTemplate;
  final String? backupDirectoryPath;
  final bool autoBackupBeforeImports;
  final bool gamificationEnabled;
  final bool flashcardSpacedRepetitionEnabled;
  final bool noteSpacedRepetitionEnabled;
  final bool qaSpacedRepetitionEnabled;
  final bool quizPracticeSchedulingEnabled;
  final bool pomodoroEnabled;
  final int pomodoroWorkMinutes;
  final int pomodoroBreakMinutes;

  String get activeSchemaTemplate => selectedSchemaPreset == SchemaPreset.defaultSchema
      ? builtInSchemaTemplate
      : customSchemaTemplate;

  bool get isUsingCustomSchema => selectedSchemaPreset == SchemaPreset.custom;

  static const builtInSchemaTemplate = '''
STUDYDESK AI IMPORT KIT

Use one supported output mode at a time.
Return only the payload for the chosen mode.

SUPPORTED MODE 1: DECK JSON

{
  "studydesk_version": "1.0",
  "export_date": "2026-06-25T00:00:00Z",
  "type": "deck",
  "content": {
    "name": "Topic Deck",
    "description": "Short deck description",
    "tags": ["topic", "flashcards"],
    "cards": [
      {
        "id": "card_001",
        "front": "Question here",
        "back": "Answer here",
        "hint": "Optional hint here"
      }
    ]
  }
}

SUPPORTED MODE 2: QUIZ JSON

{
  "studydesk_version": "1.0",
  "type": "quiz",
  "content": {
    "name": "Competitive Practice Set",
    "description": "Timed quiz with exam-style grading rules",
    "tags": ["exam-prep", "mcq", "timed"],
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
          "name": "MCQ Section",
          "question_types": ["mcq", "true_false"],
          "negative_marking": true,
          "wrong_points": -1
        },
        {
          "section_id": "part_b",
          "name": "Numerical / TITA Section",
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
        "question": "Question here",
        "options": ["A", "B", "C", "D"],
        "correct_index": 0,
        "explanation": "Why the correct option is right",
        "points": 4,
        "grading": {
          "negative_marking": true,
          "wrong_points": -1
        }
      }
    ]
  }
}

SUPPORTED MODE 3: NOTE JSON

{
  "studydesk_version": "1.0",
  "type": "note",
  "content": {
    "title": "Topic Summary",
    "unit_id": null,
    "tags": ["topic", "notes"],
    "body_markdown": "---\nsection-level: h2\n---\n\n## Section Title\nStudy content here.\n\n## Another Section\nMore content here."
  }
}

SUPPORTED MODE 4: Q&A BANK JSON

{
  "studydesk_version": "1.0",
  "type": "qa_bank",
  "content": {
    "name": "Long Answer Recall Bank",
    "items": [
      {
        "question": "Explain the working principle of cache memory.",
        "unit_id": null,
        "tags": ["memory", "architecture", "long-answer"],
        "answer_markdown": "Cache memory is a small, high-speed memory placed close to the CPU..."
      }
    ]
  }
}

SUPPORTED MODE 5: RAW MARKDOWN NOTE

If the user explicitly asks for raw Markdown instead of StudyDesk JSON, return only Markdown.
Use headings consistently. Prefer ## for major sections.
If generated by AI, this frontmatter helps section recall mode:

---
section-level: h2
---

## Section Title
Study content here.

## Another Section
More content here.
''';

  static const builtInAiPromptTemplate = '''
Create StudyDesk-compatible study content.

Important rules:
1. Choose exactly one output mode: deck JSON, quiz JSON, note JSON, Q&A bank JSON, or raw markdown note.
2. Return only the final payload.
3. Do not add explanations.
4. Do not wrap JSON in markdown code fences.
5. Keep every required field exactly as shown in the StudyDesk schema.
6. Use valid JSON with double-quoted keys and strings.
7. If output mode is raw markdown note, return raw Markdown only.
8. Make the content realistic, complete, and ready to import.

When creating a deck JSON:
- top-level "type" must be "deck"
- include "content.name"
- include at least one card
- every card must have non-empty "front" and "back"

When creating a quiz JSON:
- top-level "type" must be "quiz"
- include "content.name"
- include at least one question
- use supported question types only: "mcq", "true_false", "fill_blank", "short_answer"
- for "mcq", include "options" and "correct_index"
- for "true_false", include "correct_answer"
- for "short_answer", include "model_answer" and at least one keyword concept

When creating a note JSON:
- top-level "type" must be "note"
- include "content.title"
- include "content.body_markdown"
- use Markdown inside "content.body_markdown"
- prefer ## headings for major sections
- include frontmatter with "section-level: h2" unless the user requests a different heading level

When creating a Q&A bank JSON:
- top-level "type" must be "qa_bank"
- include at least one item in "content.items"
- every item must include "question" and "answer_markdown"
- use Markdown inside "answer_markdown"

When creating a raw markdown note:
- use Markdown only
- prefer ## headings for major sections
- include clear, study-ready structure
- use LaTeX only where needed

Follow the StudyDesk schema reference exactly.
''';

  static const builtInAiPromptWithSchema = '''
AI TASK

$builtInAiPromptTemplate

SCHEMA REFERENCE

$builtInSchemaTemplate
''';

  static const defaultCustomSchemaTemplate = builtInSchemaTemplate;

  factory ProfileSettingsState.defaults() {
    return const ProfileSettingsState(
      displayName: 'Student',
      dailyGoalMinutes: 45,
      selectedSchemaPreset: SchemaPreset.defaultSchema,
      customSchemaTemplate: defaultCustomSchemaTemplate,
      backupDirectoryPath: null,
      autoBackupBeforeImports: true,
      gamificationEnabled: true,
      flashcardSpacedRepetitionEnabled: true,
      noteSpacedRepetitionEnabled: true,
      qaSpacedRepetitionEnabled: true,
      quizPracticeSchedulingEnabled: true,
      pomodoroEnabled: true,
      pomodoroWorkMinutes: 25,
      pomodoroBreakMinutes: 5,
    );
  }
}

enum SchemaPreset {
  defaultSchema,
  custom,
}

extension SchemaPresetX on SchemaPreset {
  String get storageValue => switch (this) {
    SchemaPreset.defaultSchema => 'default',
    SchemaPreset.custom => 'custom',
  };

  String get label => switch (this) {
    SchemaPreset.defaultSchema => 'Built-in Default',
    SchemaPreset.custom => 'Custom',
  };

  static SchemaPreset fromStorage(String? value) {
    return switch (value) {
      'custom' => SchemaPreset.custom,
      _ => SchemaPreset.defaultSchema,
    };
  }
}
