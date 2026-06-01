import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/shared/widgets/mini_player_bar.dart';

class ScaffoldWithBottomNav extends ConsumerWidget {
  const ScaffoldWithBottomNav({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _Tab(label: 'Songs', icon: Icons.library_music_outlined,
        activeIcon: Icons.library_music, route: AppRoutes.library),
    _Tab(label: 'Favorites', icon: Icons.favorite_outline,
        activeIcon: Icons.favorite, route: AppRoutes.favorites),
    _Tab(label: 'Now Playing', icon: Icons.queue_music_outlined,
        activeIcon: Icons.queue_music, route: AppRoutes.nowPlaying),
    _Tab(label: 'Settings', icon: Icons.settings_outlined,
        activeIcon: Icons.settings, route: AppRoutes.settings),
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
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player sits above the nav bar; hidden on Now Playing tab.
          const MiniPlayerBar(),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(_tabs[i].route),
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
