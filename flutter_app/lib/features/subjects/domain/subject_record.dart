import 'dart:convert';

class SubjectRecord {
  const SubjectRecord({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubjectRecord copyWith({
    String? id,
    String? name,
    String? emoji,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubjectRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SubjectRecord.fromMap(Map<String, dynamic> map) {
    return SubjectRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      colorValue: map['colorValue'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SubjectRecord.fromJson(String source) {
    return SubjectRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
