import 'dart:convert';

import '../../study/domain/study_rating.dart';

enum QaRecallRating {
  couldNotRecall,
  partial,
  full,
}

extension QaRecallRatingX on QaRecallRating {
  String get storageValue => switch (this) {
    QaRecallRating.couldNotRecall => 'could_not_recall',
    QaRecallRating.partial => 'partial',
    QaRecallRating.full => 'full',
  };

  String get label => switch (this) {
    QaRecallRating.couldNotRecall => 'Couldn’t recall',
    QaRecallRating.partial => 'Partial',
    QaRecallRating.full => 'Full',
  };

  StudyRating get studyRating => switch (this) {
    QaRecallRating.couldNotRecall => StudyRating.again,
    QaRecallRating.partial => StudyRating.good,
    QaRecallRating.full => StudyRating.easy,
  };

  static QaRecallRating fromStorage(String? value) {
    return switch (value) {
      'full' => QaRecallRating.full,
      'partial' => QaRecallRating.partial,
      _ => QaRecallRating.couldNotRecall,
    };
  }
}

class QaReviewRecord {
  const QaReviewRecord({
    required this.promptId,
    required this.subjectId,
    required this.unitId,
    required this.reviewCount,
    required this.lapseCount,
    required this.intervalDays,
    required this.state,
    required this.stability,
    required this.difficulty,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.lastRating,
    required this.lastAnswerSnippet,
    required this.updatedAt,
  });

  final String promptId;
  final String subjectId;
  final String? unitId;
  final int reviewCount;
  final int lapseCount;
  final int intervalDays;
  final String state;
  final double stability;
  final double difficulty;
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;
  final QaRecallRating? lastRating;
  final String? lastAnswerSnippet;
  final DateTime updatedAt;

  bool get isDue {
    final due = dueAt;
    if (due == null) {
      return true;
    }
    return !due.isAfter(DateTime.now());
  }

  QaReviewRecord copyWith({
    String? promptId,
    String? subjectId,
    Object? unitId = _qaReviewSentinel,
    int? reviewCount,
    int? lapseCount,
    int? intervalDays,
    String? state,
    double? stability,
    double? difficulty,
    Object? dueAt = _qaReviewSentinel,
    Object? lastReviewedAt = _qaReviewSentinel,
    Object? lastRating = _qaReviewSentinel,
    Object? lastAnswerSnippet = _qaReviewSentinel,
    DateTime? updatedAt,
  }) {
    return QaReviewRecord(
      promptId: promptId ?? this.promptId,
      subjectId: subjectId ?? this.subjectId,
      unitId: identical(unitId, _qaReviewSentinel) ? this.unitId : unitId as String?,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
      intervalDays: intervalDays ?? this.intervalDays,
      state: state ?? this.state,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      dueAt: identical(dueAt, _qaReviewSentinel) ? this.dueAt : dueAt as DateTime?,
      lastReviewedAt: identical(lastReviewedAt, _qaReviewSentinel)
          ? this.lastReviewedAt
          : lastReviewedAt as DateTime?,
      lastRating: identical(lastRating, _qaReviewSentinel)
          ? this.lastRating
          : lastRating as QaRecallRating?,
      lastAnswerSnippet: identical(lastAnswerSnippet, _qaReviewSentinel)
          ? this.lastAnswerSnippet
          : lastAnswerSnippet as String?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'promptId': promptId,
      'subjectId': subjectId,
      'unitId': unitId,
      'reviewCount': reviewCount,
      'lapseCount': lapseCount,
      'intervalDays': intervalDays,
      'state': state,
      'stability': stability,
      'difficulty': difficulty,
      'dueAt': dueAt?.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'lastRating': lastRating?.storageValue,
      'lastAnswerSnippet': lastAnswerSnippet,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory QaReviewRecord.fromMap(Map<String, dynamic> map) {
    return QaReviewRecord(
      promptId: map['promptId'] as String,
      subjectId: map['subjectId'] as String,
      unitId: map['unitId'] as String?,
      reviewCount: (map['reviewCount'] as int?) ?? 0,
      lapseCount: (map['lapseCount'] as int?) ?? 0,
      intervalDays: (map['intervalDays'] as int?) ?? 0,
      state: (map['state'] as String?) ?? 'new',
      stability: ((map['stability'] as num?) ?? 0.1).toDouble(),
      difficulty: ((map['difficulty'] as num?) ?? 5.0).toDouble(),
      dueAt: map['dueAt'] == null ? null : DateTime.parse(map['dueAt'] as String),
      lastReviewedAt: map['lastReviewedAt'] == null
          ? null
          : DateTime.parse(map['lastReviewedAt'] as String),
      lastRating: map['lastRating'] == null
          ? null
          : QaRecallRatingX.fromStorage(map['lastRating'] as String?),
      lastAnswerSnippet: map['lastAnswerSnippet'] as String?,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory QaReviewRecord.fromJson(String source) {
    return QaReviewRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  factory QaReviewRecord.initial({
    required String promptId,
    required String subjectId,
    required String? unitId,
  }) {
    return QaReviewRecord(
      promptId: promptId,
      subjectId: subjectId,
      unitId: unitId,
      reviewCount: 0,
      lapseCount: 0,
      intervalDays: 0,
      state: 'new',
      stability: 0.1,
      difficulty: 5.0,
      dueAt: null,
      lastReviewedAt: null,
      lastRating: null,
      lastAnswerSnippet: null,
      updatedAt: DateTime.now(),
    );
  }
}

const _qaReviewSentinel = Object();
