import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notes_repository.dart';
import '../domain/note_record.dart';
import 'note_markdown_utils.dart';

final subjectNotesControllerProvider = AsyncNotifierProviderFamily<
    SubjectNotesController, List<NoteRecord>, String>(SubjectNotesController.new);

class SubjectNotesController extends FamilyAsyncNotifier<List<NoteRecord>, String> {
  NotesRepository get _repository => ref.read(notesRepositoryProvider);

  @override
  Future<List<NoteRecord>> build(String arg) async {
    final notes = await _repository.loadNotes();
    return _forSubject(notes, arg);
  }

  Future<NoteRecord> createNote({
    required String subjectId,
    required String title,
    String bodyMarkdown = '',
    List<String> tags = const [],
    String? unitId,
  }) async {
    final allNotes = await _repository.loadNotes();
    final now = DateTime.now();
    final normalizedTitle = _ensureUniqueTitle(
      title: title.trim().isEmpty ? 'Untitled Note' : title.trim(),
      subjectId: subjectId,
      notes: allNotes,
    );
    final note = NoteRecord(
      id: now.microsecondsSinceEpoch.toString(),
      subjectId: subjectId,
      unitId: unitId,
      title: normalizedTitle,
      bodyMarkdown: bodyMarkdown,
      tags: normalizeTags(tags),
      createdAt: now,
      updatedAt: now,
    );
    final updated = [...allNotes, note];
    await _repository.upsertNote(note);
    state = AsyncData(_forSubject(updated, subjectId));
    return note;
  }

  Future<NoteRecord> importMarkdownNote({
    required String subjectId,
    required String title,
    required String bodyMarkdown,
    List<String> tags = const [],
    String? unitId,
  }) async {
    return createNote(
      subjectId: subjectId,
      title: title,
      bodyMarkdown: bodyMarkdown,
      tags: tags,
      unitId: unitId,
    );
  }

  Future<NoteRecord> updateNote(NoteRecord note) async {
    final allNotes = await _repository.loadNotes();
    final normalizedTitle = _ensureUniqueTitle(
      title: note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim(),
      subjectId: note.subjectId,
      notes: allNotes,
      noteId: note.id,
    );
    final normalizedNote = note.copyWith(
      title: normalizedTitle,
      tags: normalizeTags(note.tags),
      updatedAt: DateTime.now(),
    );
    final updated = allNotes
        .map((item) => item.id == normalizedNote.id ? normalizedNote : item)
        .toList();
    await _repository.upsertNote(normalizedNote);
    state = AsyncData(_forSubject(updated, arg));
    return normalizedNote;
  }

  Future<void> deleteNote(String noteId) async {
    final allNotes = await _repository.loadNotes();
    final updated = allNotes.where((note) => note.id != noteId).toList();
    await _repository.deleteNote(noteId);
    state = AsyncData(_forSubject(updated, arg));
  }

  List<NoteRecord> _forSubject(List<NoteRecord> notes, String subjectId) {
    final filtered = notes.where((note) => note.subjectId == subjectId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  String _ensureUniqueTitle({
    required String title,
    required String subjectId,
    required List<NoteRecord> notes,
    String? noteId,
  }) {
    final base = title.trim().isEmpty ? 'Untitled Note' : title.trim();
    final existingTitles = notes
        .where((note) => note.subjectId == subjectId && note.id != noteId)
        .map((note) => note.title.trim().toLowerCase())
        .toSet();

    if (!existingTitles.contains(base.toLowerCase())) {
      return base;
    }

    var suffix = 2;
    while (existingTitles.contains('$base ($suffix)'.toLowerCase())) {
      suffix += 1;
    }
    return '$base ($suffix)';
  }
}
