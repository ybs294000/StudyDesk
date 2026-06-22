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
