import 'dart:math';

import '../../study/domain/study_rating.dart';
import '../domain/qa_review_record.dart';

class QaReviewSchedulerService {
  const QaReviewSchedulerService();

  static const _weights = <double>[
    0.212,
    1.2931,
    2.3065,
    8.2956,
    6.4133,
    0.8334,
    3.0194,
    0.001,
    1.8722,
    0.1666,
    0.796,
    1.4835,
    0.0614,
    0.2629,
    1.6483,
    0.6014,
    1.8729,
    0.5425,
    0.0912,
    0.0658,
    0.1542,
  ];
  static const _targetRetention = 0.9;
  static const _maximumIntervalDays = 36500;
  static const _againLearningStep = Duration(minutes: 10);
  static const _hardLearningStep = Duration(hours: 12);
  static final double _decay = -_weights[20];
  static final double _factor = (pow(_targetRetention, 1 / _decay) - 1).toDouble();

  QaReviewRecord applyRating({
    required QaReviewRecord review,
    required QaRecallRating rating,
    required DateTime reviewedAt,
    required String? answerSnippet,
  }) {
    final outcome = _scheduleOutcome(
      review: review,
      rating: rating.studyRating,
      reviewedAt: reviewedAt,
    );
    return review.copyWith(
      reviewCount: review.reviewCount + 1,
      lapseCount: outcome.lapseCount,
      intervalDays: outcome.intervalDays,
      state: outcome.state,
      stability: outcome.stability,
      difficulty: outcome.difficulty,
      dueAt: outcome.dueAt,
      lastReviewedAt: reviewedAt,
      lastRating: rating,
      lastAnswerSnippet: answerSnippet?.trim().isEmpty ?? true ? null : answerSnippet?.trim(),
      updatedAt: reviewedAt,
    );
  }

  _QaScheduleOutcome _scheduleOutcome({
    required QaReviewRecord review,
    required StudyRating rating,
    required DateTime reviewedAt,
  }) {
    final previousStability = _normalizedStability(review.stability);
    final previousDifficulty = _normalizedDifficulty(review.difficulty);
    final isNewCard = review.reviewCount == 0 && review.lastReviewedAt == null;
    final isLearningCard = !isNewCard && (review.state == 'learning' || review.intervalDays <= 0);
    final elapsedDays = _elapsedDays(review, reviewedAt);
    final retrievability = isNewCard || isLearningCard
        ? _targetRetention
        : _forgettingCurve(elapsedDays, previousStability);
    final ratingNumber = _ratingNumber(rating);

    if (isNewCard) {
      final difficulty = _initDifficulty(ratingNumber);
      final stability = _initStability(ratingNumber);
      return _scheduleFromState(
        rating: rating,
        reviewedAt: reviewedAt,
        difficulty: difficulty,
        stability: stability,
        lapseCount: review.lapseCount,
      );
    }

    final difficulty = _nextDifficulty(previousDifficulty, ratingNumber);

    if (isLearningCard) {
      final stability = _nextShortTermStability(previousStability, ratingNumber);
      return _scheduleFromState(
        rating: rating,
        reviewedAt: reviewedAt,
        difficulty: difficulty,
        stability: stability,
        lapseCount: rating == StudyRating.again ? review.lapseCount + 1 : review.lapseCount,
      );
    }

    if (rating == StudyRating.again) {
      final stability = _nextForgetStability(
        previousDifficulty,
        previousStability,
        retrievability,
      );
      return _QaScheduleOutcome(
        dueAt: reviewedAt.add(_againLearningStep),
        intervalDays: 0,
        state: 'learning',
        stability: stability,
        difficulty: difficulty,
        lapseCount: review.lapseCount + 1,
      );
    }

    final hardStability = _nextRecallStability(
      previousDifficulty,
      previousStability,
      retrievability,
      StudyRating.hard,
    );
    final goodStability = _nextRecallStability(
      previousDifficulty,
      previousStability,
      retrievability,
      StudyRating.good,
    );
    final easyStability = _nextRecallStability(
      previousDifficulty,
      previousStability,
      retrievability,
      StudyRating.easy,
    );

    var hardInterval = _nextIntervalDays(hardStability);
    var goodInterval = _nextIntervalDays(goodStability);
    var easyInterval = _nextIntervalDays(easyStability);

    hardInterval = min(hardInterval, goodInterval);
    goodInterval = max(goodInterval, hardInterval + 1);
    easyInterval = max(easyInterval, goodInterval + 1);

    return switch (rating) {
      StudyRating.hard => _reviewOutcome(
          reviewedAt: reviewedAt,
          difficulty: difficulty,
          stability: hardStability,
          intervalDays: hardInterval,
          lapseCount: review.lapseCount,
        ),
      StudyRating.good => _reviewOutcome(
          reviewedAt: reviewedAt,
          difficulty: difficulty,
          stability: goodStability,
          intervalDays: goodInterval,
          lapseCount: review.lapseCount,
        ),
      StudyRating.easy => _reviewOutcome(
          reviewedAt: reviewedAt,
          difficulty: difficulty,
          stability: easyStability,
          intervalDays: easyInterval,
          lapseCount: review.lapseCount,
        ),
      StudyRating.again => throw StateError('Again should already be handled.'),
    };
  }

