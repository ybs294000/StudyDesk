import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/widgets/markdown_content.dart';
import '../../../theme/app_spacing.dart';
import '../../subjects/application/subjects_controller.dart';
import '../../subjects/domain/subject_record.dart';
import '../../units/application/subject_units_controller.dart';
import '../../units/domain/subject_unit_record.dart';
import '../application/note_markdown_utils.dart';
import '../application/subject_notes_controller.dart';
import '../domain/note_record.dart';

class SubjectNotesScreen extends ConsumerStatefulWidget {
  const SubjectNotesScreen({
    required this.subjectId,
    this.initialNoteId,
    super.key,
  });

  final String subjectId;
  final String? initialNoteId;

  @override
  ConsumerState<SubjectNotesScreen> createState() => _SubjectNotesScreenState();
}

class _SubjectNotesScreenState extends ConsumerState<SubjectNotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedNoteId;
  String _selectedUnitFilter = _allUnitsFilter;

  @override
  void initState() {
    super.initState();
    _selectedNoteId = widget.initialNoteId;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(subjectNotesControllerProvider(widget.subjectId));
    final subjectsAsync = ref.watch(subjectsControllerProvider);
    final unitsAsync = ref.watch(subjectUnitsControllerProvider(widget.subjectId));

    return unitsAsync.when(
      data: (units) => subjectsAsync.when(
        data: (subjects) {
        SubjectRecord? subject;
        for (final item in subjects) {
          if (item.id == widget.subjectId) {
            subject = item;
            break;
          }
        }
        if (subject == null) {
          return const Center(child: Text('Subject not found.'));
        }
        final resolvedSubject = subject;

        return notesAsync.when(
          data: (notes) {
            final filteredNotes = _filterNotes(notes);
            final selectedNote = _resolveSelectedNote(notes, filteredNotes);
            final activeNote = selectedNote;
            final isWide = MediaQuery.sizeOf(context).width >= 1040;
            final notesBody = filteredNotes.isEmpty
                ? _EmptyNotesState(
                    hasQuery: _searchQuery.isNotEmpty,
                    onCreateNote: _createNote,
                    onImportMarkdown: _importMarkdown,
                  )
                : isWide && activeNote != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 340,
                        child: _NotesListPane(
                          notes: filteredNotes,
                          units: units,
                          selectedNoteId: activeNote.id,
                          onSelect: (note) {
                            setState(() => _selectedNoteId = note.id);
                          },
                          onEdit: (note) => _openEditor(note.id),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _NotePreviewPane(
                          note: activeNote,
                          units: units,
                          allNotes: notes,
                          onOpenLinkedNote: _openOrCreateLinkedNote,
                          onEdit: () => _openEditor(activeNote.id),
                          onCreateNote: _createNote,
                        ),
                      ),
                    ],
                  )
                : _NotesListPane(
                    notes: filteredNotes,
                    units: units,
                    selectedNoteId: activeNote?.id,
                    onSelect: (note) => _openEditor(note.id),
                    onEdit: (note) => _openEditor(note.id),
                  );

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotesHeader(
                    subjectName: resolvedSubject.name,
                    noteCount: notes.length,
                    units: units,
                    selectedUnitFilter: _selectedUnitFilter,
                    onUnitFilterChanged: (value) {
                      setState(() => _selectedUnitFilter = value);
                    },
                    searchController: _searchController,
                    onCreateNote: _createNote,
                    onImportMarkdown: _importMarkdown,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(child: notesBody),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('Could not load notes: $error'),
          ),
        );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Could not load subject: $error'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Could not load units: $error'),
      ),
    );
  }

  List<NoteRecord> _filterNotes(List<NoteRecord> notes) {
    return notes.where((note) {
      final matchesUnit = switch (_selectedUnitFilter) {
        _allUnitsFilter => true,
        _uncategorizedUnitFilter => note.unitId == null,
        _ => note.unitId == _selectedUnitFilter,
      };
      if (!matchesUnit) {
        return false;
      }
      if (_searchQuery.isEmpty) {
        return true;
      }
      final haystack = [
        note.title,
        note.bodyMarkdown,
        note.tags.join(' '),
      ].join(' ').toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  NoteRecord? _resolveSelectedNote(
    List<NoteRecord> allNotes,
    List<NoteRecord> filteredNotes,
  ) {
    if (filteredNotes.isEmpty) {
      return null;
    }

    NoteRecord? selected;
    for (final note in allNotes) {
      if (note.id == _selectedNoteId) {
        selected = note;
        break;
      }
    }
    if (selected != null) {
      final resolvedSelected = selected;
      if (filteredNotes.any((note) => note.id == resolvedSelected.id)) {
        return resolvedSelected;
      }
    }

    final fallback = filteredNotes.first;
    if (_selectedNoteId != fallback.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedNoteId = fallback.id);
        }
      });
    }
    return fallback;
  }

  Future<void> _createNote() async {
    try {
      final note = await ref
          .read(subjectNotesControllerProvider(widget.subjectId).notifier)
          .createNote(
            subjectId: widget.subjectId,
            unitId: _defaultUnitIdForCreate(),
            title: 'New Note',
            bodyMarkdown: '# New Note\n\nStart writing here.',
          );
      if (!mounted) {
        return;
      }
      _openEditor(note.id);
    } catch (error) {
      _showMessage('Could not create note: $error');
    }
  }

  Future<void> _importMarkdown() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md', 'markdown'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('The selected Markdown file could not be read.');
      }
      final markdown = utf8.decode(bytes);
      final imported = await ref
          .read(subjectNotesControllerProvider(widget.subjectId).notifier)
          .importMarkdownNote(
            subjectId: widget.subjectId,
            unitId: _defaultUnitIdForCreate(),
            title: deriveTitleFromMarkdown(
              markdown,
              fallback: p.basenameWithoutExtension(file.name),
            ),
            bodyMarkdown: markdown,
          );
      if (!mounted) {
        return;
      }
      setState(() => _selectedNoteId = imported.id);
      _showMessage('Imported ${imported.title}.');
    } catch (error) {
      _showMessage('Markdown import failed: $error');
    }
  }

  String? _defaultUnitIdForCreate() {
    return switch (_selectedUnitFilter) {
      _allUnitsFilter || _uncategorizedUnitFilter => null,
      _ => _selectedUnitFilter,
    };
  }

  Future<void> _openOrCreateLinkedNote(String noteTitle) async {
    final notes = await ref.read(subjectNotesControllerProvider(widget.subjectId).future);
    final existing = resolveLinkedNote(notes: notes, title: noteTitle);
    if (existing != null) {
      final resolvedExisting = existing;
      if (!mounted) {
        return;
      }
      setState(() => _selectedNoteId = resolvedExisting.id);
      return;
    }

    try {
      final created = await ref
          .read(subjectNotesControllerProvider(widget.subjectId).notifier)
          .createNote(
            subjectId: widget.subjectId,
            unitId: _defaultUnitIdForCreate(),
            title: noteTitle,
            bodyMarkdown: '# $noteTitle\n\n',
          );
      if (!mounted) {
        return;
      }
      _openEditor(created.id);
    } catch (error) {
      _showMessage('Could not create linked note: $error');
    }
  }

  void _openEditor(String noteId) {
    if (!mounted) {
      return;
    }
    context.go('/subjects/${widget.subjectId}/notes/$noteId');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _NotesHeader extends StatelessWidget {
  const _NotesHeader({
    required this.subjectName,
    required this.noteCount,
    required this.units,
    required this.selectedUnitFilter,
    required this.onUnitFilterChanged,
    required this.searchController,
    required this.onCreateNote,
    required this.onImportMarkdown,
  });

  final String subjectName;
  final int noteCount;
  final List<SubjectUnitRecord> units;
  final String selectedUnitFilter;
  final ValueChanged<String> onUnitFilterChanged;
  final TextEditingController searchController;
  final Future<void> Function() onCreateNote;
  final Future<void> Function() onImportMarkdown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$subjectName Notes',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$noteCount note${noteCount == 1 ? '' : 's'} with Markdown, LaTeX, backlinks, and export support.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: selectedUnitFilter == _allUnitsFilter,
              onSelected: (_) => onUnitFilterChanged(_allUnitsFilter),
            ),
            ChoiceChip(
              label: const Text('Uncategorized'),
              selected: selectedUnitFilter == _uncategorizedUnitFilter,
              onSelected: (_) => onUnitFilterChanged(_uncategorizedUnitFilter),
            ),
            for (final unit in units)
              ChoiceChip(
                label: Text(unit.name),
                selected: selectedUnitFilter == unit.id,
                onSelected: (_) => onUnitFilterChanged(unit.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Search notes',
                  hintText: 'Search titles, tags, and content',
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onCreateNote,
              icon: const Icon(Icons.note_add_rounded),
              label: const Text('New Note'),
            ),
            FilledButton.tonalIcon(
              onPressed: onImportMarkdown,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import Markdown'),
            ),
          ],
        ),
      ],
    );
  }
}

