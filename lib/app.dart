import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_theme.dart';

/// Root widget — wraps the entire app in [ProviderScope] and wires up
/// the [GoRouter] and [ThemeData].
class JwSongbookApp extends ConsumerWidget {
  const JwSongbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Kingdom Songs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // No light theme — the app is dark-only.
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
