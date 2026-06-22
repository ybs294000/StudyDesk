import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/quiz_models.dart';

class QuizQuestionDraft {
  const QuizQuestionDraft({
    required this.type,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.correctAnswer,
    required this.correctAnswers,
    required this.caseSensitive,
    required this.modelAnswer,
    required this.requiredKeywords,
    required this.supportingKeywords,
    required this.minWords,
    required this.maxWords,
    required this.minimumKeywordMatches,
    required this.minimumKeywordScorePercent,
    required this.allowPartialCredit,
    required this.explanation,
    required this.points,
  });

  final QuizQuestionType type;
  final String question;
  final List<String> options;
  final int? correctIndex;
  final bool? correctAnswer;
  final List<String> correctAnswers;
  final bool caseSensitive;
  final String modelAnswer;
  final List<String> requiredKeywords;
  final List<String> supportingKeywords;
  final int? minWords;
  final int? maxWords;
  final int? minimumKeywordMatches;
  final double? minimumKeywordScorePercent;
  final bool allowPartialCredit;
  final String explanation;
  final double points;
}

class QuizQuestionEditorSheet extends StatefulWidget {
  const QuizQuestionEditorSheet({
    this.initialQuestion,
    super.key,
  });

  final QuizQuestion? initialQuestion;

  @override
  State<QuizQuestionEditorSheet> createState() => _QuizQuestionEditorSheetState();
}

class _QuizQuestionEditorSheetState extends State<QuizQuestionEditorSheet> {
  late QuizQuestionType _type;
  late final TextEditingController _questionController;
  late final TextEditingController _optionsController;
  late final TextEditingController _correctIndexController;
  late final TextEditingController _correctAnswerController;
  late final TextEditingController _requiredKeywordsController;
  late final TextEditingController _supportingKeywordsController;
  late final TextEditingController _minWordsController;
  late final TextEditingController _maxWordsController;
  late final TextEditingController _minimumKeywordMatchesController;
  late final TextEditingController _minimumKeywordScorePercentController;
  late final TextEditingController _modelAnswerController;
  late final TextEditingController _explanationController;
  late final TextEditingController _pointsController;
  late bool _caseSensitive;
  late bool _allowPartialCredit;
  bool? _trueFalseAnswer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuestion;
    _type = initial?.type ?? QuizQuestionType.mcq;
    _questionController = TextEditingController(text: initial?.question ?? '');
    _optionsController = TextEditingController(
      text: initial == null ? '' : initial.options.join('\n'),
    );
    _correctIndexController = TextEditingController(
      text: initial?.correctIndex == null ? '' : '${initial!.correctIndex! + 1}',
    );
    _correctAnswerController = TextEditingController(
      text: initial == null ? '' : initial.correctAnswers.join('\n'),
    );
    final requiredKeywords = initial == null
        ? const <String>[]
        : initial.keywordRules.isNotEmpty
            ? initial.keywordRules
                .where((rule) => rule.required)
                .map((rule) => rule.term)
                .toList()
            : initial.keywords;
    final supportingKeywords = initial == null
        ? const <String>[]
        : initial.keywordRules
            .where((rule) => !rule.required)
            .map((rule) => rule.term)
            .toList();
    _requiredKeywordsController = TextEditingController(
      text: requiredKeywords.join('\n'),
    );
    _supportingKeywordsController = TextEditingController(
      text: supportingKeywords.join('\n'),
    );
    _minWordsController = TextEditingController(
      text: initial?.minWords?.toString() ?? '',
    );
    _maxWordsController = TextEditingController(
      text: initial?.maxWords?.toString() ?? '',
    );
    _minimumKeywordMatchesController = TextEditingController(
      text: initial?.minimumKeywordMatches?.toString() ?? '',
    );
    _minimumKeywordScorePercentController = TextEditingController(
      text: initial?.minimumKeywordScorePercent == null
          ? ''
          : '${(initial!.minimumKeywordScorePercent! * 100).round()}',
    );
    _modelAnswerController = TextEditingController(
      text: initial?.modelAnswer ?? '',
    );
    _explanationController = TextEditingController(
      text: initial?.explanation ?? '',
    );
    _pointsController = TextEditingController(
      text: (initial?.points ?? 1).toStringAsFixed(
        (initial?.points ?? 1).truncateToDouble() == (initial?.points ?? 1) ? 0 : 1,
      ),
    );
    _caseSensitive = initial?.caseSensitive ?? false;
    _allowPartialCredit = initial?.allowPartialCredit ?? false;
    _trueFalseAnswer = initial?.correctAnswer;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionsController.dispose();
    _correctIndexController.dispose();
    _correctAnswerController.dispose();
    _requiredKeywordsController.dispose();
    _supportingKeywordsController.dispose();
    _minWordsController.dispose();
    _maxWordsController.dispose();
    _minimumKeywordMatchesController.dispose();
    _minimumKeywordScorePercentController.dispose();
    _modelAnswerController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          children: [
            Text(
              widget.initialQuestion == null ? 'Add Question' : 'Edit Question',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<QuizQuestionType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Question type'),
              items: const [
                DropdownMenuItem(
                  value: QuizQuestionType.mcq,
                  child: Text('MCQ'),
                ),
                DropdownMenuItem(
                  value: QuizQuestionType.trueFalse,
                  child: Text('True / False'),
                ),
                DropdownMenuItem(
                  value: QuizQuestionType.fillBlank,
                  child: Text('Fill in the Blank'),
                ),
                DropdownMenuItem(
                  value: QuizQuestionType.shortAnswer,
                  child: Text('Question & Answer'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _questionController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Question text',
                helperText: 'Markdown and LaTeX are supported in quiz content.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _pointsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Points'),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_type == QuizQuestionType.mcq) ...[
              TextField(
                controller: _optionsController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Options',
                  helperText: 'One option per line.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _correctIndexController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Correct option number',
                  helperText: 'Use 1 for the first option, 2 for the second, and so on.',
                ),
              ),
            ],
            if (_type == QuizQuestionType.trueFalse) ...[
              DropdownButtonFormField<bool>(
                initialValue: _trueFalseAnswer,
                decoration: const InputDecoration(labelText: 'Correct answer'),
                items: const [
                  DropdownMenuItem(value: true, child: Text('True')),
                  DropdownMenuItem(value: false, child: Text('False')),
                ],
                onChanged: (value) => setState(() => _trueFalseAnswer = value),
              ),
            ],
            if (_type == QuizQuestionType.fillBlank) ...[
              TextField(
                controller: _correctAnswerController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Accepted answers',
                  helperText: 'One accepted answer per line.',
                ),
              ),
              SwitchListTile(
                value: _caseSensitive,
                onChanged: (value) => setState(() => _caseSensitive = value),
                title: const Text('Case sensitive matching'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            if (_type == QuizQuestionType.shortAnswer) ...[
              TextField(
                controller: _modelAnswerController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Model answer',
                  helperText: 'Shown in review mode after submission.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _requiredKeywordsController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Required keywords',
                  helperText:
                      'One required concept per line. These carry the main scoring weight.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _supportingKeywordsController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Supporting keywords',
                  helperText:
                      'Optional extra concepts, one per line. These can contribute partial credit.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minimumKeywordMatchesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum keyword matches',
                        helperText: 'Leave blank for automatic threshold.',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _minimumKeywordScorePercentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Pass threshold %',
                        helperText: 'Example: 60',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _allowPartialCredit,
                onChanged: (value) => setState(() => _allowPartialCredit = value),
                title: const Text('Allow partial credit from keyword coverage'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _caseSensitive,
                onChanged: (value) => setState(() => _caseSensitive = value),
                title: const Text('Case sensitive matching'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minWordsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min words'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _maxWordsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max words'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _explanationController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Explanation',
                helperText: 'Shown during results review.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submit,
              child: Text(
                widget.initialQuestion == null ? 'Add Question' : 'Save Question',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question text is required.')),
      );
      return;
    }

    final double points = double.tryParse(_pointsController.text.trim()) ?? 1.0;
    final options = _optionsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final answers = _correctAnswerController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final requiredKeywords = _requiredKeywordsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final supportingKeywords = _supportingKeywordsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final correctIndex = int.tryParse(_correctIndexController.text.trim());
    final minimumKeywordMatches = int.tryParse(
      _minimumKeywordMatchesController.text.trim(),
    );
    final minimumKeywordScorePercentValue = double.tryParse(
      _minimumKeywordScorePercentController.text.trim(),
    );

    if (_type == QuizQuestionType.mcq) {
      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MCQ questions need at least two options.')),
        );
        return;
      }
      if (correctIndex == null || correctIndex < 1 || correctIndex > options.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Provide a valid correct option number.')),
        );
        return;
      }
    }

    if (_type == QuizQuestionType.trueFalse && _trueFalseAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select whether the answer is true or false.')),
      );
      return;
    }

    if (_type == QuizQuestionType.fillBlank && answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one accepted answer.')),
      );
      return;
    }

    if (_type == QuizQuestionType.shortAnswer && requiredKeywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Q&A grading needs at least one required keyword.')),
      );
      return;
    }

    if (_type == QuizQuestionType.shortAnswer &&
        minimumKeywordMatches != null &&
        minimumKeywordMatches < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum keyword matches must be at least 1.')),
      );
      return;
    }

