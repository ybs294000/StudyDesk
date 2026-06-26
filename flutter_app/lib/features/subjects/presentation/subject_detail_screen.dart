import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/profile_settings_controller.dart';
import '../../../core/widgets/json_drop_zone.dart';
import '../../../services/content_portability_service.dart';
import '../../../services/export_file_service.dart';
import '../../../services/library_backup_service.dart';
import '../../../core/security/studydesk_security.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../decks/application/subject_decks_controller.dart';
import '../../decks/domain/deck_record.dart';
import '../../decks/presentation/widgets/deck_card.dart';
import '../../decks/presentation/widgets/deck_editor_sheet.dart';
import '../../notes/application/subject_notes_controller.dart';
import '../../notes/domain/note_record.dart';
import '../../qa/application/subject_qa_controller.dart';
import '../../qa/data/qa_review_repository.dart';
import '../../qa/domain/qa_item_record.dart';
import '../../quizzes/application/subject_quizzes_controller.dart';
import '../../quizzes/domain/quiz_models.dart';
import '../../quizzes/presentation/widgets/quiz_card.dart';
import '../../quizzes/presentation/widgets/quiz_editor_sheet.dart';
import '../../units/application/subject_units_controller.dart';
import '../../units/domain/subject_unit_record.dart';
import '../application/subjects_controller.dart';
import '../domain/subject_record.dart';

