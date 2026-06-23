import 'dart:convert';

import 'quiz_models.dart';

class QuizAttemptSessionRecord {
  const QuizAttemptSessionRecord({
    required this.id,
    required this.quizId,
    required this.subjectId,
    required this.unitId,
    required this.quizName,
    required this.quizDescription,
    required this.quizTags,
    required this.startedAt,
    required this.endedAt,
    required this.mode,
    required this.totalQuestions,
    required this.attemptedQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
    required this.rawScore,
    required this.maxScore,
    required this.scorePercent,
    required this.passingScorePercent,
    required this.passed,
    required this.weakTags,
    required this.strongTags,
    required this.items,
  });

  final String id;
  final String quizId;
  final String subjectId;
  final String? unitId;
  final String quizName;
  final String quizDescription;
  final List<String> quizTags;
  final DateTime startedAt;
  final DateTime endedAt;
  final String mode;
  final int totalQuestions;
  final int attemptedQuestions;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final double rawScore;
  final double maxScore;
  final double scorePercent;
  final int? passingScorePercent;
  final bool? passed;
  final List<String> weakTags;
  final List<String> strongTags;
  final List<QuizAttemptItemRecord> items;

  Duration get duration => endedAt.difference(startedAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'subjectId': subjectId,
      'unitId': unitId,
      'quizName': quizName,
      'quizDescription': quizDescription,
      'quizTags': quizTags,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'mode': mode,
      'totalQuestions': totalQuestions,
      'attemptedQuestions': attemptedQuestions,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'skippedCount': skippedCount,
      'rawScore': rawScore,
      'maxScore': maxScore,
      'scorePercent': scorePercent,
      'passingScorePercent': passingScorePercent,
      'passed': passed,
      'weakTags': weakTags,
      'strongTags': strongTags,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory QuizAttemptSessionRecord.fromMap(Map<String, dynamic> map) {
    return QuizAttemptSessionRecord(
      id: map['id'] as String,
      quizId: map['quizId'] as String,
      subjectId: map['subjectId'] as String,
      unitId: map['unitId'] as String?,
      quizName: (map['quizName'] as String?) ?? '',
      quizDescription: (map['quizDescription'] as String?) ?? '',
      quizTags: ((map['quizTags'] as List?) ?? const []).cast<String>(),
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: DateTime.parse(map['endedAt'] as String),
      mode: (map['mode'] as String?) ?? 'practice',
      totalQuestions: map['totalQuestions'] as int,
      attemptedQuestions: map['attemptedQuestions'] as int,
      correctCount: map['correctCount'] as int,
      wrongCount: map['wrongCount'] as int,
      skippedCount: map['skippedCount'] as int,
      rawScore: ((map['rawScore'] as num?) ?? 0).toDouble(),
      maxScore: ((map['maxScore'] as num?) ?? 0).toDouble(),
      scorePercent: ((map['scorePercent'] as num?) ?? 0).toDouble(),
      passingScorePercent: map['passingScorePercent'] as int?,
      passed: map['passed'] as bool?,
      weakTags: ((map['weakTags'] as List?) ?? const []).cast<String>(),
      strongTags: ((map['strongTags'] as List?) ?? const []).cast<String>(),
      items: ((map['items'] as List?) ?? const [])
          .map(
            (item) => QuizAttemptItemRecord.fromMap(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory QuizAttemptSessionRecord.fromJson(String source) {
    return QuizAttemptSessionRecord.fromMap(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }
}

class QuizAttemptItemRecord {
  const QuizAttemptItemRecord({
    required this.questionId,
    required this.question,
    required this.questionType,
    required this.options,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.wasSkipped,
    required this.hintUsed,
    required this.hintToggledAtSeconds,
    required this.timeSpentSeconds,
    required this.tags,
    required this.explanation,
    required this.pointsAwarded,
    required this.maxPoints,
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.keywordScorePercent,
    required this.wordCount,
    required this.meetsWordCount,
  });

  final String questionId;
  final String question;
  final QuizQuestionType questionType;
  final List<String> options;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final bool wasSkipped;
  final bool hintUsed;
  final int? hintToggledAtSeconds;
  final int timeSpentSeconds;
  final List<String> tags;
  final String explanation;
  final double pointsAwarded;
  final double maxPoints;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final double? keywordScorePercent;
  final int wordCount;
  final bool meetsWordCount;

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'question': question,
      'questionType': questionType.storageValue,
      'options': options,
      'selectedAnswer': selectedAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      'wasSkipped': wasSkipped,
      'hintUsed': hintUsed,
      'hintToggledAtSeconds': hintToggledAtSeconds,
      'timeSpentSeconds': timeSpentSeconds,
      'tags': tags,
      'explanation': explanation,
      'pointsAwarded': pointsAwarded,
      'maxPoints': maxPoints,
      'matchedKeywords': matchedKeywords,
      'missingKeywords': missingKeywords,
      'keywordScorePercent': keywordScorePercent,
      'wordCount': wordCount,
      'meetsWordCount': meetsWordCount,
    };
  }

  factory QuizAttemptItemRecord.fromMap(Map<String, dynamic> map) {
    return QuizAttemptItemRecord(
      questionId: map['questionId'] as String,
      question: (map['question'] as String?) ?? '',
      questionType: QuizQuestionTypeX.fromStorage(
        (map['questionType'] as String?) ?? 'mcq',
      ),
      options: ((map['options'] as List?) ?? const []).cast<String>(),
      selectedAnswer: (map['selectedAnswer'] as String?) ?? '',
      correctAnswer: (map['correctAnswer'] as String?) ?? '',
      isCorrect: (map['isCorrect'] as bool?) ?? false,
      wasSkipped: (map['wasSkipped'] as bool?) ?? false,
      hintUsed: (map['hintUsed'] as bool?) ?? false,
      hintToggledAtSeconds: map['hintToggledAtSeconds'] as int?,
      timeSpentSeconds: (map['timeSpentSeconds'] as int?) ?? 0,
      tags: ((map['tags'] as List?) ?? const []).cast<String>(),
      explanation: (map['explanation'] as String?) ?? '',
      pointsAwarded: ((map['pointsAwarded'] as num?) ?? 0).toDouble(),
      maxPoints: ((map['maxPoints'] as num?) ?? 0).toDouble(),
      matchedKeywords: ((map['matchedKeywords'] as List?) ?? const []).cast<String>(),
      missingKeywords: ((map['missingKeywords'] as List?) ?? const []).cast<String>(),
      keywordScorePercent: (map['keywordScorePercent'] as num?)?.toDouble(),
      wordCount: (map['wordCount'] as int?) ?? 0,
      meetsWordCount: (map['meetsWordCount'] as bool?) ?? true,
    );
  }
}
