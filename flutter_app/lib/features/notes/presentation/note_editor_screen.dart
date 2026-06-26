import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/studydesk_security.dart';
import '../../../core/widgets/markdown_content.dart';
import '../../../theme/app_spacing.dart';
import '../../cards/application/deck_cards_controller.dart';
import '../../cards/presentation/widgets/card_editor_sheet.dart';
import '../../decks/application/subject_decks_controller.dart';
import '../../decks/domain/deck_record.dart';
import '../../decks/presentation/widgets/deck_editor_sheet.dart';
import '../../quizzes/application/subject_quizzes_controller.dart';
import '../../quizzes/domain/quiz_models.dart';
import '../../qa/application/subject_qa_controller.dart';
import '../../units/application/subject_units_controller.dart';
import '../../units/domain/subject_unit_record.dart';
import '../application/note_markdown_utils.dart';
import '../application/subject_notes_controller.dart';
import '../domain/note_record.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    required this.subjectId,
    required this.noteId,
    super.key,
  });

  final String subjectId;
  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final ScrollController _editorScrollController = ScrollController();
  Timer? _saveDebounce;
  String? _boundNoteId;
  String? _selectedUnitId;
  bool _isSaving = false;
  bool _hasPendingChanges = false;
  bool _isHydrating = false;

  void _goBackToNotes() {
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/subjects/${widget.subjectId}/notes?noteId=${widget.noteId}');
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleSave);
    _tagsController.addListener(_scheduleSave);
    _bodyController.addListener(_scheduleSave);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.dispose();
    _tagsController.dispose();
    _bodyController.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(subjectNotesControllerProvider(widget.subjectId));
    final decksAsync = ref.watch(subjectDecksControllerProvider(widget.subjectId));
    final unitsAsync = ref.watch(subjectUnitsControllerProvider(widget.subjectId));

    return unitsAsync.when(
      data: (units) => notesAsync.when(
        data: (notes) {
        NoteRecord? note;
        for (final item in notes) {
          if (item.id == widget.noteId) {
            note = item;
            break;
          }
        }
        if (note == null) {
          return _MissingNoteState(subjectId: widget.subjectId);
        }

        _bindNote(note);
        final isWide = MediaQuery.sizeOf(context).width >= 1100;
        final headings = extractHeadings(_bodyController.text);
        final backlinks = findBacklinks(notes: notes, target: note);
        final linkedNotes = extractWikiLinks(_bodyController.text);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            final canLeave = await _handleBackNavigation();
            if (canLeave) {
              _goBackToNotes();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EditorTopBar(
                  titleController: _titleController,
                  tagsController: _tagsController,
                  availableUnits: units,
                  selectedUnitId: _selectedUnitId,
                  onUnitChanged: (value) {
                    setState(() => _selectedUnitId = value);
                    _scheduleSave();
                  },
                  isSaving: _isSaving,
                  onBack: () async {
                    final canPop = await _handleBackNavigation();
                    if (canPop) {
                      _goBackToNotes();
                    }
                  },
                  onOpenReader: () {
                    context.push('/subjects/${widget.subjectId}/notes/${widget.noteId}/read');
                  },
                  onImportFromAi: _openAiWorkspace,
                  onImportBody: _replaceBodyFromMarkdown,
                  onExportMarkdown: _exportMarkdown,
                  onCreateCard: () => _createCardFromSelection(decksAsync),
                  onGenerateQaBank: _generateQaBankFromNote,
                  onGenerateQaQuiz: _generateQaQuizFromNote,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 11,
                              child: _EditorPane(
                                controller: _bodyController,
                                scrollController: _editorScrollController,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              flex: 10,
                              child: _PreviewPane(
                                markdown: _bodyController.text,
                                linkedNotes: linkedNotes,
                                onOpenLinkedNote: _openOrCreateLinkedNote,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            SizedBox(
                              width: 260,
                              child: _InsightsPane(
                                headings: headings,
                                backlinks: backlinks,
                                linkedNotes: linkedNotes,
                                onOpenLinkedNote: _openOrCreateLinkedNote,
                              ),
                            ),
                          ],
                        )
                      : DefaultTabController(
                          length: 3,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: 'Edit'),
                                  Tab(text: 'Preview'),
                                  Tab(text: 'Links'),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _EditorPane(
                                      controller: _bodyController,
                                      scrollController: _editorScrollController,
                                    ),
                                    _PreviewPane(
                                      markdown: _bodyController.text,
                                      linkedNotes: linkedNotes,
                                      onOpenLinkedNote: _openOrCreateLinkedNote,
                                    ),
                                    _InsightsPane(
                                      headings: headings,
                                      backlinks: backlinks,
                                      linkedNotes: linkedNotes,
                                      onOpenLinkedNote: _openOrCreateLinkedNote,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Could not load note: $error'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Could not load units: $error'),
      ),
    );
  }

  void _bindNote(NoteRecord note) {
    if (_boundNoteId == note.id) {
      return;
    }
    _isHydrating = true;
    _boundNoteId = note.id;
    _selectedUnitId = note.unitId;
    _titleController.text = note.title;
    _tagsController.text = note.tags.join(', ');
    _bodyController.text = note.bodyMarkdown;
    _hasPendingChanges = false;
    _isHydrating = false;
  }

  void _scheduleSave() {
    if (_isHydrating) {
      return;
    }
    _hasPendingChanges = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveNow);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveNow() async {
    if (!_hasPendingChanges || _boundNoteId == null || !mounted) {
      return;
    }

    final notes = await ref.read(subjectNotesControllerProvider(widget.subjectId).future);
    NoteRecord? note;
    for (final item in notes) {
      if (item.id == widget.noteId) {
        note = item;
        break;
      }
    }
    if (note == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedNote = note.copyWith(
        title: _titleController.text.trim(),
        unitId: _selectedUnitId,
        bodyMarkdown: _bodyController.text,
        tags: _tagsController.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      );
      final normalized = await ref
          .read(subjectNotesControllerProvider(widget.subjectId).notifier)
          .updateNote(updatedNote);
      _isHydrating = true;
      _titleController.text = normalized.title;
      _tagsController.text = normalized.tags.join(', ');
      _isHydrating = false;
      _hasPendingChanges = false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _handleBackNavigation() async {
    _saveDebounce?.cancel();
    await _saveNow();
    return true;
  }

  Future<void> _replaceBodyFromMarkdown() async {
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
      StudyDeskSecurity.ensureImportSize(
        bytes,
        label: file.name.isEmpty ? 'Markdown file' : file.name,
        maxBytes: StudyDeskSecurity.maxMarkdownImportBytes,
      );
      final markdown = StudyDeskSecurity.decodeUtf8(
        bytes,
        label: file.name.isEmpty ? 'Markdown file' : file.name,
      );
      setState(() {
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = deriveTitleFromMarkdown(markdown);
        }
        _bodyController.text = markdown;
      });
      _showMessage('Note body replaced from ${file.name}.');
    } catch (error) {
      _showMessage('Could not import Markdown: $error');
    }
  }

  Future<void> _openAiWorkspace() async {
    if (!mounted) {
      return;
    }
    context.push('/subjects/${widget.subjectId}/ai?kind=note&noteId=${widget.noteId}');
  }

  Future<void> _exportMarkdown() async {
    try {
      await _saveNow();
      final fileName = '${_titleController.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')}.md';
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Export StudyDesk note',
        fileName: fileName.isEmpty ? 'studydesk-note.md' : fileName,
        type: FileType.custom,
        allowedExtensions: const ['md'],
        bytes: Uint8List.fromList(utf8.encode(_bodyController.text)),
      );
      if (savedPath == null || !mounted) {
        return;
      }
      _showMessage('Exported note to $savedPath.');
    } catch (error) {
      _showMessage('Could not export note: $error');
    }
  }

  Future<void> _openOrCreateLinkedNote(String noteTitle) async {
    await _saveNow();
    final notes = await ref.read(subjectNotesControllerProvider(widget.subjectId).future);
      final existing = resolveLinkedNote(notes: notes, title: noteTitle);
    if (existing != null) {
      if (mounted) {
        context.push('/subjects/${widget.subjectId}/notes/${existing.id}');
      }
      return;
    }

    try {
      final created = await ref
          .read(subjectNotesControllerProvider(widget.subjectId).notifier)
          .createNote(
            subjectId: widget.subjectId,
            unitId: _selectedUnitId,
            title: noteTitle,
            bodyMarkdown: '# $noteTitle\n\n',
          );
      if (mounted) {
        context.push('/subjects/${widget.subjectId}/notes/${created.id}');
      }
    } catch (error) {
      _showMessage('Could not create linked note: $error');
    }
  }

  Future<void> _createCardFromSelection(AsyncValue<List<DeckRecord>> decksAsync) async {
    final selection = _bodyController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _showMessage('Select text in the note editor first to draft a flashcard.');
      return;
    }

    final selectedText = selection.textInside(_bodyController.text).trim();
    if (selectedText.isEmpty) {
      _showMessage('The selected text is empty.');
      return;
    }

    await _saveNow();

    final currentHeading = currentHeadingForOffset(
      _bodyController.text,
      selection.start,
    );
    DeckRecord? targetDeck;

    final decks = decksAsync.value ?? const <DeckRecord>[];
    targetDeck = await _chooseDeck(decks);
    if (targetDeck == null || !mounted) {
      return;
    }

    final front = currentHeading == null
        ? 'Recall from ${_titleController.text.trim()}'
        : 'Recall: $currentHeading';
    final draft = await showModalBottomSheet<CardDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CardEditorSheet(
        initialDraft: CardDraft(
          front: front,
          back: selectedText,
          hint: 'Generated from note selection.',
        ),
      ),
    );
    if (draft == null || !mounted) {
      return;
    }

    try {
      await ref.read(deckCardsControllerProvider(targetDeck.id).notifier).addCard(
            deckId: targetDeck.id,
            front: draft.front,
            back: draft.back,
            hint: draft.hint,
          );
      _showMessage('Added card to ${targetDeck.name}.');
    } catch (error) {
      _showMessage('Could not create card: $error');
    }
  }

  Future<void> _generateQaQuizFromNote() async {
    await _saveNow();
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled Note'
        : _titleController.text.trim();
    final sections = extractSections(_bodyController.text);
    if (sections.isEmpty) {
      _showMessage(
        'Add structured headings with content first so StudyDesk can generate Q&A prompts from the note.',
      );
      return;
    }

    final now = DateTime.now();
    final questions = <QuizQuestion>[];
    for (var index = 0; index < sections.length; index += 1) {
      final section = sections[index];
      final keywords = deriveKeywordsFromMarkdown(section.bodyMarkdown);
      if (keywords.isEmpty) {
        continue;
      }
      questions.add(
        QuizQuestion(
          id: '${now.microsecondsSinceEpoch}_note_qa_$index',
          type: QuizQuestionType.shortAnswer,
          question: 'Explain ${section.heading}.',
          options: const [],
          correctIndex: null,
          correctAnswer: null,
          correctAnswers: const [],
          caseSensitive: false,
          modelAnswer: section.bodyMarkdown,
          keywords: keywords,
          keywordRules: [
            for (final keyword in keywords)
              QuizKeywordRule(
                term: keyword,
                aliases: const [],
                required: true,
                weight: 1,
              ),
          ],
          minWords: 20,
          maxWords: null,
          minimumKeywordMatches: keywords.length >= 4 ? 2 : 1,
          minimumKeywordScorePercent: 0.35,
          allowPartialCredit: true,
          gradingMode: 'keywords',
          explanation: section.bodyMarkdown,
          points: 5,
          grading: null,
        ),
      );
    }

    if (questions.isEmpty) {
      _showMessage(
        'StudyDesk could not derive grading keywords from this note yet. Add more explanatory text under headings and try again.',
      );
      return;
    }

    final quiz = QuizRecord(
      id: now.microsecondsSinceEpoch.toString(),
      subjectId: widget.subjectId,
      unitId: _selectedUnitId,
      name: '$title Q&A Recall',
      description:
          'Generated from note sections in $title for structured recall practice.',
      tags: normalizeTags([
        ..._tagsController.text.split(',').map((tag) => tag.trim()),
        'notes-generated',
        'qa-recall',
      ]),
      settings: const QuizSettings(
        shuffleQuestions: false,
        shuffleOptions: false,
        timerMode: 'none',
        timerSeconds: 0,
        showFeedback: 'after_quiz',
        passingScorePercent: null,
        marking: QuizMarking(
          correctPoints: 5,
          wrongPoints: 0,
          skippedPoints: 0,
          negativeMarking: false,
          partialCredit: true,
        ),
        sectionRules: [],
      ),
      questions: questions,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref
          .read(subjectQuizzesControllerProvider(widget.subjectId).notifier)
          .upsertQuiz(quiz);
      _showMessage('Created ${quiz.name} with ${questions.length} Q&A prompts.');
    } catch (error) {
      _showMessage('Could not generate Q&A quiz: $error');
    }
  }

  Future<void> _generateQaBankFromNote() async {
    await _saveNow();
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled Note'
        : _titleController.text.trim();
    final sections = extractSections(_bodyController.text);
    if (sections.isEmpty) {
      _showMessage(
        'Add structured headings with content first so StudyDesk can create recall prompts from the note.',
      );
      return;
    }

    var createdCount = 0;
    for (final section in sections) {
      final answer = section.bodyMarkdown.trim();
      if (answer.isEmpty) {
        continue;
      }
      final question = 'Explain ${section.heading}.';
      await ref.read(subjectQaControllerProvider(widget.subjectId).notifier).upsertQa(
            subjectId: widget.subjectId,
            unitId: _selectedUnitId,
            question: question,
            answerMarkdown: answer,
            tags: normalizeTags([
              ..._tagsController.text.split(',').map((tag) => tag.trim()),
              'notes-generated',
              'qa-bank',
              title,
            ]),
          );
      createdCount += 1;
    }

    if (createdCount == 0) {
      _showMessage('No Q&A prompts could be created from this note yet.');
      return;
    }
    _showMessage('Created $createdCount Q&A prompt${createdCount == 1 ? '' : 's'} from this note.');
  }

  Future<DeckRecord?> _chooseDeck(List<DeckRecord> decks) async {
    return showModalBottomSheet<DeckRecord>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_box_rounded),
                title: const Text('Create new deck'),
                subtitle: const Text('Create a deck before saving this card'),
                onTap: () async {
                  final createdDeck = await _createDeckForCardFlow();
                  if (context.mounted) {
                    Navigator.of(context).pop(createdDeck);
                  }
                },
              ),
              if (decks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('No decks yet. Create one to store this card.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: decks.length,
                    itemBuilder: (context, index) {
                      final deck = decks[index];
                      return ListTile(
                        leading: const Icon(Icons.collections_bookmark_rounded),
                        title: Text(deck.name),
                        subtitle: Text(
                          deck.description.isEmpty ? 'No description' : deck.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(deck),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DeckRecord?> _createDeckForCardFlow() async {
    final draft = await showModalBottomSheet<DeckDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DeckEditorSheet(
        availableUnits:
            ref.read(subjectUnitsControllerProvider(widget.subjectId)).value ?? const [],
        initialUnitId: _selectedUnitId,
      ),
    );
    if (draft == null || !mounted) {
      return null;
    }
    try {
      return await ref.read(subjectDecksControllerProvider(widget.subjectId).notifier).addDeck(
            subjectId: widget.subjectId,
            unitId: draft.unitId ?? _selectedUnitId,
            name: draft.name,
            description: draft.description,
            tags: draft.tags,
          );
    } catch (error) {
      _showMessage('Could not create deck: $error');
      return null;
    }
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

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.titleController,
    required this.tagsController,
    required this.availableUnits,
    required this.selectedUnitId,
    required this.onUnitChanged,
    required this.isSaving,
    required this.onBack,
    required this.onOpenReader,
    required this.onImportFromAi,
    required this.onImportBody,
    required this.onExportMarkdown,
    required this.onCreateCard,
    required this.onGenerateQaBank,
    required this.onGenerateQaQuiz,
  });

  final TextEditingController titleController;
  final TextEditingController tagsController;
  final List<SubjectUnitRecord> availableUnits;
  final String? selectedUnitId;
  final ValueChanged<String?> onUnitChanged;
  final bool isSaving;
  final Future<void> Function() onBack;
  final VoidCallback onOpenReader;
  final Future<void> Function() onImportFromAi;
  final Future<void> Function() onImportBody;
  final Future<void> Function() onExportMarkdown;
  final Future<void> Function() onCreateCard;
  final Future<void> Function() onGenerateQaBank;
  final Future<void> Function() onGenerateQaQuiz;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to notes',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: TextField(
                controller: titleController,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Untitled Note',
                ),
              ),
            ),
            if (isSaving)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  'Saved locally',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.sell_outlined),
                  labelText: 'Tags',
                  hintText: 'chemistry, revision, formulas',
                ),
              ),
            ),
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String?>(
                initialValue: selectedUnitId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.folder_copy_outlined),
                  labelText: 'Unit',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Uncategorized'),
                  ),
                  for (final unit in availableUnits)
                    DropdownMenuItem<String?>(
                      value: unit.id,
                      child: Text(unit.name),
                    ),
                ],
                onChanged: onUnitChanged,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenReader,
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Read'),
            ),
            FilledButton.tonalIcon(
              onPressed: onImportFromAi,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('AI Workspace'),
            ),
            FilledButton.tonalIcon(
              onPressed: onImportBody,
              icon: const Icon(Icons.file_open_rounded),
              label: const Text('Replace from Markdown'),
            ),
            FilledButton.tonalIcon(
              onPressed: onExportMarkdown,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export .md'),
            ),
            FilledButton.icon(
              onPressed: onCreateCard,
              icon: const Icon(Icons.style_rounded),
              label: const Text('Create Card from Selection'),
            ),
            FilledButton.tonalIcon(
              onPressed: onGenerateQaBank,
              icon: const Icon(Icons.record_voice_over_rounded),
              label: const Text('Generate Q&A Bank'),
            ),
            FilledButton.tonalIcon(
              onPressed: onGenerateQaQuiz,
              icon: const Icon(Icons.quiz_rounded),
              label: const Text('Generate Q&A Quiz'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({
    required this.controller,
    required this.scrollController,
  });

  final TextEditingController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Markdown Editor',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                scrollController: scrollController,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'Courier New',
                      height: 1.55,
                    ),
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  hintText: '# Title\n\nWrite Markdown, LaTeX, and [[wiki links]] here.',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.markdown,
    required this.linkedNotes,
    required this.onOpenLinkedNote,
  });

  final String markdown;
  final List<NoteLinkMatch> linkedNotes;
  final ValueChanged<String> onOpenLinkedNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Live Preview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${markdown.length} chars',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: markdown.trim().isEmpty
                  ? const Center(
                      child: Text('Start writing to preview this note.'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: MarkdownContent(
                        data: markdown,
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
            if (linkedNotes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final link in linkedNotes.take(8))
                    ActionChip(
                      label: Text(link.label),
                      onPressed: () => onOpenLinkedNote(link.title),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightsPane extends StatelessWidget {
  const _InsightsPane({
    required this.headings,
    required this.backlinks,
    required this.linkedNotes,
    required this.onOpenLinkedNote,
  });

  final List<NoteHeading> headings;
  final List<NoteRecord> backlinks;
  final List<NoteLinkMatch> linkedNotes;
  final ValueChanged<String> onOpenLinkedNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: [
            Text(
              'Outline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (headings.isEmpty)
              const Text('Use headings to structure this note.')
            else
              for (final heading in headings)
                Padding(
                  padding: EdgeInsets.only(
                    left: (heading.level - 1) * 10,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(heading.text),
                ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Backlinks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (backlinks.isEmpty)
              const Text('No other notes link to this one yet.')
            else
              for (final note in backlinks)
                TextButton(
                  onPressed: () => onOpenLinkedNote(note.title),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(note.title),
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Outgoing Links',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (linkedNotes.isEmpty)
              const Text('Use [[Note Title]] to create connected notes.')
            else
              for (final link in linkedNotes)
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
    );
  }
}

class _MissingNoteState extends StatelessWidget {
  const _MissingNoteState({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.note_alt_outlined, size: 52),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Note not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This note may have been removed or renamed locally.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go('/subjects/$subjectId/notes');
              },
              child: const Text('Back to Notes'),
            ),
          ],
        ),
      ),
    );
  }
}
