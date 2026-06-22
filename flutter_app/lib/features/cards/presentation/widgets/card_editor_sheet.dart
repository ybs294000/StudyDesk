import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/card_record.dart';

class CardDraft {
  const CardDraft({
    required this.front,
    required this.back,
    required this.hint,
  });

  final String front;
  final String back;
  final String hint;
}

class CardEditorSheet extends StatefulWidget {
  const CardEditorSheet({
    this.initialCard,
    this.initialDraft,
    super.key,
  });

  final CardRecord? initialCard;
  final CardDraft? initialDraft;

  @override
  State<CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<CardEditorSheet> {
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  late final TextEditingController _hintController;
  String? _frontError;
  String? _backError;

  bool get _isEditing => widget.initialCard != null;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(
      text: widget.initialCard?.front ?? widget.initialDraft?.front ?? '',
    );
    _backController = TextEditingController(
      text: widget.initialCard?.back ?? widget.initialDraft?.back ?? '',
    );
    _hintController = TextEditingController(
      text: widget.initialCard?.hint ?? widget.initialDraft?.hint ?? '',
    );
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _hintController.dispose();
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
              _isEditing ? 'Edit Card' : 'Create Card',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _frontController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Front',
                hintText: 'What is the functional group of an alcohol?',
                errorText: _frontError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _backController,
              minLines: 4,
              maxLines: 7,
              decoration: InputDecoration(
                labelText: 'Back',
                hintText: 'Hydroxyl group: -OH',
                errorText: _backError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _hintController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Hint',
                hintText: 'Optional hint shown before revealing the answer.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                label: Text(_isEditing ? 'Save Card' : 'Create Card'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();
    setState(() {
      _frontError = front.isEmpty ? 'Front text is required.' : null;
      _backError = back.isEmpty ? 'Back text is required.' : null;
    });
    if (_frontError != null || _backError != null) {
      return;
    }

    Navigator.of(context).pop(
      CardDraft(
        front: front,
        back: back,
        hint: _hintController.text.trim(),
      ),
    );
  }
}
