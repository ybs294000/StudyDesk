import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'application/library_overview_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubjectId = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(libraryOverviewProvider);

    return overview.when(
      data: (data) => _LibraryContent(
        overview: data,
        searchController: _searchController,
        selectedSubjectId: _selectedSubjectId,
        onSearchChanged: () {
          setState(() {});
        },
        onSelectSubject: (value) {
          setState(() {
            _selectedSubjectId = value;
          });
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('StudyDesk could not load the library: $error'),
        ),
      ),
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.overview,
    required this.searchController,
    required this.selectedSubjectId,
    required this.onSearchChanged,
    required this.onSelectSubject,
  });

  final LibraryOverview overview;
  final TextEditingController searchController;
  final String selectedSubjectId;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onSelectSubject;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final filteredDecks = overview.deckSummaries.where((summary) {
      final matchesSubject =
          selectedSubjectId == 'all' || summary.subject.id == selectedSubjectId;
      final tagText = summary.deck.tags.join(' ').toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          summary.subject.name.toLowerCase().contains(query) ||
          summary.deck.name.toLowerCase().contains(query) ||
          summary.deck.description.toLowerCase().contains(query) ||
          tagText.contains(query);
      return matchesSubject && matchesQuery;
    }).toList();

    final crossAxisCount = switch (MediaQuery.sizeOf(context).width) {
      > 1280 => 3,
      > 760 => 2,
      _ => 1,
    };

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _LibraryHero(overview: overview),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: searchController,
          onChanged: (_) => onSearchChanged(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Search subjects or decks',
            hintText: 'DSA, chemistry, midterm deck...',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('All Subjects'),
              selected: selectedSubjectId == 'all',
              onSelected: (_) => onSelectSubject('all'),
            ),
            for (final subject in overview.subjects)
              ChoiceChip(
                label: Text('${subject.emoji} ${subject.name}'),
                selected: selectedSubjectId == subject.id,
                onSelected: (_) => onSelectSubject(subject.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (filteredDecks.isEmpty)
          const _EmptyLibraryState()
        else
          GridView.builder(
            itemCount: filteredDecks.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              mainAxisExtent: 268,
            ),
            itemBuilder: (context, index) {
              final summary = filteredDecks[index];
              return _DeckLibraryCard(summary: summary);
            },
          ),
      ],
    );
  }
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({required this.overview});

  final LibraryOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryStrong, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Library',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Browse every deck across your subjects, see what is due, and jump straight into review.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetricChip(label: '${overview.totalDeckCount} decks'),
              _MetricChip(label: '${overview.totalCardCount} cards'),
              _MetricChip(label: '${overview.totalDueCount} due now'),
              _MetricChip(
                label: '${overview.totalStudiedToday} reviewed today',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DeckLibraryCard extends StatelessWidget {
  const _DeckLibraryCard({required this.summary});

  final LibraryDeckSummary summary;

  @override
  Widget build(BuildContext context) {
    final subjectColor = Color(summary.subject.colorValue);
    final secondaryTextColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: subjectColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    summary.subject.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.deck.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        summary.subject.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (summary.deck.description.isNotEmpty)
              Text(
                summary.deck.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Text(
                'No description yet. Open this deck to edit cards or start reviewing.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _InfoBadge(label: '${summary.cardCount} cards'),
                _InfoBadge(
                  label: '${summary.dueCount} due',
                  color: summary.dueCount > 0 ? AppColors.accent : null,
                ),
                _InfoBadge(label: '${summary.newCount} new'),
                _InfoBadge(label: '${summary.learningCount} learning'),
                for (final tag in summary.deck.tags.take(3))
                  _InfoBadge(label: '#$tag'),
              ],
            ),
            const Spacer(),
            Text(
              _lastStudiedLabel(summary.lastStudiedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(
                      '/subjects/${summary.subject.id}/decks/${summary.deck.id}',
                    ),
                    child: const Text('Open'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: summary.cardCount == 0
                        ? null
                        : () => context.push(
                              '/subjects/${summary.subject.id}/decks/${summary.deck.id}/study?deckName=${Uri.encodeComponent(summary.deck.name)}',
                            ),
                    child: const Text('Study'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _lastStudiedLabel(DateTime? value) {
    if (value == null) {
      return 'Not studied yet';
    }
    final now = DateTime.now();
    final days = now.difference(value).inDays;
    if (days <= 0) {
      return 'Studied today';
    }
    if (days == 1) {
      return 'Studied yesterday';
    }
    return 'Studied $days days ago';
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.primarySoft;
    final foreground = color == null
        ? AppColors.primaryStrong
        : AppColors.onColor(resolvedColor);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 52),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No matching decks yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create a subject or import one of the bundled sample decks to make the Library useful immediately.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
