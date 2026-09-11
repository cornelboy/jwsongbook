import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';

abstract final class AppTheme {
  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    colors: AppPalette.dark,
  );

  static final ThemeData light = _build(
    brightness: Brightness.light,
    colors: AppPalette.light,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette colors,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: colors.primaryPurple,
            onPrimary: colors.background,
            secondary: colors.activeWordHighlight,
            onSecondary: colors.background,
            surface: colors.background,
            onSurface: colors.textHigh,
            error: colors.error,
            onError: colors.background,
            surfaceContainerHighest: colors.card,
            outline: colors.divider,
            outlineVariant: colors.divider,
          )
        : ColorScheme.light(
            primary: colors.primaryPurple,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFE9DDFF),
            onPrimaryContainer: const Color(0xFF27113F),
            secondary: colors.activeWordHighlight,
            onSecondary: Colors.white,
            surface: colors.background,
            onSurface: colors.textHigh,
            onSurfaceVariant: colors.textMedium,
            error: colors.error,
            onError: Colors.white,
            surfaceContainer: colors.surfaceElevated,
            surfaceContainerHighest: colors.card,
            outline: colors.outline,
            outlineVariant: colors.divider,
          );
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = TextTheme(
      displaySmall: AppTypography.displayTitle.copyWith(color: colors.textHigh),
      titleMedium: AppTypography.songTitle.copyWith(color: colors.textHigh),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: colors.textHigh),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: colors.textMedium),
      bodySmall: AppTypography.caption.copyWith(color: colors.textMedium),
      labelLarge:
          AppTypography.labelButton.copyWith(color: colors.primaryPurple),
      labelMedium:
          AppTypography.songNumber.copyWith(color: colors.primaryPurple),
    );
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.surfaceElevated,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      extensions: [colors],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textHigh,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
        titleTextStyle:
            AppTypography.displayTitle.copyWith(color: colors.textHigh),
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceElevated,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.caption.copyWith(
              color: colors.primaryPurple,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.caption.copyWith(color: colors.textMedium);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.primaryPurple, size: 24);
          }
          return IconThemeData(color: colors.textMedium, size: 24);
        }),
        height: 64,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        hintStyle: AppTypography.bodyMedium.copyWith(color: colors.textMedium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      iconTheme: IconThemeData(color: colors.textMedium, size: 24),
      textTheme: textTheme,
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primaryPurple,
        inactiveTrackColor: colors.divider,
        thumbColor: colors.primaryPurple,
        overlayColor: colors.primaryPurple.withAlpha(31),
        trackHeight: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.card,
        contentTextStyle:
            AppTypography.bodyMedium.copyWith(color: colors.textHigh),
        actionTextColor: colors.primaryPurple,
        disabledActionTextColor: colors.textInactive,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      splashColor: colors.primaryPurple.withAlpha(31),
      highlightColor: colors.primaryPurple.withAlpha(20),
    );
  }
}
