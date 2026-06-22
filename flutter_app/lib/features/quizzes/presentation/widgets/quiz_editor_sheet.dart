import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/quiz_models.dart';
import '../../../units/domain/subject_unit_record.dart';

class QuizEditorDraft {
  const QuizEditorDraft({
    required this.name,
    required this.description,
    required this.unitId,
    required this.tags,
    required this.shuffleQuestions,
    required this.shuffleOptions,
    required this.timerMode,
    required this.timerSeconds,
    required this.passingScorePercent,
    required this.correctPoints,
    required this.wrongPoints,
    required this.skippedPoints,
    required this.negativeMarking,
  });

  final String name;
  final String description;
  final String? unitId;
  final List<String> tags;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final String timerMode;
  final int timerSeconds;
  final int? passingScorePercent;
  final double correctPoints;
  final double wrongPoints;
  final double skippedPoints;
  final bool negativeMarking;
}

class QuizEditorSheet extends StatefulWidget {
  const QuizEditorSheet({
    this.initialQuiz,
    this.availableUnits = const [],
    super.key,
  });

  final QuizRecord? initialQuiz;
  final List<SubjectUnitRecord> availableUnits;

  @override
  State<QuizEditorSheet> createState() => _QuizEditorSheetState();
}

class _QuizEditorSheetState extends State<QuizEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _timerMinutesController;
  late final TextEditingController _passingScoreController;
  late final TextEditingController _correctPointsController;
  late final TextEditingController _wrongPointsController;
  late final TextEditingController _skippedPointsController;
  late bool _shuffleQuestions;
  late bool _shuffleOptions;
  late bool _negativeMarking;
  late String _timerMode;
  String? _selectedUnitId;

  @override
  void initState() {
    super.initState();
    final quiz = widget.initialQuiz;
    final settings = quiz?.settings ?? QuizSettings.defaults;
    final marking = settings.marking;
    _nameController = TextEditingController(text: quiz?.name ?? '');
    _descriptionController = TextEditingController(text: quiz?.description ?? '');
    _tagsController = TextEditingController(
      text: (quiz?.tags ?? const <String>[]).join(', '),
    );
    _timerMinutesController = TextEditingController(
      text: settings.timerSeconds <= 0 ? '' : '${settings.timerSeconds ~/ 60}',
    );
    _passingScoreController = TextEditingController(
      text: settings.passingScorePercent?.toString() ?? '',
    );
    _correctPointsController = TextEditingController(
      text: marking.correctPoints.toStringAsFixed(
        marking.correctPoints.truncateToDouble() == marking.correctPoints ? 0 : 1,
      ),
    );
    _wrongPointsController = TextEditingController(
      text: marking.wrongPoints.toStringAsFixed(
        marking.wrongPoints.truncateToDouble() == marking.wrongPoints ? 0 : 1,
      ),
    );
    _skippedPointsController = TextEditingController(
      text: marking.skippedPoints.toStringAsFixed(
        marking.skippedPoints.truncateToDouble() == marking.skippedPoints ? 0 : 1,
      ),
    );
    _shuffleQuestions = settings.shuffleQuestions;
    _shuffleOptions = settings.shuffleOptions;
    _negativeMarking = marking.negativeMarking;
    _timerMode = settings.timerMode;
    _selectedUnitId = quiz?.unitId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _timerMinutesController.dispose();
    _passingScoreController.dispose();
    _correctPointsController.dispose();
    _wrongPointsController.dispose();
    _skippedPointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialQuiz != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Edit Quiz' : 'Create Quiz',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Quiz name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _selectedUnitId,
              decoration: const InputDecoration(
                labelText: 'Unit',
                helperText: 'Optional chapter or unit for this quiz.',
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
                hintText: 'practice, revision, easy',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Behavior',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              value: _shuffleQuestions,
              onChanged: (value) => setState(() => _shuffleQuestions = value),
              title: const Text('Shuffle question order'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _shuffleOptions,
              onChanged: (value) => setState(() => _shuffleOptions = value),
              title: const Text('Shuffle answer options'),
              contentPadding: EdgeInsets.zero,
            ),
            DropdownButtonFormField<String>(
              initialValue: _timerMode,
              decoration: const InputDecoration(labelText: 'Timer mode'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No timer')),
                DropdownMenuItem(value: 'per_quiz', child: Text('Whole quiz timer')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _timerMode = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _timerMinutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Timer minutes',
                helperText: 'Leave blank for untimed quizzes.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passingScoreController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Passing score percent',
                helperText: 'Optional. Example: 50',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Marking',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _correctPointsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Correct answer points'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _wrongPointsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Wrong answer points'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _skippedPointsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Skipped answer points'),
            ),
            SwitchListTile(
              value: _negativeMarking,
              onChanged: (value) => setState(() => _negativeMarking = value),
              title: const Text('Enable negative marking'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Save Quiz' : 'Create Quiz'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz name is required.')),
      );
      return;
    }

    final timerMinutes = int.tryParse(_timerMinutesController.text.trim()) ?? 0;
    final passingScore = int.tryParse(_passingScoreController.text.trim());
    final double correctPoints =
        double.tryParse(_correctPointsController.text.trim()) ?? 1.0;
    final double wrongPoints =
        double.tryParse(_wrongPointsController.text.trim()) ?? 0.0;
    final double skippedPoints =
        double.tryParse(_skippedPointsController.text.trim()) ?? 0.0;

    Navigator.of(context).pop(
      QuizEditorDraft(
        name: name,
        description: _descriptionController.text.trim(),
        unitId: _selectedUnitId,
        tags: _tagsController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        shuffleQuestions: _shuffleQuestions,
        shuffleOptions: _shuffleOptions,
        timerMode: timerMinutes > 0 && _timerMode == 'per_quiz' ? 'per_quiz' : 'none',
        timerSeconds: timerMinutes > 0 ? timerMinutes * 60 : 0,
        passingScorePercent: passingScore,
        correctPoints: correctPoints,
        wrongPoints: wrongPoints,
        skippedPoints: skippedPoints,
        negativeMarking: _negativeMarking,
      ),
    );
  }
}
