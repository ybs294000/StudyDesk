import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/cards/data/cards_repository.dart';
import '../features/cards/domain/card_record.dart';
import '../features/decks/data/decks_repository.dart';
import '../features/decks/domain/deck_record.dart';
import '../features/notes/application/note_markdown_utils.dart';
import '../features/quizzes/data/quizzes_repository.dart';
import '../features/quizzes/domain/quiz_models.dart';

final contentPortabilityServiceProvider = Provider<ContentPortabilityService>((
  ref,
) {
  return ContentPortabilityService(
    decksRepository: ref.read(decksRepositoryProvider),
    cardsRepository: ref.read(cardsRepositoryProvider),
    quizzesRepository: ref.read(quizzesRepositoryProvider),
  );
});

class ContentPortabilityService {
  ContentPortabilityService({
    required this.decksRepository,
    required this.cardsRepository,
    required this.quizzesRepository,
  });

  final DecksRepository decksRepository;
  final CardsRepository cardsRepository;
  final QuizzesRepository quizzesRepository;

  Future<StudyImportResult> importStudyJson({
    required String subjectId,
    required String jsonSource,
    String? unitId,
  }) async {
    final parsed = jsonDecode(jsonSource) as Map<String, dynamic>;
    final type = parsed['type'];

    switch (type) {
      case 'deck':
        final result = await importDeckJson(
          subjectId: subjectId,
          jsonSource: jsonSource,
          unitId: unitId,
        );
        return StudyImportResult.deck(
          id: result.deckId,
          name: result.deckName,
          itemCount: result.importedCardCount,
        );
      case 'quiz':
        final result = await importQuizJson(
          subjectId: subjectId,
          jsonSource: jsonSource,
          unitId: unitId,
        );
        return StudyImportResult.quiz(
          id: result.quizId,
          name: result.quizName,
          itemCount: result.importedQuestionCount,
        );
      default:
        throw FormatException(
          'Unsupported StudyDesk JSON type: $type. Expected "deck" or "quiz".',
        );
    }
  }

