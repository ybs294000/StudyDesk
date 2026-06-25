import 'package:flutter/material.dart';

import '../../../../theme/app_spacing.dart';
import '../../domain/quiz_models.dart';

class QuizCard extends StatelessWidget {
  const QuizCard({
    required this.quiz,
    required this.unitName,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final QuizRecord quiz;
  final String? unitName;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final timerLabel = switch (quiz.settings.timerMode) {
      'per_quiz' => '${quiz.settings.timerSeconds ~/ 60} min total',
      'per_question' => '${quiz.settings.timerSeconds ~/ 60} min each',
      _ => 'Untimed',
    };
    final marking = quiz.settings.marking;

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
                        quiz.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        quiz.description.isEmpty
                            ? 'No description provided.'
                            : quiz.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete quiz'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _Badge(label: '${quiz.questions.length} questions'),
                _Badge(label: timerLabel),
                _Badge(
                  label:
                      '${marking.correctPoints.toStringAsFixed(0)}/${marking.wrongPoints.toStringAsFixed(0)} scoring',
                ),
                if (unitName != null) _Badge(label: unitName!),
                for (final tag in quiz.tags.take(3)) _Badge(label: '#$tag'),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onOpen,
                    child: const Text('Open Quiz'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
