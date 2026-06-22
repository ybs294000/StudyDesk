import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/cards/data/cards_repository.dart';
import '../../features/decks/data/decks_repository.dart';
import '../../features/quizzes/data/quizzes_repository.dart';
import '../../features/subjects/data/subjects_repository.dart';
import '../../features/subjects/domain/subject_record.dart';
import '../../services/content_portability_service.dart';

const _bootstrapSeededKey = 'studydesk_bootstrap_seeded_v3';

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final service = AppBootstrapService(
    subjectsRepository: ref.read(subjectsRepositoryProvider),
    decksRepository: ref.read(decksRepositoryProvider),
    cardsRepository: ref.read(cardsRepositoryProvider),
    quizzesRepository: ref.read(quizzesRepositoryProvider),
    portabilityService: ref.read(contentPortabilityServiceProvider),
  );
  await service.ensureSeeded();
});

class AppBootstrapService {
  AppBootstrapService({
    required this.subjectsRepository,
    required this.decksRepository,
    required this.cardsRepository,
    required this.quizzesRepository,
    required this.portabilityService,
  });

  final SubjectsRepository subjectsRepository;
  final DecksRepository decksRepository;
  final CardsRepository cardsRepository;
  final QuizzesRepository quizzesRepository;
  final ContentPortabilityService portabilityService;

  Future<void> ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeeded = prefs.getBool(_bootstrapSeededKey) ?? false;
    if (alreadySeeded) {
      return;
    }

    final subjects = await subjectsRepository.loadSubjects();
    final decks = await decksRepository.loadDecks();
    final cards = await cardsRepository.loadCards();
    final quizzes = await quizzesRepository.loadQuizzes();
    final hasExistingContent = subjects.isNotEmpty ||
        decks.isNotEmpty ||
        cards.isNotEmpty ||
        quizzes.isNotEmpty;

    if (hasExistingContent) {
      await prefs.setBool(_bootstrapSeededKey, true);
      return;
    }

    final now = DateTime.now();
    final starterSubject = SubjectRecord(
      id: now.microsecondsSinceEpoch.toString(),
      name: 'Starter Library',
      emoji: '🧪',
      colorValue: 0xFF0F9D8A,
      createdAt: now,
      updatedAt: now,
    );

    await subjectsRepository.saveSubjects([starterSubject]);

    for (final asset in _starterDeckAssets) {
      await portabilityService.importDeckAsset(
        subjectId: starterSubject.id,
        assetPath: asset,
      );
    }

    for (final asset in _starterQuizAssets) {
      await portabilityService.importQuizAsset(
        subjectId: starterSubject.id,
        assetPath: asset,
      );
    }

    await prefs.setBool(_bootstrapSeededKey, true);
  }
}

const _starterDeckAssets = <String>[
  'assets/sample_data/sample_deck_chemistry.json',
  'assets/sample_data/sample_deck_dsa.json',
];

const _starterQuizAssets = <String>[
  'assets/sample_data/sample_quiz_neet_style.json',
  'assets/sample_data/sample_quiz_jee_style.json',
  'assets/sample_data/sample_quiz_math_foundations.json',
  'assets/sample_data/sample_quiz_biology_basics.json',
  'assets/sample_data/sample_quiz_history_civics.json',
  'assets/sample_data/sample_quiz_science_qa.json',
];