const _allUnitsFilter = '__all_units__';
const _uncategorizedUnitFilter = '__uncategorized_unit__';
const _allTagsFilter = '__all_tags__';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    required this.subjectId,
    super.key,
  });

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsControllerProvider);

    return subjects.when(
      data: (items) {
        SubjectRecord? subject;
        for (final item in items) {
          if (item.id == subjectId) {
            subject = item;
            break;
          }
        }
        if (subject == null) {
          return const _MissingSubjectView();
        }
        return _SubjectDetailContent(subject: subject);
      },
      error: (error, stackTrace) => Center(child: Text('Failed to load subject: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SubjectDetailContent extends ConsumerStatefulWidget {
  const _SubjectDetailContent({required this.subject});

  final SubjectRecord subject;

  @override
  ConsumerState<_SubjectDetailContent> createState() => _SubjectDetailContentState();
}

class _SubjectDetailContentState extends ConsumerState<_SubjectDetailContent> {
  String _selectedUnitFilter = _allUnitsFilter;
  String _selectedTagFilter = _allTagsFilter;

  SubjectRecord get subject => widget.subject;

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decks = ref.watch(subjectDecksControllerProvider(subject.id));
    final quizzes = ref.watch(subjectQuizzesControllerProvider(subject.id));
    final notes = ref.watch(subjectNotesControllerProvider(subject.id));
    final qaItems = ref.watch(subjectQaControllerProvider(subject.id));
    final units = ref.watch(subjectUnitsControllerProvider(subject.id));

    return units.when(
      data: (unitItems) => decks.when(
        data: (deckItems) => quizzes.when(
          data: (quizItems) => notes.when(
            data: (noteItems) => qaItems.when(
            data: (qaPromptItems) {
              final unitFilteredDecks = _filterByUnit(deckItems, (deck) => deck.unitId);
              final unitFilteredQuizzes = _filterByUnit(quizItems, (quiz) => quiz.unitId);
              final unitFilteredNotes = _filterByUnit(noteItems, (note) => note.unitId);
              final unitFilteredQa = _filterByUnit(qaPromptItems, (item) => item.unitId);
              final availableTags = _collectTags(
                decks: unitFilteredDecks,
                quizzes: unitFilteredQuizzes,
                notes: unitFilteredNotes,
                qaItems: unitFilteredQa,
              );
              _ensureSelectedTagStillAvailable(availableTags);
              final filteredDecks = _filterByTag(
                unitFilteredDecks,
                (deck) => deck.tags,
              );
              final filteredQuizzes = _filterByTag(
                unitFilteredQuizzes,
                (quiz) => quiz.tags,
              );
              final filteredNotes = _filterByTag(
                unitFilteredNotes,
                (note) => note.tags,
              );
              final filteredQa = _filterByTag(
                unitFilteredQa,
                (item) => item.tags,
              );
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SubjectHero(
                        subject: subject,
                        deckCount: filteredDecks.length,
                        quizCount: filteredQuizzes.length,
                        noteCount: filteredNotes.length,
                        qaCount: filteredQa.length,
                        activeScopeLabel: _scopeLabel(unitItems),
                        onCreateDeck: () => _openCreateDeck(context, unitItems),
                        onImportJson: _pickAndImportJson,
                        onImportDroppedJson: _importDroppedJson,
                        onImportSample: _openSampleImporter,
                        onOpenNotes: () => context.push('/subjects/${subject.id}/notes'),
                        onCreateNote: _createQuickNote,
                        onOpenQaBank: () => context.push('/subjects/${subject.id}/qa'),
                        onOpenAiWorkspace: () => context.push('/subjects/${subject.id}/ai'),
                        onExportBundle: _exportSubjectBundle,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _UnitFilterCard(
                        units: unitItems,
                        selectedFilter: _selectedUnitFilter,
                        onChanged: (value) => setState(() {
                          _selectedUnitFilter = value;
                          _selectedTagFilter = _allTagsFilter;
                        }),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _TagFilterCard(
                        tags: availableTags,
                        selectedFilter: _selectedTagFilter,
                        onChanged: (value) => setState(() => _selectedTagFilter = value),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Units',
                        actionLabel: 'Add Unit',
                        onAction: () => _openCreateUnit(context),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _UnitsOverviewCard(
                        units: unitItems,
                        deckCountByUnit: _countByUnit(deckItems, (deck) => deck.unitId),
                        quizCountByUnit: _countByUnit(quizItems, (quiz) => quiz.unitId),
                        noteCountByUnit: _countByUnit(noteItems, (note) => note.unitId),
                        qaCountByUnit: _countByUnit(qaPromptItems, (item) => item.unitId),
                        onSelectUnit: (unitId) =>
                            setState(() => _selectedUnitFilter = unitId),
                        onEditUnit: (unit) => _openEditUnit(context, unit),
                        onDeleteUnit: (unit) => _confirmDeleteUnit(
                          context,
                          unit,
                          deckItems: deckItems,
                          quizItems: quizItems,
                          noteItems: noteItems,
                          qaItems: qaPromptItems,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Notes',
                        actionLabel: 'Open Notes',
                        onAction: () => context.push('/subjects/${subject.id}/notes'),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _NotesOverviewCard(
                        notes: filteredNotes,
                        activeScopeLabel: _scopeLabel(unitItems),
                        onOpenWorkspace: () => context.push('/subjects/${subject.id}/notes'),
                        onCreateNote: _createQuickNote,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Q&A Bank',
                        actionLabel: 'Open Q&A',
                        onAction: () => context.push('/subjects/${subject.id}/qa'),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _QaOverviewCard(
                        items: filteredQa,
                        activeScopeLabel: _scopeLabel(unitItems),
                        onOpenWorkspace: () => context.push('/subjects/${subject.id}/qa'),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Decks',
                        actionLabel: 'Add Deck',
                        onAction: () => _openCreateDeck(context, unitItems),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    sliver: filteredDecks.isEmpty
                        ? SliverToBoxAdapter(
                            child: _EmptyDecksState(
                              subject: subject,
                              activeScopeLabel: _scopeLabel(unitItems),
                              onCreateDeck: () => _openCreateDeck(context, unitItems),
                            ),
                          )
                        : SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: MediaQuery.sizeOf(context).width > 980 ? 2 : 1,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisExtent: 220,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final deck = filteredDecks[index];
                                return DeckCard(
                                  deck: deck,
                                  unitName: _unitName(unitItems, deck.unitId),
                                  onOpen: () => context.push(
                                    '/subjects/${subject.id}/decks/${deck.id}',
                                  ),
                                  onEdit: () => _openEditDeck(context, deck, unitItems),
                                  onDelete: () => _confirmDeleteDeck(context, deck),
                                );
                              },
                              childCount: filteredDecks.length,
                            ),
                          ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Quizzes',
                        actionLabel: 'Add Empty Quiz',
                        onAction: () => _openCreateQuiz(context, unitItems),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    sliver: filteredQuizzes.isEmpty
                        ? SliverToBoxAdapter(
                            child: _EmptyQuizState(activeScopeLabel: _scopeLabel(unitItems)),
                          )
                        : SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: MediaQuery.sizeOf(context).width > 980 ? 2 : 1,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisExtent: 240,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final quiz = filteredQuizzes[index];
                                return QuizCard(
                                  quiz: quiz,
                                  unitName: _unitName(unitItems, quiz.unitId),
                                  onOpen: () => context.push(
                                    '/subjects/${subject.id}/quizzes/${quiz.id}',
                                  ),
                                  onDelete: () => _confirmDeleteQuiz(context, quiz),
                                );
                              },
                              childCount: filteredQuizzes.length,
                            ),
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Failed to load Q&A prompts: $error')),
          ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Failed to load notes: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Failed to load quizzes: $error')),
        ),
        error: (error, stackTrace) => Center(child: Text('Failed to load decks: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Failed to load units: $error')),
    );
  }

  List<T> _filterByUnit<T>(List<T> items, String? Function(T item) unitResolver) {
    return items.where((item) {
      final unitId = unitResolver(item);
      return switch (_selectedUnitFilter) {
        _allUnitsFilter => true,
        _uncategorizedUnitFilter => unitId == null,
        _ => unitId == _selectedUnitFilter,
      };
    }).toList();
  }

  List<T> _filterByTag<T>(List<T> items, List<String> Function(T item) tagsResolver) {
    return items.where((item) {
      if (_selectedTagFilter == _allTagsFilter) {
        return true;
      }
      return tagsResolver(item).any(
        (tag) => tag.toLowerCase() == _selectedTagFilter.toLowerCase(),
      );
    }).toList();
  }

  Map<String, int> _countByUnit<T>(
    List<T> items,
    String? Function(T item) unitResolver,
  ) {
    final counts = <String, int>{};
    for (final item in items) {
      final key = unitResolver(item) ?? _uncategorizedUnitFilter;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  String _scopeLabel(List<SubjectUnitRecord> units) {
    final tagLabel = _selectedTagFilter == _allTagsFilter
        ? null
        : '#$_selectedTagFilter';
    if (_selectedUnitFilter == _allUnitsFilter) {
      return tagLabel == null ? 'All content' : 'All content • $tagLabel';
    }
    if (_selectedUnitFilter == _uncategorizedUnitFilter) {
      return tagLabel == null ? 'Uncategorized' : 'Uncategorized • $tagLabel';
    }
    final unitLabel = _unitName(units, _selectedUnitFilter) ?? 'Selected unit';
    return tagLabel == null ? unitLabel : '$unitLabel • $tagLabel';
  }

  String? _unitName(List<SubjectUnitRecord> units, String? unitId) {
    if (unitId == null) {
      return null;
    }
    for (final unit in units) {
      if (unit.id == unitId) {
        return unit.name;
      }
    }
    return null;
  }

  String? _defaultUnitForCreate() {
    return switch (_selectedUnitFilter) {
      _allUnitsFilter || _uncategorizedUnitFilter => null,
      _ => _selectedUnitFilter,
    };
  }

  List<String> _collectTags({
    required List<DeckRecord> decks,
    required List<QuizRecord> quizzes,
    required List<NoteRecord> notes,
    required List<QaItemRecord> qaItems,
  }) {
    final tags = <String>{};
    for (final deck in decks) {
      for (final tag in deck.tags) {
        tags.add(tag);
      }
    }
    for (final quiz in quizzes) {
      for (final tag in quiz.tags) {
        tags.add(tag);
      }
    }
    for (final note in notes) {
      for (final tag in note.tags) {
        tags.add(tag);
      }
    }
    for (final item in qaItems) {
      for (final tag in item.tags) {
        tags.add(tag);
      }
    }
    final sorted = tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  void _ensureSelectedTagStillAvailable(List<String> availableTags) {
    if (_selectedTagFilter == _allTagsFilter) {
      return;
    }
    final stillExists = availableTags.any(
      (tag) => tag.toLowerCase() == _selectedTagFilter.toLowerCase(),
    );
    if (!stillExists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedTagFilter = _allTagsFilter);
        }
      });
    }
  }

  Future<void> _createQuickNote() async {
    try {
      final note = await ref
          .read(subjectNotesControllerProvider(subject.id).notifier)
          .createNote(
            subjectId: subject.id,
            unitId: _defaultUnitForCreate(),
            title: 'New Note',
            bodyMarkdown: '# New Note\n\nStart writing here.',
          );
      if (!mounted) {
        return;
      }
      context.push('/subjects/${subject.id}/notes/${note.id}');
    } catch (error) {
      _showSnackBar('Could not create note: $error');
    }
  }

  Future<void> _exportSubjectBundle() async {
    try {
      final bytes = await ref
          .read(contentPortabilityServiceProvider)
          .exportSubjectBundleZip(subjectId: subject.id);
      final savedPath = await ref.read(exportFileServiceProvider).saveZip(
            fileName: '${subject.name}_subject_bundle',
            bytes: bytes,
          );
      if (!mounted || savedPath == null) {
        return;
      }
      _showSnackBar('Subject bundle exported to $savedPath');
    } catch (error) {
      _showSnackBar('Could not export subject bundle: $error');
    }
  }

  Future<void> _openCreateUnit(BuildContext context) async {
    final draft = await showModalBottomSheet<_UnitDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _UnitEditorSheet(),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      final unit = await ref.read(subjectUnitsControllerProvider(subject.id).notifier).addUnit(
            subjectId: subject.id,
            name: draft.name,
            description: draft.description,
          );
      if (mounted) {
        setState(() => _selectedUnitFilter = unit.id);
        _showSnackBar('${unit.name} created.');
      }
    } catch (error) {
      _showSnackBar('Could not create unit: $error');
    }
  }

  Future<void> _openEditUnit(BuildContext context, SubjectUnitRecord unit) async {
    final draft = await showModalBottomSheet<_UnitDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UnitEditorSheet(initialUnit: unit),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      final updated = await ref
          .read(subjectUnitsControllerProvider(subject.id).notifier)
          .updateUnit(
            unit.copyWith(
              name: draft.name,
              description: draft.description,
            ),
          );
      if (mounted) {
        _showSnackBar('${updated.name} updated.');
      }
    } catch (error) {
      _showSnackBar('Could not update unit: $error');
    }
  }

  Future<void> _confirmDeleteUnit(
    BuildContext context,
    SubjectUnitRecord unit, {
    required List<DeckRecord> deckItems,
    required List<QuizRecord> quizItems,
    required List<NoteRecord> noteItems,
    required List<QaItemRecord> qaItems,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete unit?'),
        content: Text(
          'Delete ${unit.name}? Items in this unit will remain in the subject and move to Uncategorized.',
        ),
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
    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      for (final deck in deckItems.where((item) => item.unitId == unit.id)) {
        await ref.read(subjectDecksControllerProvider(subject.id).notifier).updateDeck(
              deck.copyWith(unitId: null),
            );
      }
      for (final quiz in quizItems.where((item) => item.unitId == unit.id)) {
        await ref.read(subjectQuizzesControllerProvider(subject.id).notifier).upsertQuiz(
              quiz.copyWith(unitId: null),
            );
      }
      for (final note in noteItems.where((item) => item.unitId == unit.id)) {
        await ref.read(subjectNotesControllerProvider(subject.id).notifier).updateNote(
              note.copyWith(unitId: null),
            );
      }
      for (final item in qaItems.where((prompt) => prompt.unitId == unit.id)) {
        await ref.read(subjectQaControllerProvider(subject.id).notifier).saveItem(
              item.copyWith(unitId: null, updatedAt: DateTime.now()),
            );
        final review = await ref.read(qaReviewRepositoryProvider).loadReview(item.id);
        if (review != null) {
          await ref.read(qaReviewRepositoryProvider).upsertReview(
                review.copyWith(
                  unitId: null,
                  updatedAt: DateTime.now(),
                ),
              );
        }
      }
      await ref.read(subjectUnitsControllerProvider(subject.id).notifier).deleteUnit(unit.id);
      if (_selectedUnitFilter == unit.id) {
        setState(() => _selectedUnitFilter = _uncategorizedUnitFilter);
      }
      if (mounted) {
        _showSnackBar('${unit.name} moved to uncategorized content.');
      }
    } catch (error) {
      _showSnackBar('Could not delete unit: $error');
    }
  }

  Future<void> _openCreateDeck(
    BuildContext context,
    List<SubjectUnitRecord> unitItems,
  ) async {
    final draft = await showModalBottomSheet<DeckDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DeckEditorSheet(
        availableUnits: unitItems,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }

    try {
      await ref.read(subjectDecksControllerProvider(subject.id).notifier).addDeck(
            subjectId: subject.id,
            unitId: draft.unitId ?? _defaultUnitForCreate(),
            name: draft.name,
            description: draft.description,
            tags: draft.tags,
          );
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        _showSnackBar('Deck created.');
      }
    } catch (error) {
      _showSnackBar('Could not create deck: $error');
    }
  }

  Future<void> _openEditDeck(
    BuildContext context,
    DeckRecord deck,
    List<SubjectUnitRecord> unitItems,
  ) async {
    final draft = await showModalBottomSheet<DeckDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DeckEditorSheet(
        initialDeck: deck,
        availableUnits: unitItems,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }

    try {
      await ref.read(subjectDecksControllerProvider(subject.id).notifier).updateDeck(
            deck.copyWith(
              name: draft.name,
              description: draft.description,
              unitId: draft.unitId,
              tags: draft.tags,
            ),
          );
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        _showSnackBar('Deck updated.');
      }
    } catch (error) {
      _showSnackBar('Could not update deck: $error');
    }
  }

  Future<void> _confirmDeleteDeck(BuildContext context, DeckRecord deck) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete deck?'),
        content: Text(
          'Delete ${deck.name}? This will remove its future flashcards and study history in this subject.',
        ),
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
    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await ref.read(subjectDecksControllerProvider(subject.id).notifier).deleteDeck(deck.id);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        _showSnackBar('${deck.name} deleted.');
      }
    } catch (error) {
      _showSnackBar('Could not delete deck: $error');
    }
  }

  Future<void> _openCreateQuiz(
    BuildContext context,
    List<SubjectUnitRecord> unitItems,
  ) async {
    final draft = await showModalBottomSheet<QuizEditorDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => QuizEditorSheet(availableUnits: unitItems),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      final now = DateTime.now();
      final existing = await ref.read(subjectQuizzesControllerProvider(subject.id).future);
      final newQuiz = QuizRecord(
        id: now.microsecondsSinceEpoch.toString(),
        subjectId: subject.id,
        unitId: draft.unitId ?? _defaultUnitForCreate(),
        name: draft.name,
        description: draft.description,
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
          sectionRules: const [],
        ),
        questions: const [],
        createdAt: now,
        updatedAt: now,
      );
      await ref
          .read(subjectQuizzesControllerProvider(subject.id).notifier)
          .saveAllForSubject(subject.id, [...existing, newQuiz]);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        _showSnackBar('Empty quiz created.');
      }
    } catch (error) {
      _showSnackBar('Could not create quiz: $error');
    }
  }

  Future<void> _confirmDeleteQuiz(BuildContext context, QuizRecord quiz) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete quiz?'),
        content: Text('Delete ${quiz.name}?'),
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
    if (shouldDelete != true || !mounted) {
      return;
    }
    try {
      await ref.read(subjectQuizzesControllerProvider(subject.id).notifier).deleteQuiz(quiz.id);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        _showSnackBar('${quiz.name} deleted.');
      }
    } catch (error) {
      _showSnackBar('Could not delete quiz: $error');
    }
  }

  Future<void> _openSampleImporter() async {
    final context = this.context;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('Import DSA Sample Deck'),
                subtitle: const Text('Data structures flashcards'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_deck_dsa.json',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.science_rounded),
                title: const Text('Import Chemistry Sample Deck'),
                subtitle: const Text('Organic chemistry flashcards'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_deck_chemistry.json',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.biotech_rounded),
                title: const Text('Import Biology & Chemistry Practice Quiz'),
                subtitle: const Text('Timed single-correct MCQ practice'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_quiz_neet_style.json',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.functions_rounded),
                title: const Text('Import Physics & Mathematics Practice Quiz'),
                subtitle: const Text('Mixed objective and numerical practice'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_quiz_jee_style.json',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calculate_rounded),
                title: const Text('Import Math Foundations Quiz'),
                subtitle: const Text('Arithmetic and algebra warm-up'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_quiz_math_foundations.json',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.biotech_outlined),
                title: const Text('Import Biology Basics Quiz'),
                subtitle: const Text('Cells and physiology practice'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_quiz_biology_basics.json',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_rounded),
                title: const Text('Import History & Civics Quiz'),
                subtitle: const Text('Humanities practice set'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_quiz_history_civics.json',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Import Science Q&A Quiz'),
                subtitle: const Text('Short-answer practice with keyword grading'),
                onTap: () => Navigator.of(context).pop(
                  'assets/sample_data/sample_quiz_science_qa.json',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }

    try {
      await _maybeCreateSafetySnapshot(
        choice.contains('sample_quiz') ? 'sample-quiz-import' : 'sample-deck-import',
      );
      if (choice.contains('sample_quiz')) {
        final result = await ref
            .read(contentPortabilityServiceProvider)
            .importQuizAsset(
              subjectId: subject.id,
              assetPath: choice,
              unitId: _defaultUnitForCreate(),
            );
        ref.invalidate(subjectQuizzesControllerProvider(subject.id));
        ref.invalidate(dashboardSummaryProvider);
        if (mounted) {
          _showSnackBar(
            'Imported ${result.quizName} with ${result.importedQuestionCount} questions.',
          );
        }
        return;
      }

      final deckResult = await ref
          .read(contentPortabilityServiceProvider)
          .importDeckAsset(
            subjectId: subject.id,
            assetPath: choice,
            unitId: _defaultUnitForCreate(),
          );
      ref.invalidate(subjectDecksControllerProvider(subject.id));
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        _showSnackBar(
          'Imported ${deckResult.deckName} with ${deckResult.importedCardCount} cards.',
        );
      }
    } catch (error) {
      _showSnackBar('Import failed: $error');
    }
  }

  Future<void> _pickAndImportJson() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty || !mounted) {
        return;
      }

      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException(
          'The selected file could not be read in memory.',
        );
      }

      await _importImportedBytes(
        bytes,
        sourceLabel: file.name.isEmpty ? 'selected file' : file.name,
        extension: (file.extension ?? '').toLowerCase(),
      );
    } catch (error) {
      _showSnackBar('Import failed: $error');
    }
  }

  Future<void> _importDroppedJson(DroppedJsonFile file) async {
    try {
      await _importImportedBytes(
        file.bytes,
        sourceLabel: file.name,
        extension: 'json',
      );
    } catch (error) {
      _showSnackBar('Drop import failed: $error');
    }
  }

  Future<void> _importImportedBytes(
    List<int> bytes, {
    required String sourceLabel,
    required String extension,
  }) async {
    if (extension == 'csv') {
      StudyDeskSecurity.ensureImportSize(
        bytes,
        label: sourceLabel,
        maxBytes: StudyDeskSecurity.maxCsvImportBytes,
      );
      await _maybeCreateSafetySnapshot('csv-import');
      final result = await ref
          .read(contentPortabilityServiceProvider)
          .importDeckCsv(
            subjectId: subject.id,
            csvSource: StudyDeskSecurity.decodeUtf8(
              bytes,
              label: sourceLabel,
            ),
            unitId: _defaultUnitForCreate(),
            deckName: sourceLabel.replaceAll(RegExp(r'\.csv$', caseSensitive: false), ''),
          );
      ref.invalidate(subjectDecksControllerProvider(subject.id));
      ref.invalidate(dashboardSummaryProvider);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        'Imported ${result.deckName} from $sourceLabel with ${result.importedCardCount} cards.',
      );
      return;
    }

    StudyDeskSecurity.ensureImportSize(
      bytes,
      label: sourceLabel,
      maxBytes: StudyDeskSecurity.maxJsonImportBytes,
    );
    await _maybeCreateSafetySnapshot('json-import');
    final jsonSource = StudyDeskSecurity.decodeUtf8(
      bytes,
      label: sourceLabel,
    );
    final result = await ref
        .read(contentPortabilityServiceProvider)
        .importStudyJson(
          subjectId: subject.id,
          jsonSource: jsonSource,
          unitId: _defaultUnitForCreate(),
        );

    ref.invalidate(subjectDecksControllerProvider(subject.id));
    ref.invalidate(subjectQuizzesControllerProvider(subject.id));
    ref.invalidate(subjectNotesControllerProvider(subject.id));
    ref.invalidate(subjectQaControllerProvider(subject.id));
    ref.invalidate(dashboardSummaryProvider);

    if (!mounted) {
      return;
    }

    final importedLabel = switch (result.type) {
      StudyImportType.deck => 'cards',
      StudyImportType.quiz => 'questions',
      StudyImportType.note => 'note',
      StudyImportType.qaBank => 'prompts',
    };
    _showSnackBar(
      'Imported ${result.name} from $sourceLabel with ${result.itemCount} $importedLabel.',
    );
  }

  Future<void> _maybeCreateSafetySnapshot(String reason) async {
    final settings = ref.read(profileSettingsControllerProvider);
    if (!settings.autoBackupBeforeImports) {
      return;
    }
    await ref.read(libraryBackupServiceProvider).createSafetySnapshot(
          reason: reason,
          interactiveFallback: false,
        );
  }
}