  Future<DeckImportResult> importDeckJson({
    required String subjectId,
    required String jsonSource,
    String? unitId,
  }) async {
    final parsed = jsonDecode(jsonSource) as Map<String, dynamic>;
    final version =
        parsed['studydesk_version'] ?? parsed['studyforge_version'];
    if (version == null) {
      throw const FormatException('Missing version field in JSON.');
    }

    final type = parsed['type'];
    if (type != 'deck') {
      throw FormatException('Only deck imports are supported right now, got: $type');
    }

    final content = parsed['content'] as Map<String, dynamic>? ?? const {};
    final name = (content['name'] as String?)?.trim();
    final description = (content['description'] as String?)?.trim() ?? '';
    final tags = normalizeTags(((content['tags'] as List?) ?? const []).cast<String>());
    final cards = content['cards'] as List<dynamic>? ?? const [];

    if (name == null || name.isEmpty) {
      throw const FormatException('Deck import is missing a name.');
    }
    if (cards.isEmpty) {
      throw const FormatException('Deck import contains no cards.');
    }

    final now = DateTime.now();
    final deckId = now.microsecondsSinceEpoch.toString();
    final newDeck = DeckRecord(
      id: deckId,
      subjectId: subjectId,
      unitId: unitId,
      name: name,
      description: description,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    final allDecks = await decksRepository.loadDecks();
    await decksRepository.saveDecks([...allDecks, newDeck]);

    final allCards = await cardsRepository.loadCards();
    final importedCards = <CardRecord>[];
    for (var index = 0; index < cards.length; index += 1) {
      final raw = cards[index] as Map<String, dynamic>;
      final front = (raw['front'] as String?)?.trim();
      final back = (raw['back'] as String?)?.trim();
      if (front == null || front.isEmpty || back == null || back.isEmpty) {
        throw FormatException('Card ${index + 1} is missing front/back text.');
      }
      importedCards.add(
        CardRecord(
          id: '${now.microsecondsSinceEpoch}_$index',
          deckId: deckId,
          front: front,
          back: back,
          hint: ((raw['hint'] as String?) ?? '').trim(),
          schedulerVersion: 'adaptive_memory_v2',
          state: 'new',
          reviewCount: 0,
          lapseCount: 0,
          intervalDays: 0,
          ease: 2.5,
          stability: 0.2,
          difficulty: 5.0,
          dueAt: null,
          lastReviewedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await cardsRepository.saveCards([...allCards, ...importedCards]);

    return DeckImportResult(
      deckId: deckId,
      deckName: newDeck.name,
      importedCardCount: importedCards.length,
    );
  }

  Future<DeckImportResult> importDeckAsset({
    required String subjectId,
    required String assetPath,
    String? unitId,
  }) async {
    final jsonSource = await rootBundle.loadString(assetPath);
    return importDeckJson(
      subjectId: subjectId,
      jsonSource: jsonSource,
      unitId: unitId,
    );
  }

  Future<QuizImportResult> importQuizJson({
    required String subjectId,
    required String jsonSource,
    String? unitId,
  }) async {
    final parsed = jsonDecode(jsonSource) as Map<String, dynamic>;
    final version =
        parsed['studydesk_version'] ?? parsed['studyforge_version'];
    if (version == null) {
      throw const FormatException('Missing version field in JSON.');
    }
    if (parsed['type'] != 'quiz') {
      throw FormatException(
        'Only quiz imports are supported in this path, got: ${parsed['type']}',
      );
    }

    final content = parsed['content'] as Map<String, dynamic>? ?? const {};
    final name = (content['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw const FormatException('Quiz import is missing a name.');
    }

    final questions = (content['questions'] as List?) ?? const [];
    if (questions.isEmpty) {
      throw const FormatException('Quiz import contains no questions.');
    }

    final parsedQuestions = questions
        .map((question) => QuizQuestion.fromMap((question as Map).cast<String, dynamic>()))
        .toList();
    _validateQuizQuestions(parsedQuestions);

    final now = DateTime.now();
    final quiz = QuizRecord(
      id: now.microsecondsSinceEpoch.toString(),
      subjectId: subjectId,
      unitId: unitId,
      name: name,
      description: (content['description'] as String?)?.trim() ?? '',
      tags: normalizeTags(((content['tags'] as List?) ?? const []).cast<String>()),
      settings: QuizSettings.fromMap(
        (content['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      questions: parsedQuestions,
      createdAt: now,
      updatedAt: now,
    );

    final allQuizzes = await quizzesRepository.loadQuizzes();
    await quizzesRepository.saveQuizzes([...allQuizzes, quiz]);

    return QuizImportResult(
      quizId: quiz.id,
      quizName: quiz.name,
      importedQuestionCount: quiz.questions.length,
    );
  }

  Future<QuizImportResult> importQuizAsset({
    required String subjectId,
    required String assetPath,
    String? unitId,
  }) async {
    final jsonSource = await rootBundle.loadString(assetPath);
    return importQuizJson(
      subjectId: subjectId,
      jsonSource: jsonSource,
      unitId: unitId,
    );
  }

  Future<String> exportDeckJson({
    required DeckRecord deck,
    required List<CardRecord> cards,
  }) async {
    final payload = {
      'studydesk_version': '1.0',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'type': 'deck',
      'content': {
        'name': deck.name,
        'description': deck.description,
        'tags': deck.tags,
        'cards': [
          for (final card in cards)
            {
              'id': card.id,
              'front': card.front,
              'back': card.back,
              'front_image': null,
              'back_image': null,
              'tags': <String>[],
              'hint': card.hint.isEmpty ? null : card.hint,
            },
        ],
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  void _validateQuizQuestions(List<QuizQuestion> questions) {
    for (var index = 0; index < questions.length; index += 1) {
      final question = questions[index];
      if (question.question.trim().isEmpty) {
        throw FormatException('Question ${index + 1} is missing question text.');
      }
      if (question.type == QuizQuestionType.mcq) {
        if (question.options.length < 2) {
          throw FormatException('Question ${index + 1} needs at least two options.');
        }
        final correctIndex = question.correctIndex;
        if (correctIndex == null ||
            correctIndex < 0 ||
            correctIndex >= question.options.length) {
          throw FormatException('Question ${index + 1} has an invalid correct option index.');
        }
      }
      if (question.type == QuizQuestionType.fillBlank &&
          question.correctAnswers.every((answer) => answer.trim().isEmpty)) {
        throw FormatException('Question ${index + 1} needs at least one accepted answer.');
      }
      if (question.type == QuizQuestionType.trueFalse &&
          question.correctAnswer == null) {
        throw FormatException('Question ${index + 1} must define true or false.');
      }
      if (question.type == QuizQuestionType.shortAnswer) {
        final hasRequiredRule = question.keywordRules.any(
          (rule) => rule.required && rule.term.trim().isNotEmpty,
        );
        final hasLegacyKeywords = question.keywords.any(
          (keyword) => keyword.trim().isNotEmpty,
        );
        if (!hasRequiredRule && !hasLegacyKeywords) {
          throw FormatException(
            'Question ${index + 1} needs at least one required keyword for grading.',
          );
        }
      }
    }
  }
}

class DeckImportResult {
  const DeckImportResult({
    required this.deckId,
    required this.deckName,
    required this.importedCardCount,
  });

  final String deckId;
  final String deckName;
  final int importedCardCount;
}

class QuizImportResult {
  const QuizImportResult({
    required this.quizId,
    required this.quizName,
    required this.importedQuestionCount,
  });

  final String quizId;
  final String quizName;
  final int importedQuestionCount;
}

enum StudyImportType { deck, quiz }

class StudyImportResult {
  const StudyImportResult({
    required this.type,
    required this.id,
    required this.name,
    required this.itemCount,
  });

  const StudyImportResult.deck({
    required String id,
    required String name,
    required int itemCount,
  }) : this(
         type: StudyImportType.deck,
         id: id,
         name: name,
         itemCount: itemCount,
       );

  const StudyImportResult.quiz({
    required String id,
    required String name,
    required int itemCount,
  }) : this(
         type: StudyImportType.quiz,
         id: id,
         name: name,
         itemCount: itemCount,
       );

  final StudyImportType type;
  final String id;
  final String name;
  final int itemCount;
}
