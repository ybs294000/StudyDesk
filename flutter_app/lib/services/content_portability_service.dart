import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/profile_settings_controller.dart';
import '../features/cards/data/cards_repository.dart';
import '../features/cards/domain/card_record.dart';
import '../features/dashboard/application/dashboard_summary_provider.dart';
import '../features/decks/data/decks_repository.dart';
import '../features/decks/domain/deck_record.dart';
import '../features/gamification/application/gamification_summary_provider.dart';
import '../features/notes/application/note_markdown_utils.dart';
import '../features/notes/data/note_review_repository.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/domain/note_record.dart';
import '../features/notes/domain/note_review_record.dart';
import '../features/qa/data/qa_items_repository.dart';
import '../features/qa/data/qa_review_repository.dart';
import '../features/qa/domain/qa_item_record.dart';
import '../features/qa/domain/qa_review_record.dart';
import '../features/quizzes/data/quiz_attempts_repository.dart';
import '../features/quizzes/data/quizzes_repository.dart';
import '../features/quizzes/domain/quiz_attempt_session_record.dart';
import '../features/quizzes/domain/quiz_models.dart';
import '../features/study/data/study_sessions_repository.dart';
import '../features/study/domain/study_session_record.dart';
import '../features/subjects/data/subjects_repository.dart';
import '../features/subjects/domain/subject_record.dart';
import '../features/units/data/subject_units_repository.dart';
import '../features/units/domain/subject_unit_record.dart';

final contentPortabilityServiceProvider = Provider<ContentPortabilityService>((ref) {
  return ContentPortabilityService(
    decksRepository: ref.read(decksRepositoryProvider),
    cardsRepository: ref.read(cardsRepositoryProvider),
    quizzesRepository: ref.read(quizzesRepositoryProvider),
    notesRepository: ref.read(notesRepositoryProvider),
    noteReviewRepository: ref.read(noteReviewRepositoryProvider),
    qaItemsRepository: ref.read(qaItemsRepositoryProvider),
    qaReviewRepository: ref.read(qaReviewRepositoryProvider),
    subjectsRepository: ref.read(subjectsRepositoryProvider),
    unitsRepository: ref.read(subjectUnitsRepositoryProvider),
    studySessionsRepository: ref.read(studySessionsRepositoryProvider),
    quizAttemptsRepository: ref.read(quizAttemptsRepositoryProvider),
    readDailyGoalMinutes: () => ref.read(profileSettingsControllerProvider).dailyGoalMinutes,
    readFlashcardSchedulingEnabled: () =>
        ref.read(profileSettingsControllerProvider).flashcardSpacedRepetitionEnabled,
    readNoteSchedulingEnabled: () =>
        ref.read(profileSettingsControllerProvider).noteSpacedRepetitionEnabled,
    readQaSchedulingEnabled: () =>
        ref.read(profileSettingsControllerProvider).qaSpacedRepetitionEnabled,
    readQuizSchedulingEnabled: () =>
        ref.read(profileSettingsControllerProvider).quizPracticeSchedulingEnabled,
  );
});

class ContentPortabilityService {
  ContentPortabilityService({
    required this.decksRepository,
    required this.cardsRepository,
    required this.quizzesRepository,
    required this.notesRepository,
    required this.noteReviewRepository,
    required this.qaItemsRepository,
    required this.qaReviewRepository,
    required this.subjectsRepository,
    required this.unitsRepository,
    required this.studySessionsRepository,
    required this.quizAttemptsRepository,
    required this.readDailyGoalMinutes,
    required this.readFlashcardSchedulingEnabled,
    required this.readNoteSchedulingEnabled,
    required this.readQaSchedulingEnabled,
    required this.readQuizSchedulingEnabled,
  });

  final DecksRepository decksRepository;
  final CardsRepository cardsRepository;
  final QuizzesRepository quizzesRepository;
  final NotesRepository notesRepository;
  final NoteReviewRepository noteReviewRepository;
  final QaItemsRepository qaItemsRepository;
  final QaReviewRepository qaReviewRepository;
  final SubjectsRepository subjectsRepository;
  final SubjectUnitsRepository unitsRepository;
  final StudySessionsRepository studySessionsRepository;
  final QuizAttemptsRepository quizAttemptsRepository;
  final int Function() readDailyGoalMinutes;
  final bool Function() readFlashcardSchedulingEnabled;
  final bool Function() readNoteSchedulingEnabled;
  final bool Function() readQaSchedulingEnabled;
  final bool Function() readQuizSchedulingEnabled;

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

