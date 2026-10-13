import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/album/album_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/catalog/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/pdf/pdf_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/profile/profile_screen.dart';
import 'home_shell.dart';

/// Пути экранов — в одном месте, чтобы не собирать строки по коду.
abstract final class Routes {
  static const home = '/';
  static const library = '/library';
  static const profile = '/profile';
  static const onboarding = '/onboarding';

  /// Вход. Возвращает `true` через `context.push<bool>`, если вход удался.
  static const login = '/login';
  static String album(String id) => '/album/$id';
  static String lesson(String albumId, String lessonId) =>
      '/album/$albumId/lesson/$lessonId';
  static String material(String albumId, String materialId) =>
      '/album/$albumId/material/$materialId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final seen = ref.read(onboardingSeenProvider);
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!seen && !atOnboarding) return Routes.onboarding;
      if (seen && atOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/album/:id',
        builder: (context, state) =>
            AlbumScreen(albumId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'lesson/:lessonId',
            builder: (context, state) => PlayerScreen(
              albumId: state.pathParameters['id']!,
              lessonId: state.pathParameters['lessonId']!,
            ),
          ),
          GoRoute(
            path: 'material/:materialId',
            builder: (context, state) => PdfScreen(
              albumId: state.pathParameters['id']!,
              materialId: state.pathParameters['materialId']!,
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
