import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      name: quiz.name.trim(),
      description: quiz.description.trim(),
      tags: normalizeTags(quiz.tags),
      updatedAt: DateTime.now(),
    );
    final updated = [
      for (final item in allQuizzes)
        if (item.id != normalized.id) item,
      normalized,
    ];
    await _repository.saveQuizzes(updated);
    state = AsyncData(_forSubject(updated, arg));
  }

  Future<void> deleteQuiz(String quizId) async {
    final allQuizzes = await _repository.loadQuizzes();
    final updated = allQuizzes.where((quiz) => quiz.id != quizId).toList();
    await _repository.saveQuizzes(updated);
    state = AsyncData(_forSubject(updated, arg));
  }

  List<QuizRecord> _forSubject(List<QuizRecord> quizzes, String subjectId) {
    final filtered = quizzes.where((quiz) => quiz.subjectId == subjectId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }
}