  Future<DeckImportResult> importDeckCsv({
    required String subjectId,
    required String csvSource,
    String? unitId,
    String? deckName,
    String? description,
    List<String> tags = const [],
  }) async {
    final rows = const LineSplitter()
        .convert(csvSource)
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (rows.isEmpty) {
      throw const FormatException('CSV import contains no rows.');
    }

    final parsedCards = <({String front, String back})>[];
    var startIndex = 0;
    if (_looksLikeCsvHeader(rows.first)) {
      startIndex = 1;
    }
    for (var index = startIndex; index < rows.length; index += 1) {
      final columns = _parseCsvLine(rows[index]);
      if (columns.length < 2) {
        throw FormatException('CSV row ${index + 1} must have at least two columns.');
      }
      final front = columns[0].trim();
      final back = columns[1].trim();
      if (front.isEmpty || back.isEmpty) {
        throw FormatException('CSV row ${index + 1} must include both front and back text.');
      }
      parsedCards.add((front: front, back: back));
    }
    if (parsedCards.isEmpty) {
      throw const FormatException('CSV import did not contain any usable flashcards.');
    }

    final now = DateTime.now();
    final resolvedDeckName = (deckName == null || deckName.trim().isEmpty)
        ? 'Imported CSV Deck'
        : deckName.trim();
    final deckId = now.microsecondsSinceEpoch.toString();
    final newDeck = DeckRecord(
      id: deckId,
      subjectId: subjectId,
      unitId: unitId,
      name: resolvedDeckName,
      description: description?.trim() ?? '',
      tags: normalizeTags(tags),
      createdAt: now,
      updatedAt: now,
    );
    await decksRepository.upsertDeck(newDeck);

    final importedCards = <CardRecord>[];
    for (var index = 0; index < parsedCards.length; index += 1) {
      final card = parsedCards[index];
      importedCards.add(
        CardRecord(
          id: '${now.microsecondsSinceEpoch}_csv_$index',
          deckId: deckId,
          front: card.front,
          back: card.back,
          hint: '',
          schedulerVersion: CardRecord.defaultSchedulerVersion,
          state: 'new',
          reviewCount: 0,
          lapseCount: 0,
          intervalDays: 0,
          ease: 2.5,
          stability: 0.1,
          difficulty: 5.0,
          dueAt: null,
          lastReviewedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await cardsRepository.upsertCards(importedCards);

    return DeckImportResult(
      deckId: deckId,
      deckName: newDeck.name,
      importedCardCount: importedCards.length,
    );
  }

  Future<DeckImportResult> importDeckJson({
    required String subjectId,
    required String jsonSource,
    String? unitId,
  }) async {
    final parsed = jsonDecode(jsonSource) as Map<String, dynamic>;
    final version = parsed['studydesk_version'] ?? parsed['studyforge_version'];
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

    await decksRepository.upsertDeck(newDeck);

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
          schedulerVersion: CardRecord.defaultSchedulerVersion,
          state: 'new',
          reviewCount: 0,
          lapseCount: 0,
          intervalDays: 0,
          ease: 2.5,
          stability: 0.1,
          difficulty: 5.0,
          dueAt: null,
          lastReviewedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await cardsRepository.upsertCards(importedCards);

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
    final version = parsed['studydesk_version'] ?? parsed['studyforge_version'];
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
        .map(
          (question) => QuizQuestion.fromMap(
            (question as Map).cast<String, dynamic>(),
          ),
        )
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

    await quizzesRepository.upsertQuiz(quiz);

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

  Future<List<QuizAttemptSessionRecord>> loadQuizAttempts() {
    return quizAttemptsRepository.loadAttempts();
  }

  Future<QuizAttemptSessionRecord?> latestAttemptForQuiz(String quizId) async {
    final attempts = await quizAttemptsRepository.loadAttempts();
    for (final attempt in attempts) {
      if (attempt.quizId == quizId) {
        return attempt;
      }
    }
    return null;
  }

  Future<QuizRecord?> buildRetryQuizFromLatestAttempt(String quizId) async {
    final attempt = await latestAttemptForQuiz(quizId);
    if (attempt == null) {
      return null;
    }
    final wrongItems = attempt.items
        .where((item) => !item.isCorrect || item.wasSkipped)
        .toList();
    if (wrongItems.isEmpty) {
      return null;
    }

    final questions = wrongItems
        .map(_wrongItemToQuizQuestion)
        .whereType<QuizQuestion>()
        .toList();
    if (questions.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    return QuizRecord(
      id: now.microsecondsSinceEpoch.toString(),
      subjectId: attempt.subjectId,
      unitId: attempt.unitId,
      name: '${attempt.quizName} Retry Wrong Answers',
      description:
          'Generated from incorrect or skipped answers in the latest attempt of ${attempt.quizName}.',
      tags: normalizeTags([
        ...attempt.quizTags,
        'retry',
        'wrong-answers',
      ]),
      settings: const QuizSettings(
        shuffleQuestions: false,
        shuffleOptions: false,
        timerMode: 'none',
        timerSeconds: 0,
        showFeedback: 'after_quiz',
        passingScorePercent: null,
        marking: QuizMarking(
          correctPoints: 1,
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
  }

  Future<List<QuizAttemptSessionRecord>> attemptsForSubject(String subjectId) async {
    final attempts = await quizAttemptsRepository.loadAttempts();
    return attempts.where((attempt) => attempt.subjectId == subjectId).toList();
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
    return _prettyJson(payload);
  }

  Future<String> exportQuizJson({
    required QuizRecord quiz,
  }) async {
    final payload = {
      'studydesk_version': '1.0',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'type': 'quiz',
      'content': {
        'name': quiz.name,
        'description': quiz.description,
        'tags': quiz.tags,
        'settings': quiz.settings.toMap(),
        'questions': quiz.questions.map((question) => question.toMap()).toList(),
      },
    };
    return _prettyJson(payload);
  }

  Future<String> exportQuizAttemptJson({
    required QuizAttemptSessionRecord attempt,
  }) async {
    final payload = {
      'studydesk_version': '1.0',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'type': 'quiz_attempt',
      'content': {
        'quizTitle': attempt.quizName,
        'subjectId': attempt.subjectId,
        'quizId': attempt.quizId,
        'attemptId': attempt.id,
        'mode': attempt.mode,
        'startedAt': attempt.startedAt.toIso8601String(),
        'endedAt': attempt.endedAt.toIso8601String(),
        'durationSeconds': attempt.duration.inSeconds,
        'totalQuestions': attempt.totalQuestions,
        'attempted': attempt.attemptedQuestions,
        'correct': attempt.correctCount,
        'wrong': attempt.wrongCount,
        'skipped': attempt.skippedCount,
        'rawScore': attempt.rawScore,
        'maxScore': attempt.maxScore,
        'scorePercent': attempt.scorePercent,
        'passingScorePercent': attempt.passingScorePercent,
        'passed': attempt.passed,
        'weakTags': attempt.weakTags,
        'strongTags': attempt.strongTags,
        'questions': attempt.items.map((item) => item.toMap()).toList(),
      },
    };
    return _prettyJson(payload);
  }

  Future<String> exportQuizAttemptAiPackageJson({
    required QuizAttemptSessionRecord attempt,
  }) async {
    final payload = {
      'studydesk_version': '1.0',
      'type': 'ai_review_package',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'prompt':
          'Analyze this StudyDesk quiz attempt. Identify weak areas by tag and by question type. Then generate a focused remediation plan and 10 follow-up StudyDesk quiz questions that target the weakest concepts.',
      'attempt': attempt.toMap(),
    };
    return _prettyJson(payload);
  }

  Future<String> exportQaBankJson({
    required String subjectId,
  }) async {
    final subjects = await subjectsRepository.loadSubjects();
    final subject = subjects.where((item) => item.id == subjectId).firstOrNull;
    if (subject == null) {
      throw StateError('Subject $subjectId could not be found for Q&A export.');
    }
    final units = (await unitsRepository.loadUnits())
        .where((unit) => unit.subjectId == subjectId)
        .toList();
    final items = (await qaItemsRepository.loadItems())
        .where((item) => item.subjectId == subjectId)
        .toList();
    final reviews = (await qaReviewRepository.loadReviews())
        .where((review) => review.subjectId == subjectId)
        .toList();

    final payload = {
      'studydesk_version': '1.0',
      'type': 'qa_bank',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'subject': subject.toMap(),
      'units': units.map((unit) => unit.toMap()).toList(),
      'items': items.map((item) => item.toMap()).toList(),
      'reviews': reviews.map((review) => review.toMap()).toList(),
    };
    return _prettyJson(payload);
  }

  Future<String> exportQaBankMarkdown({
    required String subjectId,
  }) async {
    final subjects = await subjectsRepository.loadSubjects();
    final subject = subjects.where((item) => item.id == subjectId).firstOrNull;
    if (subject == null) {
      throw StateError('Subject $subjectId could not be found for Q&A export.');
    }
    final units = (await unitsRepository.loadUnits())
        .where((unit) => unit.subjectId == subjectId)
        .toList();
    final items = (await qaItemsRepository.loadItems())
        .where((item) => item.subjectId == subjectId)
        .toList()
      ..sort((a, b) => a.question.toLowerCase().compareTo(b.question.toLowerCase()));
    final unitById = {for (final unit in units) unit.id: unit};

    final buffer = StringBuffer()
      ..writeln('# ${subject.name} Q&A Bank')
      ..writeln()
      ..writeln('Generated by StudyDesk on ${DateTime.now().toLocal().toIso8601String()}.')
      ..writeln();

    if (items.isEmpty) {
      buffer.writeln('No Q&A prompts are available for this subject yet.');
      return buffer.toString().trimRight();
    }

    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      final unitName = item.unitId == null ? null : unitById[item.unitId]?.name;
      buffer
        ..writeln('## ${index + 1}. ${item.question}')
        ..writeln();
      if (unitName != null || item.tags.isNotEmpty) {
        if (unitName != null) {
          buffer.writeln('- Unit: $unitName');
        }
        if (item.tags.isNotEmpty) {
          buffer.writeln('- Tags: ${item.tags.map((tag) => '#$tag').join(', ')}');
        }
        buffer.writeln();
      }
      buffer
        ..writeln(item.answerMarkdown.trim())
        ..writeln()
        ..writeln('---')
        ..writeln();
    }

    return buffer.toString().trimRight();
  }

  Future<String> exportStudySessionsAiPackageJson() async {
    final sessions = await studySessionsRepository.loadSessions();
    final analytics = jsonDecode(await exportAnalyticsJson()) as Map<String, dynamic>;
    final dueItems = jsonDecode(await exportDueItemsJson()) as Map<String, dynamic>;
    final payload = {
      'studydesk_version': '1.0',
      'type': 'ai_study_sessions_package',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'prompt':
          'Analyze this StudyDesk study history. Identify weak areas, under-reviewed subjects, due-load imbalances, and concrete next-study priorities. Then suggest a focused one-week study plan that fits the recorded pace and due items.',
      'sessions': sessions.map((session) => session.toMap()).toList(),
      'analytics': analytics,
      'dueItems': dueItems,
    };
    return _prettyJson(payload);
  }

  Future<String> exportStudySessionsJson() async {
    final sessions = await studySessionsRepository.loadSessions();
    final payload = {
      'studydesk_version': '1.0',
      'type': 'study_sessions',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'sessions': sessions.map((session) => session.toMap()).toList(),
    };
    return _prettyJson(payload);
  }

  Future<String> exportQuizAttemptsJson() async {
    final attempts = await quizAttemptsRepository.loadAttempts();
    final payload = {
      'studydesk_version': '1.0',
      'type': 'quiz_attempts',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'attempts': attempts.map((attempt) => attempt.toMap()).toList(),
    };
    return _prettyJson(payload);
  }

  Future<String> exportStudyStreaksJson() async {
    final sessions = await studySessionsRepository.loadSessions();
    final daily = <String, Map<String, dynamic>>{};

    for (final session in sessions) {
      final key = _dayKey(session.startedAt);
      final entry = daily.putIfAbsent(
        key,
        () => {
          'date': key,
          'sessionCount': 0,
          'reviewedCount': 0,
          'completedCount': 0,
          'minutesStudied': 0,
          'sessionTypes': <String, int>{},
        },
      );
      entry['sessionCount'] = (entry['sessionCount'] as int) + 1;
      entry['reviewedCount'] = (entry['reviewedCount'] as int) + session.reviewedCount;
      entry['completedCount'] = (entry['completedCount'] as int) + session.completedCount;
      entry['minutesStudied'] = (entry['minutesStudied'] as int) +
          session.endedAt.difference(session.startedAt).inMinutes;
      final typeCounts = entry['sessionTypes'] as Map<String, int>;
      typeCounts[session.sessionType] = (typeCounts[session.sessionType] ?? 0) + 1;
    }

    final orderedDays = daily.values.toList()
      ..sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );

    var longestStreak = 0;
    var currentStreak = 0;
    DateTime? previousDay;

    for (final day in orderedDays) {
      final date = DateTime.parse(day['date'] as String);
      if (previousDay == null) {
        currentStreak = 1;
      } else {
        final gap = date.difference(previousDay).inDays;
        currentStreak = gap == 1 ? currentStreak + 1 : 1;
      }
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
      day['streakLength'] = currentStreak;
      previousDay = date;
    }

    final payload = {
      'studydesk_version': '1.0',
      'type': 'study_streaks',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'longestStreakDays': longestStreak,
      'currentStreakDays': orderedDays.isEmpty ? 0 : (orderedDays.last['streakLength'] as int),
      'days': orderedDays,
    };
    return _prettyJson(payload);
  }

  Future<String> exportAnalyticsJson() async {
    final subjects = await subjectsRepository.loadSubjects();
    final decks = await decksRepository.loadDecks();
    final cards = await cardsRepository.loadCards();
    final notes = await notesRepository.loadNotes();
    final noteReviews = await noteReviewRepository.loadReviews();
    final qaItems = await qaItemsRepository.loadItems();
    final qaReviews = await qaReviewRepository.loadReviews();
    final quizzes = await quizzesRepository.loadQuizzes();
    final sessions = await studySessionsRepository.loadSessions();
    final attempts = await quizAttemptsRepository.loadAttempts();
    final dashboard = DashboardSummary.fromData(
      subjects: subjects.map((subject) => subject.id).toList(),
      decks: decks.map((deck) => (id: deck.id, subjectId: deck.subjectId)).toList(),
      cards: cards,
      notes: notes,
      noteReviews: noteReviews,
      qaItems: qaItems,
      qaReviews: qaReviews,
      quizzes: quizzes,
      quizAttempts: attempts,
      sessions: sessions,
      flashcardsEnabled: readFlashcardSchedulingEnabled(),
      notesEnabled: readNoteSchedulingEnabled(),
      qaEnabled: readQaSchedulingEnabled(),
      quizzesEnabled: readQuizSchedulingEnabled(),
    );
    final gamification = GamificationSummary.fromData(
      dashboard: dashboard,
      sessions: sessions,
      dailyGoalMinutes: readDailyGoalMinutes(),
    );
    final subjectById = {for (final subject in subjects) subject.id: subject};
    final deckById = {for (final deck in decks) deck.id: deck};

    final payload = {
      'studydesk_version': '1.0',
      'type': 'analytics',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'dashboard': {
        'totalDueCards': dashboard.totalDueCards,
        'totalDueNotes': dashboard.totalDueNotes,
        'totalDueQa': dashboard.totalDueQa,
        'totalDueQuizzes': dashboard.totalDueQuizzes,
        'totalDueItems': dashboard.totalDueItems,
        'totalCards': dashboard.totalCards,
        'studiedTodayCount': dashboard.studiedTodayCount,
        'currentStreak': dashboard.currentStreak,
        'sevenDayReviewedCount': dashboard.sevenDayReviewedCount,
        'sevenDayQuizAccuracyRate': dashboard.sevenDayQuizAccuracyRate,
        'hasSevenDayQuizData': dashboard.hasSevenDayQuizData,
        'dueForecast': {
          'overdue': dashboard.dueForecast.overdue,
          'unscheduled': dashboard.dueForecast.unscheduled,
          'dueToday': dashboard.dueForecast.dueToday,
          'dueThisWeek': dashboard.dueForecast.dueThisWeek,
          'dueLater': dashboard.dueForecast.dueLater,
          'total': dashboard.dueForecast.total,
        },
        'activityLast7Days': [
          for (final day in dashboard.activityLast7Days)
            {
              'day': day.day.toIso8601String(),
              'reviewedCount': day.reviewedCount,
              'sessionCount': day.sessionCount,
            },
        ],
        'subjectMetrics': {
          for (final entry in dashboard.subjectMetrics.entries)
            entry.key: {
              'subjectName': subjectById[entry.key]?.name ?? 'Unknown subject',
              'dueCount': entry.value.dueCount,
              'deckCount': entry.value.deckCount,
              'cardsCount': entry.value.cardsCount,
              'notesCount': entry.value.notesCount,
              'qaCount': entry.value.qaCount,
              'quizCount': entry.value.quizCount,
              'reviewedToday': entry.value.reviewedToday,
              'masteryRatio': entry.value.masteryRatio,
            },
        },
        'sessionTypeCounts': dashboard.sessionTypeCounts,
        'recentSessions': [
          for (final session in dashboard.recentSessions)
            {
              ...session.toMap(),
              'subjectName': session.subjectId == null
                  ? null
                  : subjectById[session.subjectId!]?.name,
              'deckName': session.deckId == null ? null : deckById[session.deckId!]?.name,
            },
        ],
      },
      'gamification': {
        'totalXp': gamification.totalXp,
        'currentLevel': gamification.currentLevel,
        'levelStartXp': gamification.levelStartXp,
        'nextLevelXp': gamification.nextLevelXp,
        'todayMinutes': gamification.todayMinutes,
        'dailyGoalMinutes': gamification.dailyGoalMinutes,
        'dailyGoalProgress': gamification.dailyGoalProgress,
        'goalStreakDays': gamification.goalStreakDays,
        'weeklyMinutes': gamification.weeklyMinutes,
        'weeklyReviewedCount': gamification.weeklyReviewedCount,
        'weeklySessionCount': gamification.weeklySessionCount,
        'weeklyQuizAccuracyRate': gamification.weeklyQuizAccuracyRate,
        'hasWeeklyQuizData': gamification.hasWeeklyQuizData,
        'totalReviewedCount': gamification.totalReviewedCount,
        'totalSessionCount': gamification.totalSessionCount,
        'unlockedMilestones': [
          for (final milestone in gamification.unlockedMilestones)
            {
              'title': milestone.title,
              'description': milestone.description,
              'progress': milestone.progress,
              'progressLabel': milestone.progressLabel,
            },
        ],
        'nextMilestone': gamification.nextMilestone == null
            ? null
            : {
                'title': gamification.nextMilestone!.title,
                'description': gamification.nextMilestone!.description,
                'progress': gamification.nextMilestone!.progress,
                'progressLabel': gamification.nextMilestone!.progressLabel,
              },
      },
      'studyScheduling': {
        'flashcardsEnabled': readFlashcardSchedulingEnabled(),
        'notesEnabled': readNoteSchedulingEnabled(),
        'qaEnabled': readQaSchedulingEnabled(),
        'quizzesEnabled': readQuizSchedulingEnabled(),
      },
      'quizAttemptCount': attempts.length,
    };
    return _prettyJson(payload);
  }

  Future<String> exportDueItemsJson() async {
    final subjects = await subjectsRepository.loadSubjects();
    final decks = await decksRepository.loadDecks();
    final cards = await cardsRepository.loadCards();
    final notes = await notesRepository.loadNotes();
    final noteReviews = await noteReviewRepository.loadReviews();
    final qaItems = await qaItemsRepository.loadItems();
    final qaReviews = await qaReviewRepository.loadReviews();
    final quizzes = await quizzesRepository.loadQuizzes();
    final attempts = await quizAttemptsRepository.loadAttempts();
    final now = DateTime.now();
    final deckById = {for (final deck in decks) deck.id: deck};
    final subjectById = {for (final subject in subjects) subject.id: subject};
    final reviewByNoteId = {for (final review in noteReviews) review.noteId: review};
    final reviewByPromptId = {for (final review in qaReviews) review.promptId: review};
    final latestAttemptByQuiz = <String, QuizAttemptSessionRecord>{};
    for (final attempt in attempts) {
      final existing = latestAttemptByQuiz[attempt.quizId];
      if (existing == null || attempt.endedAt.isAfter(existing.endedAt)) {
        latestAttemptByQuiz[attempt.quizId] = attempt;
      }
    }

    final dueItems = <Map<String, dynamic>>[];
    if (readFlashcardSchedulingEnabled()) {
      for (final card in cards) {
        final deck = deckById[card.deckId];
        if (deck == null) {
          continue;
        }
        final subject = subjectById[deck.subjectId];
        if (subject == null) {
          continue;
        }
        final isDue = card.dueAt == null || !card.dueAt!.isAfter(now);
        if (!isDue) {
          continue;
        }
        dueItems.add({
          'contentType': 'flashcard',
          'subjectId': subject.id,
          'subjectName': subject.name,
          'deckId': deck.id,
          'deckName': deck.name,
          'itemId': card.id,
          'title': card.front,
          'hint': card.hint,
          'dueAt': card.dueAt?.toIso8601String(),
          'reviewCount': card.reviewCount,
          'difficulty': card.difficulty,
          'stability': card.stability,
          'state': card.state,
        });
      }
    }

    if (readNoteSchedulingEnabled()) {
      for (final note in notes) {
        final subject = subjectById[note.subjectId];
        if (subject == null) {
          continue;
        }
        final review = reviewByNoteId[note.id];
        final isDue = review == null || review.dueAt == null || !review.dueAt!.isAfter(now);
        if (!isDue) {
          continue;
        }
        dueItems.add({
          'contentType': 'note',
          'subjectId': subject.id,
          'subjectName': subject.name,
          'noteId': note.id,
          'itemId': note.id,
          'title': note.title,
          'excerpt': note.excerpt,
          'dueAt': review?.dueAt?.toIso8601String(),
          'reviewCount': review?.reviewCount ?? 0,
          'lastRating': review?.lastRating?.storageValue,
          'hasPendingSelfNote': review?.pendingSelfNote?.trim().isNotEmpty ?? false,
          'tags': note.tags,
        });
      }
    }
    if (readQaSchedulingEnabled()) {
      for (final item in qaItems) {
        final subject = subjectById[item.subjectId];
        if (subject == null) {
          continue;
        }
        final review = reviewByPromptId[item.id];
        final isDue = review == null || review.dueAt == null || !review.dueAt!.isAfter(now);
        if (!isDue) {
          continue;
        }
        dueItems.add({
          'contentType': 'qa',
          'subjectId': subject.id,
          'subjectName': subject.name,
          'itemId': item.id,
          'title': item.question,
          'unitId': item.unitId,
          'dueAt': review?.dueAt?.toIso8601String(),
          'reviewCount': review?.reviewCount ?? 0,
          'difficulty': review?.difficulty ?? 5.0,
          'stability': review?.stability ?? 0.1,
          'state': review?.state ?? 'new',
          'tags': item.tags,
        });
      }
    }

    if (readQuizSchedulingEnabled()) {
      for (final quiz in quizzes) {
        final subject = subjectById[quiz.subjectId];
        if (subject == null) {
          continue;
        }
        final latestAttempt = latestAttemptByQuiz[quiz.id];
        final recommendedDueAt = _recommendedQuizDueAt(latestAttempt);
        final isDue = recommendedDueAt == null || !recommendedDueAt.isAfter(now);
        if (!isDue) {
          continue;
        }
        dueItems.add({
          'contentType': 'quiz',
          'subjectId': subject.id,
          'subjectName': subject.name,
          'quizId': quiz.id,
          'itemId': quiz.id,
          'title': quiz.name,
          'description': quiz.description,
          'dueAt': recommendedDueAt?.toIso8601String(),
          'latestAttemptId': latestAttempt?.id,
          'latestScorePercent': latestAttempt?.scorePercent,
          'latestPassed': latestAttempt?.passed,
          'tags': quiz.tags,
        });
      }
    }

    final payload = {
      'studydesk_version': '1.0',
      'type': 'due_items',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'dueCount': dueItems.length,
      'items': dueItems,
    };
    return _prettyJson(payload);
  }

  Future<String> exportWeakTopicsJson() async {
    final attempts = await quizAttemptsRepository.loadAttempts();
    final buckets = <String, _TagPerformance>{};

    for (final attempt in attempts) {
      final tags = attempt.quizTags.isEmpty ? const ['untagged'] : attempt.quizTags;
      for (final tag in tags) {
        final bucket = buckets.putIfAbsent(tag, _TagPerformance.new);
        bucket.attemptCount += 1;
        bucket.questionCount += attempt.totalQuestions;
        bucket.correctCount += attempt.correctCount;
        bucket.wrongCount += attempt.wrongCount;
        bucket.skippedCount += attempt.skippedCount;
      }
    }

    final ranked = buckets.entries.toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));

    final payload = {
      'studydesk_version': '1.0',
      'type': 'weak_topics',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'topics': [
        for (final entry in ranked)
          {
            'tag': entry.key,
            'attemptCount': entry.value.attemptCount,
            'questionCount': entry.value.questionCount,
            'correctCount': entry.value.correctCount,
            'wrongCount': entry.value.wrongCount,
            'skippedCount': entry.value.skippedCount,
            'accuracyRate': entry.value.accuracy,
            'strength': entry.value.accuracy >= 0.8
                ? 'strong'
                : entry.value.accuracy >= 0.6
                    ? 'developing'
                    : 'weak',
          },
      ],
    };
    return _prettyJson(payload);
  }

  Future<String> exportWeakSectionsMarkdown() async {
    final notes = await notesRepository.loadNotes();
    final reviews = await noteReviewRepository.loadReviews();
    final reviewByNoteId = {for (final review in reviews) review.noteId: review};
    final weakEntries = <({NoteRecord note, String heading, String annotation, DateTime? dueAt})>[];

    for (final note in notes) {
      final review = reviewByNoteId[note.id];
      if (review == null) {
        continue;
      }
      if (review.lastRating == NoteRecallRating.full &&
          review.sectionAnnotations.isEmpty) {
        continue;
      }
      for (final entry in review.sectionAnnotations.entries) {
        if (entry.value.trim().isEmpty) {
          continue;
        }
        weakEntries.add((
          note: note,
          heading: entry.key,
          annotation: entry.value.trim(),
          dueAt: review.dueAt,
        ));
      }
    }

    weakEntries.sort((a, b) {
      final noteComparison = a.note.title.compareTo(b.note.title);
      if (noteComparison != 0) {
        return noteComparison;
      }
      return a.heading.compareTo(b.heading);
    });

    final buffer = StringBuffer()
      ..writeln('# Weak Sections Review')
      ..writeln()
      ..writeln(
        'Generated from note-reading sessions and saved section annotations in StudyDesk.',
      )
      ..writeln();

    if (weakEntries.isEmpty) {
      buffer.writeln('No weak note sections have been recorded yet.');
      return buffer.toString().trimRight();
    }

    for (final item in weakEntries) {
      buffer
        ..writeln('## ${item.note.title} -> ${item.heading}')
        ..writeln()
        ..writeln('- Subject note: ${item.note.title}')
        ..writeln('- Due: ${item.dueAt?.toIso8601String() ?? 'Manual review'}')
        ..writeln('- Reminder: ${item.annotation}')
        ..writeln()
        ..writeln('---')
        ..writeln();
    }

    return buffer.toString().trimRight();
  }

  Future<String> exportWrongQuestionsAsQuizJson() async {
    final attempts = await quizAttemptsRepository.loadAttempts();
    final wrongItems = _collectLatestWrongItems(attempts);
    final questions = wrongItems
        .map((item) => _wrongItemToQuizQuestion(item))
        .whereType<QuizQuestion>()
        .toList();
    final payload = {
      'studydesk_version': '1.0',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'type': 'quiz',
      'content': {
        'name': 'Wrong Questions Review',
        'description': 'Generated from incorrect or skipped questions in StudyDesk quiz attempts.',
        'tags': ['review', 'wrong-questions'],
        'settings': QuizSettings.defaults.toMap(),
        'questions': questions.map((question) => question.toMap()).toList(),
      },
    };
    return _prettyJson(payload);
  }

  Future<String> exportWrongQuestionsAsDeckJson() async {
    final attempts = await quizAttemptsRepository.loadAttempts();
    final wrongItems = _collectLatestWrongItems(attempts);
    final payload = {
      'studydesk_version': '1.0',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'type': 'deck',
      'content': {
        'name': 'Wrong Questions Flashcards',
        'description': 'Flashcard review built from incorrect or skipped quiz questions.',
        'tags': ['review', 'wrong-questions'],
        'cards': [
          for (final item in wrongItems)
            {
              'id': item.questionId,
              'front': item.question,
              'back': _wrongItemBack(item),
              'hint': item.selectedAnswer.isEmpty
                  ? null
                  : 'Previous answer: ${item.selectedAnswer}',
            },
        ],
      },
    };
    return _prettyJson(payload);
  }

  Future<String> exportWrongQuestionsMarkdown() async {
    final attempts = await quizAttemptsRepository.loadAttempts();
    final wrongItems = _collectLatestWrongItems(attempts);
    final buffer = StringBuffer()
      ..writeln('# Wrong Questions Review')
      ..writeln()
      ..writeln(
        'Generated from incorrect or skipped quiz questions recorded in StudyDesk.',
      )
      ..writeln();

    if (wrongItems.isEmpty) {
      buffer.writeln('No wrong or skipped quiz questions have been recorded yet.');
    } else {
      for (var index = 0; index < wrongItems.length; index += 1) {
        final item = wrongItems[index];
        buffer
          ..writeln('## ${index + 1}. ${item.question}')
          ..writeln()
          ..writeln('- Correct answer: ${item.correctAnswer}')
          ..writeln(
            '- Your answer: ${item.selectedAnswer.isEmpty ? 'Skipped' : item.selectedAnswer}',
          )
          ..writeln('- Time spent: ${item.timeSpentSeconds}s')
          ..writeln('- Points: ${item.pointsAwarded.toStringAsFixed(1)} / ${item.maxPoints.toStringAsFixed(1)}');
        if (item.explanation.isNotEmpty) {
          buffer
            ..writeln()
            ..writeln(item.explanation);
        }
        if (item.missingKeywords.isNotEmpty) {
          buffer
            ..writeln()
            ..writeln('Missing keywords: ${item.missingKeywords.join(', ')}');
        }
        buffer
          ..writeln()
          ..writeln('---')
          ..writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  Future<String> exportLibraryJson() async {
    final subjects = await subjectsRepository.loadSubjects();
    final units = await unitsRepository.loadUnits();
    final decks = await decksRepository.loadDecks();
    final cards = await cardsRepository.loadCards();
    final quizzes = await quizzesRepository.loadQuizzes();
    final notes = await notesRepository.loadNotes();
    final noteReviews = await noteReviewRepository.loadReviews();
    final qaItems = await qaItemsRepository.loadItems();
    final qaReviews = await qaReviewRepository.loadReviews();
    final sessions = await studySessionsRepository.loadSessions();
    final attempts = await quizAttemptsRepository.loadAttempts();

    final payload = {
      'studydesk_version': '1.0',
      'type': 'library',
      'export_date': DateTime.now().toUtc().toIso8601String(),
      'subjects': subjects.map((subject) => subject.toMap()).toList(),
      'units': units.map((unit) => unit.toMap()).toList(),
      'decks': decks.map((deck) => deck.toMap()).toList(),
      'cards': cards.map((card) => card.toMap()).toList(),
      'quizzes': quizzes.map((quiz) => quiz.toMap()).toList(),
      'notes': notes.map((note) => note.toMap()).toList(),
      'noteReviews': noteReviews.map((review) => review.toMap()).toList(),
      'qaItems': qaItems.map((item) => item.toMap()).toList(),
      'qaReviews': qaReviews.map((review) => review.toMap()).toList(),
      'studySessions': sessions.map((session) => session.toMap()).toList(),
      'quizAttempts': attempts.map((attempt) => attempt.toMap()).toList(),
    };
    return _prettyJson(payload);
  }

  Future<Uint8List> exportSubjectBundleZip({
    required String subjectId,
  }) async {
    final subjects = await subjectsRepository.loadSubjects();
    final subject = subjects.where((item) => item.id == subjectId).firstOrNull;
    if (subject == null) {
      throw StateError('Subject $subjectId could not be found for export.');
    }

    final units = (await unitsRepository.loadUnits())
        .where((unit) => unit.subjectId == subjectId)
        .toList();
    final decks = (await decksRepository.loadDecks())
        .where((deck) => deck.subjectId == subjectId)
        .toList();
    final cards = await cardsRepository.loadCards();
    final quizzes = (await quizzesRepository.loadQuizzes())
        .where((quiz) => quiz.subjectId == subjectId)
        .toList();
    final notes = (await notesRepository.loadNotes())
        .where((note) => note.subjectId == subjectId)
        .toList();
    final noteReviews = (await noteReviewRepository.loadReviews())
        .where((review) => review.subjectId == subjectId)
        .toList();
    final qaItems = (await qaItemsRepository.loadItems())
        .where((item) => item.subjectId == subjectId)
        .toList();
    final qaReviews = (await qaReviewRepository.loadReviews())
        .where((review) => review.subjectId == subjectId)
        .toList();
    final sessions = (await studySessionsRepository.loadSessions())
        .where((session) => session.subjectId == subjectId)
        .toList();
    final attempts = (await quizAttemptsRepository.loadAttempts())
        .where((attempt) => attempt.subjectId == subjectId)
        .toList();

    final archive = Archive();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    _addTextFile(
      archive,
      'manifest.json',
      _prettyJson({
        'studydesk_version': '1.0',
        'bundle_type': 'subject_bundle',
        'export_date': timestamp,
        'subject': subject.toMap(),
        'counts': {
          'units': units.length,
          'notes': notes.length,
          'noteReviews': noteReviews.length,
          'qaItems': qaItems.length,
          'qaReviews': qaReviews.length,
          'decks': decks.length,
          'cards': cards.where((card) => decks.any((deck) => deck.id == card.deckId)).length,
          'quizzes': quizzes.length,
          'studySessions': sessions.length,
          'quizAttempts': attempts.length,
        },
      }),
    );

    _addTextFile(archive, 'subject.json', _prettyJson(subject.toMap()));
    _addTextFile(
      archive,
      'units/units.json',
      _prettyJson(units.map((unit) => unit.toMap()).toList()),
    );
    _addTextFile(
      archive,
      'notes/index.json',
      _prettyJson(
        notes
            .map(
              (note) => {
                ...note.toMap(),
                'slug': _slugify(note.title, fallback: note.id),
              },
            )
            .toList(),
      ),
    );
    _addTextFile(
      archive,
      'notes/review_states.json',
      _prettyJson(noteReviews.map((review) => review.toMap()).toList()),
    );
    _addTextFile(
      archive,
      'qa/index.json',
      _prettyJson(qaItems.map((item) => item.toMap()).toList()),
    );
    _addTextFile(
      archive,
      'qa/review_states.json',
      _prettyJson(qaReviews.map((review) => review.toMap()).toList()),
    );

    for (final note in notes) {
      _addTextFile(
        archive,
        'notes/${_slugify(note.title, fallback: note.id)}.md',
        note.bodyMarkdown,
      );
    }

    for (final item in qaItems) {
      _addTextFile(
        archive,
        'qa/${_slugify(item.question, fallback: item.id)}.md',
        '# ${item.question}\n\n${item.answerMarkdown}',
      );
    }

    for (final deck in decks) {
      final deckCards = cards.where((card) => card.deckId == deck.id).toList();
      _addTextFile(
        archive,
        'decks/${_slugify(deck.name, fallback: deck.id)}.json',
        await exportDeckJson(deck: deck, cards: deckCards),
      );
    }

    for (final quiz in quizzes) {
      _addTextFile(
        archive,
        'quizzes/${_slugify(quiz.name, fallback: quiz.id)}.json',
        await exportQuizJson(quiz: quiz),
      );
    }

    for (final attempt in attempts) {
      _addTextFile(
        archive,
        'quiz_attempts/${_slugify('${attempt.quizName}-${attempt.id}', fallback: attempt.id)}.json',
        await exportQuizAttemptJson(attempt: attempt),
      );
    }

    _addTextFile(
      archive,
      'study_sessions/study_sessions.json',
      _prettyJson(sessions.map((session) => session.toMap()).toList()),
    );
    _addTextFile(
      archive,
      'analytics/subject_summary.json',
      _prettyJson(
        await _subjectSummary(
          subject,
          units,
          decks,
          cards,
          quizzes,
          notes,
          noteReviews,
          qaItems,
          qaReviews,
          sessions,
          attempts,
        ),
      ),
    );

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw StateError('Subject bundle zip could not be generated.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<Map<String, dynamic>> _subjectSummary(
    SubjectRecord subject,
    List<SubjectUnitRecord> units,
    List<DeckRecord> decks,
    List<CardRecord> allCards,
    List<QuizRecord> quizzes,
    List<NoteRecord> notes,
    List<NoteReviewRecord> noteReviews,
    List<QaItemRecord> qaItems,
    List<QaReviewRecord> qaReviews,
    List<StudySessionRecord> sessions,
    List<QuizAttemptSessionRecord> attempts,
  ) async {
    final cards = allCards.where((card) => decks.any((deck) => deck.id == card.deckId)).toList();
    final now = DateTime.now();
    final dueCards = cards.where((card) => card.dueAt == null || !card.dueAt!.isAfter(now)).length;
    final dueNotes = noteReviews
        .where((review) => review.dueAt == null || !review.dueAt!.isAfter(now))
        .length;
    final dueQa = qaReviews
        .where((review) => review.dueAt == null || !review.dueAt!.isAfter(now))
        .length;
    final reviewedCards = cards.where((card) => card.reviewCount > 0).length;

    return {
      'subjectId': subject.id,
      'subjectName': subject.name,
      'unitCount': units.length,
      'noteCount': notes.length,
      'noteReviewCount': noteReviews.length,
      'qaCount': qaItems.length,
      'qaReviewCount': qaReviews.length,
      'deckCount': decks.length,
      'cardCount': cards.length,
      'quizCount': quizzes.length,
      'studySessionCount': sessions.length,
      'quizAttemptCount': attempts.length,
      'dueCardCount': dueCards,
      'dueNoteCount': dueNotes,
      'dueQaCount': dueQa,
      'masteryRatio': cards.isEmpty ? 0.0 : reviewedCards / cards.length,
      'totalQuizCorrect': attempts.fold<int>(0, (sum, attempt) => sum + attempt.correctCount),
      'totalQuizQuestions': attempts.fold<int>(0, (sum, attempt) => sum + attempt.totalQuestions),
    };
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
        if (correctIndex == null || correctIndex < 0 || correctIndex >= question.options.length) {
          throw FormatException('Question ${index + 1} has an invalid correct option index.');
        }
      }
      if (question.type == QuizQuestionType.fillBlank &&
          question.correctAnswers.every((answer) => answer.trim().isEmpty)) {
        throw FormatException('Question ${index + 1} needs at least one accepted answer.');
      }
      if (question.type == QuizQuestionType.trueFalse && question.correctAnswer == null) {
        throw FormatException('Question ${index + 1} must define true or false.');
      }
      if (question.type == QuizQuestionType.shortAnswer) {
        final hasRequiredRule = question.keywordRules.any(
          (rule) => rule.required && rule.term.trim().isNotEmpty,
        );
        final hasLegacyKeywords = question.keywords.any((keyword) => keyword.trim().isNotEmpty);
        if (!hasRequiredRule && !hasLegacyKeywords) {
          throw FormatException(
            'Question ${index + 1} needs at least one required keyword for grading.',
          );
        }
      }
    }
  }

  List<QuizAttemptItemRecord> _collectLatestWrongItems(
    List<QuizAttemptSessionRecord> attempts,
  ) {
    final latestByQuestion = <String, QuizAttemptItemRecord>{};
    for (final attempt in attempts) {
      for (final item in attempt.items) {
        if (item.isCorrect && !item.wasSkipped) {
          continue;
        }
        latestByQuestion[item.questionId] = item;
      }
    }
    return latestByQuestion.values.toList()
      ..sort((a, b) => a.question.compareTo(b.question));
  }

  QuizQuestion? _wrongItemToQuizQuestion(QuizAttemptItemRecord item) {
    switch (item.questionType) {
      case QuizQuestionType.mcq:
        final correctIndex = item.options.indexOf(item.correctAnswer);
        if (correctIndex == -1) {
          return null;
        }
        return QuizQuestion(
          id: item.questionId,
          type: item.questionType,
          question: item.question,
          options: item.options,
          correctIndex: correctIndex,
          correctAnswer: null,
          correctAnswers: const [],
          caseSensitive: false,
          modelAnswer: '',
          keywords: const [],
          keywordRules: const [],
          minWords: null,
          maxWords: null,
          minimumKeywordMatches: null,
          minimumKeywordScorePercent: null,
          allowPartialCredit: false,
          gradingMode: 'keywords',
          explanation: item.explanation,
          points: item.maxPoints <= 0 ? 1 : item.maxPoints,
          grading: null,
        );
      case QuizQuestionType.trueFalse:
        return QuizQuestion(
          id: item.questionId,
          type: item.questionType,
          question: item.question,
          options: const [],
          correctIndex: null,
          correctAnswer: item.correctAnswer.toLowerCase() == 'true',
          correctAnswers: const [],
          caseSensitive: false,
          modelAnswer: '',
          keywords: const [],
          keywordRules: const [],
          minWords: null,
          maxWords: null,
          minimumKeywordMatches: null,
          minimumKeywordScorePercent: null,
          allowPartialCredit: false,
          gradingMode: 'keywords',
          explanation: item.explanation,
          points: item.maxPoints <= 0 ? 1 : item.maxPoints,
          grading: null,
        );
      case QuizQuestionType.fillBlank:
        return QuizQuestion(
          id: item.questionId,
          type: item.questionType,
          question: item.question,
          options: const [],
          correctIndex: null,
          correctAnswer: null,
          correctAnswers: item.correctAnswer.isEmpty
              ? const []
              : [item.correctAnswer],
          caseSensitive: false,
          modelAnswer: '',
          keywords: const [],
          keywordRules: const [],
          minWords: null,
          maxWords: null,
          minimumKeywordMatches: null,
          minimumKeywordScorePercent: null,
          allowPartialCredit: false,
          gradingMode: 'keywords',
          explanation: item.explanation,
          points: item.maxPoints <= 0 ? 1 : item.maxPoints,
          grading: null,
        );
      case QuizQuestionType.shortAnswer:
        final terms = <String>{
          ...item.matchedKeywords,
          ...item.missingKeywords,
        };
        return QuizQuestion(
          id: item.questionId,
          type: item.questionType,
          question: item.question,
          options: const [],
          correctIndex: null,
          correctAnswer: null,
          correctAnswers: const [],
          caseSensitive: false,
          modelAnswer: item.correctAnswer,
          keywords: item.matchedKeywords.isEmpty && item.missingKeywords.isEmpty
              ? const []
              : [...item.matchedKeywords, ...item.missingKeywords],
          keywordRules: [
            for (final term in terms)
              QuizKeywordRule(
                term: term,
                aliases: const [],
                required: true,
                weight: 1,
              ),
          ],
          minWords: null,
          maxWords: null,
          minimumKeywordMatches: null,
          minimumKeywordScorePercent: item.keywordScorePercent?.clamp(0.2, 1.0),
          allowPartialCredit: true,
          gradingMode: 'keywords',
          explanation: item.explanation,
          points: item.maxPoints <= 0 ? 1 : item.maxPoints,
          grading: null,
        );
    }
  }

  String _wrongItemBack(QuizAttemptItemRecord item) {
    final buffer = StringBuffer()
      ..writeln('Correct answer: ${item.correctAnswer}');
    if (item.explanation.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(item.explanation);
    }
    if (item.missingKeywords.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Missing keywords: ${item.missingKeywords.join(', ')}');
    }
    return buffer.toString().trimRight();
  }

  String _dayKey(DateTime dateTime) {
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    ).toIso8601String();
  }

  void _addTextFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _slugify(String value, {required String fallback}) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? fallback : slug;
  }

  String _prettyJson(Object payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  DateTime? _recommendedQuizDueAt(QuizAttemptSessionRecord? latestAttempt) {
    if (latestAttempt == null) {
      return null;
    }
    final score = latestAttempt.scorePercent;
    final intervalDays = switch (score) {
      < 50 => 1,
      < 70 => 3,
      < 90 => 7,
      _ => 14,
    };
    return latestAttempt.endedAt.add(Duration(days: intervalDays));
  }

  bool _looksLikeCsvHeader(String line) {
    final columns = _parseCsvLine(line).map((item) => item.trim().toLowerCase()).toList();
    if (columns.length < 2) {
      return false;
    }
    final first = columns[0];
    final second = columns[1];
    return (first == 'front' || first == 'question') &&
        (second == 'back' || second == 'answer');
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < line.length; index += 1) {
      final char = line[index];
      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index += 1;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    values.add(buffer.toString());
    return values;
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

class _TagPerformance {
  int attemptCount = 0;
  int questionCount = 0;
  int correctCount = 0;
  int wrongCount = 0;
  int skippedCount = 0;

  double get accuracy => questionCount == 0 ? 0.0 : correctCount / questionCount;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
