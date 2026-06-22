import 'dart:convert';

class StudySessionRecord {
  const StudySessionRecord({
    required this.id,
    required this.subjectId,
    required this.deckId,
    required this.sessionType,
    required this.startedAt,
    required this.endedAt,
    required this.reviewedCount,
    required this.completedCount,
    required this.againCount,
    required this.dueCount,
  });

  final String id;
  final String? subjectId;
  final String? deckId;
  final String sessionType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int reviewedCount;
  final int completedCount;
  final int againCount;
  final int dueCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'deckId': deckId,
      'sessionType': sessionType,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'reviewedCount': reviewedCount,
      'completedCount': completedCount,
      'againCount': againCount,
      'dueCount': dueCount,
    };
  }

  factory StudySessionRecord.fromMap(Map<String, dynamic> map) {
    return StudySessionRecord(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String?,
      deckId: map['deckId'] as String?,
      sessionType: map['sessionType'] as String,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: DateTime.parse(map['endedAt'] as String),
      reviewedCount: map['reviewedCount'] as int,
      completedCount: map['completedCount'] as int,
      againCount: map['againCount'] as int,
      dueCount: map['dueCount'] as int,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory StudySessionRecord.fromJson(String source) {
    return StudySessionRecord.fromMap(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }
}
