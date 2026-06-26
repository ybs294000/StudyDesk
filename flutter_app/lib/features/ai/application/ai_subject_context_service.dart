import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/data/cards_repository.dart';
import '../../decks/data/decks_repository.dart';
import '../../notes/data/notes_repository.dart';
import '../../qa/data/qa_items_repository.dart';
import '../../quizzes/domain/quiz_models.dart';
import '../../quizzes/data/quizzes_repository.dart';
import '../../subjects/data/subjects_repository.dart';
import '../../units/data/subject_units_repository.dart';

final aiSubjectContextServiceProvider = Provider<AiSubjectContextService>((ref) {
  return AiSubjectContextService(
    subjectsRepository: ref.read(subjectsRepositoryProvider),
    unitsRepository: ref.read(subjectUnitsRepositoryProvider),
    decksRepository: ref.read(decksRepositoryProvider),
    cardsRepository: ref.read(cardsRepositoryProvider),
    quizzesRepository: ref.read(quizzesRepositoryProvider),
    notesRepository: ref.read(notesRepositoryProvider),
    qaItemsRepository: ref.read(qaItemsRepositoryProvider),
  );
});

class AiSubjectContextService {
  AiSubjectContextService({
    required this.subjectsRepository,
    required this.unitsRepository,
    required this.decksRepository,
    required this.cardsRepository,
    required this.quizzesRepository,
    required this.notesRepository,
    required this.qaItemsRepository,
  });

  final SubjectsRepository subjectsRepository;
  final SubjectUnitsRepository unitsRepository;
  final DecksRepository decksRepository;
  final CardsRepository cardsRepository;
  final QuizzesRepository quizzesRepository;
  final NotesRepository notesRepository;
  final QaItemsRepository qaItemsRepository;

  Future<String> buildSubjectContext({
    required String subjectId,
    String? noteId,
  }) async {
    final subjects = await subjectsRepository.loadSubjects();
    final subject = subjects.firstWhere(
      (item) => item.id == subjectId,
      orElse: () => throw StateError('Subject not found for AI workspace.'),
    );
    final units = (await unitsRepository.loadUnits())
        .where((item) => item.subjectId == subjectId)
        .toList();
    final decks = (await decksRepository.loadDecks())
        .where((item) => item.subjectId == subjectId)
        .toList();
    final quizzes = (await quizzesRepository.loadQuizzes())
        .where((item) => item.subjectId == subjectId)
        .toList();
    final notes = (await notesRepository.loadNotes())
        .where((item) => item.subjectId == subjectId)
        .toList();
    final qaItems = (await qaItemsRepository.loadItems())
        .where((item) => item.subjectId == subjectId)
        .toList();
    final cards = (await cardsRepository.loadCards())
        .where((card) => decks.any((deck) => deck.id == card.deckId))
        .toList();

    final selectedNote = noteId == null
        ? null
        : notes.where((item) => item.id == noteId).firstOrNull;

    final payload = <String, dynamic>{
      'subject': {
        'id': subject.id,
        'name': subject.name,
        'emoji': subject.emoji,
      },
      'units': [
        for (final unit in units.take(12))
          {
            'id': unit.id,
            'name': unit.name,
            'description': unit.description,
          },
      ],
      'existing_decks': [
        for (final deck in decks.take(8))
          {
            'id': deck.id,
            'name': deck.name,
            'description': deck.description,
            'tags': deck.tags,
            'sample_card_fronts': [
              for (final card in cards.where((item) => item.deckId == deck.id).take(3))
                _clip(card.front, 240),
            ],
          },
      ],
      'existing_quizzes': [
        for (final quiz in quizzes.take(8))
          {
            'id': quiz.id,
            'name': quiz.name,
            'description': quiz.description,
            'tags': quiz.tags,
            'question_count': quiz.questions.length,
            'sample_questions': [
              for (final question in quiz.questions.take(3))
                {
                  'type': question.type.storageValue,
                  'question': _clip(question.question, 240),
                },
            ],
          },
      ],
      'existing_notes': [
        for (final note in notes.take(10))
          {
            'id': note.id,
            'title': note.title,
            'tags': note.tags,
            'excerpt': _clip(note.excerpt, 240),
          },
      ],
      'existing_qa_bank': [
        for (final item in qaItems.take(10))
          {
            'id': item.id,
            'question': _clip(item.question, 240),
            'tags': item.tags,
            'answer_excerpt': _clip(item.excerpt, 240),
          },
      ],
      if (selectedNote != null)
        'active_note': {
          'id': selectedNote.id,
          'title': selectedNote.title,
          'tags': selectedNote.tags,
          'body_markdown': _clip(selectedNote.bodyMarkdown, 12000),
        },
      'guidance': {
        'avoid_duplicate_titles': true,
        'prefer_existing_units': units.map((unit) => unit.name).toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _clip(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 3)}...';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
