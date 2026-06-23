import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings/shell_layout_controller.dart';
import '../../theme/app_spacing.dart';

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
    final selectedIndex = _selectedIndexForPath(currentPath);
    final destination = _destinations[selectedIndex];
    final canNavigateBack = !isWide && GoRouter.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isWide && isSidebarVisible)
              NavigationRail(
                selectedIndex: selectedIndex,
                extended: width >= 1200,
                labelType: NavigationRailLabelType.none,
                onDestinationSelected: (index) {
                  _onDestinationSelected(context, index);
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
                      AppSpacing.sm,
                    ),
                      child: Row(
                        children: [
                          if (isWide)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
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
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
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
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: AppSpacing.micro),
                              Text(
                                destination.label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _openControls(context),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Controls'),
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
                _onDestinationSelected(context, index);
              },
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }

  int _selectedIndexForPath(String path) {
    final index = _destinations.indexWhere((destination) {
      if (destination.route == '/') {
        return path == '/' || path.startsWith('/subjects/');
      }
      return path == destination.route || path.startsWith('${destination.route}/');
    });
    return index == -1 ? 0 : index;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    final route = _destinations[index].route;
    if (route != currentPath) {
      GoRouter.of(context).go(route);
    }
  }

  void _openControls(BuildContext context) {
    if (currentPath == '/settings') {
      return;
    }
    context.push('/settings');
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
