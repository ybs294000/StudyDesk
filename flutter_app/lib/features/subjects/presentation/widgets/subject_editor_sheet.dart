import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/subject_record.dart';

const subjectColorPalette = <int>[
  0xFF0F766E,
  0xFFEC4899,
  0xFFF59E0B,
  0xFF16A34A,
  0xFF2563EB,
  0xFFDC2626,
  0xFF0EA5A4,
  0xFF7C3AED,
  0xFFF97316,
  0xFF0891B2,
  0xFF65A30D,
  0xFFDB2777,
];

class SubjectDraft {
  const SubjectDraft({
    required this.name,
    required this.emoji,
    required this.colorValue,
  });

  final String name;
  final String emoji;
  final int colorValue;
}

class SubjectEditorSheet extends StatefulWidget {
  const SubjectEditorSheet({this.initialSubject, super.key});

  final SubjectRecord? initialSubject;

  @override
  State<SubjectEditorSheet> createState() => _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends State<SubjectEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  late int _colorValue;
  String? _errorText;
  String? _emojiErrorText;

  bool get _isEditing => widget.initialSubject != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialSubject?.name ?? '',
    );
    _emojiController = TextEditingController(
      text: widget.initialSubject?.emoji ?? '📚',
    );
    _colorValue = widget.initialSubject?.colorValue ?? subjectColorPalette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Subject' : 'Create Subject',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'Subject name',
                hintText: 'Organic Chemistry',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Emoji', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Text(
                    _emojiController.text.trim().isEmpty
                        ? '📚'
                        : _emojiController.text.trim(),
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _emojiController,
                    onChanged: (_) {
                      if (_emojiErrorText != null) {
                        setState(() => _emojiErrorText = null);
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Subject emoji',
                      hintText: '📚',
                      helperText:
                          'Enter any emoji. On Windows, press Win + . to open the emoji picker.',
                      errorText: _emojiErrorText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final colorValue in subjectColorPalette)
                  _ColorSwatch(
                    colorValue: colorValue,
                    selected: colorValue == _colorValue,
                    onTap: () => setState(() => _colorValue = colorValue),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
      child: FilledButton.icon(
                onPressed: _submit,
                icon: Icon(
                  _isEditing ? Icons.save_rounded : Icons.add_circle_rounded,
                ),
                label: Text(_isEditing ? 'Save Changes' : 'Create Subject'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'StudyDesk keeps subjects on this device so your core workflow stays offline-first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final trimmedName = _nameController.text.trim();
    final trimmedEmoji = _emojiController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _errorText = 'Please give the subject a name.');
      return;
    }
    if (trimmedEmoji.isEmpty) {
      setState(() => _emojiErrorText = 'Please choose an emoji for the subject.');
      return;
    }

    Navigator.of(context).pop(
      SubjectDraft(
        name: trimmedName,
        emoji: trimmedEmoji,
        colorValue: _colorValue,
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : null,
      ),
    );
  }
}