    if (_type == QuizQuestionType.shortAnswer &&
        minimumKeywordScorePercentValue != null &&
        (minimumKeywordScorePercentValue <= 0 || minimumKeywordScorePercentValue > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pass threshold must be between 1 and 100.')),
      );
      return;
    }

    Navigator.of(context).pop(
      QuizQuestionDraft(
        type: _type,
        question: question,
        options: options,
        correctIndex: _type == QuizQuestionType.mcq ? correctIndex! - 1 : null,
        correctAnswer: _type == QuizQuestionType.trueFalse ? _trueFalseAnswer : null,
        correctAnswers: _type == QuizQuestionType.fillBlank ? answers : const [],
        caseSensitive: (_type == QuizQuestionType.fillBlank ||
                _type == QuizQuestionType.shortAnswer)
            ? _caseSensitive
            : false,
        modelAnswer: _type == QuizQuestionType.shortAnswer
            ? _modelAnswerController.text.trim()
            : '',
        requiredKeywords: _type == QuizQuestionType.shortAnswer
            ? requiredKeywords
            : const [],
        supportingKeywords: _type == QuizQuestionType.shortAnswer
            ? supportingKeywords
            : const [],
        minWords: _type == QuizQuestionType.shortAnswer
            ? int.tryParse(_minWordsController.text.trim())
            : null,
        maxWords: _type == QuizQuestionType.shortAnswer
            ? int.tryParse(_maxWordsController.text.trim())
            : null,
        minimumKeywordMatches: _type == QuizQuestionType.shortAnswer
            ? minimumKeywordMatches
            : null,
        minimumKeywordScorePercent: _type == QuizQuestionType.shortAnswer
            ? (minimumKeywordScorePercentValue == null
                ? null
                : minimumKeywordScorePercentValue / 100)
            : null,
        allowPartialCredit:
            _type == QuizQuestionType.shortAnswer ? _allowPartialCredit : false,
        explanation: _explanationController.text.trim(),
        points: points,
      ),
    );
  }
}