const _allUnitsFilter = '__all_units__';
const _uncategorizedUnitFilter = '__uncategorized_unit__';

class _NotesListPane extends StatelessWidget {
  const _NotesListPane({
    required this.notes,
    required this.units,
    required this.selectedNoteId,
    required this.onSelect,
    required this.onEdit,
  });

  final List<NoteRecord> notes;
  final List<SubjectUnitRecord> units;
  final String? selectedNoteId;
  final ValueChanged<NoteRecord> onSelect;
  final ValueChanged<NoteRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: notes.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final note = notes[index];
          final isSelected = note.id == selectedNoteId;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => onSelect(note),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit note',
                        onPressed: () => onEdit(note),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    note.excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (note.unitId != null || note.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (note.unitId != null)
                          Chip(
                            label: Text(_unitName(units, note.unitId) ?? 'Unit'),
                          ),
                        for (final tag in note.tags.take(4))
                          Chip(label: Text('#$tag')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotePreviewPane extends StatelessWidget {
  const _NotePreviewPane({
    required this.note,
    required this.units,
    required this.allNotes,
    required this.onOpenLinkedNote,
    required this.onEdit,
    required this.onCreateNote,
  });

  final NoteRecord note;
  final List<SubjectUnitRecord> units;
  final List<NoteRecord> allNotes;
  final ValueChanged<String> onOpenLinkedNote;
  final VoidCallback onEdit;
  final Future<void> Function() onCreateNote;

  @override
  Widget build(BuildContext context) {
    final headings = extractHeadings(note.bodyMarkdown);
    final backlinks = findBacklinks(notes: allNotes, target: note);
    final links = extractWikiLinks(note.bodyMarkdown);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                        'Updated ${_formatTimestamp(note.updatedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Edit'),
                ),
              ],
            ),
            if (note.unitId != null || note.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (note.unitId != null)
                    Chip(
                      label: Text(_unitName(units, note.unitId) ?? 'Unit'),
                    ),
                  for (final tag in note.tags) Chip(label: Text('#$tag')),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: MarkdownContent(
                        data: note.bodyMarkdown,
                        selectable: true,
                        enableWikiLinks: true,
                        onTapLink: (text, href, title) {
                          final uri = href == null ? null : Uri.tryParse(href);
                          if (uri?.scheme == 'studydesk-note' && uri != null) {
                            final noteTitle = Uri.decodeComponent(
                              uri.host.isNotEmpty ? uri.host : uri.path,
                            );
                            if (noteTitle.isNotEmpty) {
                              onOpenLinkedNote(noteTitle);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(
                    width: 260,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SideSection(
                            title: 'Outline',
                            child: headings.isEmpty
                                ? const Text('No headings yet.')
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final heading in headings)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left: (heading.level - 1) * 10,
                                            bottom: AppSpacing.xs,
                                          ),
                                          child: Text(heading.text),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SideSection(
                            title: 'Backlinks',
                            child: backlinks.isEmpty
                                ? const Text('No notes link here yet.')
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final backlink in backlinks)
                                        TextButton(
                                          onPressed: () => onOpenLinkedNote(backlink.title),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(backlink.title),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SideSection(
                            title: 'Linked Notes',
                            child: links.isEmpty
                                ? const Text('Use [[Note Title]] to connect notes.')
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final link in links)
                                        TextButton(
                                          onPressed: () => onOpenLinkedNote(link.title),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(link.label),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: onCreateNote,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New linked note'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideSection extends StatelessWidget {
  const _SideSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState({
    required this.hasQuery,
    required this.onCreateNote,
    required this.onImportMarkdown,
  });

  final bool hasQuery;
  final Future<void> Function() onCreateNote;
  final Future<void> Function() onImportMarkdown;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 52),
                const SizedBox(height: AppSpacing.md),
                Text(
                  hasQuery ? 'No matching notes' : 'No notes yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hasQuery
                      ? 'Try a different search term or create a fresh note.'
                      : 'Create Markdown study notes with wiki links, LaTeX, and export support.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onCreateNote,
                      icon: const Icon(Icons.note_add_rounded),
                      label: const Text('New Note'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onImportMarkdown,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Import Markdown'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month ${hour.toString().padLeft(2, '0')}:$minute $suffix';
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
