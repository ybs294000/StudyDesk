import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/deck_record.dart';
import '../../../units/domain/subject_unit_record.dart';

class DeckDraft {
  const DeckDraft({
    required this.name,
    required this.description,
    required this.unitId,
    required this.tags,
  });

  final String name;
  final String description;
  final String? unitId;
  final List<String> tags;
}

class DeckEditorSheet extends StatefulWidget {
  const DeckEditorSheet({
    this.initialDeck,
    this.availableUnits = const [],
    this.initialUnitId,
    super.key,
  });

  final DeckRecord? initialDeck;
  final List<SubjectUnitRecord> availableUnits;
  final String? initialUnitId;

  @override
  State<DeckEditorSheet> createState() => _DeckEditorSheetState();
}

class _DeckEditorSheetState extends State<DeckEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  String? _selectedUnitId;
  String? _nameError;

  bool get _isEditing => widget.initialDeck != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDeck?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDeck?.description ?? '',
    );
    _tagsController = TextEditingController(
      text: (widget.initialDeck?.tags ?? const <String>[]).join(', '),
    );
    _selectedUnitId = widget.initialDeck?.unitId ?? widget.initialUnitId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
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
            Text(
              _isEditing ? 'Edit Deck' : 'Create Deck',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Deck name',
                hintText: 'Functional Groups',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What this deck covers and how you will use it.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _selectedUnitId,
              decoration: const InputDecoration(
                labelText: 'Unit',
                helperText: 'Optional chapter or unit inside this subject.',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Uncategorized'),
                ),
                for (final unit in widget.availableUnits)
                  DropdownMenuItem<String?>(
                    value: unit.id,
                    child: Text(unit.name),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedUnitId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'memory, chapter-1, formulas',
                helperText: 'Comma-separated labels for search and filtering.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                label: Text(_isEditing ? 'Save Deck' : 'Create Deck'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _nameError = 'Please give the deck a name.');
      return;
    }
    Navigator.of(context).pop(
      DeckDraft(
        name: trimmedName,
        description: _descriptionController.text.trim(),
        unitId: _selectedUnitId,
        tags: _tagsController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      ),
    );
  }
}
