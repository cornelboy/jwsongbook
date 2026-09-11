import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/platform/lyrics_overlay_bubble.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/shared/widgets/mini_player_bar.dart';

class ScaffoldWithBottomNav extends ConsumerWidget {
  const ScaffoldWithBottomNav({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _Tab(
      label: 'Songs',
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music,
      route: AppRoutes.library,
    ),
    _Tab(
      label: 'Now Playing',
      icon: Icons.queue_music_outlined,
      activeIcon: Icons.queue_music,
      route: AppRoutes.nowPlaying,
    ),
    _Tab(
      label: 'Favorites',
      icon: Icons.favorite_outline,
      activeIcon: Icons.favorite,
      route: AppRoutes.favorites,
    ),
    _Tab(
      label: 'Playlists',
      icon: Icons.playlist_play_outlined,
      activeIcon: Icons.playlist_play,
      route: AppRoutes.playlists,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _currentIndex(context);
    final isSongsPage = location.startsWith(AppRoutes.library);
    final isNowPlayingPage = shouldSuppressFloatingLyricsForLocation(location);
    final floatingLyricsEnabled =
        ref.watch(floatingLyricsBubbleEnabledProvider);
    final floatingLyricsExpanded =
        ref.watch(floatingLyricsBubbleExpandedProvider);
    final colors = context.appColors;

    return PopScope(
      canPop: isSongsPage || Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (context.canPop()) {
          context.pop();
          return;
        }

        if (!isSongsPage) {
          context.go(AppRoutes.library);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            body: Stack(
              children: [
                child,
                ExternalLyricsBubbleSync(
                  suppressWhileForeground: isNowPlayingPage,
                ),
              ],
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini player sits above the nav bar; hidden on Now Playing tab.
                const MiniPlayerBar(),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colors.divider, width: 0.5),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: currentIndex,
                    onDestinationSelected: (i) {
                      final route = _tabs[i].route;
                      context.go(route);
                      if (route == AppRoutes.nowPlaying) {
                        ref
                            .read(
                              miniPlayerAnimateExpansionProvider.notifier,
                            )
                            .state = false;
                        ref.read(miniPlayerCollapsedProvider.notifier).state =
                            false;
                      }
                    },
                    destinations: _tabs
                        .map(
                          (t) => NavigationDestination(
                            icon: Icon(t.icon),
                            selectedIcon: Icon(t.activeIcon),
                            label: t.label,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          if (floatingLyricsEnabled && floatingLyricsExpanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref
                      .read(floatingLyricsBubbleExpandedProvider.notifier)
                      .state = false;
                  unawaited(
                    ref.read(lyricsOverlayBubbleProvider).collapseBubble(),
                  );
                },
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
