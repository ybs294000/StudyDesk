import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/markdown_content.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../library/application/library_overview_provider.dart';
import '../application/quiz_grading_service.dart';
import '../../study/data/study_sessions_repository.dart';
import '../../study/domain/study_session_record.dart';
import '../application/subject_quizzes_controller.dart';
import '../domain/quiz_models.dart';

class QuizSessionScreen extends ConsumerStatefulWidget {
  const QuizSessionScreen({
    required this.subjectId,
    required this.quizId,
    super.key,
  });

  final String subjectId;
  final String quizId;

  @override
  ConsumerState<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends ConsumerState<QuizSessionScreen> {
  QuizRecord? _quiz;
  List<QuizQuestion> _questions = [];
  final Map<String, dynamic> _answers = {};
  int _currentIndex = 0;
  Timer? _timer;
  int? _remainingSeconds;
  DateTime? _startedAt;
  bool _submitted = false;
  bool _isSubmitting = false;
  List<QuizAttemptRecord> _results = const [];
  final TextEditingController _textController = TextEditingController();
  DateTime? _endedAt;
  final QuizGradingService _gradingService = const QuizGradingService();

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted && _quiz != null) {
      return _QuizResultsView(
        quiz: _quiz!,
        questions: _questions,
        results: _results,
        startedAt: _startedAt!,
        endedAt: _endedAt!,
      );
    }

