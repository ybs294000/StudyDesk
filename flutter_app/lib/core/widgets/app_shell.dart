import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/tab_history_controller.dart';
import '../../features/pomodoro/application/pomodoro_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../settings/shell_layout_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  static const _destinations = [
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_rounded,
      route: '/',
    ),
    _ShellDestination(
      label: 'Library',
      icon: Icons.folder_copy_rounded,
      route: '/library',
    ),
    _ShellDestination(
      label: 'Study',
      icon: Icons.school_rounded,
      route: '/study',
    ),
    _ShellDestination(
      label: 'Analytics',
      icon: Icons.auto_graph_rounded,
      route: '/analytics',
    ),
    _ShellDestination(
      label: 'Settings',
      icon: Icons.settings_rounded,
      route: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final isSidebarVisible = ref.watch(shellLayoutControllerProvider);
    final pomodoro = ref.watch(pomodoroControllerProvider);
    final selectedIndex = _selectedIndexForPath(currentPath);
    final destination = _destinations[selectedIndex];
    final canNavigateBack = !isWide && GoRouter.of(context).canPop();
    final currentTopRoute = _topLevelRouteForPath(currentPath);
    final hasTabHistory = ref.watch(
      tabHistoryControllerProvider.select(
        (history) => history.where((route) => route != currentTopRoute).isNotEmpty,
      ),
    );
    final isFocusRoute = currentPath.contains('/study') ||
        currentPath.contains('/session') ||
        currentPath.contains('/read');

    return PopScope(
      canPop: canNavigateBack || !hasTabHistory,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || canNavigateBack) {
          return;
        }
        final previousTopRoute = ref
            .read(tabHistoryControllerProvider.notifier)
            .popPrevious(currentRoute: currentTopRoute);
        if (previousTopRoute != null) {
          GoRouter.of(context).go(previousTopRoute);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (isWide && isSidebarVisible)
                NavigationRail(
                  selectedIndex: selectedIndex,
                  extended: width >= 1200,
                  labelType: NavigationRailLabelType.none,
                  onDestinationSelected: (index) {
                    _onDestinationSelected(context, ref, index);
                  },
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          if (isWide)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: IconButton(
                                tooltip: isSidebarVisible
                                    ? 'Hide sidebar'
                                    : 'Show sidebar',
                                onPressed: () {
                                  ref
                                      .read(
                                        shellLayoutControllerProvider.notifier,
                                      )
                                      .toggleSidebar();
                                },
                                icon: Icon(
                                  isSidebarVisible
                                      ? Icons.menu_open_rounded
                                      : Icons.menu_rounded,
                                ),
                              ),
                            ),
                          if (canNavigateBack)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: IconButton(
                                tooltip: 'Back',
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'StudyDesk',
                                  style: isFocusRoute
                                      ? Theme.of(context).textTheme.headlineSmall
                                      : Theme.of(context).textTheme.headlineMedium,
                                ),
                                if (!isFocusRoute) ...[
                                  const SizedBox(height: AppSpacing.micro),
                                  Text(
                                    destination.label,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _ControlsButton(
                            pomodoro: pomodoro,
                            onPressed: () => _openControls(context, ref, pomodoro),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  _onDestinationSelected(context, ref, index);
                },
                destinations: [
                  for (final item in _destinations)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                ],
              ),
      ),
    );
  }

  int _selectedIndexForPath(String path) {
    final index = _destinations.indexWhere((destination) {
      if (destination.route == '/') {
        return path == '/' || path.startsWith('/subjects/');
      }
      return path == destination.route ||
          path.startsWith('${destination.route}/');
    });
    return index == -1 ? 0 : index;
  }

  String _topLevelRouteForPath(String path) {
    final index = _selectedIndexForPath(path);
    return _destinations[index].route;
  }

  void _onDestinationSelected(BuildContext context, WidgetRef ref, int index) {
    final route = _destinations[index].route;
    final currentTopRoute = _topLevelRouteForPath(currentPath);
    if (route != currentTopRoute) {
      ref.read(tabHistoryControllerProvider.notifier).recordTransition(
            fromRoute: currentTopRoute,
            toRoute: route,
          );
      GoRouter.of(context).go(route);
    }
  }

  void _openControls(
    BuildContext context,
    WidgetRef ref,
    PomodoroState pomodoro,
  ) {
    final controller = ref.read(pomodoroControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controls',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (pomodoro.isEnabled && pomodoro.isHydrated)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              size: 18,
                              color: pomodoro.phase == PomodoroPhase.work
                                  ? AppColors.primary
                                  : AppColors.accent,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${pomodoro.phaseLabel} ${pomodoro.remainingLabel}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Spacer(),
                            Text(
                              '${pomodoro.completedWorkSessionsToday} done',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                controller.toggle();
                              },
                              icon: Icon(
                                pomodoro.isRunning
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                pomodoro.isRunning ? 'Pause' : 'Start',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              tooltip: 'Skip phase',
                              onPressed: () {
                                Navigator.of(context).pop();
                                controller.skipPhase();
                              },
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                            IconButton(
                              tooltip: 'Reset timer',
                              onPressed: () {
                                Navigator.of(context).pop();
                                controller.reset();
                              },
                              icon: const Icon(Icons.restart_alt_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_rounded),
                  title: const Text('Open settings'),
                  subtitle: const Text('Themes, scheduling, backups, and app preferences'),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentPath != '/settings') {
                      context.push('/settings');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ControlsButton extends StatelessWidget {
  const _ControlsButton({
    required this.pomodoro,
    required this.onPressed,
  });

  final PomodoroState pomodoro;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final showActiveDot = pomodoro.isEnabled && pomodoro.isHydrated && pomodoro.isRunning;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Controls',
          onPressed: onPressed,
          icon: const Icon(Icons.tune_rounded),
        ),
        if (showActiveDot)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
