import 'dart:async';

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
import '../application/note_markdown_utils.dart';
import '../application/subject_notes_controller.dart';
import '../data/note_review_repository.dart';
import '../domain/note_record.dart';
import '../domain/note_review_record.dart';

class NoteReadingScreen extends ConsumerStatefulWidget {
  const NoteReadingScreen({
    required this.subjectId,
    required this.noteId,
    super.key,
  });

  final String subjectId;
  final String noteId;

  @override
  ConsumerState<NoteReadingScreen> createState() => _NoteReadingScreenState();
}

class _NoteReadingScreenState extends ConsumerState<NoteReadingScreen> {
  Timer? _ticker;
  DateTime? _sessionStartedAt;
  NoteReviewRecord? _review;
  bool _loadedReview = false;
  bool _sectionRecallMode = false;
  int _currentSectionIndex = 0;
  bool _sectionRevealed = false;
  final Map<String, String> _draftAnnotations = <String, String>{};
  late final TextEditingController _annotationController;
  late final Future<NoteReviewRecord?> _reviewFuture;
  bool _sessionHadPendingPrompt = false;

  @override
  void initState() {
    super.initState();
    _annotationController = TextEditingController();
    _reviewFuture = ref.read(noteReviewRepositoryProvider).loadReview(widget.noteId);
    _sessionStartedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _annotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(subjectNotesControllerProvider(widget.subjectId));
    final settings = ref.watch(profileSettingsControllerProvider);

    return notesAsync.when(
      data: (notes) {
        NoteRecord? note;
        for (final item in notes) {
          if (item.id == widget.noteId) {
            note = item;
            break;
          }
        }
        if (note == null) {
          return _MissingReadingNote(subjectId: widget.subjectId);
        }
        final resolvedNote = note;
        return FutureBuilder<NoteReviewRecord?>(
          future: _reviewFuture,
          builder: (context, snapshot) {
            if (!_loadedReview && snapshot.connectionState == ConnectionState.done) {
              final loaded = snapshot.data ??
                  NoteReviewRecord.initial(
                    noteId: resolvedNote.id,
                    subjectId: resolvedNote.subjectId,
                    unitId: resolvedNote.unitId,
                  );
              _review = loaded;
              _draftAnnotations
                ..clear()
                ..addAll(loaded.sectionAnnotations);
              _sessionHadPendingPrompt =
                  (loaded.pendingSelfNote?.trim().isNotEmpty ?? false);
              _loadedReview = true;
            }

            if (!_loadedReview || _review == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final review = _review!;
            final sections = extractSections(resolvedNote.bodyMarkdown);
            final sectionRecallAvailable = sections.isNotEmpty;
            final safeSectionIndex = sectionRecallAvailable
                ? _currentSectionIndex.clamp(0, sections.length - 1)
                : 0;
            final currentSection = sectionRecallAvailable
                ? sections[safeSectionIndex]
                : null;
            if (currentSection != null &&
                _annotationController.text !=
                    (_draftAnnotations[currentSection.heading] ?? '')) {
              _annotationController.text =
                  _draftAnnotations[currentSection.heading] ?? '';
            }

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadingTopBar(
                    note: resolvedNote,
                    elapsed: _elapsed,
                    dueAt: review.dueAt,
                    sectionRecallAvailable: sectionRecallAvailable,
                    sectionRecallMode: _sectionRecallMode,
                    onToggleSectionRecall: sectionRecallAvailable
                        ? (value) {
                            setState(() {
                              _sectionRecallMode = value;
                              _currentSectionIndex = 0;
                              _sectionRevealed = false;
                            });
                          }
                        : null,
                    onBack: _goBack,
                    onOpenEditor: () => context.push(
                      '/subjects/${widget.subjectId}/notes/${widget.noteId}',
                    ),
                    onFinish: () => _finishSession(
                      note: resolvedNote,
                      review: review,
                      sectionCount: sections.length,
                      settings: settings,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (review.pendingSelfNote?.trim().isNotEmpty ?? false) ...[
                    _PendingPromptBanner(message: review.pendingSelfNote!.trim()),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Expanded(
                    child: _sectionRecallMode && currentSection != null
                        ? _SectionRecallPane(
                            section: currentSection,
                            sectionIndex: _currentSectionIndex,
                            totalSections: sections.length,
                            revealed: _sectionRevealed,
                            annotationController: _annotationController,
                            existingAnnotation:
                                _draftAnnotations[currentSection.heading],
                            onReveal: () {
                              setState(() => _sectionRevealed = true);
                            },
                            onPrevious: _currentSectionIndex > 0
                                ? () {
                                    _persistCurrentAnnotation(currentSection.heading);
                                    setState(() {
                                      _currentSectionIndex -= 1;
                                      _sectionRevealed = false;
                                    });
                                  }
                                : null,
                            onNext: _currentSectionIndex < sections.length - 1
                                ? () {
                                    _persistCurrentAnnotation(currentSection.heading);
                                    setState(() {
                                      _currentSectionIndex += 1;
                                      _sectionRevealed = false;
                                    });
                                  }
                                : null,
                            onAnnotationChanged: (value) {
                              _draftAnnotations[currentSection.heading] = value.trim();
                            },
                          )
                        : _ReadingPane(markdown: resolvedNote.bodyMarkdown),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Could not load note: $error'),
      ),
    );
  }

  Duration get _elapsed {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(startedAt);
  }

  void _persistCurrentAnnotation(String heading) {
    final value = _annotationController.text.trim();
    if (value.isEmpty) {
      _draftAnnotations.remove(heading);
      return;
    }
    _draftAnnotations[heading] = value;
  }

  Future<void> _finishSession({
    required NoteRecord note,
    required NoteReviewRecord review,
    required int sectionCount,
    required ProfileSettingsState settings,
  }) async {
    if (_sectionRecallMode) {
      final sections = extractSections(note.bodyMarkdown);
      if (sections.isNotEmpty) {
        _persistCurrentAnnotation(sections[_currentSectionIndex].heading);
      }
    }

    final outcome = await showModalBottomSheet<_NoteSessionOutcome>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FinishReadingSheet(
        defaultSchedulingEnabled: settings.noteSpacedRepetitionEnabled,
        initialSuggestedDays:
            (review.lastRating ?? NoteRecallRating.partial).suggestedDays,
      ),
    );
    if (outcome == null || !mounted) {
      return;
    }

    final now = DateTime.now();
    final archived = <NoteArchivedPrompt>[
      ...review.archivedSelfNotes,
      if (_sessionHadPendingPrompt &&
          review.pendingSelfNote != null &&
          review.pendingSelfNoteCreatedAt != null)
        NoteArchivedPrompt(
          message: review.pendingSelfNote!,
          createdAt: review.pendingSelfNoteCreatedAt!,
          archivedAt: now,
        ),
    ];
    final dueAt = outcome.scheduleNextRead
        ? now.add(Duration(days: outcome.nextReviewDays))
        : null;
    final updatedReview = review.copyWith(
      subjectId: note.subjectId,
      unitId: note.unitId,
      reviewCount: review.reviewCount + 1,
      lastReadAt: now,
      dueAt: dueAt,
      lastRating: outcome.rating,
      pendingSelfNote: outcome.noteToFuture.trim().isEmpty
          ? null
          : outcome.noteToFuture.trim(),
      pendingSelfNoteCreatedAt: outcome.noteToFuture.trim().isEmpty ? null : now,
      archivedSelfNotes: archived.take(20).toList(),
      sectionAnnotations: Map<String, String>.from(_draftAnnotations)
        ..removeWhere((key, value) => value.trim().isEmpty),
      updatedAt: now,
    );

    await ref.read(noteReviewRepositoryProvider).upsertReview(updatedReview);
    final effectiveReviewCount = _sectionRecallMode
        ? sectionCount.clamp(1, 9999)
        : 1;
    final effectiveCompletedCount = outcome.rating == NoteRecallRating.full
        ? effectiveReviewCount
        : outcome.rating == NoteRecallRating.partial
            ? (_sectionRecallMode
                ? (sectionCount / 2).ceil().clamp(1, 9999)
                : 1)
            : 0;
    await ref.read(studySessionsRepositoryProvider).addSession(
          StudySessionRecord(
            id: now.microsecondsSinceEpoch.toString(),
            subjectId: note.subjectId,
            deckId: null,
            sessionType: 'note',
            startedAt: _sessionStartedAt ?? now,
            endedAt: now,
            reviewedCount: effectiveReviewCount,
            completedCount: effectiveCompletedCount,
            againCount: outcome.rating == NoteRecallRating.needsReread ? 1 : 0,
            dueCount: effectiveReviewCount,
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
          outcome.scheduleNextRead
              ? 'Reading session saved. Next review scheduled in ${outcome.nextReviewDays} day${outcome.nextReviewDays == 1 ? '' : 's'}.'
              : 'Reading session saved.',
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
    context.go('/subjects/${widget.subjectId}/notes?noteId=${widget.noteId}');
  }
}

class _ReadingTopBar extends StatelessWidget {
  const _ReadingTopBar({
    required this.note,
    required this.elapsed,
    required this.dueAt,
    required this.sectionRecallAvailable,
    required this.sectionRecallMode,
    required this.onToggleSectionRecall,
    required this.onBack,
    required this.onOpenEditor,
    required this.onFinish,
  });

  final NoteRecord note;
  final Duration elapsed;
  final DateTime? dueAt;
  final bool sectionRecallAvailable;
  final bool sectionRecallMode;
  final ValueChanged<bool>? onToggleSectionRecall;
  final VoidCallback onBack;
  final VoidCallback onOpenEditor;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final dueLabel = dueAt == null
        ? 'Manual review'
        : 'Due ${_formatRelativeDue(dueAt!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'Back to notes',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$dueLabel • ${_formatElapsed(elapsed)} elapsed',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenEditor,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Edit'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Finish'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (sectionRecallAvailable)
              FilterChip(
                selected: sectionRecallMode,
                onSelected: onToggleSectionRecall,
                label: const Text('Section Recall Mode'),
              ),
            for (final tag in note.tags.take(6))
              Chip(label: Text('#$tag')),
          ],
        ),
      ],
    );
  }
}

class _PendingPromptBanner extends StatelessWidget {
  const _PendingPromptBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Carry-forward note',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReadingPane extends StatelessWidget {
  const _ReadingPane({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: MarkdownContent(
            data: markdown,
            selectable: true,
            enableWikiLinks: true,
          ),
        ),
      ),
    );
  }
}

class _SectionRecallPane extends StatelessWidget {
  const _SectionRecallPane({
    required this.section,
    required this.sectionIndex,
    required this.totalSections,
    required this.revealed,
    required this.annotationController,
    required this.existingAnnotation,
    required this.onReveal,
    required this.onPrevious,
    required this.onNext,
    required this.onAnnotationChanged,
  });

