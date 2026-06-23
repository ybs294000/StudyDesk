import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/profile_settings_controller.dart';
import 'content_portability_service.dart';
import 'directory_file_writer.dart';
import 'export_file_service.dart';

final libraryBackupServiceProvider = Provider<LibraryBackupService>((ref) {
  return LibraryBackupService(
    portabilityService: ref.read(contentPortabilityServiceProvider),
    exportFileService: ref.read(exportFileServiceProvider),
    directoryFileWriter: ref.read(directoryFileWriterProvider),
    readSettings: () => ref.read(profileSettingsControllerProvider),
  );
});

class LibraryBackupService {
  const LibraryBackupService({
    required this.portabilityService,
    required this.exportFileService,
    required this.directoryFileWriter,
    required this.readSettings,
  });

  final ContentPortabilityService portabilityService;
  final ExportFileService exportFileService;
  final DirectoryFileWriter directoryFileWriter;
  final ProfileSettingsState Function() readSettings;

  Future<String?> createSafetySnapshot({
    required String reason,
    bool interactiveFallback = false,
  }) async {
    final bytes = await _buildSnapshotZip(reason: reason);
    final fileName = _snapshotFileName(reason);
    final settings = readSettings();

    if (!kIsWeb) {
      final configuredDirectory = settings.backupDirectoryPath?.trim();
      if (configuredDirectory != null && configuredDirectory.isNotEmpty) {
        final path = await directoryFileWriter.writeBytesToDirectory(
          directoryPath: configuredDirectory,
          fileName: fileName,
          bytes: bytes,
        );
        if (path != null) {
          return path;
        }
      }
    }

    if (!interactiveFallback) {
      return null;
    }

    return exportFileService.saveZip(
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<Uint8List> _buildSnapshotZip({
    required String reason,
  }) async {
    final archive = Archive();
    final now = DateTime.now().toUtc();
    final createdAt = now.toIso8601String();

    _addTextFile(
      archive,
      'manifest.json',
      _prettyJson({
        'studydesk_version': '1.0',
        'snapshot_type': 'safety_backup',
        'reason': reason,
        'created_at': createdAt,
      }),
    );
    _addTextFile(
      archive,
      'library/library.json',
      await portabilityService.exportLibraryJson(),
    );
    _addTextFile(
      archive,
      'analytics/analytics.json',
      await portabilityService.exportAnalyticsJson(),
    );
    _addTextFile(
      archive,
      'analytics/streaks.json',
      await portabilityService.exportStudyStreaksJson(),
    );
    _addTextFile(
      archive,
      'sessions/study_sessions.json',
      await portabilityService.exportStudySessionsJson(),
    );
    _addTextFile(
      archive,
      'sessions/quiz_attempts.json',
      await portabilityService.exportQuizAttemptsJson(),
    );
    _addTextFile(
      archive,
      'review/due_items.json',
      await portabilityService.exportDueItemsJson(),
    );
    _addTextFile(
      archive,
      'review/weak_topics.json',
      await portabilityService.exportWeakTopicsJson(),
    );

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw StateError('StudyDesk could not create the safety snapshot archive.');
    }
    return Uint8List.fromList(bytes);
  }

  String _snapshotFileName(String reason) {
    final now = DateTime.now();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final normalizedReason = reason
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final suffix = normalizedReason.isEmpty ? 'manual' : normalizedReason;
    return 'studydesk-safety-snapshot-$suffix-$timestamp.zip';
  }

  void _addTextFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _prettyJson(Object payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
