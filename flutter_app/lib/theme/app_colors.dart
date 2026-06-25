import 'package:flutter/material.dart';

enum AppThemePreset {
  studydesk,
  slateBlue,
  workspaceMono,
}

extension AppThemePresetX on AppThemePreset {
  String get storageValue => switch (this) {
    AppThemePreset.studydesk => 'studydesk',
    AppThemePreset.slateBlue => 'slate_blue',
    AppThemePreset.workspaceMono => 'workspace_mono',
  };

  String get label => switch (this) {
    AppThemePreset.studydesk => 'StudyDesk',
    AppThemePreset.slateBlue => 'Slate Blue',
    AppThemePreset.workspaceMono => 'Workspace Mono',
  };

  String get description => switch (this) {
    AppThemePreset.studydesk =>
      'Teal and amber accents with a calm, focused look.',
    AppThemePreset.slateBlue =>
      'Neutral surfaces with softened blue accents.',
    AppThemePreset.workspaceMono =>
      'A monochrome workspace with quiet contrast and minimal color noise.',
  };

  static AppThemePreset fromStorage(String? value) {
    return switch (value) {
      'slate_blue' => AppThemePreset.slateBlue,
      'workspace_mono' => AppThemePreset.workspaceMono,
      _ => AppThemePreset.studydesk,
    };
  }
}

class AppColors {
  AppColors._();

  static AppThemePreset _preset = AppThemePreset.studydesk;

  static void setThemePreset(AppThemePreset preset) {
    _preset = preset;
  }

  static _AppPalette get _palette => switch (_preset) {
    AppThemePreset.studydesk => _studyDeskPalette,
    AppThemePreset.slateBlue => _slateBluePalette,
    AppThemePreset.workspaceMono => _workspaceMonoPalette,
  };

  static Color get primary => _palette.primary;
  static Color get primaryStrong => _palette.primaryStrong;
  static Color get primarySoft => _palette.primarySoft;
  static Color get accent => _palette.accent;

  static Color get backgroundLight => _palette.backgroundLight;
  static Color get surfaceLight => _palette.surfaceLight;
  static Color get borderLight => _palette.borderLight;
  static Color get textPrimaryLight => _palette.textPrimaryLight;
  static Color get textSecondaryLight => _palette.textSecondaryLight;

  static Color get backgroundDark => _palette.backgroundDark;
  static Color get surfaceDark => _palette.surfaceDark;
  static Color get borderDark => _palette.borderDark;
  static Color get textPrimaryDark => _palette.textPrimaryDark;
  static Color get textSecondaryDark => _palette.textSecondaryDark;

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);

  static Color onColor(Color background) {
    return background.computeLuminance() > 0.5
        ? AppColors.textPrimaryLight
        : Colors.white;
  }

  static Color onColorMuted(Color background) {
    return onColor(background).withValues(alpha: 0.82);
  }
}

class _AppPalette {
  const _AppPalette({
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.accent,
    required this.backgroundLight,
    required this.surfaceLight,
    required this.borderLight,
    required this.textPrimaryLight,
    required this.textSecondaryLight,
    required this.backgroundDark,
    required this.surfaceDark,
    required this.borderDark,
    required this.textPrimaryDark,
    required this.textSecondaryDark,
  });

  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color accent;
  final Color backgroundLight;
  final Color surfaceLight;
  final Color borderLight;
  final Color textPrimaryLight;
  final Color textSecondaryLight;
  final Color backgroundDark;
  final Color surfaceDark;
  final Color borderDark;
  final Color textPrimaryDark;
  final Color textSecondaryDark;
}

const _studyDeskPalette = _AppPalette(
  primary: Color(0xFF0F766E),
  primaryStrong: Color(0xFF115E59),
  primarySoft: Color(0xFFCCFBF1),
  accent: Color(0xFFF59E0B),
  backgroundLight: Color(0xFFF6F7F4),
  surfaceLight: Color(0xFFFFFFFF),
  borderLight: Color(0xFFD6DDD7),
  textPrimaryLight: Color(0xFF12211D),
  textSecondaryLight: Color(0xFF566761),
  backgroundDark: Color(0xFF0D1513),
  surfaceDark: Color(0xFF14201D),
  borderDark: Color(0xFF29413B),
  textPrimaryDark: Color(0xFFEAF3EF),
  textSecondaryDark: Color(0xFF9FB3AD),
);

const _slateBluePalette = _AppPalette(
  primary: Color(0xFF4F6FA8),
  primaryStrong: Color(0xFF3F5F95),
  primarySoft: Color(0xFFE8EEF8),
  accent: Color(0xFF7A93C2),
  backgroundLight: Color(0xFFF6F8FB),
  surfaceLight: Color(0xFFFFFFFF),
  borderLight: Color(0xFFD6DFEB),
  textPrimaryLight: Color(0xFF172033),
  textSecondaryLight: Color(0xFF5E6B7E),
  backgroundDark: Color(0xFF0E1520),
  surfaceDark: Color(0xFF151E2B),
  borderDark: Color(0xFF2A394D),
  textPrimaryDark: Color(0xFFF2F5FA),
  textSecondaryDark: Color(0xFFADB8C7),
);

const _workspaceMonoPalette = _AppPalette(
  primary: Color(0xFF2F3437),
  primaryStrong: Color(0xFF23272A),
  primarySoft: Color(0xFFF7F6F3),
  accent: Color(0xFF8B8A87),
  backgroundLight: Color(0xFFFFFFFF),
  surfaceLight: Color(0xFFFFFFFF),
  borderLight: Color(0xFFE9E9E7),
  textPrimaryLight: Color(0xFF37352F),
  textSecondaryLight: Color(0xFF787774),
  backgroundDark: Color(0xFF2F3438),
  surfaceDark: Color(0xFF373C3F),
  borderDark: Color(0xFF4A4F53),
  textPrimaryDark: Color(0xFFECEAE8),
  textSecondaryDark: Color(0xFFB3B1AD),
);
