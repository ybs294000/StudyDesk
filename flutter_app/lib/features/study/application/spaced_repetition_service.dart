import 'dart:math';

import '../../cards/domain/card_record.dart';
import '../domain/study_rating.dart';

class SpacedRepetitionService {
  const SpacedRepetitionService();

  static const _targetRetention = 0.9;
  static const _schedulerVersion = 'adaptive_memory_v2';

  CardRecord applyRating({
    required CardRecord card,
    required StudyRating rating,
    required DateTime reviewedAt,
  }) {
    final outcome = _scheduleOutcome(
      card: card,
      rating: rating,
      reviewedAt: reviewedAt,
    );

    return card.copyWith(
      schedulerVersion: _schedulerVersion,
      state: outcome.state,
      reviewCount: card.reviewCount + 1,
      lapseCount: outcome.lapseCount,
      intervalDays: outcome.intervalDays,
      ease: outcome.ease,
      stability: outcome.stability,
      difficulty: outcome.difficulty,
      dueAt: outcome.dueAt,
      lastReviewedAt: reviewedAt,
      updatedAt: reviewedAt,
    );
  }

  int previewIntervalDays(CardRecord card, StudyRating rating) {
    final updated = _scheduleOutcome(
      card: card,
      rating: rating,
      reviewedAt: DateTime.now(),
    );
    return updated.intervalDays;
  }

  String previewIntervalLabel(CardRecord card, StudyRating rating) {
    final updated = _scheduleOutcome(
      card: card,
      rating: rating,
      reviewedAt: DateTime.now(),
    );
    return _formatDuration(updated.dueAt.difference(DateTime.now()));
  }

  _ScheduleOutcome _scheduleOutcome({
    required CardRecord card,
    required StudyRating rating,
    required DateTime reviewedAt,
  }) {
    final previousStability = max(card.stability, _seedStability(card));
    final previousDifficulty = card.difficulty.clamp(1.0, 10.0).toDouble();
    final previousEase = card.ease.clamp(1.3, 3.0).toDouble();
    final elapsedDays = _elapsedDays(card, reviewedAt);
    final retrievability = _retrievability(
      stability: previousStability,
      elapsedDays: elapsedDays,
    );
    final isNewCard = card.reviewCount == 0 && card.lastReviewedAt == null;

    switch (rating) {
      case StudyRating.again:
        final difficulty = (previousDifficulty + 0.55).clamp(1.0, 10.0).toDouble();
        final nextStability = max(
          0.35,
          previousStability *
              (0.2 + ((11 - previousDifficulty) / 45)) *
              (1 - min(card.lapseCount * 0.03, 0.2)),
        ).toDouble();
        final dueAt = reviewedAt.add(const Duration(minutes: 10));
        return _ScheduleOutcome(
          dueAt: dueAt,
          intervalDays: 0,
          state: 'learning',
          ease: (previousEase - 0.16).clamp(1.3, 3.0).toDouble(),
          stability: nextStability,
          difficulty: difficulty,
          lapseCount: card.lapseCount + 1,
        );
      case StudyRating.hard:
        final difficulty = (previousDifficulty + 0.1).clamp(1.0, 10.0).toDouble();
        final nextStability = isNewCard
            ? 1.2
            : previousStability * _successGrowthFactor(
                rating: rating,
                difficulty: difficulty,
                retrievability: retrievability,
              );
        final duration = isNewCard
            ? const Duration(hours: 12)
            : _durationFromDays(max(0.5, nextStability * 0.75));
        final dueAt = reviewedAt.add(duration);
        return _ScheduleOutcome(
          dueAt: dueAt,
          intervalDays: max(0, duration.inHours >= 24 ? duration.inDays : 0),
          state: duration.inHours < 24 ? 'learning' : 'review',
          ease: (previousEase - 0.05).clamp(1.3, 3.0).toDouble(),
          stability: nextStability,
          difficulty: difficulty,
          lapseCount: card.lapseCount,
        );
      case StudyRating.good:
        final difficulty = (previousDifficulty - 0.12).clamp(1.0, 10.0).toDouble();
        final nextStability = isNewCard
            ? 3.0
            : previousStability * _successGrowthFactor(
                rating: rating,
                difficulty: difficulty,
                retrievability: retrievability,
              );
        final duration = isNewCard
            ? const Duration(days: 3)
            : _durationFromDays(nextStability);
        final dueAt = reviewedAt.add(duration);
        return _ScheduleOutcome(
          dueAt: dueAt,
          intervalDays: max(1, duration.inHours >= 24 ? duration.inDays : 1),
          state: duration.inDays >= 1 ? 'review' : 'learning',
          ease: previousEase,
          stability: nextStability,
          difficulty: difficulty,
          lapseCount: card.lapseCount,
        );
      case StudyRating.easy:
        final difficulty = (previousDifficulty - 0.28).clamp(1.0, 10.0).toDouble();
        final nextStability = isNewCard
            ? 5.5
            : previousStability * _successGrowthFactor(
                rating: rating,
                difficulty: difficulty,
                retrievability: retrievability,
              );
        final duration = isNewCard
            ? const Duration(days: 5)
            : _durationFromDays(nextStability * 1.35);
        final dueAt = reviewedAt.add(duration);
        return _ScheduleOutcome(
          dueAt: dueAt,
          intervalDays: max(1, duration.inHours >= 24 ? duration.inDays : 1),
          state: 'review',
          ease: (previousEase + 0.05).clamp(1.3, 3.0).toDouble(),
          stability: nextStability,
          difficulty: difficulty,
          lapseCount: card.lapseCount,
        );
    }
  }