class _SubjectHero extends StatelessWidget {
  const _SubjectHero({
    required this.subject,
    required this.deckCount,
    required this.quizCount,
    required this.noteCount,
    required this.qaCount,
    required this.activeScopeLabel,
    required this.onCreateDeck,
    required this.onImportJson,
    required this.onImportDroppedJson,
    required this.onImportSample,
    required this.onOpenNotes,
    required this.onCreateNote,
    required this.onOpenQaBank,
    required this.onOpenAiWorkspace,
    required this.onExportBundle,
  });

  final SubjectRecord subject;
  final int deckCount;
  final int quizCount;
  final int noteCount;
  final int qaCount;
  final String activeScopeLabel;
  final VoidCallback onCreateDeck;
  final VoidCallback onImportJson;
  final ValueChanged<DroppedJsonFile> onImportDroppedJson;
  final VoidCallback onImportSample;
  final VoidCallback onOpenNotes;
  final VoidCallback onCreateNote;
  final VoidCallback onOpenQaBank;
  final VoidCallback onOpenAiWorkspace;
  final VoidCallback onExportBundle;

  @override
  Widget build(BuildContext context) {
    final accent = Color(subject.colorValue);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(subject.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  subject.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$activeScopeLabel • $noteCount note${noteCount == 1 ? '' : 's'}, $qaCount Q&A prompt${qaCount == 1 ? '' : 's'}, $deckCount deck${deckCount == 1 ? '' : 's'}, and $quizCount quiz${quizCount == 1 ? '' : 'zes'}.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onCreateDeck,
                icon: const Icon(Icons.collections_bookmark_rounded),
                label: const Text('Add Deck'),
              ),
              FilledButton.icon(
                onPressed: onOpenNotes,
                icon: const Icon(Icons.note_alt_rounded),
                label: const Text('Open Notes'),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenQaBank,
                icon: const Icon(Icons.record_voice_over_rounded),
                label: const Text('Q&A Bank'),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenAiWorkspace,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('AI Workspace'),
              ),
              FilledButton.tonalIcon(
                onPressed: onCreateNote,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Quick Note'),
              ),
              FilledButton.tonalIcon(
                onPressed: onImportJson,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Import File'),
              ),
              FilledButton.tonalIcon(
                onPressed: onImportSample,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Import Sample'),
              ),
              FilledButton.tonalIcon(
                onPressed: onExportBundle,
                icon: const Icon(Icons.archive_rounded),
                label: const Text('Export Bundle'),
              ),
            ],
          ),
          if (kIsWeb) ...[
            const SizedBox(height: AppSpacing.md),
            JsonDropZone(onFileDropped: onImportDroppedJson),
          ],
        ],
      ),
    );
  }
}

