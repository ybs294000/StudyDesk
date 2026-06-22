import 'dart:convert';

class DeckRecord {
  const DeckRecord({
    required this.id,
    required this.subjectId,
    required this.unitId,
    required this.name,
    required this.description,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String? unitId;
  final String name;
  final String description;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeckRecord copyWith({
    String? id,
    String? subjectId,
    Object? unitId = _deckSentinel,
    String? name,
    String? description,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeckRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      unitId: identical(unitId, _deckSentinel) ? this.unitId : unitId as String?,
      name: name ?? this.name,
      description: description ?? this.description,
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
      'name': name,
      'description': description,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DeckRecord.fromMap(Map<String, dynamic> map) {
    return DeckRecord(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String,
      unitId: map['unitId'] as String?,
      name: map['name'] as String,
      description: map['description'] as String,
      tags: ((map['tags'] as List?) ?? const []).cast<String>(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DeckRecord.fromJson(String source) {
    return DeckRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

const _deckSentinel = Object();
