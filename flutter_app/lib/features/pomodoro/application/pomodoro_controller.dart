import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/profile_settings_controller.dart';
import '../../dashboard/application/dashboard_summary_provider.dart';
import '../../gamification/application/gamification_summary_provider.dart';
import '../../study/data/study_sessions_repository.dart';
import '../../study/domain/study_session_record.dart';

const _pomodoroPhaseKey = 'pomodoro_phase_v1';
const _pomodoroRemainingSecondsKey = 'pomodoro_remaining_seconds_v1';
const _pomodoroCompletedWorkSessionsKey = 'pomodoro_completed_work_sessions_v1';
const _pomodoroCompletedDayKey = 'pomodoro_completed_day_v1';

final pomodoroControllerProvider =
    NotifierProvider<PomodoroController, PomodoroState>(
      PomodoroController.new,
    );

class PomodoroController extends Notifier<PomodoroState> {
  Timer? _timer;
  DateTime? _currentPhaseStartedAt;
  bool _didHydrate = false;
  String? _completedSessionsDayKey;

  @override
  PomodoroState build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen<ProfileSettingsState>(
      profileSettingsControllerProvider,
      (previous, next) => _applySettings(next),
    );

    final settings = ref.watch(profileSettingsControllerProvider);
    if (!_didHydrate) {
      _didHydrate = true;
      _loadPersistedState(settings);
    }
    return PomodoroState.initial(
      isEnabled: settings.pomodoroEnabled,
      workMinutes: settings.pomodoroWorkMinutes,
      breakMinutes: settings.pomodoroBreakMinutes,
    );
  }

  Future<void> _loadPersistedState(ProfileSettingsState settings) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(DateTime.now());
    final savedDay = prefs.getString(_pomodoroCompletedDayKey);
    _completedSessionsDayKey = savedDay ?? todayKey;
    final completedWorkSessions = savedDay == todayKey
        ? prefs.getInt(_pomodoroCompletedWorkSessionsKey) ?? 0
        : 0;
    final savedPhase = PomodoroPhaseX.fromStorage(
      prefs.getString(_pomodoroPhaseKey),
    );
    final defaultSeconds = savedPhase == PomodoroPhase.breakTime
        ? settings.pomodoroBreakMinutes * 60
        : settings.pomodoroWorkMinutes * 60;

    state = state.copyWith(
      isEnabled: settings.pomodoroEnabled,
      workMinutes: settings.pomodoroWorkMinutes,
      breakMinutes: settings.pomodoroBreakMinutes,
      phase: savedPhase,
      remainingSeconds:
          prefs.getInt(_pomodoroRemainingSecondsKey) ?? defaultSeconds,
      completedWorkSessionsToday: completedWorkSessions,
      isHydrated: true,
    );
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pomodoroPhaseKey, state.phase.storageValue);
    await prefs.setInt(_pomodoroRemainingSecondsKey, state.remainingSeconds);
    _completedSessionsDayKey ??= _dayKey(DateTime.now());
    await prefs.setString(_pomodoroCompletedDayKey, _completedSessionsDayKey!);
    await prefs.setInt(
      _pomodoroCompletedWorkSessionsKey,
      state.completedWorkSessionsToday,
    );
  }

  void _applySettings(ProfileSettingsState settings) {
    final defaultSeconds = state.phase == PomodoroPhase.breakTime
        ? settings.pomodoroBreakMinutes * 60
        : settings.pomodoroWorkMinutes * 60;
    final shouldResetRemaining = !state.isRunning &&
        (settings.pomodoroWorkMinutes != state.workMinutes ||
            settings.pomodoroBreakMinutes != state.breakMinutes);

    state = state.copyWith(
      isEnabled: settings.pomodoroEnabled,
      workMinutes: settings.pomodoroWorkMinutes,
      breakMinutes: settings.pomodoroBreakMinutes,
      remainingSeconds: shouldResetRemaining
          ? defaultSeconds
          : state.remainingSeconds,
    );

    if (!settings.pomodoroEnabled) {
      pause();
    }
    unawaited(_persistState());
  }

  void start() {
    if (!state.isEnabled || state.isRunning) {
      return;
    }

    _refreshDailyCounterIfNeeded();
    _currentPhaseStartedAt ??= DateTime.now();
    state = state.copyWith(isRunning: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    if (state.isRunning) {
      state = state.copyWith(isRunning: false);
      unawaited(_persistState());
    }
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _currentPhaseStartedAt = null;
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: _secondsForPhase(state.phase),
    );
    unawaited(_persistState());
  }

  void skipPhase() {
    _timer?.cancel();
    _timer = null;
    _completePhase(manualSkip: true);
  }

  void toggle() {
    if (state.isRunning) {
      pause();
    } else {
      start();
    }
  }

  Future<void> _tick() async {
    if (!state.isRunning) {
      return;
    }
    _refreshDailyCounterIfNeeded();
    final nextRemaining = state.remainingSeconds - 1;
    if (nextRemaining <= 0) {
      _timer?.cancel();
      _timer = null;
      await _completePhase();
      return;
    }

    state = state.copyWith(remainingSeconds: nextRemaining);
    await _persistState();
  }

  Future<void> _completePhase({bool manualSkip = false}) async {
    final completedPhase = state.phase;
    final nextPhase = completedPhase == PomodoroPhase.work
        ? PomodoroPhase.breakTime
        : PomodoroPhase.work;
    final shouldAutoStartNextPhase = !manualSkip && state.isRunning;

    if (completedPhase == PomodoroPhase.work && !manualSkip) {
      _completedSessionsDayKey = _dayKey(DateTime.now());
      final startedAt = _currentPhaseStartedAt ??
          DateTime.now().subtract(Duration(seconds: _secondsForPhase(completedPhase)));
      final endedAt = DateTime.now();
      await ref.read(studySessionsRepositoryProvider).addSession(
            StudySessionRecord(
              id: endedAt.microsecondsSinceEpoch.toString(),
              subjectId: null,
              deckId: null,
              sessionType: 'pomodoro',
              startedAt: startedAt,
              endedAt: endedAt,
              reviewedCount: 0,
              completedCount: 1,
              againCount: 0,
              dueCount: 1,
            ),
          );
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(gamificationSummaryProvider);
    }

    state = state.copyWith(
      isRunning: false,
      phase: nextPhase,
      remainingSeconds: _secondsForPhase(nextPhase),
      completedWorkSessionsToday:
          completedPhase == PomodoroPhase.work && !manualSkip
              ? state.completedWorkSessionsToday + 1
              : state.completedWorkSessionsToday,
    );
    _currentPhaseStartedAt = null;
    await _persistState();

    if (shouldAutoStartNextPhase) {
      start();
    }
  }

  int _secondsForPhase(PomodoroPhase phase) {
    return switch (phase) {
      PomodoroPhase.work => state.workMinutes * 60,
      PomodoroPhase.breakTime => state.breakMinutes * 60,
    };
  }

  String _dayKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void _refreshDailyCounterIfNeeded() {
    final todayKey = _dayKey(DateTime.now());
    final currentKey = _completedSessionsDayKey;
    if (currentKey == null) {
      _completedSessionsDayKey = todayKey;
      return;
    }
    if (todayKey != currentKey && state.completedWorkSessionsToday != 0) {
      _completedSessionsDayKey = todayKey;
      state = state.copyWith(completedWorkSessionsToday: 0);
      unawaited(_persistState());
    } else if (todayKey != currentKey) {
      _completedSessionsDayKey = todayKey;
    }
  }
}

