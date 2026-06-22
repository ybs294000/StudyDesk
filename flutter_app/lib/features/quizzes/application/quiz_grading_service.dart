import 'dart:math';

import '../domain/quiz_models.dart';

class QuizGradingService {
  const QuizGradingService();

  QuizAttemptRecord gradeQuestion({
    required QuizQuestion question,
    required QuizMarking marking,
    required dynamic rawAnswer,
  }) {
    final normalizedAnswer = rawAnswer == null ? '' : '$rawAnswer'.trim();
    final isSkipped = normalizedAnswer.isEmpty;

    var isCorrect = false;
    var pointsEarned = marking.skippedPoints;
    var matchedKeywords = const <String>[];
    var missingKeywords = const <String>[];
    double? keywordScorePercent;
    var wordCount = _wordCount(normalizedAnswer);
    var meetsWordCount = true;

    switch (question.type) {
      case QuizQuestionType.mcq:
        isCorrect = rawAnswer is int && rawAnswer == question.correctIndex;
      case QuizQuestionType.trueFalse:
        isCorrect = rawAnswer is bool && rawAnswer == question.correctAnswer;
      case QuizQuestionType.fillBlank:
        final expected = question.correctAnswers.map((answer) {
          return question.caseSensitive ? answer.trim() : _normalize(answer);
        }).toList();
        final actual = question.caseSensitive
            ? normalizedAnswer
            : _normalize(normalizedAnswer);
        isCorrect = expected.contains(actual);
      case QuizQuestionType.shortAnswer:
        final evaluation = _evaluateShortAnswer(question, normalizedAnswer);
        isCorrect = evaluation.isCorrect;
        matchedKeywords = evaluation.matchedKeywords;
        missingKeywords = evaluation.missingKeywords;
        keywordScorePercent = evaluation.keywordScorePercent;
        wordCount = evaluation.wordCount;
        meetsWordCount = evaluation.meetsWordCount;
        if (!isSkipped) {
          if (isCorrect) {
            pointsEarned = question.points;
          } else if (question.allowPartialCredit &&
              evaluation.keywordScorePercent > 0 &&
              evaluation.meetsWordCount) {
            pointsEarned = question.points * evaluation.keywordScorePercent;
          } else {
            pointsEarned = marking.negativeMarking ? marking.wrongPoints : 0.0;
          }
        }
    }

    if (question.type != QuizQuestionType.shortAnswer) {
      pointsEarned = isSkipped
          ? marking.skippedPoints
          : isCorrect
              ? question.points
              : (marking.negativeMarking ? marking.wrongPoints : 0.0);
    }

    return QuizAttemptRecord(
      questionId: question.id,
      questionType: question.type,
      answer: normalizedAnswer,
      isCorrect: isCorrect,
      pointsEarned: (pointsEarned.clamp(
        marking.negativeMarking ? marking.wrongPoints : 0.0,
        question.points,
      ) as num)
          .toDouble(),
      maxPoints: question.points,
      matchedKeywords: matchedKeywords,
      missingKeywords: missingKeywords,
      keywordScorePercent: keywordScorePercent,
      wordCount: wordCount,
      meetsWordCount: meetsWordCount,
    );
  }

  _ShortAnswerEvaluation _evaluateShortAnswer(
    QuizQuestion question,
    String answer,
  ) {
    final wordCount = _wordCount(answer);
    final meetsMinWords = question.minWords == null || wordCount >= question.minWords!;
    final meetsMaxWords = question.maxWords == null || wordCount <= question.maxWords!;
    final meetsWordCount = meetsMinWords && meetsMaxWords;

    final rules = _effectiveRules(question);
    if (rules.isEmpty) {
      return _ShortAnswerEvaluation(
        isCorrect: false,
        matchedKeywords: const [],
        missingKeywords: const [],
        keywordScorePercent: 0,
        wordCount: wordCount,
        meetsWordCount: meetsWordCount,
      );
    }

    final matchedKeywords = <String>[];
    final missingKeywords = <String>[];
    var matchedWeight = 0.0;
    var requiredCount = 0;
    var matchedRequiredCount = 0;

    for (final rule in rules) {
      final matched = _matchesRule(
        answer: answer,
        rule: rule,
        caseSensitive: question.caseSensitive,
      );
      if (matched) {
        matchedKeywords.add(rule.term);
        matchedWeight += rule.weight <= 0 ? 1 : rule.weight;
        if (rule.required) {
          matchedRequiredCount += 1;
        }
      } else {
        missingKeywords.add(rule.term);
      }
      if (rule.required) {
        requiredCount += 1;
      }
    }

    final totalWeight = rules.fold<double>(
      0,
      (sum, rule) => sum + (rule.weight <= 0 ? 1 : rule.weight),
    );
    final matchPercent = totalWeight == 0 ? 0.0 : matchedWeight / totalWeight;
    final minimumMatches = question.minimumKeywordMatches ??
        (requiredCount > 0 ? requiredCount : max(1, (rules.length / 2).ceil()));
    final minimumScorePercent = question.minimumKeywordScorePercent ?? 0.6;
    final hasEnoughMatches = matchedKeywords.length >= minimumMatches;
    final requiredSatisfied =
        requiredCount == 0 || matchedRequiredCount == requiredCount;
    final isCorrect =
        meetsWordCount && requiredSatisfied && hasEnoughMatches && matchPercent >= minimumScorePercent;

    return _ShortAnswerEvaluation(
      isCorrect: isCorrect,
      matchedKeywords: matchedKeywords,
      missingKeywords: missingKeywords,
      keywordScorePercent: (matchPercent.clamp(0.0, 1.0) as num).toDouble(),
      wordCount: wordCount,
      meetsWordCount: meetsWordCount,
    );
  }

  List<QuizKeywordRule> _effectiveRules(QuizQuestion question) {
    final configuredRules = question.keywordRules
        .where((rule) => rule.term.trim().isNotEmpty)
        .toList();
    if (configuredRules.isNotEmpty) {
      return configuredRules;
    }
    return question.keywords
        .where((keyword) => keyword.trim().isNotEmpty)
        .map(
          (keyword) => QuizKeywordRule(
            term: keyword.trim(),
            aliases: const [],
            required: true,
            weight: 1,
          ),
        )
        .toList();
  }

  bool _matchesRule({
    required String answer,
    required QuizKeywordRule rule,
    required bool caseSensitive,
  }) {
    final haystack = caseSensitive ? _collapseWhitespace(answer) : _normalize(answer);
    final candidates = <String>[rule.term, ...rule.aliases];
    for (final candidate in candidates) {
      final needle = caseSensitive
          ? _collapseWhitespace(candidate)
          : _normalize(candidate);
      if (needle.isEmpty) {
        continue;
      }
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  int _wordCount(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .length;
  }

  String _normalize(String value) {
    return _collapseWhitespace(
      value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' '),
    );
  }

  String _collapseWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _ShortAnswerEvaluation {
  const _ShortAnswerEvaluation({
    required this.isCorrect,
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.keywordScorePercent,
    required this.wordCount,
    required this.meetsWordCount,
  });

  final bool isCorrect;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final double keywordScorePercent;
  final int wordCount;
  final bool meetsWordCount;
}