  final NoteSection section;
  final int sectionIndex;
  final int totalSections;
  final bool revealed;
  final TextEditingController annotationController;
  final String? existingAnnotation;
  final VoidCallback onReveal;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<String> onAnnotationChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Section ${sectionIndex + 1} of $totalSections',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              section.heading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              revealed
                  ? 'Read the revealed section, then leave a short memory note if this part usually trips you up.'
                  : 'Pause and recall this section before revealing it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!revealed)
              FilledButton.icon(
                onPressed: onReveal,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Reveal Section'),
              )
            else ...[
              Expanded(
                child: SingleChildScrollView(
                  child: MarkdownContent(
                    data: section.bodyMarkdown,
                    selectable: true,
                    enableWikiLinks: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: annotationController,
                minLines: 2,
                maxLines: 4,
                onChanged: onAnnotationChanged,
                decoration: InputDecoration(
                  labelText: 'Section note',
                  hintText: existingAnnotation?.trim().isNotEmpty ?? false
                      ? existingAnnotation
                      : 'Example: revisit the derivation and compare it with the previous section.',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Previous'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    sectionIndex == totalSections - 1 ? 'Last Section' : 'Next',
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

class _FinishReadingSheet extends StatefulWidget {
  const _FinishReadingSheet({
    required this.defaultSchedulingEnabled,
    required this.initialSuggestedDays,
  });

  final bool defaultSchedulingEnabled;
  final int initialSuggestedDays;

  @override
  State<_FinishReadingSheet> createState() => _FinishReadingSheetState();
}

class _FinishReadingSheetState extends State<_FinishReadingSheet> {
  NoteRecallRating _rating = NoteRecallRating.partial;
  bool _scheduleNextRead = true;
  int _nextReviewDays = 3;
  final TextEditingController _futureNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scheduleNextRead = widget.defaultSchedulingEnabled;
    _nextReviewDays = widget.initialSuggestedDays;
  }

  @override
  void dispose() {
    _futureNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finish Reading Session',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'How well did you recall this note?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final option in NoteRecallRating.values)
                    ChoiceChip(
                      selected: _rating == option,
                      label: Text(option.label),
                      onSelected: (_) {
                        setState(() {
                          _rating = option;
                          _nextReviewDays = option.suggestedDays;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _futureNoteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note to future you',
                  hintText: 'Example: revisit the comparison table before the next exam revision.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _scheduleNextRead,
                onChanged: (value) {
                  setState(() => _scheduleNextRead = value);
                },
                title: const Text('Schedule the next read'),
                subtitle: const Text(
                  'Keep this note in the study queue so it can resurface automatically.',
                ),
              ),
              if (_scheduleNextRead) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Next review',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _ReviewDayChip(
                      selected: _nextReviewDays == 1,
                      label: 'Tomorrow',
                      onTap: () => setState(() => _nextReviewDays = 1),
                    ),
                    _ReviewDayChip(
                      selected: _nextReviewDays == 3,
                      label: '3 Days',
                      onTap: () => setState(() => _nextReviewDays = 3),
                    ),
                    _ReviewDayChip(
                      selected: _nextReviewDays == 7,
                      label: '1 Week',
                      onTap: () => setState(() => _nextReviewDays = 7),
                    ),
                    _ReviewDayChip(
                      selected: _nextReviewDays == 14,
                      label: '2 Weeks',
                      onTap: () => setState(() => _nextReviewDays = 14),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _NoteSessionOutcome(
                          rating: _rating,
                          scheduleNextRead: _scheduleNextRead,
                          nextReviewDays: _nextReviewDays,
                          noteToFuture: _futureNoteController.text,
                        ),
                      );
                    },
                    child: const Text('Save Session'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewDayChip extends StatelessWidget {
  const _ReviewDayChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
    );
  }
}

class _MissingReadingNote extends StatelessWidget {
  const _MissingReadingNote({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 52),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Note not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This reading session could not be opened because the note no longer exists locally.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go('/subjects/$subjectId/notes'),
              child: const Text('Back to Notes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteSessionOutcome {
  const _NoteSessionOutcome({
    required this.rating,
    required this.scheduleNextRead,
    required this.nextReviewDays,
    required this.noteToFuture,
  });

  final NoteRecallRating rating;
  final bool scheduleNextRead;
  final int nextReviewDays;
  final String noteToFuture;
}

String _formatElapsed(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String _formatRelativeDue(DateTime dueAt) {
  final today = DateTime.now();
  final dateOnlyNow = DateTime(today.year, today.month, today.day);
  final dateOnlyDue = DateTime(dueAt.year, dueAt.month, dueAt.day);
  final diff = dateOnlyDue.difference(dateOnlyNow).inDays;
  if (diff < 0) {
    return '${diff.abs()} day${diff.abs() == 1 ? '' : 's'} ago';
  }
  if (diff == 0) {
    return 'today';
  }
  if (diff == 1) {
    return 'tomorrow';
  }
  return 'in $diff days';
}
