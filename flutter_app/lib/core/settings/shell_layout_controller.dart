import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sidebarVisibleKey = 'shell_sidebar_visible';

final shellLayoutControllerProvider =
    NotifierProvider<ShellLayoutController, bool>(ShellLayoutController.new);

class ShellLayoutController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_sidebarVisibleKey) ?? true;
  }

  Future<void> setSidebarVisible(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarVisibleKey, value);
  }

  Future<void> toggleSidebar() async {
    await setSidebarVisible(!state);
  }
}
