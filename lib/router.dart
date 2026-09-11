import 'package:go_router/go_router.dart';
import 'screens/onboarding_screen.dart';
import 'screens/library_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/source_viewer_screen.dart';
import 'screens/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/chat/:documentId',
      builder: (context, state) {
        final docId = state.pathParameters['documentId']!;
        return ChatScreen(documentId: docId);
      },
    ),
    GoRoute(
      path: '/source/:documentId/:page',
      builder: (context, state) {
        final docId = state.pathParameters['documentId']!;
        final page = int.tryParse(state.pathParameters['page'] ?? '0') ?? 0;
        return SourceViewerScreen(documentId: docId, highlightPage: page);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
