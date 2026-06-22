import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/profile_settings_controller.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../core/settings/theme_preset_controller.dart';
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

    if (_lastAppliedDisplayName != profile.displayName ||
        _lastAppliedGoal != profile.dailyGoalMinutes ||
        _lastAppliedSchemaTemplate != profile.customSchemaTemplate ||
        _selectedSchemaPreset != profile.selectedSchemaPreset) {
      _displayNameController.text = profile.displayName;
      _dailyGoalController.text = profile.dailyGoalMinutes.toString();
      _schemaTemplateController.text = profile.customSchemaTemplate;
      _lastAppliedDisplayName = profile.displayName;
      _lastAppliedGoal = profile.dailyGoalMinutes;
      _lastAppliedSchemaTemplate = profile.customSchemaTemplate;
      _selectedSchemaPreset = profile.selectedSchemaPreset;
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
                    ],
                  ),
                ] else ...[
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
