import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/markdown_content.dart';
import '../../../services/content_portability_service.dart';
import '../../../services/export_file_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../units/application/subject_units_controller.dart';
import '../../units/domain/subject_unit_record.dart';
import '../application/subject_quizzes_controller.dart';
import '../domain/quiz_models.dart';
import 'widgets/quiz_editor_sheet.dart';
import 'widgets/quiz_question_editor_sheet.dart';

class QuizDetailScreen extends ConsumerWidget {
  const QuizDetailScreen({
    required this.subjectId,
    required this.quizId,
    super.key,
  });

  final String subjectId;
  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzes = ref.watch(subjectQuizzesControllerProvider(subjectId));
    final units = ref.watch(subjectUnitsControllerProvider(subjectId));

    return units.when(
      data: (unitItems) => quizzes.when(
        data: (items) {
          QuizRecord? quiz;
          for (final item in items) {
            if (item.id == quizId) {
              quiz = item;
              break;
            }
          }
          if (quiz == null) {
            return const Center(child: Text('Quiz not found.'));
          }
          return _QuizDetailContent(
            subjectId: subjectId,
            quiz: quiz,
            availableUnits: unitItems,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Failed to load quiz: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load units: $error')),
    );
  }
}

class _QuizDetailContent extends ConsumerWidget {
  const _QuizDetailContent({
    required this.subjectId,
    required this.quiz,
    required this.availableUnits,
  });

  final String subjectId;
  final QuizRecord quiz;
  final List<SubjectUnitRecord> availableUnits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerLabel = quiz.settings.timerMode == 'none'
        ? 'Untimed'
        : '${quiz.settings.timerSeconds ~/ 60} minutes';
    final marking = quiz.settings.marking;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            quiz.description.isEmpty
                                ? 'This quiz is ready for timed practice.'
                                : quiz.description,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _openEditQuiz(context, ref),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PopupMenuButton<_QuizExportAction>(
                      tooltip: 'Export quiz data',
                      onSelected: (action) => _handleExportAction(context, ref, action),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _QuizExportAction.quizJson,
                          child: Text('Export Quiz JSON'),
                        ),
                        PopupMenuItem(
                          value: _QuizExportAction.latestAttemptJson,
                          child: Text('Export Latest Attempt'),
                        ),
                        PopupMenuItem(
                          value: _QuizExportAction.aiReviewPackage,
                          child: Text('Export AI Review Package'),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Icon(Icons.ios_share_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _StatPill(label: '${quiz.questions.length} questions'),
                    _StatPill(label: timerLabel),
                    _StatPill(
                      label:
                          '+${marking.correctPoints.toStringAsFixed(0)} / ${marking.wrongPoints.toStringAsFixed(0)} / skip ${marking.skippedPoints.toStringAsFixed(0)}',
                    ),
                    if (quiz.settings.passingScorePercent != null)
                      _StatPill(
                        label: 'Pass ${quiz.settings.passingScorePercent}%',
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: quiz.questions.isEmpty
                          ? null
                          : () => context.push(
                                '/subjects/$subjectId/quizzes/${quiz.id}/session',
                              ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Quiz'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _openAddQuestion(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Question'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (quiz.questions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(Icons.quiz_outlined, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'This quiz has no questions yet.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add your first question and this quiz becomes immediately testable.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          ...[
            Text(
              'Questions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < quiz.questions.length; index += 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _QuestionCard(
                  index: index,
                  question: quiz.questions[index],
                  onEdit: () => _openEditQuestion(
                    context,
                    ref,
                    index,
                    quiz.questions[index],
                  ),
                  onDelete: () => _deleteQuestion(context, ref, index),
                ),
              ),
          ],
      ],
    );
  }

  Future<void> _openEditQuiz(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<QuizEditorDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => QuizEditorSheet(
        initialQuiz: quiz,
        availableUnits: availableUnits,
      ),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    final updatedQuestions = quiz.questions
        .map(
          (question) => question.points == quiz.settings.marking.correctPoints
              ? QuizQuestion(
                  id: question.id,
                  type: question.type,
                  question: question.question,
                  options: question.options,
                  correctIndex: question.correctIndex,
                  correctAnswer: question.correctAnswer,
                  correctAnswers: question.correctAnswers,
                  caseSensitive: question.caseSensitive,
                  modelAnswer: question.modelAnswer,
                  keywords: question.keywords,
                  keywordRules: question.keywordRules,
                  minWords: question.minWords,
                  maxWords: question.maxWords,
                  minimumKeywordMatches: question.minimumKeywordMatches,
                  minimumKeywordScorePercent: question.minimumKeywordScorePercent,
                  allowPartialCredit: question.allowPartialCredit,
                  gradingMode: question.gradingMode,
                  explanation: question.explanation,
                  points: draft.correctPoints,
                  grading: question.grading,
                )
              : question,
        )
        .toList();

    final updated = quiz.copyWith(
      name: draft.name,
      description: draft.description,
      unitId: draft.unitId,
      tags: draft.tags,
      settings: QuizSettings(
        shuffleQuestions: draft.shuffleQuestions,
        shuffleOptions: draft.shuffleOptions,
        timerMode: draft.timerMode,
        timerSeconds: draft.timerSeconds,
        showFeedback: 'after_quiz',
        passingScorePercent: draft.passingScorePercent,
        marking: QuizMarking(
          correctPoints: draft.correctPoints,
          wrongPoints: draft.wrongPoints,
          skippedPoints: draft.skippedPoints,
          negativeMarking: draft.negativeMarking,
          partialCredit: false,
        ),
        sectionRules: quiz.settings.sectionRules,
      ),
      questions: updatedQuestions,
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(subjectQuizzesControllerProvider(subjectId).notifier).upsertQuiz(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz updated.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update quiz: $error')),
        );
      }
    }
  }

  Future<void> _openAddQuestion(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<QuizQuestionDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const QuizQuestionEditorSheet(),
    );
    if (draft == null || !context.mounted) {
      return;
    }
    await _saveQuestionDraft(context, ref, draft);
  }

  Future<void> _openEditQuestion(
    BuildContext context,
    WidgetRef ref,
    int index,
    QuizQuestion question,
  ) async {
    final draft = await showModalBottomSheet<QuizQuestionDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => QuizQuestionEditorSheet(initialQuestion: question),
    );
    if (draft == null || !context.mounted) {
      return;
    }
    await _saveQuestionDraft(
      context,
      ref,
      draft,
      index: index,
      existingId: question.id,
    );
  }

