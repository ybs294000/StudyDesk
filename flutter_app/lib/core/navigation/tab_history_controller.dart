import 'package:flutter_riverpod/flutter_riverpod.dart';

final tabHistoryControllerProvider =
    NotifierProvider<TabHistoryController, List<String>>(
      TabHistoryController.new,
    );

class TabHistoryController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void recordTransition({
    required String fromRoute,
    required String toRoute,
  }) {
    if (fromRoute == toRoute) {
      return;
    }
    final updated = [...state];
    updated.removeWhere((route) => route == toRoute);
    updated.add(fromRoute);
    state = updated;
  }

  String? popPrevious({required String currentRoute}) {
    if (state.isEmpty) {
      return null;
    }
    final updated = [...state];
    while (updated.isNotEmpty && updated.last == currentRoute) {
      updated.removeLast();
    }
    if (updated.isEmpty) {
      state = updated;
      return null;
    }
    final previous = updated.removeLast();
    state = updated;
    return previous;
  }

  bool hasPreviousFor(String currentRoute) {
    return state.where((route) => route != currentRoute).isNotEmpty;
  }
}
