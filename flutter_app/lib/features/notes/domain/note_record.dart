import 'dart:convert';

class NoteRecord {
  const NoteRecord({
    required this.id,
    required this.subjectId,
    required this.unitId,
    required this.title,
    required this.bodyMarkdown,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String? unitId;
  final String title;
  final String bodyMarkdown;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteRecord copyWith({
    String? id,
    String? subjectId,
    Object? unitId = _noteSentinel,
    String? title,
    String? bodyMarkdown,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      unitId: identical(unitId, _noteSentinel) ? this.unitId : unitId as String?,
      title: title ?? this.title,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get excerpt {
    final sanitized = bodyMarkdown
        .replaceAll(RegExp(r'[#>*`\-\[\]\(\)_]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return 'Empty note';
    }
    if (sanitized.length <= 140) {
      return sanitized;
    }
    return '${sanitized.substring(0, 137)}...';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'unitId': unitId,
      'title': title,
      'bodyMarkdown': bodyMarkdown,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteRecord.fromMap(Map<String, dynamic> map) {
    return NoteRecord(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String,
      unitId: map['unitId'] as String?,
      title: map['title'] as String,
      bodyMarkdown: (map['bodyMarkdown'] as String?) ?? '',
      tags: ((map['tags'] as List?) ?? const []).cast<String>(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NoteRecord.fromJson(String source) {
    return NoteRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

const _noteSentinel = Object();
