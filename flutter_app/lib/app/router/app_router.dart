import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_shell.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/cards/presentation/deck_detail_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/notes/presentation/note_editor_screen.dart';
import '../../features/notes/presentation/note_reading_screen.dart';
import '../../features/notes/presentation/subject_notes_screen.dart';
import '../../features/qa/presentation/qa_session_screen.dart';
import '../../features/qa/presentation/subject_qa_screen.dart';
import '../../features/quizzes/presentation/quiz_detail_screen.dart';
import '../../features/quizzes/presentation/quiz_session_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/study/study_screen.dart';
import '../../features/study/presentation/study_session_screen.dart';
import '../../features/subjects/presentation/subjects_home_screen.dart';
import '../../features/subjects/presentation/subject_detail_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentPath: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SubjectsHomeScreen(),
          ),
          GoRoute(
            path: '/subjects/:subjectId',
            builder: (context, state) => SubjectDetailScreen(
              subjectId: state.pathParameters['subjectId']!,
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/decks/:deckId',
            builder: (context, state) => DeckDetailScreen(
              subjectId: state.pathParameters['subjectId']!,
              deckId: state.pathParameters['deckId']!,
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/notes',
            builder: (context, state) => SubjectNotesScreen(
              subjectId: state.pathParameters['subjectId']!,
              initialNoteId: state.uri.queryParameters['noteId'],
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/notes/:noteId',
            builder: (context, state) => NoteEditorScreen(
              subjectId: state.pathParameters['subjectId']!,
              noteId: state.pathParameters['noteId']!,
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/notes/:noteId/read',
            builder: (context, state) => NoteReadingScreen(
              subjectId: state.pathParameters['subjectId']!,
              noteId: state.pathParameters['noteId']!,
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/qa',
            builder: (context, state) => SubjectQaScreen(
              subjectId: state.pathParameters['subjectId']!,
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/qa/:promptId/session',
            builder: (context, state) => QaSessionScreen(
              subjectId: state.pathParameters['subjectId']!,
              promptId: state.pathParameters['promptId']!,
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/decks/:deckId/study',
            builder: (context, state) => StudySessionScreen(
              deckId: state.pathParameters['deckId']!,
              deckName: state.uri.queryParameters['deckName'] ?? 'Study Deck',
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/quizzes/:quizId',
            builder: (context, state) => QuizDetailScreen(
              subjectId: state.pathParameters['subjectId']!,
              quizId: state.pathParameters['quizId']!,
            ),
          ),
          GoRoute(
            path: '/subjects/:subjectId/quizzes/:quizId/session',
            builder: (context, state) => QuizSessionScreen(
              subjectId: state.pathParameters['subjectId']!,
              quizId: state.pathParameters['quizId']!,
              sessionMode: state.uri.queryParameters['mode'] ?? 'practice',
            ),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/study',
            builder: (context, state) => const StudyScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