  Future<void> _saveQuestionDraft(
    BuildContext context,
    WidgetRef ref,
    QuizQuestionDraft draft, {
    int? index,
    String? existingId,
  }) async {
    final question = QuizQuestion(
      id: existingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: draft.type,
      question: draft.question,
      options: draft.options,
      correctIndex: draft.correctIndex,
      correctAnswer: draft.correctAnswer,
      correctAnswers: draft.correctAnswers,
      caseSensitive: draft.caseSensitive,
      modelAnswer: draft.modelAnswer,
      keywords: [...draft.requiredKeywords, ...draft.supportingKeywords],
      keywordRules: [
        for (final keyword in draft.requiredKeywords)
          QuizKeywordRule(
            term: keyword,
            aliases: const [],
            required: true,
            weight: 1.0,
          ),
        for (final keyword in draft.supportingKeywords)
          QuizKeywordRule(
            term: keyword,
            aliases: const [],
            required: false,
            weight: 0.6,
          ),
      ],
      minWords: draft.minWords,
      maxWords: draft.maxWords,
      minimumKeywordMatches: draft.minimumKeywordMatches,
      minimumKeywordScorePercent: draft.minimumKeywordScorePercent,
      allowPartialCredit: draft.allowPartialCredit,
      gradingMode: draft.type == QuizQuestionType.shortAnswer ? 'keywords' : 'exact',
      explanation: draft.explanation,
      points: draft.points,
      grading: null,
    );

    final updatedQuestions = [...quiz.questions];
    if (index == null) {
      updatedQuestions.add(question);
    } else {
      updatedQuestions[index] = question;
    }

    try {
      await ref.read(subjectQuizzesControllerProvider(subjectId).notifier).upsertQuiz(
            quiz.copyWith(
              questions: updatedQuestions,
              updatedAt: DateTime.now(),
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(index == null ? 'Question added.' : 'Question updated.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save question: $error')),
        );
      }
    }
  }

  Future<void> _deleteQuestion(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete question?'),
        content: const Text('This removes the question from the quiz immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

    final updatedQuestions = [...quiz.questions]..removeAt(index);
    try {
      await ref.read(subjectQuizzesControllerProvider(subjectId).notifier).upsertQuiz(
            quiz.copyWith(
              questions: updatedQuestions,
              updatedAt: DateTime.now(),
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete question: $error')),
        );
      }
    }
  }

  Future<void> _handleExportAction(
    BuildContext context,
    WidgetRef ref,
    _QuizExportAction action,
  ) async {
    try {
      final portability = ref.read(contentPortabilityServiceProvider);
      final exportFiles = ref.read(exportFileServiceProvider);

      switch (action) {
        case _QuizExportAction.quizJson:
          final json = await portability.exportQuizJson(quiz: quiz);
          final path = await exportFiles.saveJson(
            fileName: '${quiz.name}_quiz_export',
            json: json,
          );
          if (!context.mounted || path == null) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Quiz exported to $path')),
          );
          return;
        case _QuizExportAction.latestAttemptJson:
          final attempt = await portability.latestAttemptForQuiz(quiz.id);
          if (!context.mounted) {
            return;
          }
          if (attempt == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No quiz attempt has been recorded yet.'),
              ),
            );
            return;
          }
          final json = await portability.exportQuizAttemptJson(attempt: attempt);
          final path = await exportFiles.saveJson(
            fileName: '${quiz.name}_latest_attempt',
            json: json,
          );
          if (!context.mounted || path == null) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Latest attempt exported to $path')),
          );
          return;
        case _QuizExportAction.aiReviewPackage:
          final attempt = await portability.latestAttemptForQuiz(quiz.id);
          if (!context.mounted) {
            return;
          }
          if (attempt == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Complete the quiz once to export an AI review package.'),
              ),
            );
            return;
          }
          final json = await portability.exportQuizAttemptAiPackageJson(
            attempt: attempt,
          );
          final path = await exportFiles.saveJson(
            fileName: '${quiz.name}_ai_review_package',
            json: json,
          );
          if (!context.mounted || path == null) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI review package exported to $path')),
          );
          return;
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export quiz data: $error')),
      );
    }
  }
}

