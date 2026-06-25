import 'dart:convert';

class QaItemRecord {
  const QaItemRecord({
    required this.id,
    required this.subjectId,
    required this.unitId,
    required this.question,
    required this.answerMarkdown,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String? unitId;
  final String question;
  final String answerMarkdown;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get excerpt {
    final normalized = answerMarkdown.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 110) {
      return normalized;
    }
    return '${normalized.substring(0, 107)}...';
  }

  QaItemRecord copyWith({
    String? id,
    String? subjectId,
    Object? unitId = _qaItemSentinel,
    String? question,
    String? answerMarkdown,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QaItemRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      unitId: identical(unitId, _qaItemSentinel) ? this.unitId : unitId as String?,
      question: question ?? this.question,
      answerMarkdown: answerMarkdown ?? this.answerMarkdown,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'unitId': unitId,
      'question': question,
      'answerMarkdown': answerMarkdown,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory QaItemRecord.fromMap(Map<String, dynamic> map) {
    return QaItemRecord(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String,
      unitId: map['unitId'] as String?,
      question: map['question'] as String? ?? '',
      answerMarkdown: map['answerMarkdown'] as String? ?? '',
      tags: ((map['tags'] as List?) ?? const []).map((item) => item.toString()).toList(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory QaItemRecord.fromJson(String source) {
    return QaItemRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

const _qaItemSentinel = Object();