  double _successGrowthFactor({
    required StudyRating rating,
    required double difficulty,
    required double retrievability,
  }) {
    final difficultyWeight = (11 - difficulty) / 10;
    final retrievabilityWeight = 1 + (1 - retrievability) * 1.6;

    return switch (rating) {
      StudyRating.hard => 1.18 + difficultyWeight * 0.42 + retrievabilityWeight * 0.18,
      StudyRating.good => 1.85 + difficultyWeight * 0.7 + retrievabilityWeight * 0.42,
      StudyRating.easy => 2.45 + difficultyWeight * 0.95 + retrievabilityWeight * 0.6,
      StudyRating.again => 1,
    };
  }

  double _elapsedDays(CardRecord card, DateTime reviewedAt) {
    final anchor = card.lastReviewedAt ?? card.createdAt;
    final raw = reviewedAt.difference(anchor).inMinutes / (60 * 24);
    return max(0, raw);
  }

  double _seedStability(CardRecord card) {
    if (card.intervalDays > 0) {
      return card.intervalDays.toDouble();
    }
    if (card.reviewCount > 0) {
      return 1.0;
    }
    return 0.4;
  }

  double _retrievability({
    required double stability,
    required double elapsedDays,
  }) {
    final safeStability = max(stability, 0.1);
    final value = exp(log(_targetRetention) * (elapsedDays / safeStability));
    return value.clamp(0.03, 0.999).toDouble();
  }

  Duration _durationFromDays(double days) {
    final totalMinutes = max(10, (days * 24 * 60).round());
    return Duration(minutes: totalMinutes);
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${max(1, duration.inMinutes)}m';
    }
    if (duration.inHours < 24) {
      return '${duration.inHours}h';
    }
    if (duration.inDays < 30) {
      return '${duration.inDays}d';
    }
    final weeks = (duration.inDays / 7).round();
    if (weeks < 8) {
      return '${max(1, weeks)}w';
    }
    final months = (duration.inDays / 30).round();
    return '${max(1, months)}mo';
  }
}

class _ScheduleOutcome {
  const _ScheduleOutcome({
    required this.dueAt,
    required this.intervalDays,
    required this.state,
    required this.ease,
    required this.stability,
    required this.difficulty,
    required this.lapseCount,
  });

  final DateTime dueAt;
  final int intervalDays;
  final String state;
  final double ease;
  final double stability;
  final double difficulty;
  final int lapseCount;
}
