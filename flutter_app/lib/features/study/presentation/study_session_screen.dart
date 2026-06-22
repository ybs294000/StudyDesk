import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../core/widgets/markdown_content.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../cards/domain/card_record.dart';
import '../application/study_session_controller.dart';
import '../domain/study_rating.dart';

class StudySessionScreen extends ConsumerWidget {
  const StudySessionScreen({
    required this.deckId,
    required this.deckName,
    super.key,
  });

  final String deckId;
  final String deckName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studySessionControllerProvider(deckId));

    return session.when(
      data: (state) {
        if (state.isComplete) {
          return _SessionCompleteView(
            deckName: deckName,
            originalCount: state.originalCount,
            reviewedCount: state.reviewedCount,
            againCount: state.againCount,
          );
        }
        final card = state.currentCard;
        if (card == null) {
          return const Center(child: Text('No cards available.'));
        }
        return _ActiveStudyView(
          deckId: deckId,
          deckName: deckName,
          state: state,
          card: card,
        );
      },
      error: (error, stackTrace) =>
          Center(child: Text('Failed to start study session: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ActiveStudyView extends ConsumerWidget {
  const _ActiveStudyView({
    required this.deckId,
    required this.deckName,
    required this.state,
    required this.card,
  });

  final String deckId;
  final String deckName;
  final StudySessionState state;
  final CardRecord card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduler = ref.watch(spacedRepetitionServiceProvider);
    final hintTextColor = AppColors.onColor(AppColors.primarySoft);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deckName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const _SessionTimerChip(),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: state.progress),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${state.completedCount}/${state.originalCount} completed',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isShowingAnswer ? 'Back' : 'Front',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: SingleChildScrollView(
                        child: MarkdownContent(
                          data: state.isShowingAnswer ? card.back : card.front,
                          selectable: true,
                          baseTextStyle:
                              Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    if (!state.isShowingAnswer && card.hint.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: hintTextColor,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: MarkdownContent(
                                data: card.hint,
                                baseTextStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: hintTextColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (!state.isShowingAnswer)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(studySessionControllerProvider(deckId).notifier)
                                  .revealAnswer();
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not reveal answer: $error'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Show Answer'),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How well did you recall it?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              _RatingButton(
                                label: 'Again',
                                subtitle: scheduler.previewIntervalLabel(
                                  card,
                                  StudyRating.again,
                                ),
                                color: AppColors.error,
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(
                                          studySessionControllerProvider(deckId)
                                              .notifier,
                                        )
                                        .rateCurrent(StudyRating.again);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not save rating: $error'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              _RatingButton(
                                label: 'Hard',
                                subtitle: scheduler.previewIntervalLabel(
                                  card,
                                  StudyRating.hard,
                                ),
                                color: AppColors.warning,
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(
                                          studySessionControllerProvider(deckId)
                                              .notifier,
                                        )
                                        .rateCurrent(StudyRating.hard);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not save rating: $error'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              _RatingButton(
                                label: 'Good',
                                subtitle: scheduler.previewIntervalLabel(
                                  card,
                                  StudyRating.good,
                                ),
                                color: AppColors.primary,
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(
                                          studySessionControllerProvider(deckId)
                                              .notifier,
                                        )
                                        .rateCurrent(StudyRating.good);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not save rating: $error'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              _RatingButton(
                                label: 'Easy',
                                subtitle: scheduler.previewIntervalLabel(
                                  card,
                                  StudyRating.easy,
                                ),
                                color: AppColors.success,
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(
                                          studySessionControllerProvider(deckId)
                                              .notifier,
                                        )
                                        .rateCurrent(StudyRating.easy);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not save rating: $error'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _SessionTimerChip extends StatefulWidget {
  const _SessionTimerChip();

  @override
  State<_SessionTimerChip> createState() => _SessionTimerChipState();
}

class _SessionTimerChipState extends State<_SessionTimerChip> {
  late final Stopwatch _stopwatch;
  late final Timer _ticker;
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier<int>(0);
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stopwatch.isRunning) {
        _elapsedSeconds.value = _stopwatch.elapsed.inSeconds;
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _stopwatch.stop();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 18),
          const SizedBox(width: AppSpacing.xs),
          ValueListenableBuilder<int>(
            valueListenable: _elapsedSeconds,
            builder: (context, value, child) {
              return Text(
                _formatSeconds(value),
                style: Theme.of(context).textTheme.labelLarge,
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: _isRunning ? 'Pause timer' : 'Resume timer',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            onPressed: () {
              setState(() {
                if (_isRunning) {
                  _stopwatch.stop();
                } else {
                  _stopwatch.start();
                }
                _isRunning = !_isRunning;
              });
            },
            icon: Icon(
              _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 18,
            ),
          ),
          IconButton(
            tooltip: 'Reset timer',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            onPressed: () {
              _stopwatch
                ..reset()
                ..start();
              _elapsedSeconds.value = 0;
              if (!_isRunning) {
                setState(() {
                  _isRunning = true;
                });
              }
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = AppColors.onColor(color);
    final subtitleColor = AppColors.onColorMuted(color);

    return SizedBox(
      width: 120,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
        ),
        child: Column(
          children: [
            Text(label),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCompleteView extends StatelessWidget {
  const _SessionCompleteView({
    required this.deckName,
    required this.originalCount,
    required this.reviewedCount,
    required this.againCount,
  });

  final String deckName;
  final int originalCount;
  final int reviewedCount;
  final int againCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Session Complete',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  deckName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Cards queued: $originalCount'),
                Text('Review actions: $reviewedCount'),
                Text('Again ratings: $againCount'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
