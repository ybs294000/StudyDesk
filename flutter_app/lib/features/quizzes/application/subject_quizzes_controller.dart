import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/studydesk_security.dart';
import '../../notes/application/note_markdown_utils.dart';
import '../data/quizzes_repository.dart';
import '../domain/quiz_models.dart';

final subjectQuizzesControllerProvider = AsyncNotifierProviderFamily<
    SubjectQuizzesController, List<QuizRecord>, String>(SubjectQuizzesController.new);

class SubjectQuizzesController extends FamilyAsyncNotifier<List<QuizRecord>, String> {
  QuizzesRepository get _repository => ref.read(quizzesRepositoryProvider);

  @override
  Future<List<QuizRecord>> build(String arg) async {
    final quizzes = await _repository.loadQuizzes();
    return _forSubject(quizzes, arg);
  }

  Future<void> saveAllForSubject(String subjectId, List<QuizRecord> subjectQuizzes) async {
    final allQuizzes = await _repository.loadQuizzes();
    final otherQuizzes =
        allQuizzes.where((quiz) => quiz.subjectId != subjectId).toList();
    final updated = [...otherQuizzes, ...subjectQuizzes];
    await _repository.saveQuizzes(updated);
    state = AsyncData(_forSubject(updated, subjectId));
  }

  Future<void> upsertQuiz(QuizRecord quiz) async {
    final allQuizzes = await _repository.loadQuizzes();
    final normalized = quiz.copyWith(
      name: StudyDeskSecurity.sanitizeSingleLine(
        quiz.name,
        field: 'Quiz name',
        maxLength: StudyDeskSecurity.maxShortTitleLength,
      ),
      description: StudyDeskSecurity.sanitizeMultiline(
        quiz.description,
        field: 'Quiz description',
        maxLength: StudyDeskSecurity.maxDescriptionLength,
      ),
      tags: normalizeTags(quiz.tags),
      questions: [
        for (final question in quiz.questions) _normalizeQuestion(question),
      ],
      updatedAt: DateTime.now(),
    );
    final updated = [
      for (final item in allQuizzes)
        if (item.id != normalized.id) item,
      normalized,
    ];
    await _repository.upsertQuiz(normalized);
    state = AsyncData(_forSubject(updated, arg));
  }

  Future<void> deleteQuiz(String quizId) async {
    final allQuizzes = await _repository.loadQuizzes();
    final updated = allQuizzes.where((quiz) => quiz.id != quizId).toList();
    await _repository.deleteQuiz(quizId);
    state = AsyncData(_forSubject(updated, arg));
  }

  List<QuizRecord> _forSubject(List<QuizRecord> quizzes, String subjectId) {
    final filtered = quizzes.where((quiz) => quiz.subjectId == subjectId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  QuizQuestion _normalizeQuestion(QuizQuestion question) {
    final normalizedOptions = question.options
        .map(
          (option) => StudyDeskSecurity.sanitizeSingleLine(
            option,
            field: 'Quiz option',
            maxLength: StudyDeskSecurity.maxQuizOptionLength,
          ),
        )
        .take(StudyDeskSecurity.maxQuizOptions)
        .toList();
    final normalizedAnswers = question.correctAnswers
        .map(
          (answer) => StudyDeskSecurity.sanitizeSingleLine(
            answer,
            field: 'Accepted answer',
            maxLength: StudyDeskSecurity.maxQuizOptionLength,
          ),
        )
        .toList();
    return QuizQuestion(
      id: question.id,
      type: question.type,
      question: StudyDeskSecurity.sanitizeMultiline(
        question.question,
        field: 'Quiz question',
        maxLength: StudyDeskSecurity.maxQuizQuestionLength,
        allowEmpty: false,
      ),
      options: normalizedOptions,
      correctIndex: question.correctIndex,
      correctAnswer: question.correctAnswer,
      correctAnswers: normalizedAnswers,
      caseSensitive: question.caseSensitive,
      modelAnswer: StudyDeskSecurity.sanitizeMultiline(
        question.modelAnswer,
        field: 'Model answer',
        maxLength: StudyDeskSecurity.maxQaAnswerLength,
      ),
      keywords: StudyDeskSecurity.sanitizeTags(question.keywords),
      keywordRules: [
        for (final rule in question.keywordRules)
          QuizKeywordRule(
            term: StudyDeskSecurity.sanitizeSingleLine(
              rule.term,
              field: 'Keyword rule term',
              maxLength: StudyDeskSecurity.maxTagLength,
            ),
            aliases: StudyDeskSecurity.sanitizeTags(rule.aliases),
            required: rule.required,
            weight: rule.weight,
          ),
      ],
      minWords: question.minWords,
      maxWords: question.maxWords,
      minimumKeywordMatches: question.minimumKeywordMatches,
      minimumKeywordScorePercent: question.minimumKeywordScorePercent,
      allowPartialCredit: question.allowPartialCredit,
      gradingMode: question.gradingMode,
      explanation: StudyDeskSecurity.sanitizeMultiline(
        question.explanation,
        field: 'Quiz explanation',
        maxLength: StudyDeskSecurity.maxQuizExplanationLength,
      ),
      points: question.points,
      grading: question.grading,
    );
  }
}
