import 'package:flutter/material.dart';

/// KS-Designer spec — exact hex values from the design system.
/// Do NOT invent new colors. If you need a colour variant, add it here.
abstract final class AppColors {
  // ── Backgrounds ────────────────────────────────────────────────────────
  /// Material dark surface — NOT pure black. Matches JW Library.
  static const Color background = Color(0xFF121212);

  /// Slightly elevated surface (dialogs, bottom sheets).
  static const Color surfaceElevated = Color(0xFF1E1E1E);

  /// Card / container background.
  static const Color card = Color(0xFF242424);

  // ── Accent ─────────────────────────────────────────────────────────────
  /// Primary purple — Material Purple 200. Matches JW Library accent.
  static const Color primaryPurple = Color(0xFFBB86FC);

  /// Lighter mauve used for the active word highlight fill.
  static const Color activeWordHighlight = Color(0xFFE0B0FF);

  // ── Text ───────────────────────────────────────────────────────────────
  /// High-emphasis text — 87 % white.
  static const Color textHigh = Color(0xDEFFFFFF);

  /// Medium-emphasis text — 60 % white.
  static const Color textMedium = Color(0x99FFFFFF);

  /// Inactive / dimmed lyrics text — 40 % white.
  static const Color textInactive = Color(0x66FFFFFF);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color error = Color(0xFFCF6679);

  /// Dividers and outlines — 12 % white.
  static const Color divider = Color(0x1FFFFFFF);

  // ── Lyrics opacity helpers (use with white) ────────────────────────────
  static const double opacityActive = 0.87;
  static const double opacityUpcoming = 0.60;
  static const double opacityPast = 0.40;
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surfaceElevated,
    required this.card,
    required this.primaryPurple,
    required this.activeWordHighlight,
    required this.textHigh,
    required this.textMedium,
    required this.textInactive,
    required this.error,
    required this.divider,
    required this.outline,
  });

  static const dark = AppPalette(
    background: AppColors.background,
    surfaceElevated: AppColors.surfaceElevated,
    card: AppColors.card,
    primaryPurple: AppColors.primaryPurple,
    activeWordHighlight: AppColors.activeWordHighlight,
    textHigh: AppColors.textHigh,
    textMedium: AppColors.textMedium,
    textInactive: AppColors.textInactive,
    error: AppColors.error,
    divider: AppColors.divider,
    outline: AppColors.textInactive,
  );

  static const light = AppPalette(
    background: Color(0xFFF8F7FA),
    surfaceElevated: Color(0xFFF0EEF3),
    card: Color(0xFFE9E7EC),
    primaryPurple: Color(0xFF6D3AA8),
    activeWordHighlight: Color(0xFF5F2D91),
    textHigh: Color(0xFF1C1B1F),
    textMedium: Color(0xFF49454F),
    textInactive: Color(0xFF706B73),
    error: Color(0xFFB3261E),
    divider: Color(0xFFCAC4D0),
    outline: Color(0xFF79747E),
  );

  final Color background;
  final Color surfaceElevated;
  final Color card;
  final Color primaryPurple;
  final Color activeWordHighlight;
  final Color textHigh;
  final Color textMedium;
  final Color textInactive;
  final Color error;
  final Color divider;
  final Color outline;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surfaceElevated,
    Color? card,
    Color? primaryPurple,
    Color? activeWordHighlight,
    Color? textHigh,
    Color? textMedium,
    Color? textInactive,
    Color? error,
    Color? divider,
    Color? outline,
  }) =>
      AppPalette(
        background: background ?? this.background,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        card: card ?? this.card,
        primaryPurple: primaryPurple ?? this.primaryPurple,
        activeWordHighlight: activeWordHighlight ?? this.activeWordHighlight,
        textHigh: textHigh ?? this.textHigh,
        textMedium: textMedium ?? this.textMedium,
        textInactive: textInactive ?? this.textInactive,
        error: error ?? this.error,
        divider: divider ?? this.divider,
        outline: outline ?? this.outline,
      );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      card: Color.lerp(card, other.card, t)!,
      primaryPurple: Color.lerp(primaryPurple, other.primaryPurple, t)!,
      activeWordHighlight:
          Color.lerp(activeWordHighlight, other.activeWordHighlight, t)!,
      textHigh: Color.lerp(textHigh, other.textHigh, t)!,
      textMedium: Color.lerp(textMedium, other.textMedium, t)!,
      textInactive: Color.lerp(textInactive, other.textInactive, t)!,
      error: Color.lerp(error, other.error, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appColors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
