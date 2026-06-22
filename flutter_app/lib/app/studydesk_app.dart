import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bootstrap/app_bootstrap_service.dart';
import 'router/app_router.dart';
import '../core/settings/theme_mode_controller.dart';
import '../core/settings/theme_preset_controller.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

class StudyDeskApp extends ConsumerWidget {
  const StudyDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final themePreset = ref.watch(themePresetControllerProvider);
    final router = ref.watch(appRouterProvider);

    AppColors.setThemePreset(themePreset);

    return bootstrap.when(
      data: (_) => MaterialApp.router(
        title: 'StudyDesk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        routerConfig: router,
      ),
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        home: const _BootstrapScreen(),
      ),
      error: (error, stackTrace) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themePreset),
        darkTheme: AppTheme.dark(themePreset),
        themeMode: themeMode,
        home: _BootstrapErrorScreen(error: '$error'),
      ),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing StudyDesk...'),
          ],
        ),
      ),
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 12),
              Text(
                'StudyDesk could not finish startup.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
