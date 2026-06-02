import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/features/favorites/screens/favorites_screen.dart';
import 'package:jwsongbook/features/library/screens/library_screen.dart';
import 'package:jwsongbook/features/player/screens/player_screen.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';
import 'package:jwsongbook/shared/widgets/scaffold_with_bottom_nav.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Route path constants — always reference these, never raw strings.
abstract final class AppRoutes {
  static const String library = '/library';
  static const String favorites = '/favorites';
  static const String nowPlaying = '/now-playing';
  static const String settings = '/settings';
  static const String song = '/song/:number';

  static String songPath(int number) => '/song/$number';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.library,
    debugLogDiagnostics: true,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithBottomNav(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.library,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.favorites,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FavoritesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.nowPlaying,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlayerScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.song,
            builder: (context, state) {
              final number =
                  int.tryParse(state.pathParameters['number'] ?? '') ?? 1;
              return PlayerScreen(initialSongNumber: number);
            },
          ),
        ],
      ),
    ],
  );
}
