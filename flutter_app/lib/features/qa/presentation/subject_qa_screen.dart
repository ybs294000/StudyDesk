import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/content_portability_service.dart';
import '../../../services/export_file_service.dart';
import '../../../theme/app_spacing.dart';
import '../../notes/application/note_markdown_utils.dart';
import '../../units/application/subject_units_controller.dart';
import '../../units/domain/subject_unit_record.dart';
import '../application/subject_qa_controller.dart';
import '../data/qa_review_repository.dart';
import '../domain/qa_item_record.dart';
import '../domain/qa_review_record.dart';

class SubjectQaScreen extends ConsumerStatefulWidget {
  const SubjectQaScreen({
    required this.subjectId,
    super.key,
  });

  final String subjectId;

  @override
  ConsumerState<SubjectQaScreen> createState() => _SubjectQaScreenState();
}

class _SubjectQaScreenState extends ConsumerState<SubjectQaScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedUnitId;
  String _selectedTag = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(subjectQaControllerProvider(widget.subjectId));
    final unitsAsync = ref.watch(subjectUnitsControllerProvider(widget.subjectId));
    final reviewsAsync = FutureBuilder<List<QaReviewRecord>>(
      future: ref.read(qaReviewRepositoryProvider).loadReviews(),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <QaReviewRecord>[];
        return unitsAsync.when(
          data: (units) => itemsAsync.when(
            data: (items) {
              final filtered = _filteredItems(items);
              final tags = _collectTags(items);
              final reviewById = {for (final review in reviews) review.promptId: review};
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _QaHeader(
                    onBack: _goBack,
                    onAdd: () => _openEditor(units: units),
                    onOpenNotes: () => context.push('/subjects/${widget.subjectId}/notes'),
                    onExportJson: _exportQaJson,
                    onExportMarkdown: _exportQaMarkdown,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded),
                              labelText: 'Search Q&A prompts',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedUnitId,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All units'),
                                    ),
                                    const DropdownMenuItem<String?>(
                                      value: '__uncategorized__',
                                      child: Text('Uncategorized'),
                                    ),
                                    for (final unit in units)
                                      DropdownMenuItem<String?>(
                                        value: unit.id,
                                        child: Text(unit.name),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() => _selectedUnitId = value),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedTag.isEmpty ? '__all__' : _selectedTag,
                                  decoration: const InputDecoration(
                                    labelText: 'Tag',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '__all__',
                                      child: Text('All tags'),
                                    ),
                                    for (final tag in tags)
                                      DropdownMenuItem<String>(
                                        value: tag,
                                        child: Text('#$tag'),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _selectedTag = value == null || value == '__all__' ? '' : value;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          children: [
                            const Icon(Icons.record_voice_over_rounded, size: 52),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No Q&A prompts yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Create long-form recall prompts for theory-heavy studying, or generate them from structured notes.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final item in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _QaItemTile(
                          item: item,
                          review: reviewById[item.id],
                          unitName: _unitName(units, item.unitId),
                          onOpen: () => context.push('/subjects/${widget.subjectId}/qa/${item.id}/session'),
                          onEdit: () => _openEditor(units: units, existing: item),
                          onDelete: () => _deleteItem(item),
                        ),
                      ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Could not load Q&A prompts: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Could not load units: $error')),
        );
      },
    );

    return reviewsAsync;
  }

  List<QaItemRecord> _filteredItems(List<QaItemRecord> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      final unitMatch = switch (_selectedUnitId) {
        null => true,
        '__uncategorized__' => item.unitId == null,
        _ => item.unitId == _selectedUnitId,
      };
      final tagMatch = _selectedTag.isEmpty ||
          item.tags.any((tag) => tag.toLowerCase() == _selectedTag.toLowerCase());
      final queryMatch = query.isEmpty ||
          item.question.toLowerCase().contains(query) ||
          item.answerMarkdown.toLowerCase().contains(query) ||
          item.tags.any((tag) => tag.toLowerCase().contains(query));
      return unitMatch && tagMatch && queryMatch;
    }).toList();
  }

  List<String> _collectTags(List<QaItemRecord> items) {
    final tags = <String>{};
    for (final item in items) {
      tags.addAll(item.tags);
    }
    final sorted = tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
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

  Future<void> _openEditor({
    required List<SubjectUnitRecord> units,
    QaItemRecord? existing,
  }) async {
    final draft = await showModalBottomSheet<_QaDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _QaEditorSheet(
        existing: existing,
        units: units,
      ),
    );
    if (draft == null) {
      return;
    }
    try {
      final now = DateTime.now();
      if (existing == null) {
        await ref.read(subjectQaControllerProvider(widget.subjectId).notifier).upsertQa(
              subjectId: widget.subjectId,
              unitId: draft.unitId,
              question: draft.question,
              answerMarkdown: draft.answerMarkdown,
              tags: normalizeTags(draft.tags),
            );
      } else {
        final updatedItem = existing.copyWith(
          unitId: draft.unitId,
          question: draft.question,
          answerMarkdown: draft.answerMarkdown,
          tags: normalizeTags(draft.tags),
          updatedAt: now,
        );
        await ref.read(subjectQaControllerProvider(widget.subjectId).notifier).saveItem(updatedItem);
        final review = await ref.read(qaReviewRepositoryProvider).loadReview(existing.id);
        if (review != null) {
          await ref.read(qaReviewRepositoryProvider).upsertReview(
                review.copyWith(
                  subjectId: updatedItem.subjectId,
                  unitId: updatedItem.unitId,
                  updatedAt: now,
                ),
              );
        }
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Q&A prompt created.' : 'Q&A prompt updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save Q&A prompt: $error')),
      );
    }
  }

  Future<void> _deleteItem(QaItemRecord item) async {
    await ref.read(subjectQaControllerProvider(widget.subjectId).notifier).deleteItem(item.id);
    await ref.read(qaReviewRepositoryProvider).deleteReview(item.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Q&A prompt deleted.')),
    );
  }

  Future<void> _exportQaJson() async {
    try {
      final json = await ref
          .read(contentPortabilityServiceProvider)
          .exportQaBankJson(subjectId: widget.subjectId);
      final path = await ref.read(exportFileServiceProvider).saveJson(
            fileName: 'studydesk_qa_bank_${widget.subjectId}',
            json: json,
          );
      if (!mounted || path == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Q&A bank exported to $path')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export Q&A bank: $error')),
      );
    }
  }

  Future<void> _exportQaMarkdown() async {
    try {
      final markdown = await ref
          .read(contentPortabilityServiceProvider)
          .exportQaBankMarkdown(subjectId: widget.subjectId);
      final path = await ref.read(exportFileServiceProvider).saveMarkdown(
            fileName: 'studydesk_qa_bank_${widget.subjectId}',
            markdown: markdown,
          );
      if (!mounted || path == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Q&A markdown exported to $path')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export Q&A markdown: $error')),
      );
    }
  }

  void _goBack() {
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/subjects/${widget.subjectId}');
  }
}