enum _QuizExportAction {
  quizJson,
  latestAttemptJson,
  aiReviewPackage,
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final QuizQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final requiredKeywords = question.keywordRules.isNotEmpty
        ? question.keywordRules
            .where((rule) => rule.required)
            .map((rule) => rule.term)
            .toList()
        : question.keywords;
    final supportingKeywords = question.keywordRules
        .where((rule) => !rule.required)
        .map((rule) => rule.term)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1} • ${_typeLabel(question.type)} • ${question.points.toStringAsFixed(1)} pts',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      MarkdownContent(
                        data: question.question,
                        baseTextStyle: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    }
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit question'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete question'),
                    ),
                  ],
                ),
              ],
            ),
            if (question.type == QuizQuestionType.mcq &&
                question.options.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (var optionIndex = 0;
                  optionIndex < question.options.length;
                  optionIndex += 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${optionIndex + 1}. '),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            fontWeight: optionIndex == question.correctIndex
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          child: MarkdownContent(
                            data: question.options[optionIndex],
                            baseTextStyle: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (question.type == QuizQuestionType.trueFalse) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Correct answer: ${question.correctAnswer == true ? 'True' : 'False'}'),
            ],
            if (question.type == QuizQuestionType.fillBlank &&
                question.correctAnswers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Accepted answers: ${question.correctAnswers.join(', ')}'),
            ],
            if (question.type == QuizQuestionType.shortAnswer) ...[
              if (requiredKeywords.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Required: ${requiredKeywords.join(', ')}',
                ),
                if (supportingKeywords.isNotEmpty)
                  Text(
                    'Supporting: ${supportingKeywords.join(', ')}',
                  ),
                if (question.minimumKeywordScorePercent != null)
                  Text(
                    'Pass threshold: ${(question.minimumKeywordScorePercent! * 100).toStringAsFixed(0)}%',
                  ),
                if (question.minimumKeywordMatches != null)
                  Text(
                    'Minimum matches: ${question.minimumKeywordMatches}',
                  ),
                Text(
                  question.allowPartialCredit
                      ? 'Scoring: partial credit enabled'
                      : 'Scoring: full credit only',
                ),
              ],
              if (question.modelAnswer.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                MarkdownContent(
                  data: '**Model answer**\n\n${question.modelAnswer}',
                  baseTextStyle: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              MarkdownContent(
                data: question.explanation,
                baseTextStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(QuizQuestionType type) {
    return switch (type) {
      QuizQuestionType.mcq => 'MCQ',
      QuizQuestionType.trueFalse => 'True/False',
      QuizQuestionType.fillBlank => 'Fill Blank',
      QuizQuestionType.shortAnswer => 'Q&A',
    };
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(label),
    );
  }
}
