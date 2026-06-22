import 'dart:convert';

class SubjectUnitRecord {
  const SubjectUnitRecord({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubjectUnitRecord copyWith({
    String? id,
    String? subjectId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubjectUnitRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SubjectUnitRecord.fromMap(Map<String, dynamic> map) {
    return SubjectUnitRecord(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SubjectUnitRecord.fromJson(String source) {
    return SubjectUnitRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
