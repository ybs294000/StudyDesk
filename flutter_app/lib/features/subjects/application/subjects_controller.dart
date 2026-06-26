import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/studydesk_security.dart';
import '../data/subjects_repository.dart';
import '../domain/subject_record.dart';

final subjectsControllerProvider =
    AsyncNotifierProvider<SubjectsController, List<SubjectRecord>>(
      SubjectsController.new,
    );

class SubjectsController extends AsyncNotifier<List<SubjectRecord>> {
  SubjectsRepository get _repository => ref.read(subjectsRepositoryProvider);

  @override
  Future<List<SubjectRecord>> build() {
    return _repository.loadSubjects();
  }

  Future<void> addSubject({
    required String name,
    required String emoji,
    required int colorValue,
  }) async {
    final current = await future;
    final now = DateTime.now();
    final subject = SubjectRecord(
      id: now.microsecondsSinceEpoch.toString(),
      name: StudyDeskSecurity.sanitizeSingleLine(
        name,
        field: 'Subject name',
        maxLength: StudyDeskSecurity.maxSubjectNameLength,
      ),
      emoji: emoji,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
    final updated = [...current, subject]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = AsyncData(updated);
    await _repository.upsertSubject(subject);
  }

  Future<void> updateSubject(SubjectRecord subject) async {
    final current = await future;
    final normalized = subject.copyWith(
      name: StudyDeskSecurity.sanitizeSingleLine(
        subject.name,
        field: 'Subject name',
        maxLength: StudyDeskSecurity.maxSubjectNameLength,
      ),
      updatedAt: DateTime.now(),
    );
    final updated = current
        .map((item) => item.id == normalized.id ? normalized : item)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = AsyncData(updated);
    await _repository.upsertSubject(normalized);
  }

  Future<void> deleteSubject(String id) async {
    final current = await future;
    final updated = current.where((item) => item.id != id).toList();
    state = AsyncData(updated);
    await _repository.deleteSubject(id);
  }
}