class PomodoroState {
  const PomodoroState({
    required this.isEnabled,
    required this.workMinutes,
    required this.breakMinutes,
    required this.phase,
    required this.remainingSeconds,
    required this.isRunning,
    required this.completedWorkSessionsToday,
    required this.isHydrated,
  });

  final bool isEnabled;
  final int workMinutes;
  final int breakMinutes;
  final PomodoroPhase phase;
  final int remainingSeconds;
  final bool isRunning;
  final int completedWorkSessionsToday;
  final bool isHydrated;

  factory PomodoroState.initial({
    required bool isEnabled,
    required int workMinutes,
    required int breakMinutes,
  }) {
    return PomodoroState(
      isEnabled: isEnabled,
      workMinutes: workMinutes,
      breakMinutes: breakMinutes,
      phase: PomodoroPhase.work,
      remainingSeconds: workMinutes * 60,
      isRunning: false,
      completedWorkSessionsToday: 0,
      isHydrated: false,
    );
  }

  PomodoroState copyWith({
    bool? isEnabled,
    int? workMinutes,
    int? breakMinutes,
    PomodoroPhase? phase,
    int? remainingSeconds,
    bool? isRunning,
    int? completedWorkSessionsToday,
    bool? isHydrated,
  }) {
    return PomodoroState(
      isEnabled: isEnabled ?? this.isEnabled,
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      phase: phase ?? this.phase,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      completedWorkSessionsToday:
          completedWorkSessionsToday ?? this.completedWorkSessionsToday,
      isHydrated: isHydrated ?? this.isHydrated,
    );
  }

  String get phaseLabel => switch (phase) {
    PomodoroPhase.work => 'Focus',
    PomodoroPhase.breakTime => 'Break',
  };

  String get remainingLabel {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

enum PomodoroPhase {
  work,
  breakTime,
}

extension PomodoroPhaseX on PomodoroPhase {
  String get storageValue => switch (this) {
    PomodoroPhase.work => 'work',
    PomodoroPhase.breakTime => 'break',
  };

  static PomodoroPhase fromStorage(String? value) {
    return switch (value) {
      'break' => PomodoroPhase.breakTime,
      _ => PomodoroPhase.work,
    };
  }
}
