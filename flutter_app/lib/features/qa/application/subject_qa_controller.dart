import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/studydesk_security.dart';
import '../data/qa_items_repository.dart';
import '../domain/qa_item_record.dart';

final subjectQaControllerProvider =
    AsyncNotifierProviderFamily<SubjectQaController, List<QaItemRecord>, String>(
      SubjectQaController.new,
    );

class SubjectQaController extends FamilyAsyncNotifier<List<QaItemRecord>, String> {
  QaItemsRepository get _repository => ref.read(qaItemsRepositoryProvider);

  @override
  Future<List<QaItemRecord>> build(String arg) async {
    final items = await _repository.loadItems();
    return _forSubject(items, arg);
  }

  Future<QaItemRecord> upsertQa({
    required String subjectId,
    required String? unitId,
    String? id,
    required String question,
    required String answerMarkdown,
    required List<String> tags,
  }) async {
    final now = DateTime.now();
    final item = QaItemRecord(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      subjectId: subjectId,
      unitId: unitId,
      question: StudyDeskSecurity.sanitizeSingleLine(
        question,
        field: 'Q&A question',
        maxLength: StudyDeskSecurity.maxQaQuestionLength,
      ),
      answerMarkdown: StudyDeskSecurity.sanitizeMultiline(
        answerMarkdown,
        field: 'Q&A answer',
        maxLength: StudyDeskSecurity.maxQaAnswerLength,
        allowEmpty: false,
      ),
      tags: StudyDeskSecurity.sanitizeTags(tags),
      createdAt: now,
      updatedAt: now,
    );
    await _repository.upsertItem(item);
    final items = await _repository.loadItems();
    state = AsyncData(_forSubject(items, subjectId));
    return item;
  }

  Future<void> saveItem(QaItemRecord item) async {
    final normalized = item.copyWith(
      question: StudyDeskSecurity.sanitizeSingleLine(
        item.question,
        field: 'Q&A question',
        maxLength: StudyDeskSecurity.maxQaQuestionLength,
      ),
      answerMarkdown: StudyDeskSecurity.sanitizeMultiline(
        item.answerMarkdown,
        field: 'Q&A answer',
        maxLength: StudyDeskSecurity.maxQaAnswerLength,
        allowEmpty: false,
      ),
      tags: StudyDeskSecurity.sanitizeTags(item.tags),
      updatedAt: DateTime.now(),
    );
    await _repository.upsertItem(normalized);
    final items = await _repository.loadItems();
    state = AsyncData(_forSubject(items, arg));
  }

  Future<void> deleteItem(String id) async {
    await _repository.deleteItem(id);
    final items = await _repository.loadItems();
    state = AsyncData(_forSubject(items, arg));
  }

  List<QaItemRecord> _forSubject(List<QaItemRecord> items, String subjectId) {
    final filtered = items.where((item) => item.subjectId == subjectId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }
}
