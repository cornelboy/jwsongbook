import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';

/// Produces the single [ThemeData] used throughout the app.
/// The app is dark-only — matching JW Library's aesthetic.
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      // ── Colour scheme ──────────────────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPurple,
        onPrimary: AppColors.background,
        secondary: AppColors.activeWordHighlight,
        onSecondary: AppColors.background,
        surface: AppColors.background,
        onSurface: AppColors.textHigh,
        error: AppColors.error,
        onError: AppColors.background,
        surfaceContainerHighest: AppColors.card,
        outline: AppColors.divider,
      ),

      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textHigh,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: AppTypography.displayTitle,
        centerTitle: false,
      ),

      // ── Bottom navigation ─────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        indicatorColor: AppColors.primaryPurple.withAlpha(51), // ~20 %
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.caption.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.caption;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.primaryPurple,
              size: 24,
            );
          }
          return const IconThemeData(color: AppColors.textMedium, size: 24);
        }),
        height: 64,
      ),

      // ── Cards ─────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // ── Input / search ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        hintStyle: AppTypography.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ── Icon ──────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: AppColors.textMedium, size: 24),

      // ── Text ──────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displaySmall: AppTypography.displayTitle,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.labelButton,
      ),

      // ── Sliders (seek bar) ────────────────────────────────────────────
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primaryPurple,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.primaryPurple,
        overlayColor: Color(0x1FBB86FC),
        trackHeight: 3,
      ),

      // ── Snack bar ─────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: AppTypography.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Ripple / splash ───────────────────────────────────────────────
      splashColor: AppColors.primaryPurple.withAlpha(31),
      highlightColor: AppColors.primaryPurple.withAlpha(20),
    );
  }
}