    final quizzes = ref.watch(subjectQuizzesControllerProvider(widget.subjectId));
    return quizzes.when(
      data: (items) {
        _initializeQuiz(items);
        if (_quiz == null || _questions.isEmpty) {
          return const Center(child: Text('Quiz not available.'));
        }
        final question = _questions[_currentIndex];
        _syncTextController(question);
        final total = _questions.length;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _quiz!.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_remainingSeconds != null) _TimerPill(seconds: _remainingSeconds!),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: (_currentIndex + 1) / total.toDouble()),
            const SizedBox(height: AppSpacing.xs),
            Text('Question ${_currentIndex + 1} of $total'),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${_currentIndex + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MarkdownContent(
                      data: question.question,
                      baseTextStyle: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _QuestionInput(
                      question: question,
                      currentAnswer: _answers[question.id],
                      controller: _textController,
                      onChanged: (value) {
                        setState(() {
                          _answers[question.id] = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _currentIndex == 0
                              ? null
                              : () {
                                  setState(() {
                                    _currentIndex -= 1;
                                  });
                                },
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _answers.remove(question.id);
                              if (_textController.text.isNotEmpty) {
                                _textController.clear();
                              }
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        if (_currentIndex == total - 1)
                          FilledButton(
                            onPressed: _isSubmitting ? null : _submitQuiz,
                            child: Text(_isSubmitting ? 'Submitting...' : 'Submit Quiz'),
                          )
                        else
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _currentIndex += 1;
                              });
                            },
                            child: const Text('Next'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load quiz: $error')),
    );
  }

  void _initializeQuiz(List<QuizRecord> items) {
    if (_quiz != null) {
      return;
    }
    for (final item in items) {
      if (item.id == widget.quizId) {
        _quiz = item;
        break;
      }
    }
    if (_quiz == null) {
      return;
    }
    _questions = [..._quiz!.questions];
    if (_quiz!.settings.shuffleQuestions) {
      _questions.shuffle(Random());
    }
    if (_quiz!.settings.shuffleOptions) {
      _questions = _questions.map(_shuffleQuestionOptions).toList();
    }
    _startedAt = DateTime.now();
    if (_quiz!.settings.timerMode == 'per_quiz' && _quiz!.settings.timerSeconds > 0) {
      _remainingSeconds = _quiz!.settings.timerSeconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _submitted) {
          timer.cancel();
          return;
        }
        if (_remainingSeconds == null) {
          return;
        }
        if (_remainingSeconds! <= 1) {
          timer.cancel();
          _remainingSeconds = 0;
          _submitQuiz();
          return;
        }
        setState(() {
          _remainingSeconds = _remainingSeconds! - 1;
        });
      });
    }
  }

  QuizQuestion _shuffleQuestionOptions(QuizQuestion question) {
    if (question.type != QuizQuestionType.mcq || question.options.isEmpty) {
      return question;
    }
    final indexed = question.options.asMap().entries.toList()..shuffle(Random());
    final newOptions = indexed.map((entry) => entry.value).toList();
    int? newCorrectIndex;
    for (var index = 0; index < indexed.length; index += 1) {
      if (indexed[index].key == question.correctIndex) {
        newCorrectIndex = index;
        break;
      }
    }
    return QuizQuestion(
      id: question.id,
      type: question.type,
      question: question.question,
      options: newOptions,
      correctIndex: newCorrectIndex,
      correctAnswer: question.correctAnswer,
      correctAnswers: question.correctAnswers,
      caseSensitive: question.caseSensitive,
      modelAnswer: question.modelAnswer,
      keywords: question.keywords,
      keywordRules: question.keywordRules,
      minWords: question.minWords,
      maxWords: question.maxWords,
      minimumKeywordMatches: question.minimumKeywordMatches,
      minimumKeywordScorePercent: question.minimumKeywordScorePercent,
      allowPartialCredit: question.allowPartialCredit,
      gradingMode: question.gradingMode,
      explanation: question.explanation,
      points: question.points,
      grading: question.grading,
    );
  }

  void _syncTextController(QuizQuestion question) {
    final answer = _answers[question.id];
    if (question.type == QuizQuestionType.fillBlank ||
        question.type == QuizQuestionType.shortAnswer) {
      final next = answer is String ? answer : '';
      if (_textController.text != next) {
        _textController.text = next;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      }
    } else if (_textController.text.isNotEmpty) {
      _textController.clear();
    }
  }

  Future<void> _submitQuiz() async {
    if (_quiz == null || _submitted || _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    _timer?.cancel();
    try {
      final endedAt = DateTime.now();
      final results = _questions.map(_gradeQuestion).toList();
      final correctCount = results.where((result) => result.isCorrect).length;
      final totalQuestions = results.length;
      final reviewedCount = results
          .where((result) => result.answer.trim().isNotEmpty)
          .length;

      await ref.read(studySessionsRepositoryProvider).addSession(
            StudySessionRecord(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              subjectId: widget.subjectId,
              deckId: null,
              sessionType: 'quiz',
              startedAt: _startedAt!,
              endedAt: endedAt,
              reviewedCount: reviewedCount,
              completedCount: correctCount,
              againCount: max(0, totalQuestions - correctCount),
              dueCount: totalQuestions,
            ),
          );
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(libraryOverviewProvider);

      if (!mounted) {
        return;
      }
      setState(() {
        _submitted = true;
        _results = results;
        _endedAt = endedAt;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit quiz: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  QuizAttemptRecord _gradeQuestion(QuizQuestion question) {
    return _gradingService.gradeQuestion(
      question: question,
      marking: _markingForQuestion(question),
      rawAnswer: _answers[question.id],
    );
  }

  QuizMarking _markingForQuestion(QuizQuestion question) {
    final override = question.grading;
    if (override != null) {
      return QuizMarking(
        correctPoints: question.points,
        wrongPoints: override.wrongPoints,
        skippedPoints: _quiz!.settings.marking.skippedPoints,
        negativeMarking: override.negativeMarking,
        partialCredit: _quiz!.settings.marking.partialCredit,
      );
    }
    return _quiz!.settings.marking;
  }
}

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.question,
    required this.currentAnswer,
    required this.controller,
    required this.onChanged,
  });

  final QuizQuestion question;
  final dynamic currentAnswer;
  final TextEditingController controller;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuizQuestionType.mcq:
        return RadioGroup<int>(
          groupValue: currentAnswer as int?,
          onChanged: (value) => onChanged(value),
          child: Column(
            children: [
              for (var index = 0; index < question.options.length; index += 1)
                RadioListTile<int>(
                  value: index,
                  title: MarkdownContent(
                    data: question.options[index],
                    baseTextStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        );
      case QuizQuestionType.trueFalse:
        return RadioGroup<bool>(
          groupValue: currentAnswer as bool?,
          onChanged: (value) => onChanged(value),
          child: Column(
            children: [
              const RadioListTile<bool>(
                value: true,
                title: Text('True'),
                contentPadding: EdgeInsets.zero,
              ),
              const RadioListTile<bool>(
                value: false,
                title: Text('False'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      case QuizQuestionType.fillBlank:
        return TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: const InputDecoration(
            labelText: 'Enter answer',
          ),
        );
      case QuizQuestionType.shortAnswer:
        return TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: 4,
          maxLines: 7,
          decoration: InputDecoration(
            labelText: 'Write your answer',
            helperText: question.minWords == null && question.maxWords == null
                ? null
                : 'Target: ${question.minWords ?? 0}-${question.maxWords ?? 'any'} words',
          ),
        );
    }
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    final isWarning = seconds <= 300;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.warning : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '${minutes.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isWarning
              ? Colors.white
              : AppColors.onColor(AppColors.primarySoft),
        ),
      ),
    );
  }
}

class _QuizResultsView extends StatelessWidget {
  const _QuizResultsView({
    required this.quiz,
    required this.questions,
    required this.results,
    required this.startedAt,
    required this.endedAt,
  });

  final QuizRecord quiz;
  final List<QuizQuestion> questions;
  final List<QuizAttemptRecord> results;
  final DateTime startedAt;
  final DateTime endedAt;

  @override
  Widget build(BuildContext context) {
    final totalPossible =
        quiz.questions.fold<double>(0.0, (sum, q) => sum + q.points);
    final earned = results.fold<double>(0.0, (sum, r) => sum + r.pointsEarned);
    final correct = results.where((result) => result.isCorrect).length;
    final percent = totalPossible == 0 ? 0.0 : (earned / totalPossible) * 100;
    final passed = quiz.settings.passingScorePercent == null
        ? null
        : percent >= quiz.settings.passingScorePercent!;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz Complete',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('${earned.toStringAsFixed(1)} / ${totalPossible.toStringAsFixed(1)}'),
                Text('${percent.toStringAsFixed(1)}% • $correct/${quiz.questions.length} correct'),
                Text('Time used: ${endedAt.difference(startedAt).inMinutes} min'),
                if (passed != null)
                  Text(passed ? 'Result: Pass' : 'Result: Not yet passing'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < questions.length; index += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q${index + 1}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MarkdownContent(
                      data: questions[index].question,
                      baseTextStyle: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your answer: ${_answerLabel(questions[index], results[index])}',
                    ),
                    Text(
                      'Correct answer: ${_correctAnswerLabel(questions[index])}',
                    ),
                    Text(
                      results[index].isCorrect ? 'Correct' : 'Incorrect',
                      style: TextStyle(
                        color: results[index].isCorrect
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Points: ${results[index].pointsEarned.toStringAsFixed(1)} / ${results[index].maxPoints.toStringAsFixed(1)}',
                    ),
                    if (results[index].keywordScorePercent != null) ...[
                      Text(
                        'Keyword match: ${(results[index].keywordScorePercent! * 100).toStringAsFixed(0)}%',
                      ),
                      Text(
                        results[index].meetsWordCount
                            ? 'Word count: ${results[index].wordCount}'
                            : 'Word count: ${results[index].wordCount} (outside target)',
                      ),
                      if (results[index].matchedKeywords.isNotEmpty)
                        Text(
                          'Matched: ${results[index].matchedKeywords.join(', ')}',
                        ),
                      if (results[index].missingKeywords.isNotEmpty)
                        Text(
                          'Missing: ${results[index].missingKeywords.join(', ')}',
                        ),
                    ],
                    if (questions[index].explanation.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      MarkdownContent(
                        data: questions[index].explanation,
                        baseTextStyle: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (questions[index].type == QuizQuestionType.shortAnswer &&
                        questions[index].modelAnswer.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      MarkdownContent(
                        data: '**Model answer**\n\n${questions[index].modelAnswer}',
                        baseTextStyle: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _answerLabel(QuizQuestion question, QuizAttemptRecord result) {
    if (result.answer.isEmpty) {
      return 'Skipped';
    }
    if (question.type == QuizQuestionType.mcq) {
      final selectedIndex = int.tryParse(result.answer);
      if (selectedIndex != null &&
          selectedIndex >= 0 &&
          selectedIndex < question.options.length) {
        return question.options[selectedIndex];
      }
    }
    return result.answer;
  }

  String _correctAnswerLabel(QuizQuestion question) {
    switch (question.type) {
      case QuizQuestionType.mcq:
        final index = question.correctIndex;
        if (index == null || index < 0 || index >= question.options.length) {
          return 'Not set';
        }
        return question.options[index];
      case QuizQuestionType.trueFalse:
        return question.correctAnswer == true ? 'True' : 'False';
      case QuizQuestionType.fillBlank:
        return question.correctAnswers.join(', ');
      case QuizQuestionType.shortAnswer:
        if (question.modelAnswer.isNotEmpty) {
          return question.modelAnswer;
        }
        return question.keywords.join(', ');
    }
  }
}
