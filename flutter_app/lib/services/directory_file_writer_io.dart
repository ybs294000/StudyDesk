import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/security/studydesk_security.dart';

class DirectoryFileWriter {
  const DirectoryFileWriter();

  Future<String?> writeBytesToDirectory({
    required String directoryPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final normalizedDirectory = directoryPath.trim();
    if (normalizedDirectory.isEmpty) {
      return null;
    }

    final directory = Directory(normalizedDirectory);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final path = p.join(
      directory.path,
      StudyDeskSecurity.sanitizeFileName(
        fileName,
        fallback: 'studydesk-export',
      ),
    );
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

DirectoryFileWriter createDirectoryFileWriter() {
  return const DirectoryFileWriter();
}