class _UnitFilterCard extends StatelessWidget {
  const _UnitFilterCard({
    required this.units,
    required this.selectedFilter,
    required this.onChanged,
  });

  final List<SubjectUnitRecord> units;
  final String selectedFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scope',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selectedFilter == _allUnitsFilter,
                  onSelected: (_) => onChanged(_allUnitsFilter),
                ),
                ChoiceChip(
                  label: const Text('Uncategorized'),
                  selected: selectedFilter == _uncategorizedUnitFilter,
                  onSelected: (_) => onChanged(_uncategorizedUnitFilter),
                ),
                for (final unit in units)
                  ChoiceChip(
                    label: Text(unit.name),
                    selected: selectedFilter == unit.id,
                    onSelected: (_) => onChanged(unit.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagFilterCard extends StatelessWidget {
  const _TagFilterCard({
    required this.tags,
    required this.selectedFilter,
    required this.onChanged,
  });

  final List<String> tags;
  final String selectedFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (tags.isEmpty)
              Text(
                'No tags in this scope yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('All Tags'),
                    selected: selectedFilter == _allTagsFilter,
                    onSelected: (_) => onChanged(_allTagsFilter),
                  ),
                  for (final tag in tags)
                    ChoiceChip(
                      label: Text('#$tag'),
                      selected: selectedFilter.toLowerCase() == tag.toLowerCase(),
                      onSelected: (_) => onChanged(tag),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UnitsOverviewCard extends StatelessWidget {
  const _UnitsOverviewCard({
    required this.units,
    required this.deckCountByUnit,
    required this.quizCountByUnit,
    required this.noteCountByUnit,
    required this.qaCountByUnit,
    required this.onSelectUnit,
    required this.onEditUnit,
    required this.onDeleteUnit,
  });

  final List<SubjectUnitRecord> units;
  final Map<String, int> deckCountByUnit;
  final Map<String, int> quizCountByUnit;
  final Map<String, int> noteCountByUnit;
  final Map<String, int> qaCountByUnit;
  final ValueChanged<String> onSelectUnit;
  final ValueChanged<SubjectUnitRecord> onEditUnit;
  final ValueChanged<SubjectUnitRecord> onDeleteUnit;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No units yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Create optional units like Chapter 1, Mechanics, or Module A. Anything without a unit stays available under Uncategorized.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            for (final unit in units)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(unit.name),
                subtitle: Text(
                  '${noteCountByUnit[unit.id] ?? 0} notes • ${qaCountByUnit[unit.id] ?? 0} Q&A • ${deckCountByUnit[unit.id] ?? 0} decks • ${quizCountByUnit[unit.id] ?? 0} quizzes'
                  '${unit.description.isEmpty ? '' : '\n${unit.description}'}',
                ),
                isThreeLine: unit.description.isNotEmpty,
                onTap: () => onSelectUnit(unit.id),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEditUnit(unit);
                    } else if (value == 'delete') {
                      onDeleteUnit(unit);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit unit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete unit')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotesOverviewCard extends StatelessWidget {
  const _NotesOverviewCard({
    required this.notes,
    required this.activeScopeLabel,
    required this.onOpenWorkspace,
    required this.onCreateNote,
  });

  final List<NoteRecord> notes;
  final String activeScopeLabel;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onCreateNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notes.isEmpty ? 'No notes in $activeScopeLabel' : 'Recent Notes in $activeScopeLabel',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onOpenWorkspace,
                  child: const Text('Workspace'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              notes.isEmpty
                  ? 'Create Markdown notes with LaTeX support, wiki links, backlinks, and card drafting from selected text.'
                  : 'Open the notes workspace to edit, search, preview, import, export, and turn note sections into flashcards.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (notes.isEmpty)
              FilledButton.icon(
                onPressed: onCreateNote,
                icon: const Icon(Icons.note_add_rounded),
                label: const Text('Create Note'),
              )
            else
              Column(
                children: [
                  for (final note in notes.take(3))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(note.title),
                      subtitle: Text(
                        note.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

class _QaOverviewCard extends StatelessWidget {
  const _QaOverviewCard({
    required this.items,
    required this.activeScopeLabel,
    required this.onOpenWorkspace,
  });

  final List<QaItemRecord> items;
  final String activeScopeLabel;
  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    items.isEmpty ? 'No Q&A prompts in $activeScopeLabel' : 'Recent Q&A in $activeScopeLabel',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onOpenWorkspace,
                  child: const Text('Workspace'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              items.isEmpty
                  ? 'Create long-form recall prompts for descriptive exams and theory-heavy revision.'
                  : 'Open the Q&A workspace to refine prompts, organize them by unit and tag, and run recall sessions.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final item in items.take(3))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.record_voice_over_rounded),
                  title: Text(item.question),
                  subtitle: Text(
                    item.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        FilledButton.tonal(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _EmptyDecksState extends StatelessWidget {
  const _EmptyDecksState({
    required this.subject,
    required this.activeScopeLabel,
    required this.onCreateDeck,
  });

  final SubjectRecord subject;
  final String activeScopeLabel;
  final VoidCallback onCreateDeck;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text(subject.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No decks in $activeScopeLabel',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create a deck to start storing flashcards, spaced-review progress, and exports for this subject.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreateDeck,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Deck'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyQuizState extends StatelessWidget {
  const _EmptyQuizState({required this.activeScopeLabel});

  final String activeScopeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.quiz_rounded, size: 52),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No quizzes in $activeScopeLabel',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Import a bundled sample quiz or create one from scratch and build it question by question.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingSubjectView extends StatelessWidget {
  const _MissingSubjectView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 44),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Subject not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'It may have been removed locally.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitDraft {
  const _UnitDraft({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;
}

class _UnitEditorSheet extends StatefulWidget {
  const _UnitEditorSheet({this.initialUnit});

  final SubjectUnitRecord? initialUnit;

  @override
  State<_UnitEditorSheet> createState() => _UnitEditorSheetState();
}

class _UnitEditorSheetState extends State<_UnitEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _nameError;

  bool get _isEditing => widget.initialUnit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUnit?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialUnit?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Unit' : 'Create Unit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Unit name',
                hintText: 'Chapter 1',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional summary of what belongs in this unit.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                label: Text(_isEditing ? 'Save Unit' : 'Create Unit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please give the unit a name.');
      return;
    }
    Navigator.of(context).pop(
      _UnitDraft(
        name: name,
        description: _descriptionController.text.trim(),
      ),
    );
  }
}
