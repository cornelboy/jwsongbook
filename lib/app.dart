import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_theme.dart';
import 'package:jwsongbook/data/models/app_settings.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';

/// Root widget — wraps the entire app in [ProviderScope] and wires up
/// the [GoRouter] and [ThemeData].
class JwSongbookApp extends ConsumerWidget {
  const JwSongbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themePreference = ref.watch(
      appSettingsNotifierProvider.select(
        (settings) => settings.themePreference,
      ),
    );
    final themeMode = switch (themePreference) {
      AppThemePreference.dark => ThemeMode.dark,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'JW Songs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 200),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = context.appColors;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: colors.surfaceElevated,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