class _QaHeader extends StatelessWidget {
  const _QaHeader({
    required this.onBack,
    required this.onAdd,
    required this.onOpenNotes,
    required this.onExportJson,
    required this.onExportMarkdown,
  });

  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback onOpenNotes;
  final VoidCallback onExportJson;
  final VoidCallback onExportMarkdown;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      FilledButton.tonalIcon(
        onPressed: onOpenNotes,
        icon: const Icon(Icons.note_alt_rounded),
        label: const Text('Open Notes'),
      ),
      FilledButton.tonalIcon(
        onPressed: onExportJson,
        icon: const Icon(Icons.data_object_rounded),
        label: const Text('Export JSON'),
      ),
      FilledButton.tonalIcon(
        onPressed: onExportMarkdown,
        icon: const Icon(Icons.description_rounded),
        label: const Text('Export Markdown'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'Q&A Bank',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Prompt'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: actions,
        ),
      ],
    );
  }
}

class _QaItemTile extends StatelessWidget {
  const _QaItemTile({
    required this.item,
    required this.review,
    required this.unitName,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final QaItemRecord item;
  final QaReviewRecord? review;
  final String? unitName;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dueLabel = review == null || review!.dueAt == null
        ? 'Ready now'
        : review!.isDue
            ? 'Due now'
            : 'Due ${review!.dueAt!.day}/${review!.dueAt!.month}';
    final ratingLabel = review?.lastRating?.label ?? 'New';

    return Card(
      child: InkWell(
        onTap: onOpen,
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
                          item.question,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.excerpt,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (unitName != null) Chip(label: Text(unitName!)),
                  Chip(label: Text(dueLabel)),
                  Chip(label: Text('Last result: $ratingLabel')),
                  for (final tag in item.tags.take(5)) Chip(label: Text('#$tag')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QaEditorSheet extends StatefulWidget {
  const _QaEditorSheet({
    required this.units,
    this.existing,
  });

  final List<SubjectUnitRecord> units;
  final QaItemRecord? existing;

  @override
  State<_QaEditorSheet> createState() => _QaEditorSheetState();
}

class _QaEditorSheetState extends State<_QaEditorSheet> {
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  late final TextEditingController _tagsController;
  String? _unitId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.existing?.question ?? '');
    _answerController = TextEditingController(text: widget.existing?.answerMarkdown ?? '');
    _tagsController = TextEditingController(text: widget.existing?.tags.join(', ') ?? '');
    _unitId = widget.existing?.unitId;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _tagsController.dispose();
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
                widget.existing == null ? 'Add Q&A Prompt' : 'Edit Q&A Prompt',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _questionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Question',
                  hintText: 'Explain the working principle of a hash table.',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _unitId,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Uncategorized'),
                  ),
                  for (final unit in widget.units)
                    DropdownMenuItem<String?>(
                      value: unit.id,
                      child: Text(unit.name),
                    ),
                ],
                onChanged: (value) => setState(() => _unitId = value),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'topic, exam-short, revision',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _answerController,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Model answer',
                  alignLabelWithHint: true,
                  hintText: 'Use Markdown and LaTeX if needed.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.existing == null ? 'Create Prompt' : 'Save Prompt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final question = _questionController.text.trim();
    final answer = _answerController.text.trim();
    if (question.isEmpty || answer.isEmpty) {
      setState(() {
        _error = 'Question and model answer are both required.';
      });
      return;
    }
    Navigator.of(context).pop(
      _QaDraft(
        unitId: _unitId,
        question: question,
        answerMarkdown: answer,
        tags: _tagsController.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
      ),
    );
  }
}

class _QaDraft {
  const _QaDraft({
    required this.unitId,
    required this.question,
    required this.answerMarkdown,
    required this.tags,
  });

  final String? unitId;
  final String question;
  final String answerMarkdown;
  final List<String> tags;
}
