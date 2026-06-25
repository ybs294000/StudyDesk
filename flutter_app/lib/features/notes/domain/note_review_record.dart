import 'dart:convert';

enum NoteRecallRating {
  needsReread,
  partial,
  full,
}

extension NoteRecallRatingX on NoteRecallRating {
  String get storageValue => switch (this) {
    NoteRecallRating.needsReread => 'needs_reread',
    NoteRecallRating.partial => 'partial',
    NoteRecallRating.full => 'full',
  };

  String get label => switch (this) {
    NoteRecallRating.needsReread => 'Needs reread',
    NoteRecallRating.partial => 'Partial',
    NoteRecallRating.full => 'Full',
  };

  int get suggestedDays => switch (this) {
    NoteRecallRating.needsReread => 1,
    NoteRecallRating.partial => 3,
    NoteRecallRating.full => 7,
  };

  static NoteRecallRating fromStorage(String? value) {
    return switch (value) {
      'full' => NoteRecallRating.full,
      'partial' => NoteRecallRating.partial,
      _ => NoteRecallRating.needsReread,
    };
  }
}

class NoteArchivedPrompt {
  const NoteArchivedPrompt({
    required this.message,
    required this.createdAt,
    required this.archivedAt,
  });

  final String message;
  final DateTime createdAt;
  final DateTime archivedAt;

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'archivedAt': archivedAt.toIso8601String(),
    };
  }

  factory NoteArchivedPrompt.fromMap(Map<String, dynamic> map) {
    return NoteArchivedPrompt(
      message: map['message'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      archivedAt: DateTime.parse(map['archivedAt'] as String),
    );
  }
}

class NoteReviewRecord {
  const NoteReviewRecord({
    required this.noteId,
    required this.subjectId,
    required this.unitId,
    required this.reviewCount,
    required this.lastReadAt,
    required this.dueAt,
    required this.lastRating,
    required this.pendingSelfNote,
    required this.pendingSelfNoteCreatedAt,
    required this.archivedSelfNotes,
    required this.sectionAnnotations,
    required this.updatedAt,
  });

  final String noteId;
  final String subjectId;
  final String? unitId;
  final int reviewCount;
  final DateTime? lastReadAt;
  final DateTime? dueAt;
  final NoteRecallRating? lastRating;
  final String? pendingSelfNote;
  final DateTime? pendingSelfNoteCreatedAt;
  final List<NoteArchivedPrompt> archivedSelfNotes;
  final Map<String, String> sectionAnnotations;
  final DateTime updatedAt;

  bool get isDue {
    final due = dueAt;
    if (due == null) {
      return true;
    }
    return !due.isAfter(DateTime.now());
  }

  NoteReviewRecord copyWith({
    String? noteId,
    String? subjectId,
    Object? unitId = _noteReviewSentinel,
    int? reviewCount,
    Object? lastReadAt = _noteReviewSentinel,
    Object? dueAt = _noteReviewSentinel,
    Object? lastRating = _noteReviewSentinel,
    Object? pendingSelfNote = _noteReviewSentinel,
    Object? pendingSelfNoteCreatedAt = _noteReviewSentinel,
    List<NoteArchivedPrompt>? archivedSelfNotes,
    Map<String, String>? sectionAnnotations,
    DateTime? updatedAt,
  }) {
    return NoteReviewRecord(
      noteId: noteId ?? this.noteId,
      subjectId: subjectId ?? this.subjectId,
      unitId: identical(unitId, _noteReviewSentinel)
          ? this.unitId
          : unitId as String?,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReadAt: identical(lastReadAt, _noteReviewSentinel)
          ? this.lastReadAt
          : lastReadAt as DateTime?,
      dueAt: identical(dueAt, _noteReviewSentinel)
          ? this.dueAt
          : dueAt as DateTime?,
      lastRating: identical(lastRating, _noteReviewSentinel)
          ? this.lastRating
          : lastRating as NoteRecallRating?,
      pendingSelfNote: identical(pendingSelfNote, _noteReviewSentinel)
          ? this.pendingSelfNote
          : pendingSelfNote as String?,
      pendingSelfNoteCreatedAt:
          identical(pendingSelfNoteCreatedAt, _noteReviewSentinel)
              ? this.pendingSelfNoteCreatedAt
              : pendingSelfNoteCreatedAt as DateTime?,
      archivedSelfNotes: archivedSelfNotes ?? this.archivedSelfNotes,
      sectionAnnotations: sectionAnnotations ?? this.sectionAnnotations,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'noteId': noteId,
      'subjectId': subjectId,
      'unitId': unitId,
      'reviewCount': reviewCount,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'dueAt': dueAt?.toIso8601String(),
      'lastRating': lastRating?.storageValue,
      'pendingSelfNote': pendingSelfNote,
      'pendingSelfNoteCreatedAt': pendingSelfNoteCreatedAt?.toIso8601String(),
      'archivedSelfNotes': archivedSelfNotes.map((item) => item.toMap()).toList(),
      'sectionAnnotations': sectionAnnotations,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteReviewRecord.fromMap(Map<String, dynamic> map) {
    return NoteReviewRecord(
      noteId: map['noteId'] as String,
      subjectId: map['subjectId'] as String,
      unitId: map['unitId'] as String?,
      reviewCount: (map['reviewCount'] as int?) ?? 0,
      lastReadAt: map['lastReadAt'] == null
          ? null
          : DateTime.parse(map['lastReadAt'] as String),
      dueAt: map['dueAt'] == null
          ? null
          : DateTime.parse(map['dueAt'] as String),
      lastRating: map['lastRating'] == null
          ? null
          : NoteRecallRatingX.fromStorage(map['lastRating'] as String?),
      pendingSelfNote: map['pendingSelfNote'] as String?,
      pendingSelfNoteCreatedAt: map['pendingSelfNoteCreatedAt'] == null
          ? null
          : DateTime.parse(map['pendingSelfNoteCreatedAt'] as String),
      archivedSelfNotes: ((map['archivedSelfNotes'] as List?) ?? const [])
          .map((item) => NoteArchivedPrompt.fromMap((item as Map).cast<String, dynamic>()))
          .toList(),
      sectionAnnotations: ((map['sectionAnnotations'] as Map?) ?? const {})
          .map((key, value) => MapEntry(key.toString(), value.toString())),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NoteReviewRecord.fromJson(String source) {
    return NoteReviewRecord.fromMap(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory NoteReviewRecord.initial({
    required String noteId,
    required String subjectId,
    required String? unitId,
  }) {
    return NoteReviewRecord(
      noteId: noteId,
      subjectId: subjectId,
      unitId: unitId,
      reviewCount: 0,
      lastReadAt: null,
      dueAt: null,
      lastRating: null,
      pendingSelfNote: null,
      pendingSelfNoteCreatedAt: null,
      archivedSelfNotes: const [],
      sectionAnnotations: const {},
      updatedAt: DateTime.now(),
    );
  }
}

const _noteReviewSentinel = Object();
