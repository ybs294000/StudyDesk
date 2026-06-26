import 'dart:convert';

class StudyDeskSecurity {
  const StudyDeskSecurity._();

  static const int maxJsonImportBytes = 4 * 1024 * 1024;
  static const int maxCsvImportBytes = 2 * 1024 * 1024;
  static const int maxMarkdownImportBytes = 2 * 1024 * 1024;
  static const int maxJsonTextLength = 4 * 1024 * 1024;

  static const int maxSubjectNameLength = 120;
  static const int maxUnitNameLength = 120;
  static const int maxShortTitleLength = 160;
  static const int maxDescriptionLength = 4000;
  static const int maxTagLength = 48;
  static const int maxTagCount = 24;

  static const int maxCardFaceLength = 16000;
  static const int maxCardHintLength = 4000;
  static const int maxNoteBodyLength = 250000;
  static const int maxQaQuestionLength = 4000;
  static const int maxQaAnswerLength = 50000;
  static const int maxQuizQuestionLength = 12000;
  static const int maxQuizExplanationLength = 16000;
  static const int maxQuizOptionLength = 2000;
  static const int maxQuizOptions = 12;
  static const int maxQuizQuestions = 1000;
  static const int maxDeckCards = 5000;
  static const int maxFileNameLength = 96;

  static void ensureImportSize(
    List<int> bytes, {
    required String label,
    required int maxBytes,
  }) {
    if (bytes.isEmpty) {
      throw FormatException('$label is empty.');
    }
    if (bytes.length > maxBytes) {
      throw FormatException(
        '$label exceeds the StudyDesk import size limit of ${_formatBytes(maxBytes)}.',
      );
    }
  }

  static String decodeUtf8(
    List<int> bytes, {
    required String label,
  }) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw FormatException('$label is not valid UTF-8 text.');
    }
  }

  static Map<String, dynamic> decodeJsonObject(
    String source, {
    required String label,
  }) {
    if (source.length > maxJsonTextLength) {
      throw FormatException(
        '$label exceeds the StudyDesk JSON size limit of ${_formatBytes(maxJsonTextLength)}.',
      );
    }

    dynamic parsed;
    try {
      parsed = jsonDecode(source);
    } on FormatException {
      throw FormatException('$label is not valid JSON.');
    }

    if (parsed is! Map) {
      throw FormatException('$label must contain a top-level JSON object.');
    }
    return Map<String, dynamic>.from(parsed);
  }

  static String sanitizeSingleLine(
    String value, {
    required String field,
    required int maxLength,
    String? fallback,
    bool allowEmpty = false,
  }) {
    final normalized = value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final resolved = normalized.isEmpty ? (fallback?.trim() ?? '') : normalized;
    if (resolved.isEmpty && allowEmpty) {
      return '';
    }
    if (resolved.isEmpty) {
      throw FormatException('$field cannot be empty.');
    }
    if (resolved.length > maxLength) {
      throw FormatException('$field exceeds the maximum length of $maxLength characters.');
    }
    return resolved;
  }

  static String sanitizeMultiline(
    String value, {
    required String field,
    required int maxLength,
    bool allowEmpty = true,
  }) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '');
    final trimmed = normalized.trimRight();
    if (!allowEmpty && trimmed.trim().isEmpty) {
      throw FormatException('$field cannot be empty.');
    }
    if (trimmed.length > maxLength) {
      throw FormatException('$field exceeds the maximum length of $maxLength characters.');
    }
    return trimmed;
  }

  static List<String> sanitizeTags(Iterable<String> tags) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final raw in tags) {
      final value = sanitizeSingleLine(
        raw,
        field: 'Tag',
        maxLength: maxTagLength,
        allowEmpty: true,
      );
      if (value.isEmpty) {
        continue;
      }
      final key = value.toLowerCase();
      if (seen.add(key)) {
        normalized.add(value);
      }
      if (normalized.length >= maxTagCount) {
        break;
      }
    }
    return normalized;
  }

  static String sanitizeFileName(
    String fileName, {
    required String fallback,
  }) {
    final normalized = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001F]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    final resolved = normalized.isEmpty ? fallback : normalized;
    return resolved.length <= maxFileNameLength
        ? resolved
        : resolved.substring(0, maxFileNameLength);
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes bytes';
  }
}
