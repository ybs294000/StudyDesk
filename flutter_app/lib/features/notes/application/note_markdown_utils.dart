import '../domain/note_record.dart';

class NoteHeading {
  const NoteHeading({
    required this.level,
    required this.text,
    required this.lineIndex,
  });

  final int level;
  final String text;
  final int lineIndex;
}

class NoteLinkMatch {
  const NoteLinkMatch({
    required this.title,
    required this.label,
  });

  final String title;
  final String label;
}

class NoteSection {
  const NoteSection({
    required this.heading,
    required this.level,
    required this.bodyMarkdown,
  });

  final String heading;
  final int level;
  final String bodyMarkdown;
}

final _wikiLinkPattern = RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]');

List<NoteHeading> extractHeadings(String markdown) {
  final lines = markdown.split('\n');
  final headings = <NoteHeading>[];
  for (var index = 0; index < lines.length; index += 1) {
    final match = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(lines[index].trim());
    if (match == null) {
      continue;
    }
    final text = match.group(2)?.trim() ?? '';
    if (text.isEmpty) {
      continue;
    }
    headings.add(
      NoteHeading(
        level: match.group(1)!.length,
        text: text,
        lineIndex: index,
      ),
    );
  }
  return headings;
}

int resolveSectionHeadingLevel(String markdown) {
  final override = _frontmatterSectionLevel(markdown);
  if (override != null) {
    return override;
  }

  final headings = extractHeadings(markdown);
  if (headings.isEmpty) {
    return 2;
  }

  final counts = <int, int>{};
  for (final heading in headings) {
    counts.update(heading.level, (value) => value + 1, ifAbsent: () => 1);
  }
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final countComparison = b.value.compareTo(a.value);
      if (countComparison != 0) {
        return countComparison;
      }
      return a.key.compareTo(b.key);
    });
  return ranked.first.key;
}

List<NoteSection> extractSections(String markdown) {
  final headings = extractHeadings(markdown);
  if (headings.isEmpty) {
    return const [];
  }

  final lines = markdown.split('\n');
  final sectionLevel = resolveSectionHeadingLevel(markdown);
  final sections = <NoteSection>[];

  for (var index = 0; index < headings.length; index += 1) {
    final heading = headings[index];
    if (heading.level != sectionLevel) {
      continue;
    }

    var endLineIndex = lines.length;
    for (var nextIndex = index + 1; nextIndex < headings.length; nextIndex += 1) {
      final nextHeading = headings[nextIndex];
      if (nextHeading.level <= sectionLevel) {
        endLineIndex = nextHeading.lineIndex;
        break;
      }
    }

    final bodyLines = lines.sublist(heading.lineIndex + 1, endLineIndex);
    final body = bodyLines.join('\n').trim();
    if (body.isEmpty) {
      continue;
    }

    sections.add(
      NoteSection(
        heading: heading.text,
        level: heading.level,
        bodyMarkdown: body,
      ),
    );
  }

  return sections;
}

List<NoteLinkMatch> extractWikiLinks(String markdown) {
  return _wikiLinkPattern.allMatches(markdown).map((match) {
    final title = (match.group(1) ?? '').trim();
    final label = (match.group(2) ?? title).trim();
    return NoteLinkMatch(title: title, label: label);
  }).where((link) => link.title.isNotEmpty).toList();
}

String convertWikiLinksToMarkdown(String markdown) {
  return markdown.replaceAllMapped(_wikiLinkPattern, (match) {
    final title = (match.group(1) ?? '').trim();
    final label = (match.group(2) ?? title).trim();
    if (title.isEmpty) {
      return match.group(0) ?? '';
    }
    return '[$label](studydesk-note://${Uri.encodeComponent(title)})';
  });
}

List<NoteRecord> findBacklinks({
  required List<NoteRecord> notes,
  required NoteRecord target,
}) {
  final normalizedTitle = target.title.trim().toLowerCase();
  return notes.where((note) {
    if (note.id == target.id) {
      return false;
    }
    for (final link in extractWikiLinks(note.bodyMarkdown)) {
      if (link.title.trim().toLowerCase() == normalizedTitle) {
        return true;
      }
    }
    return false;
  }).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

NoteRecord? resolveLinkedNote({
  required List<NoteRecord> notes,
  required String title,
}) {
  final normalizedTitle = title.trim().toLowerCase();
  for (final note in notes) {
    if (note.title.trim().toLowerCase() == normalizedTitle) {
      return note;
    }
  }
  return null;
}

String deriveTitleFromMarkdown(String markdown, {String fallback = 'Untitled Note'}) {
  final headings = extractHeadings(markdown);
  if (headings.isNotEmpty) {
    return headings.first.text;
  }

  final lines = markdown
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  for (final line in lines) {
    if (line.length <= 80) {
      return line;
    }
    return '${line.substring(0, 77)}...';
  }
  return fallback;
}

String? currentHeadingForOffset(String markdown, int offset) {
  final safeOffset = offset.clamp(0, markdown.length);
  final before = markdown.substring(0, safeOffset);
  final lineIndex = '\n'.allMatches(before).length;
  final headings = extractHeadings(markdown);

  String? heading;
  for (final item in headings) {
    if (item.lineIndex <= lineIndex) {
      heading = item.text;
    } else {
      break;
    }
  }
  return heading;
}

List<String> normalizeTags(Iterable<String> tags) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final raw in tags) {
    final value = raw.trim();
    if (value.isEmpty) {
      continue;
    }
    final key = value.toLowerCase();
    if (seen.add(key)) {
      normalized.add(value);
    }
  }
  return normalized;
}

List<String> deriveKeywordsFromMarkdown(
  String markdown, {
  int maxKeywords = 6,
}) {
  const stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'has',
    'in',
    'is',
    'it',
    'of',
    'on',
    'or',
    'that',
    'the',
    'to',
    'was',
    'were',
    'with',
  };

  final normalized = markdown
      .toLowerCase()
      .replaceAll(RegExp(r'[`*_>#\-\[\]\(\)\.,:;!?/\\]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) {
    return const [];
  }

  final counts = <String, int>{};
  for (final word in normalized.split(' ')) {
    if (word.length < 4 || stopWords.contains(word)) {
      continue;
    }
    counts.update(word, (value) => value + 1, ifAbsent: () => 1);
  }

  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final countComparison = b.value.compareTo(a.value);
      if (countComparison != 0) {
        return countComparison;
      }
      return a.key.compareTo(b.key);
    });
  return ranked.take(maxKeywords).map((entry) => entry.key).toList();
}

int? _frontmatterSectionLevel(String markdown) {
  final lines = markdown.split('\n');
  if (lines.length < 3 || lines.first.trim() != '---') {
    return null;
  }

  for (var index = 1; index < lines.length; index += 1) {
    final line = lines[index].trim();
    if (line == '---') {
      break;
    }
    final match = RegExp(r'^section-level:\s*h([1-6])$', caseSensitive: false)
        .firstMatch(line);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
  }
  return null;
}
