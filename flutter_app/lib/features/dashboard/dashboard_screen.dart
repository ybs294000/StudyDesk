import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = <({String title, String body, IconData icon})>[
      (
        title: 'Flashcards',
        body:
            'Build the spaced-repetition engine, due cards, and daily study loop.',
        icon: Icons.style_rounded,
      ),
      (
        title: 'Quizzes',
        body: 'Timed sessions, marking rules, and multiple question formats.',
        icon: Icons.quiz_rounded,
      ),
      (
        title: 'Sheets',
        body: 'Markdown study sheets with hide/reveal rehearsal support.',
        icon: Icons.description_rounded,
      ),
      (
        title: 'Q&A',
        body:
            'Short-answer drills with keyword grading and AI-ready structure.',
        icon: Icons.record_voice_over_rounded,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Build Focus', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'This fresh codebase starts with a stable shell, theming, and settings so we can grow safely into the study engine.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in cards)
              SizedBox(
                width: 280,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(card.icon),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          card.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(card.body),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
