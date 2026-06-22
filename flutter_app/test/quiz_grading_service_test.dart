import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/features/quizzes/application/quiz_grading_service.dart';
import 'package:studydesk/features/quizzes/domain/quiz_models.dart';

void main() {
  const service = QuizGradingService();
  const marking = QuizMarking(
    correctPoints: 4,
    wrongPoints: -1,
    skippedPoints: 0,
    negativeMarking: true,
    partialCredit: true,
  );

  QuizQuestion buildQuestion({bool allowPartialCredit = true}) {
    return QuizQuestion(
      id: 'qa_1',
      type: QuizQuestionType.shortAnswer,
      question: 'Explain why mitochondria are called the powerhouse of the cell.',
      options: const [],
      correctIndex: null,
      correctAnswer: null,
      correctAnswers: const [],
      caseSensitive: false,
      modelAnswer: 'They produce ATP through cellular respiration.',
      keywords: const ['ATP', 'energy', 'cellular respiration'],
      keywordRules: const [
        QuizKeywordRule(
          term: 'ATP',
          aliases: ['adenosine triphosphate'],
          required: true,
          weight: 1.2,
        ),
        QuizKeywordRule(
          term: 'energy',
          aliases: ['usable energy'],
          required: true,
          weight: 1.0,
        ),
        QuizKeywordRule(
          term: 'cellular respiration',
          aliases: ['respiration'],
          required: false,
          weight: 0.8,
        ),
      ],
      minWords: 5,
      maxWords: 40,
      minimumKeywordMatches: 2,
      minimumKeywordScorePercent: 0.6,
      allowPartialCredit: allowPartialCredit,
      gradingMode: 'keywords',
      explanation: '',
      points: 4,
      grading: null,
    );
  }

  test('awards full credit when required concepts and threshold are met', () {
    final result = service.gradeQuestion(
      question: buildQuestion(),
      marking: marking,
      rawAnswer:
          'Mitochondria make ATP and provide energy for the cell through cellular respiration.',
    );

    expect(result.isCorrect, isTrue);
    expect(result.pointsEarned, 4);
    expect(result.matchedKeywords, containsAll(['ATP', 'energy']));
    expect(result.keywordScorePercent, greaterThanOrEqualTo(0.6));
  });

  test('awards partial credit when configured and only some concepts match', () {
    final result = service.gradeQuestion(
      question: buildQuestion(),
      marking: marking,
      rawAnswer: 'It makes ATP for the cell.',
    );

    expect(result.isCorrect, isFalse);
    expect(result.pointsEarned, greaterThan(0));
    expect(result.pointsEarned, lessThan(4));
    expect(result.missingKeywords, contains('energy'));
  });

  test('applies negative marking when partial credit is disabled', () {
    final result = service.gradeQuestion(
      question: buildQuestion(allowPartialCredit: false),
      marking: marking,
      rawAnswer: 'It makes ATP for the cell.',
    );

    expect(result.isCorrect, isFalse);
    expect(result.pointsEarned, -1);
  });
}
