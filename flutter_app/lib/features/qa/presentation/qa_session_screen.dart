import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/profile_settings_controller.dart';
import '../../../core/widgets/markdown_content.dart';
import '../../../theme/app_spacing.dart';
import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../gamification/application/gamification_summary_provider.dart';
import '../../study/data/study_sessions_repository.dart';
import '../../study/domain/study_session_record.dart';
import '../application/qa_review_scheduler_service.dart';
import '../application/subject_qa_controller.dart';
import '../data/qa_review_repository.dart';
import '../domain/qa_item_record.dart';
import '../domain/qa_review_record.dart';

class QaSessionScreen extends ConsumerStatefulWidget {
  const QaSessionScreen({
    required this.subjectId,
    required this.promptId,
    super.key,
  });

  final String subjectId;
  final String promptId;

  @override
  ConsumerState<QaSessionScreen> createState() => _QaSessionScreenState();
}

class _QaSessionScreenState extends ConsumerState<QaSessionScreen> {
  final TextEditingController _answerController = TextEditingController();
  final QaReviewSchedulerService _scheduler = const QaReviewSchedulerService();
  DateTime? _startedAt;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(subjectQaControllerProvider(widget.subjectId));
    final settings = ref.watch(profileSettingsControllerProvider);

    return itemsAsync.when(
      data: (items) {
        QaItemRecord? selectedItem;
        for (final candidate in items) {
          if (candidate.id == widget.promptId) {
            selectedItem = candidate;
            break;
          }
        }
        if (selectedItem == null) {
          return _MissingQaPrompt(subjectId: widget.subjectId);
        }
        final item = selectedItem;
        return FutureBuilder<QaReviewRecord?>(
          future: ref.read(qaReviewRepositoryProvider).loadReview(widget.promptId),
          builder: (context, snapshot) {
            final review = snapshot.data ??
                QaReviewRecord.initial(
                  promptId: item.id,
                  subjectId: item.subjectId,
                  unitId: item.unitId,
                );
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ListView(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q&A Recall',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.micro),
                            Text(
                              review.dueAt == null
                                  ? 'Ready to practice now'
                                  : review.isDue
                                      ? 'Due now'
                                      : 'Due on ${review.dueAt!.day}/${review.dueAt!.month}/${review.dueAt!.year}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.question,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Recall the answer first. You can write a rough response for yourself, then reveal the model answer and mark how well you remembered it.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _answerController,
                            minLines: 5,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Your recalled answer',
                              alignLabelWithHint: true,
                              hintText: 'Optional: write what you remembered before revealing the model answer.',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (!_revealed)
                            FilledButton.icon(
                              onPressed: () => setState(() => _revealed = true),
                              icon: const Icon(Icons.visibility_rounded),
                              label: const Text('Reveal Model Answer'),
                            )
                          else ...[
                            Text(
                              'Model answer',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            MarkdownContent(
                              data: item.answerMarkdown,
                              selectable: true,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (item.tags.isNotEmpty)
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  for (final tag in item.tags) Chip(label: Text('#$tag')),
                                ],
                              ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'How well did you recall it?',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final rating in QaRecallRating.values)
                                  FilledButton.tonal(
                                    onPressed: () => _completeSession(
                                      item: item,
                                      review: review,
                                      rating: rating,
                                      schedulingEnabled: settings.qaSpacedRepetitionEnabled,
                                    ),
                                    child: Text(rating.label),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Could not load Q&A prompt: $error')),
    );
  }

  Future<void> _completeSession({
    required QaItemRecord item,
    required QaReviewRecord review,
    required QaRecallRating rating,
    required bool schedulingEnabled,
  }) async {
    final now = DateTime.now();
    final updatedReview = schedulingEnabled
        ? _scheduler.applyRating(
            review: review.copyWith(subjectId: item.subjectId, unitId: item.unitId),
            rating: rating,
            reviewedAt: now,
            answerSnippet: _answerController.text,
          )
        : review.copyWith(
            subjectId: item.subjectId,
            unitId: item.unitId,
            reviewCount: review.reviewCount + 1,
            lastReviewedAt: now,
            lastRating: rating,
            lastAnswerSnippet: _answerController.text.trim().isEmpty ? null : _answerController.text.trim(),
            dueAt: null,
            updatedAt: now,
          );
    await ref.read(qaReviewRepositoryProvider).upsertReview(updatedReview);
    await ref.read(studySessionsRepositoryProvider).addSession(
          StudySessionRecord(
            id: now.microsecondsSinceEpoch.toString(),
            subjectId: item.subjectId,
            deckId: null,
            sessionType: 'qa',
            startedAt: _startedAt ?? now,
            endedAt: now,
            reviewedCount: 1,
            completedCount: rating == QaRecallRating.full
                ? 1
                : rating == QaRecallRating.partial
                    ? 1
                    : 0,
            againCount: rating == QaRecallRating.couldNotRecall ? 1 : 0,
            dueCount: 1,
          ),
        );
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(gamificationSummaryProvider);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          schedulingEnabled && updatedReview.dueAt != null
              ? 'Q&A session saved. Next review scheduled.'
              : 'Q&A session saved.',
        ),
      ),
    );
    _goBack();
  }

  void _goBack() {
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/subjects/${widget.subjectId}/qa');
  }
}

class _MissingQaPrompt extends StatelessWidget {
  const _MissingQaPrompt({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.record_voice_over_outlined, size: 52),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Q&A prompt not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: () => context.go('/subjects/$subjectId/qa'),
              child: const Text('Back to Q&A Bank'),
            ),
          ],
        ),
      ),
    );
  }
}
