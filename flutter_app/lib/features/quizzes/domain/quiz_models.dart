import 'dart:convert';

enum QuizQuestionType {
  mcq,
  trueFalse,
  fillBlank,
  shortAnswer,
}

extension QuizQuestionTypeX on QuizQuestionType {
  String get storageValue => switch (this) {
    QuizQuestionType.mcq => 'mcq',
    QuizQuestionType.trueFalse => 'true_false',
    QuizQuestionType.fillBlank => 'fill_blank',
    QuizQuestionType.shortAnswer => 'short_answer',
  };

  static QuizQuestionType fromStorage(String value) {
    return switch (value) {
      'mcq' => QuizQuestionType.mcq,
      'true_false' => QuizQuestionType.trueFalse,
      'fill_blank' => QuizQuestionType.fillBlank,
      'short_answer' => QuizQuestionType.shortAnswer,
      _ => QuizQuestionType.mcq,
    };
  }
}

class QuizRecord {
  const QuizRecord({
    required this.id,
    required this.subjectId,
    required this.unitId,
    required this.name,
    required this.description,
    required this.tags,
    required this.settings,
    required this.questions,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String? unitId;
  final String name;
  final String description;
  final List<String> tags;
  final QuizSettings settings;
  final List<QuizQuestion> questions;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuizRecord copyWith({
    String? id,
    String? subjectId,
    Object? unitId = _quizSentinel,
    String? name,
    String? description,
    List<String>? tags,
    QuizSettings? settings,
    List<QuizQuestion>? questions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      unitId: identical(unitId, _quizSentinel) ? this.unitId : unitId as String?,
      name: name ?? this.name,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      settings: settings ?? this.settings,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'unitId': unitId,
      'name': name,
      'description': description,
      'tags': tags,
      'settings': settings.toMap(),
      'questions': questions.map((q) => q.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory QuizRecord.fromMap(Map<String, dynamic> map) {
    return QuizRecord(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String,
      unitId: map['unitId'] as String?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      tags: ((map['tags'] as List?) ?? const []).cast<String>(),
      settings: QuizSettings.fromMap(
        (map['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      questions: ((map['questions'] as List?) ?? const [])
          .map((question) => QuizQuestion.fromMap((question as Map).cast<String, dynamic>()))
          .toList(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory QuizRecord.fromJson(String source) {
    return QuizRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

const _quizSentinel = Object();

class QuizSettings {
  const QuizSettings({
    required this.shuffleQuestions,
    required this.shuffleOptions,
    required this.timerMode,
    required this.timerSeconds,
    required this.showFeedback,
    required this.passingScorePercent,
    required this.marking,
    required this.sectionRules,
  });

  final bool shuffleQuestions;
  final bool shuffleOptions;
  final String timerMode;
  final int timerSeconds;
  final String showFeedback;
  final int? passingScorePercent;
  final QuizMarking marking;
  final List<QuizSectionRule> sectionRules;

  static const defaults = QuizSettings(
    shuffleQuestions: false,
    shuffleOptions: false,
    timerMode: 'none',
    timerSeconds: 0,
    showFeedback: 'after_quiz',
    passingScorePercent: null,
    marking: QuizMarking.defaults,
    sectionRules: [],
  );

  Map<String, dynamic> toMap() {
    return {
      'shuffle_questions': shuffleQuestions,
      'shuffle_options': shuffleOptions,
      'timer_mode': timerMode,
      'timer_seconds': timerSeconds,
      'show_feedback': showFeedback,
      'passing_score_percent': passingScorePercent,
      'marking': marking.toMap(),
      'section_rules': sectionRules.map((rule) => rule.toMap()).toList(),
    };
  }

  factory QuizSettings.fromMap(Map<String, dynamic> map) {
    final rawTimerSeconds = map['timer_seconds'];
    return QuizSettings(
      shuffleQuestions: (map['shuffle_questions'] as bool?) ?? false,
      shuffleOptions: (map['shuffle_options'] as bool?) ?? false,
      timerMode: (map['timer_mode'] as String?) ?? 'none',
      timerSeconds: rawTimerSeconds is int
          ? rawTimerSeconds
          : ((rawTimerSeconds as num?)?.toInt() ?? 0),
      showFeedback: (map['show_feedback'] as String?) ?? 'after_quiz',
      passingScorePercent: map['passing_score_percent'] as int?,
      marking: QuizMarking.fromMap(
        (map['marking'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      sectionRules: ((map['section_rules'] as List?) ?? const [])
          .map((rule) => QuizSectionRule.fromMap((rule as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class QuizMarking {
  const QuizMarking({
    required this.correctPoints,
    required this.wrongPoints,
    required this.skippedPoints,
    required this.negativeMarking,
    required this.partialCredit,
  });

  static const defaults = QuizMarking(
    correctPoints: 1,
    wrongPoints: 0,
    skippedPoints: 0,
    negativeMarking: false,
    partialCredit: false,
  );

  final double correctPoints;
  final double wrongPoints;
  final double skippedPoints;
  final bool negativeMarking;
  final bool partialCredit;

  Map<String, dynamic> toMap() {
    return {
      'correct_points': correctPoints,
      'wrong_points': wrongPoints,
      'skipped_points': skippedPoints,
      'negative_marking': negativeMarking,
      'partial_credit': partialCredit,
    };
  }

  factory QuizMarking.fromMap(Map<String, dynamic> map) {
    return QuizMarking(
      correctPoints: ((map['correct_points'] as num?) ?? 1).toDouble(),
      wrongPoints: ((map['wrong_points'] as num?) ?? 0).toDouble(),
      skippedPoints: ((map['skipped_points'] as num?) ?? 0).toDouble(),
      negativeMarking: (map['negative_marking'] as bool?) ?? false,
      partialCredit: (map['partial_credit'] as bool?) ?? false,
    );
  }
}

class QuizSectionRule {
  const QuizSectionRule({
    required this.sectionId,
    required this.name,
    required this.questionTypes,
    required this.negativeMarking,
    required this.wrongPoints,
  });

  final String sectionId;
  final String name;
  final List<String> questionTypes;
  final bool negativeMarking;
  final double wrongPoints;

  Map<String, dynamic> toMap() {
    return {
      'section_id': sectionId,
      'name': name,
      'question_types': questionTypes,
      'negative_marking': negativeMarking,
      'wrong_points': wrongPoints,
    };
  }

  factory QuizSectionRule.fromMap(Map<String, dynamic> map) {
    return QuizSectionRule(
      sectionId: (map['section_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      questionTypes: ((map['question_types'] as List?) ?? const []).cast<String>(),
      negativeMarking: (map['negative_marking'] as bool?) ?? false,
      wrongPoints: ((map['wrong_points'] as num?) ?? 0).toDouble(),
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.correctAnswer,
    required this.correctAnswers,
    required this.caseSensitive,
    required this.modelAnswer,
    required this.keywords,
    required this.keywordRules,
    required this.minWords,
    required this.maxWords,
    required this.minimumKeywordMatches,
    required this.minimumKeywordScorePercent,
    required this.allowPartialCredit,
    required this.gradingMode,
    required this.explanation,
    required this.points,
    required this.grading,
  });

  final String id;
  final QuizQuestionType type;
  final String question;
  final List<String> options;
  final int? correctIndex;
  final bool? correctAnswer;
  final List<String> correctAnswers;
  final bool caseSensitive;
  final String modelAnswer;
  final List<String> keywords;
  final List<QuizKeywordRule> keywordRules;
  final int? minWords;
  final int? maxWords;
  final int? minimumKeywordMatches;
  final double? minimumKeywordScorePercent;
  final bool allowPartialCredit;
  final String gradingMode;
  final String explanation;
  final double points;
  final QuizQuestionGrading? grading;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.storageValue,
      'question': question,
      'options': options,
      'correct_index': correctIndex,
      'correct_answer': correctAnswer,
      'correct_answers': correctAnswers,
      'case_sensitive': caseSensitive,
      'model_answer': modelAnswer,
      'keywords': keywords,
      'keyword_rules': keywordRules.map((rule) => rule.toMap()).toList(),
      'min_words': minWords,
      'max_words': maxWords,
      'minimum_keyword_matches': minimumKeywordMatches,
      'minimum_keyword_score_percent': minimumKeywordScorePercent,
      'allow_partial_credit': allowPartialCredit,
      'grading_mode': gradingMode,
      'explanation': explanation,
      'points': points,
      'grading': grading?.toMap(),
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] as String,
      type: QuizQuestionTypeX.fromStorage((map['type'] as String?) ?? 'mcq'),
      question: (map['question'] as String?) ?? '',
      options: ((map['options'] as List?) ?? const []).cast<String>(),
      correctIndex: map['correct_index'] as int?,
      correctAnswer: map['correct_answer'] as bool?,
      correctAnswers: ((map['correct_answers'] as List?) ?? const []).cast<String>(),
      caseSensitive: (map['case_sensitive'] as bool?) ?? false,
      modelAnswer: (map['model_answer'] as String?) ?? '',
      keywords: ((map['keywords'] as List?) ?? const []).cast<String>(),
      keywordRules: ((map['keyword_rules'] as List?) ?? const [])
          .map((rule) => QuizKeywordRule.fromMap((rule as Map).cast<String, dynamic>()))
          .toList(),
      minWords: map['min_words'] as int?,
      maxWords: map['max_words'] as int?,
      minimumKeywordMatches: map['minimum_keyword_matches'] as int?,
      minimumKeywordScorePercent:
          ((map['minimum_keyword_score_percent'] as num?)?.toDouble()),
      allowPartialCredit: (map['allow_partial_credit'] as bool?) ?? false,
      gradingMode: (map['grading_mode'] as String?) ?? 'keywords',
      explanation: (map['explanation'] as String?) ?? '',
      points: ((map['points'] as num?) ?? 1).toDouble(),
      grading: map['grading'] == null
          ? null
          : QuizQuestionGrading.fromMap((map['grading'] as Map).cast<String, dynamic>()),
    );
  }
}

class QuizKeywordRule {
  const QuizKeywordRule({
    required this.term,
    required this.aliases,
    required this.required,
    required this.weight,
  });

  final String term;
  final List<String> aliases;
  final bool required;
  final double weight;

  Map<String, dynamic> toMap() {
    return {
      'term': term,
      'aliases': aliases,
      'required': required,
      'weight': weight,
    };
  }

  factory QuizKeywordRule.fromMap(Map<String, dynamic> map) {
    return QuizKeywordRule(
      term: (map['term'] as String?)?.trim() ?? '',
      aliases: ((map['aliases'] as List?) ?? const []).cast<String>(),
      required: (map['required'] as bool?) ?? true,
      weight: ((map['weight'] as num?) ?? 1).toDouble(),
    );
  }
}

class QuizQuestionGrading {
  const QuizQuestionGrading({
    required this.negativeMarking,
    required this.wrongPoints,
  });

  final bool negativeMarking;
  final double wrongPoints;

  Map<String, dynamic> toMap() {
    return {
      'negative_marking': negativeMarking,
      'wrong_points': wrongPoints,
    };
  }

  factory QuizQuestionGrading.fromMap(Map<String, dynamic> map) {
    return QuizQuestionGrading(
      negativeMarking: (map['negative_marking'] as bool?) ?? false,
      wrongPoints: ((map['wrong_points'] as num?) ?? 0).toDouble(),
    );
  }
}

class QuizAttemptRecord {
  const QuizAttemptRecord({
    required this.questionId,
    required this.questionType,
    required this.answer,
    required this.isCorrect,
    required this.pointsEarned,
    required this.maxPoints,
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.keywordScorePercent,
    required this.wordCount,
    required this.meetsWordCount,
  });

  final String questionId;
  final QuizQuestionType questionType;
  final String answer;
  final bool isCorrect;
  final double pointsEarned;
  final double maxPoints;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final double? keywordScorePercent;
  final int wordCount;
  final bool meetsWordCount;

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'questionType': questionType.storageValue,
      'answer': answer,
      'isCorrect': isCorrect,
      'pointsEarned': pointsEarned,
      'maxPoints': maxPoints,
      'matchedKeywords': matchedKeywords,
      'missingKeywords': missingKeywords,
      'keywordScorePercent': keywordScorePercent,
      'wordCount': wordCount,
      'meetsWordCount': meetsWordCount,
    };
  }

  factory QuizAttemptRecord.fromMap(Map<String, dynamic> map) {
    return QuizAttemptRecord(
      questionId: map['questionId'] as String,
      questionType: QuizQuestionTypeX.fromStorage(
        (map['questionType'] as String?) ?? 'mcq',
      ),
      answer: (map['answer'] as String?) ?? '',
      isCorrect: (map['isCorrect'] as bool?) ?? false,
      pointsEarned: ((map['pointsEarned'] as num?) ?? 0).toDouble(),
      maxPoints: ((map['maxPoints'] as num?) ?? 0).toDouble(),
      matchedKeywords: ((map['matchedKeywords'] as List?) ?? const []).cast<String>(),
      missingKeywords: ((map['missingKeywords'] as List?) ?? const []).cast<String>(),
      keywordScorePercent: (map['keywordScorePercent'] as num?)?.toDouble(),
      wordCount: (map['wordCount'] as int?) ?? 0,
      meetsWordCount: (map['meetsWordCount'] as bool?) ?? true,
    );
  }
}
