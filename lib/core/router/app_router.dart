import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/features/downloads/screens/download_screen.dart';
import 'package:jwsongbook/features/downloads/screens/manage_downloads_screen.dart';
import 'package:jwsongbook/features/favorites/screens/favorites_screen.dart';
import 'package:jwsongbook/features/library/screens/library_screen.dart';
import 'package:jwsongbook/features/player/screens/player_screen.dart';
import 'package:jwsongbook/features/playlists/screens/playlist_detail_screen.dart';
import 'package:jwsongbook/features/playlists/screens/playlists_screen.dart';
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
  static const String playlists = '/playlists';
  static String playlistPath(int id) => '$playlists/$id';
  static const String manageDownloads = '/settings/downloads';
  static const String song = '/song/:number';
  static const String download = '/download/:number';

  static String songPath(int number) => '/song/$number';
  static String nowPlayingSongPath(int number) => '$nowPlaying?song=$number';
  static String downloadPath(int number) => '/download/$number';
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
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: PlayerScreen(
                initialSongNumber:
                    int.tryParse(state.uri.queryParameters['song'] ?? ''),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.playlists,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PlaylistsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => PlaylistDetailScreen(
                  playlistId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.manageDownloads,
            builder: (context, state) => const ManageDownloadsScreen(),
          ),
          GoRoute(
            path: AppRoutes.song,
            redirect: (context, state) {
              final number =
                  int.tryParse(state.pathParameters['number'] ?? '') ?? 1;
              return AppRoutes.nowPlayingSongPath(number);
            },
          ),
          GoRoute(
            path: AppRoutes.download,
            builder: (context, state) {
              final number =
                  int.tryParse(state.pathParameters['number'] ?? '') ?? 1;
              return DownloadScreen(songNumber: number);
            },
          ),
        ],
      ),
    ],
  );
}
