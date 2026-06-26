import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/studydesk_security.dart';

final exportFileServiceProvider = Provider<ExportFileService>((ref) {
  return const ExportFileService();
});

class ExportFileService {
  const ExportFileService();

  Future<String?> pickDirectory({
    String? dialogTitle,
  }) {
    if (kIsWeb) {
      return Future.value(null);
    }
    return FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle,
    );
  }

  Future<String?> saveJson({
    required String fileName,
    required String json,
  }) {
    return saveBytes(
      fileName: _ensureExtension(fileName, 'json'),
      extension: 'json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      dialogTitle: 'Export StudyDesk JSON',
    );
  }

  Future<String?> saveMarkdown({
    required String fileName,
    required String markdown,
  }) {
    return saveBytes(
      fileName: _ensureExtension(fileName, 'md'),
      extension: 'md',
      bytes: Uint8List.fromList(utf8.encode(markdown)),
      dialogTitle: 'Export StudyDesk Markdown',
    );
  }

  Future<String?> saveText({
    required String fileName,
    required String text,
  }) {
    return saveBytes(
      fileName: _ensureExtension(fileName, 'txt'),
      extension: 'txt',
      bytes: Uint8List.fromList(utf8.encode(text)),
      dialogTitle: 'Export StudyDesk text file',
    );
  }

  Future<String?> saveZip({
    required String fileName,
    required Uint8List bytes,
  }) {
    return saveBytes(
      fileName: _ensureExtension(fileName, 'zip'),
      extension: 'zip',
      bytes: bytes,
      dialogTitle: 'Export StudyDesk bundle',
    );
  }

  Future<String?> saveBytes({
    required String fileName,
    required String extension,
    required Uint8List bytes,
    required String dialogTitle,
  }) {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
  }

  static String _ensureExtension(String fileName, String extension) {
    final normalized = extension.startsWith('.') ? extension.substring(1) : extension;
    final sanitizedName = StudyDeskSecurity.sanitizeFileName(
      fileName,
      fallback: 'studydesk-export',
    );
    final lowerName = sanitizedName.toLowerCase();
    if (lowerName.endsWith('.$normalized')) {
      return sanitizedName;
    }
    return '$sanitizedName.$normalized';
  }
}