  _QaScheduleOutcome _scheduleFromState({
    required StudyRating rating,
    required DateTime reviewedAt,
    required double difficulty,
    required double stability,
    required int lapseCount,
  }) {
    switch (rating) {
      case StudyRating.again:
        return _QaScheduleOutcome(
          dueAt: reviewedAt.add(_againLearningStep),
          intervalDays: 0,
          state: 'learning',
          stability: stability,
          difficulty: difficulty,
          lapseCount: lapseCount,
        );
      case StudyRating.hard:
        return _QaScheduleOutcome(
          dueAt: reviewedAt.add(_hardLearningStep),
          intervalDays: 0,
          state: 'learning',
          stability: stability,
          difficulty: difficulty,
          lapseCount: lapseCount,
        );
      case StudyRating.good:
        return _reviewOutcome(
          reviewedAt: reviewedAt,
          difficulty: difficulty,
          stability: stability,
          intervalDays: _nextIntervalDays(stability),
          lapseCount: lapseCount,
        );
      case StudyRating.easy:
        return _reviewOutcome(
          reviewedAt: reviewedAt,
          difficulty: difficulty,
          stability: stability,
          intervalDays: max(_nextIntervalDays(stability), 2),
          lapseCount: lapseCount,
        );
    }
  }

  _QaScheduleOutcome _reviewOutcome({
    required DateTime reviewedAt,
    required double difficulty,
    required double stability,
    required int intervalDays,
    required int lapseCount,
  }) {
    return _QaScheduleOutcome(
      dueAt: reviewedAt.add(Duration(days: intervalDays)),
      intervalDays: intervalDays,
      state: 'review',
      stability: stability,
      difficulty: difficulty,
      lapseCount: lapseCount,
    );
  }

  double _elapsedDays(QaReviewRecord review, DateTime reviewedAt) {
    final anchor = review.lastReviewedAt ?? reviewedAt;
    final raw = reviewedAt.difference(anchor).inMinutes / (60 * 24);
    return max(0, raw);
  }

  int _ratingNumber(StudyRating rating) {
    return switch (rating) {
      StudyRating.again => 1,
      StudyRating.hard => 2,
      StudyRating.good => 3,
      StudyRating.easy => 4,
    };
  }

  double _initStability(int rating) => max(_weights[rating - 1], 0.1);

  double _initDifficulty(int rating) {
    final raw = _weights[4] - exp(_weights[5] * (rating - 1)) + 1;
    return _constrainDifficulty(raw);
  }

  double _nextDifficulty(double difficulty, int rating) {
    final delta = -_weights[6] * (rating - 3);
    final damped = difficulty + _linearDamping(delta, difficulty);
    return _constrainDifficulty(_meanReversion(_initDifficulty(4), damped));
  }

  double _linearDamping(double deltaDifficulty, double oldDifficulty) {
    return deltaDifficulty * (10 - oldDifficulty) / 9;
  }

  double _meanReversion(double initial, double current) {
    return _weights[7] * initial + (1 - _weights[7]) * current;
  }

  double _nextRecallStability(
    double difficulty,
    double stability,
    double retrievability,
    StudyRating rating,
  ) {
    final hardPenalty = rating == StudyRating.hard ? _weights[15] : 1.0;
    final easyBonus = rating == StudyRating.easy ? _weights[16] : 1.0;
    final next = stability *
        (1 +
            exp(_weights[8]) *
                (11 - difficulty) *
                pow(stability, -_weights[9]) *
                (exp((1 - retrievability) * _weights[10]) - 1) *
                hardPenalty *
                easyBonus);
    return _normalizedStability(next);
  }

  double _nextForgetStability(
    double difficulty,
    double stability,
    double retrievability,
  ) {
    final minimum = stability / exp(_weights[17] * _weights[18]);
    final next = min(
      _weights[11] *
          pow(difficulty, -_weights[12]) *
          (pow(stability + 1, _weights[13]) - 1) *
          exp((1 - retrievability) * _weights[14]),
      minimum,
    );
    return _normalizedStability(next);
  }

  double _nextShortTermStability(double stability, int rating) {
    var scale = exp(_weights[17] * (rating - 3 + _weights[18])) *
        pow(stability, -_weights[19]);
    if (rating >= 3) {
      scale = max(scale, 1);
    }
    return _normalizedStability(stability * scale);
  }

  double _forgettingCurve(double elapsedDays, double stability) {
    return pow(1 + _factor * elapsedDays / stability, _decay)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int _nextIntervalDays(double stability) {
    final raw = stability / _factor * (pow(_targetRetention, 1 / _decay) - 1);
    return min(max(raw.round(), 1), _maximumIntervalDays);
  }

  double _constrainDifficulty(double difficulty) => difficulty.clamp(1.0, 10.0).toDouble();

  double _normalizedDifficulty(double difficulty) {
    if (difficulty.isFinite && difficulty > 0) {
      return _constrainDifficulty(difficulty);
    }
    return 5.0;
  }

  double _normalizedStability(double stability) {
    if (stability.isFinite && stability > 0) {
      return max(double.parse(stability.toStringAsFixed(2)), 0.1);
    }
    return 0.1;
  }
}

class _QaScheduleOutcome {
  const _QaScheduleOutcome({
    required this.dueAt,
    required this.intervalDays,
    required this.state,
    required this.stability,
    required this.difficulty,
    required this.lapseCount,
  });

  final DateTime dueAt;
  final int intervalDays;
  final String state;
  final double stability;
  final double difficulty;
  final int lapseCount;
}
