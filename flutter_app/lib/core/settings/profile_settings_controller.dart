import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _displayNameKey = 'profile_display_name';
const _dailyGoalKey = 'profile_daily_goal_minutes';
const _customSchemaTemplateKey = 'custom_schema_template_v1';
const _schemaPresetKey = 'schema_preset_v1';

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
  }) async {
    state = ProfileSettingsState(
      displayName: displayName,
      dailyGoalMinutes: dailyGoalMinutes,
      selectedSchemaPreset: selectedSchemaPreset,
      customSchemaTemplate: customSchemaTemplate,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, displayName);
    await prefs.setInt(_dailyGoalKey, dailyGoalMinutes);
    await prefs.setString(_schemaPresetKey, selectedSchemaPreset.storageValue);
    await prefs.setString(_customSchemaTemplateKey, customSchemaTemplate);
  }
}

class ProfileSettingsState {
  const ProfileSettingsState({
    required this.displayName,
    required this.dailyGoalMinutes,
    required this.selectedSchemaPreset,
    required this.customSchemaTemplate,
  });

  final String displayName;
  final int dailyGoalMinutes;
  final SchemaPreset selectedSchemaPreset;
  final String customSchemaTemplate;

  String get activeSchemaTemplate => selectedSchemaPreset == SchemaPreset.defaultSchema
      ? builtInSchemaTemplate
      : customSchemaTemplate;

  bool get isUsingCustomSchema => selectedSchemaPreset == SchemaPreset.custom;

  static const builtInSchemaTemplate = '''
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
''';

  static const defaultCustomSchemaTemplate = builtInSchemaTemplate;

  factory ProfileSettingsState.defaults() {
    return const ProfileSettingsState(
      displayName: 'Student',
      dailyGoalMinutes: 45,
      selectedSchemaPreset: SchemaPreset.defaultSchema,
      customSchemaTemplate: defaultCustomSchemaTemplate,
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
