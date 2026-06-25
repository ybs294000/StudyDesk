import 'dart:convert';

class CardRecord {
  static const defaultSchedulerVersion = 'fsrs_v6';

  const CardRecord({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.hint,
    required this.schedulerVersion,
    required this.state,
    required this.reviewCount,
    required this.lapseCount,
    required this.intervalDays,
    required this.ease,
    required this.stability,
    required this.difficulty,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String hint;
  final String schedulerVersion;
  final String state;
  final int reviewCount;
  final int lapseCount;
  final int intervalDays;
  final double ease;
  final double stability;
  final double difficulty;
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CardRecord copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
    String? hint,
    String? schedulerVersion,
    String? state,
    int? reviewCount,
    int? lapseCount,
    int? intervalDays,
    double? ease,
    double? stability,
    double? difficulty,
    DateTime? dueAt,
    Object? lastReviewedAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardRecord(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      schedulerVersion: schedulerVersion ?? this.schedulerVersion,
      state: state ?? this.state,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
      intervalDays: intervalDays ?? this.intervalDays,
      ease: ease ?? this.ease,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: identical(lastReviewedAt, _sentinel)
          ? this.lastReviewedAt
          : lastReviewedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deckId': deckId,
      'front': front,
      'back': back,
      'hint': hint,
      'schedulerVersion': schedulerVersion,
      'state': state,
      'reviewCount': reviewCount,
      'lapseCount': lapseCount,
      'intervalDays': intervalDays,
      'ease': ease,
      'stability': stability,
      'difficulty': difficulty,
      'dueAt': dueAt?.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CardRecord.fromMap(Map<String, dynamic> map) {
    return CardRecord(
      id: map['id'] as String,
      deckId: map['deckId'] as String,
      front: map['front'] as String,
      back: map['back'] as String,
      hint: map['hint'] as String,
      schedulerVersion:
          (map['schedulerVersion'] as String?) ?? defaultSchedulerVersion,
      state: (map['state'] as String?) ?? 'new',
      reviewCount: (map['reviewCount'] as int?) ?? 0,
      lapseCount: (map['lapseCount'] as int?) ?? 0,
      intervalDays: (map['intervalDays'] as int?) ?? 0,
      ease: ((map['ease'] as num?) ?? 2.5).toDouble(),
      stability: ((map['stability'] as num?) ?? 0.1).toDouble(),
      difficulty: ((map['difficulty'] as num?) ?? 5.0).toDouble(),
      dueAt: map['dueAt'] == null
          ? null
          : DateTime.parse(map['dueAt'] as String),
      lastReviewedAt: map['lastReviewedAt'] == null
          ? null
          : DateTime.parse(map['lastReviewedAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CardRecord.fromJson(String source) {
    return CardRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

const _sentinel = Object();
