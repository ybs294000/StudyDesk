import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/profile_settings_controller.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../core/settings/theme_preset_controller.dart';
import '../../services/content_portability_service.dart';
import '../../services/export_file_service.dart';
import '../../services/library_backup_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _dailyGoalController;
  late final TextEditingController _schemaTemplateController;
  String? _lastAppliedDisplayName;
  int? _lastAppliedGoal;
  SchemaPreset? _selectedSchemaPreset;
  String? _lastAppliedSchemaTemplate;
  String? _lastAppliedBackupDirectoryPath;
  bool? _lastAppliedAutoBackupBeforeImports;
  bool? _lastAppliedGamificationEnabled;
  String? _backupDirectoryPath;
  bool _autoBackupBeforeImports = true;
  bool _gamificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _dailyGoalController = TextEditingController();
    _schemaTemplateController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _dailyGoalController.dispose();
    _schemaTemplateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final themePreset = ref.watch(themePresetControllerProvider);
    final profile = ref.watch(profileSettingsControllerProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 840;

    if (_lastAppliedDisplayName != profile.displayName ||
        _lastAppliedGoal != profile.dailyGoalMinutes ||
        _lastAppliedSchemaTemplate != profile.customSchemaTemplate ||
        _selectedSchemaPreset != profile.selectedSchemaPreset ||
        _lastAppliedBackupDirectoryPath != profile.backupDirectoryPath ||
        _lastAppliedAutoBackupBeforeImports != profile.autoBackupBeforeImports ||
        _lastAppliedGamificationEnabled != profile.gamificationEnabled) {
      _displayNameController.text = profile.displayName;
      _dailyGoalController.text = profile.dailyGoalMinutes.toString();
      _schemaTemplateController.text = profile.customSchemaTemplate;
      _lastAppliedDisplayName = profile.displayName;
      _lastAppliedGoal = profile.dailyGoalMinutes;
      _lastAppliedSchemaTemplate = profile.customSchemaTemplate;
      _selectedSchemaPreset = profile.selectedSchemaPreset;
      _lastAppliedBackupDirectoryPath = profile.backupDirectoryPath;
      _lastAppliedAutoBackupBeforeImports = profile.autoBackupBeforeImports;
      _lastAppliedGamificationEnabled = profile.gamificationEnabled;
      _backupDirectoryPath = profile.backupDirectoryPath;
      _autoBackupBeforeImports = profile.autoBackupBeforeImports;
      _gamificationEnabled = profile.gamificationEnabled;
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Safety',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'StudyDesk keeps its live database in app-managed storage for reliability. Use a backup folder to store portable safety snapshots before imports or upgrades.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_open_rounded),
                  title: const Text('Backup folder'),
                  subtitle: Text(
                    _backupDirectoryPath == null || _backupDirectoryPath!.trim().isEmpty
                        ? 'No backup folder selected yet. Automatic snapshots will stay disabled until you choose one.'
                        : _backupDirectoryPath!,
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _chooseBackupFolder,
                      icon: const Icon(Icons.folder_rounded),
                      label: const Text('Choose Folder'),
                    ),
                    if (_backupDirectoryPath != null &&
                        _backupDirectoryPath!.trim().isNotEmpty)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() => _backupDirectoryPath = null);
                        },
                        icon: const Icon(Icons.folder_delete_rounded),
                        label: const Text('Clear Folder'),
                      ),
                    FilledButton.icon(
                      onPressed: _createManualSafetySnapshot,
                      icon: const Icon(Icons.archive_rounded),
                      label: const Text('Create Snapshot Now'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoBackupBeforeImports,
                  onChanged: (value) {
                    setState(() => _autoBackupBeforeImports = value);
                  },
                  title: const Text('Automatic snapshot before imports'),
                  subtitle: const Text(
                    'When a backup folder is configured, StudyDesk will create a safety archive before deck, quiz, or note imports.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    hintText: 'Student',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _dailyGoalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily study goal (minutes)',
                    hintText: '45',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _gamificationEnabled,
              onChanged: (value) {
                setState(() => _gamificationEnabled = value);
              },
              title: const Text('Gamification features'),
              subtitle: const Text(
                'Show XP, milestones, and study-goal progress across the app while keeping your study data unchanged.',
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Export your library, performance history, analytics snapshots, and targeted review material as local files.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _exportEntireLibrary,
                      icon: const Icon(Icons.library_books_rounded),
                      label: const Text('Entire Library'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportAnalytics,
                      icon: const Icon(Icons.insights_rounded),
                      label: const Text('Analytics'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportStudyStreaks,
                      icon: const Icon(Icons.local_fire_department_rounded),
                      label: const Text('Study Streaks'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportStudySessions,
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('Study Sessions'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportQuizAttempts,
                      icon: const Icon(Icons.fact_check_rounded),
                      label: const Text('Quiz Attempts'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportDueItems,
                      icon: const Icon(Icons.event_available_rounded),
                      label: const Text('Due Items'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportWeakTopics,
                      icon: const Icon(Icons.trending_down_rounded),
                      label: const Text('Weak Topics'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportWrongQuestionsQuiz,
                      icon: const Icon(Icons.quiz_rounded),
                      label: const Text('Wrong Qs as Quiz'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportWrongQuestionsDeck,
                      icon: const Icon(Icons.style_rounded),
                      label: const Text('Wrong Qs as Deck'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _exportWrongQuestionsMarkdown,
                      icon: const Icon(Icons.description_rounded),
                      label: const Text('Wrong Qs as Markdown'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About StudyDesk',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'StudyDesk is an offline-first study workspace for flashcards, quizzes, and structured Q&A practice.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your subjects, decks, quiz attempts, and study progress stay on this device by default so you can study without relying on a network connection.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The app currently supports local study organization, timed quiz sessions, markdown-rich content, and JSON-based import flows for bringing study material into a subject.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) {
                    ref
                        .read(themeModeControllerProvider.notifier)
                        .setThemeMode(selection.first);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Theme family',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final preset in AppThemePreset.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ThemePresetTile(
                      preset: preset,
                      currentPreset: themePreset,
                      selected: themePreset == preset,
                      onTap: () {
                        ref
                            .read(themePresetControllerProvider.notifier)
                            .setThemePreset(preset);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schema Editor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Use the built-in StudyDesk schema as a stable reference, or switch to your own custom schema. Your custom edits remain preserved even if you view the built-in preset again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<SchemaPreset>(
                  segments: const [
                    ButtonSegment(
                      value: SchemaPreset.defaultSchema,
                      label: Text('Built-in Default'),
                      icon: Icon(Icons.verified_rounded),
                    ),
                    ButtonSegment(
                      value: SchemaPreset.custom,
                      label: Text('Custom'),
                      icon: Icon(Icons.edit_note_rounded),
                    ),
                  ],
                  selected: {_selectedSchemaPreset ?? profile.selectedSchemaPreset},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedSchemaPreset = selection.first;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if ((_selectedSchemaPreset ?? profile.selectedSchemaPreset) ==
                    SchemaPreset.defaultSchema) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: SelectableText(
                      ProfileSettingsState.builtInSchemaTemplate,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _schemaTemplateController.text =
                                ProfileSettingsState.builtInSchemaTemplate;
                            _selectedSchemaPreset = SchemaPreset.custom;
                          });
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy Into Custom'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _editCustomSchema,
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Edit Saved Custom'),
                      ),
                    ],
                  ),
                ] else ...[
                  if (isCompact) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        _schemaTemplateController.text.trim().isEmpty
                            ? 'No custom schema saved yet.'
                            : _schemaTemplateController.text.trim(),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonalIcon(
                      onPressed: _editCustomSchema,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Edit Custom Schema'),
                    ),
                  ] else
                    TextField(
                      controller: _schemaTemplateController,
                      minLines: 10,
                      maxLines: 18,
                      decoration: const InputDecoration(
                        labelText: 'Custom schema template',
                        alignLabelWithHint: true,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Testing Assets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Bundled sample JSON files are available under assets/sample_data so you can import test decks immediately from a subject screen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _saveProfileSettings,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save Settings'),
        ),
      ],
    );
  }

  Future<void> _saveProfileSettings() async {
    final goal = int.tryParse(_dailyGoalController.text.trim()) ?? 45;
    try {
      await ref.read(profileSettingsControllerProvider.notifier).save(
            displayName: _displayNameController.text.trim().isEmpty
                ? 'Student'
                : _displayNameController.text.trim(),
            dailyGoalMinutes: goal,
            selectedSchemaPreset:
                _selectedSchemaPreset ?? SchemaPreset.defaultSchema,
            customSchemaTemplate: _schemaTemplateController.text.trim().isEmpty
                ? ProfileSettingsState.defaultCustomSchemaTemplate
                : _schemaTemplateController.text,
            backupDirectoryPath: _backupDirectoryPath?.trim().isEmpty ?? true
                ? null
                : _backupDirectoryPath?.trim(),
            autoBackupBeforeImports: _autoBackupBeforeImports,
            gamificationEnabled: _gamificationEnabled,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $error')),
        );
      }
    }
  }

  Future<void> _chooseBackupFolder() async {
    try {
      final path = await ref.read(exportFileServiceProvider).pickDirectory(
            dialogTitle: 'Choose a StudyDesk backup folder',
          );
      if (!mounted || path == null || path.trim().isEmpty) {
        return;
      }
      setState(() => _backupDirectoryPath = path);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not choose backup folder: $error')),
      );
    }
  }

  Future<void> _createManualSafetySnapshot() async {
    try {
      final path = await ref.read(libraryBackupServiceProvider).createSafetySnapshot(
            reason: 'manual',
            interactiveFallback: true,
          );
      if (!mounted || path == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Safety snapshot saved to $path')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create safety snapshot: $error')),
      );
    }
  }

  Future<void> _editCustomSchema() async {
    final draftController = TextEditingController(
      text: _schemaTemplateController.text.trim().isEmpty
          ? ProfileSettingsState.defaultCustomSchemaTemplate
          : _schemaTemplateController.text,
    );
    final savedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Schema',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The built-in schema always remains available. Changes here update only your custom schema.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: draftController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Courier New',
                          height: 1.45,
                        ),
                    decoration: const InputDecoration(
                      labelText: 'Custom schema template',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: () {
                        draftController.text =
                            ProfileSettingsState.builtInSchemaTemplate;
                      },
                      child: const Text('Reset from Built-in'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(draftController.text),
                      child: const Text('Use This Schema'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    draftController.dispose();
    if (savedValue == null) {
      return;
    }
    setState(() {
      _schemaTemplateController.text = savedValue;
      _selectedSchemaPreset = SchemaPreset.custom;
    });
  }

  Future<void> _exportEntireLibrary() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportLibraryJson();
    await _saveJsonExport(
      fileName: 'studydesk_library_export',
      json: json,
      successLabel: 'Entire library exported',
    );
  }

  Future<void> _exportAnalytics() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportAnalyticsJson();
    await _saveJsonExport(
      fileName: 'studydesk_analytics_export',
      json: json,
      successLabel: 'Analytics exported',
    );
  }

  Future<void> _exportStudyStreaks() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportStudyStreaksJson();
    await _saveJsonExport(
      fileName: 'studydesk_study_streaks',
      json: json,
      successLabel: 'Study streaks exported',
    );
  }

  Future<void> _exportStudySessions() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportStudySessionsJson();
    await _saveJsonExport(
      fileName: 'studydesk_study_sessions',
      json: json,
      successLabel: 'Study sessions exported',
    );
  }

  Future<void> _exportQuizAttempts() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportQuizAttemptsJson();
    await _saveJsonExport(
      fileName: 'studydesk_quiz_attempts',
      json: json,
      successLabel: 'Quiz attempts exported',
    );
  }

  Future<void> _exportDueItems() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportDueItemsJson();
    await _saveJsonExport(
      fileName: 'studydesk_due_items',
      json: json,
      successLabel: 'Due items exported',
    );
  }

  Future<void> _exportWeakTopics() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportWeakTopicsJson();
    await _saveJsonExport(
      fileName: 'studydesk_weak_topics',
      json: json,
      successLabel: 'Weak topics exported',
    );
  }

  Future<void> _exportWrongQuestionsQuiz() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportWrongQuestionsAsQuizJson();
    await _saveJsonExport(
      fileName: 'studydesk_wrong_questions_quiz',
      json: json,
      successLabel: 'Wrong-questions quiz exported',
    );
  }

  Future<void> _exportWrongQuestionsDeck() async {
    final json = await ref.read(contentPortabilityServiceProvider).exportWrongQuestionsAsDeckJson();
    await _saveJsonExport(
      fileName: 'studydesk_wrong_questions_deck',
      json: json,
      successLabel: 'Wrong-questions deck exported',
    );
  }

  Future<void> _exportWrongQuestionsMarkdown() async {
    try {
      final markdown = await ref
          .read(contentPortabilityServiceProvider)
          .exportWrongQuestionsMarkdown();
      final path = await ref.read(exportFileServiceProvider).saveMarkdown(
            fileName: 'studydesk_wrong_questions_review',
            markdown: markdown,
          );
      if (!mounted || path == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wrong-questions markdown exported to $path')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export wrong-questions markdown: $error')),
      );
    }
  }

  Future<void> _saveJsonExport({
    required String fileName,
    required String json,
    required String successLabel,
  }) async {
    try {
      final path = await ref.read(exportFileServiceProvider).saveJson(
            fileName: fileName,
            json: json,
          );
      if (!mounted || path == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successLabel to $path')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save export: $error')),
      );
    }
  }
}

class _ThemePresetTile extends StatelessWidget {
  const _ThemePresetTile({
    required this.preset,
    required this.currentPreset,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final AppThemePreset currentPreset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.setThemePreset(preset);
    final swatchPrimary = AppColors.primary;
    final swatchSoft = AppColors.primarySoft;
    final swatchSurface = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final swatchText = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    AppColors.setThemePreset(currentPreset);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 1.6 : 1,
          ),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            Row(
              children: [
                _ThemeSwatch(color: swatchSurface, border: true),
                const SizedBox(width: AppSpacing.xs),
                _ThemeSwatch(color: swatchSoft),
                const SizedBox(width: AppSpacing.xs),
                _ThemeSwatch(color: swatchPrimary),
                const SizedBox(width: AppSpacing.xs),
                _ThemeSwatch(color: swatchText),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Text(
                    preset.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.color,
    this.border = false,
  });

  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border
            ? Border.all(
                color: Theme.of(context).dividerColor,
              )
            : null,
      ),
    );
  }
}
