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
import '../features/notes/data/notes_repository.dart';
import '../features/notes/domain/note_record.dart';
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
    subjectsRepository: ref.read(subjectsRepositoryProvider),
    unitsRepository: ref.read(subjectUnitsRepositoryProvider),
    studySessionsRepository: ref.read(studySessionsRepositoryProvider),
    quizAttemptsRepository: ref.read(quizAttemptsRepositoryProvider),
    readDailyGoalMinutes: () => ref.read(profileSettingsControllerProvider).dailyGoalMinutes,
  );
});

class ContentPortabilityService {
  ContentPortabilityService({
    required this.decksRepository,
    required this.cardsRepository,
    required this.quizzesRepository,
    required this.notesRepository,
    required this.subjectsRepository,
    required this.unitsRepository,
    required this.studySessionsRepository,
    required this.quizAttemptsRepository,
    required this.readDailyGoalMinutes,
  });

  final DecksRepository decksRepository;
  final CardsRepository cardsRepository;
  final QuizzesRepository quizzesRepository;
  final NotesRepository notesRepository;
  final SubjectsRepository subjectsRepository;
  final SubjectUnitsRepository unitsRepository;
  final StudySessionsRepository studySessionsRepository;
  final QuizAttemptsRepository quizAttemptsRepository;
  final int Function() readDailyGoalMinutes;

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
    final sessions = await studySessionsRepository.loadSessions();
    final attempts = await quizAttemptsRepository.loadAttempts();
    final dashboard = DashboardSummary.fromData(
      subjects: subjects.map((subject) => subject.id).toList(),
      decks: decks.map((deck) => (id: deck.id, subjectId: deck.subjectId)).toList(),
      cards: cards,
      sessions: sessions,
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
      'quizAttemptCount': attempts.length,
    };
    return _prettyJson(payload);
  }

  Future<String> exportDueItemsJson() async {
    final subjects = await subjectsRepository.loadSubjects();
    final decks = await decksRepository.loadDecks();
    final cards = await cardsRepository.loadCards();
    final now = DateTime.now();
    final deckById = {for (final deck in decks) deck.id: deck};
    final subjectById = {for (final subject in subjects) subject.id: subject};

    final dueItems = <Map<String, dynamic>>[];
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
        'subjectId': subject.id,
        'subjectName': subject.name,
        'deckId': deck.id,
        'deckName': deck.name,
        'cardId': card.id,
        'front': card.front,
        'hint': card.hint,
        'dueAt': card.dueAt?.toIso8601String(),
        'reviewCount': card.reviewCount,
        'difficulty': card.difficulty,
        'stability': card.stability,
        'state': card.state,
      });
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

    for (final note in notes) {
      _addTextFile(
        archive,
        'notes/${_slugify(note.title, fallback: note.id)}.md',
        note.bodyMarkdown,
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
      _prettyJson(await _subjectSummary(subject, units, decks, cards, quizzes, notes, sessions, attempts)),
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
    List<StudySessionRecord> sessions,
    List<QuizAttemptSessionRecord> attempts,
  ) async {
    final cards = allCards.where((card) => decks.any((deck) => deck.id == card.deckId)).toList();
    final now = DateTime.now();
    final dueCards = cards.where((card) => card.dueAt == null || !card.dueAt!.isAfter(now)).length;
    final reviewedCards = cards.where((card) => card.reviewCount > 0).length;

    return {
      'subjectId': subject.id,
      'subjectName': subject.name,
      'unitCount': units.length,
      'noteCount': notes.length,
      'deckCount': decks.length,
      'cardCount': cards.length,
      'quizCount': quizzes.length,
      'studySessionCount': sessions.length,
      'quizAttemptCount': attempts.length,
      'dueCardCount': dueCards,
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
