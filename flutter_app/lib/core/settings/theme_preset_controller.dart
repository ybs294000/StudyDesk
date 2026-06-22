import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';

const _themePresetKey = 'theme_preset';

final themePresetControllerProvider =
    NotifierProvider<ThemePresetController, AppThemePreset>(
      ThemePresetController.new,
    );

class ThemePresetController extends Notifier<AppThemePreset> {
  @override
  AppThemePreset build() {
    _load();
    return AppThemePreset.studydesk;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppThemePresetX.fromStorage(prefs.getString(_themePresetKey));
  }

  Future<void> setThemePreset(AppThemePreset preset) async {
    state = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePresetKey, preset.storageValue);
  }
}
