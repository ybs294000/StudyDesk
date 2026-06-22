import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subject_units_repository.dart';
import '../domain/subject_unit_record.dart';

final subjectUnitsControllerProvider = AsyncNotifierProviderFamily<
    SubjectUnitsController, List<SubjectUnitRecord>, String>(
  SubjectUnitsController.new,
);

class SubjectUnitsController
    extends FamilyAsyncNotifier<List<SubjectUnitRecord>, String> {
  SubjectUnitsRepository get _repository => ref.read(subjectUnitsRepositoryProvider);

  @override
  Future<List<SubjectUnitRecord>> build(String arg) async {
    final units = await _repository.loadUnits();
    return _forSubject(units, arg);
  }

  Future<SubjectUnitRecord> addUnit({
    required String subjectId,
    required String name,
    required String description,
  }) async {
    final allUnits = await _repository.loadUnits();
    final now = DateTime.now();
    final normalizedName = _ensureUniqueName(
      units: allUnits,
      subjectId: subjectId,
      name: name,
    );
    final unit = SubjectUnitRecord(
      id: now.microsecondsSinceEpoch.toString(),
      subjectId: subjectId,
      name: normalizedName,
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final updated = [...allUnits, unit];
    await _repository.saveUnits(updated);
    state = AsyncData(_forSubject(updated, subjectId));
    return unit;
  }

  Future<SubjectUnitRecord> updateUnit(SubjectUnitRecord unit) async {
    final allUnits = await _repository.loadUnits();
    final normalized = unit.copyWith(
      name: _ensureUniqueName(
        units: allUnits,
        subjectId: unit.subjectId,
        name: unit.name,
        unitId: unit.id,
      ),
      description: unit.description.trim(),
      updatedAt: DateTime.now(),
    );
    final updated = allUnits
        .map((item) => item.id == normalized.id ? normalized : item)
        .toList();
    await _repository.saveUnits(updated);
    state = AsyncData(_forSubject(updated, arg));
    return normalized;
  }

  Future<void> deleteUnit(String unitId) async {
    final allUnits = await _repository.loadUnits();
    final updated = allUnits.where((unit) => unit.id != unitId).toList();
    await _repository.saveUnits(updated);
    state = AsyncData(_forSubject(updated, arg));
  }

  List<SubjectUnitRecord> _forSubject(
    List<SubjectUnitRecord> units,
    String subjectId,
  ) {
    final filtered = units.where((unit) => unit.subjectId == subjectId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  String _ensureUniqueName({
    required List<SubjectUnitRecord> units,
    required String subjectId,
    required String name,
    String? unitId,
  }) {
    final base = name.trim().isEmpty ? 'New Unit' : name.trim();
    final existing = units
        .where((unit) => unit.subjectId == subjectId && unit.id != unitId)
        .map((unit) => unit.name.trim().toLowerCase())
        .toSet();
    if (!existing.contains(base.toLowerCase())) {
      return base;
    }

    var suffix = 2;
    while (existing.contains('$base ($suffix)'.toLowerCase())) {
      suffix += 1;
    }
    return '$base ($suffix)';
  }
}
