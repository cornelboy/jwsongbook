import 'package:flutter/material.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';

/// KS-Designer typography system.
/// All sizes follow the 8dp grid; line heights are 1.4–1.6×.
abstract final class AppTypography {
  // ── Song title / display ────────────────────────────────────────────────
  static const TextStyle displayTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  // ── Lyrics ─────────────────────────────────────────────────────────────

  /// The currently singing line — larger, full brightness.
  static const TextStyle lyricsActive = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0.15,
  );

  /// Lines that haven't been reached yet — slightly smaller.
  static const TextStyle lyricsUpcoming = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0.15,
  );

  /// Lines that have already been sung — dimmed.
  static const TextStyle lyricsPast = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0.15,
  );

  // ── Congregation projection mode ───────────────────────────────────────

  /// Active lyric in landscape/projection — must be readable at 5+ m.
  static const TextStyle lyricsProjectionActive = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle lyricsProjectionUpcoming = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ── General UI ─────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.4,
  );

  static const TextStyle labelButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.25,
  );

  // ── Song card ──────────────────────────────────────────────────────────
  static const TextStyle songNumber = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle songTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
}

class AppTextStyles {
  const AppTextStyles(this.colors);

  final AppPalette colors;

  TextStyle get displayTitle =>
      AppTypography.displayTitle.copyWith(color: colors.textHigh);
  TextStyle get lyricsActive =>
      AppTypography.lyricsActive.copyWith(color: colors.textHigh);
  TextStyle get lyricsUpcoming =>
      AppTypography.lyricsUpcoming.copyWith(color: colors.textMedium);
  TextStyle get lyricsPast =>
      AppTypography.lyricsPast.copyWith(color: colors.textInactive);
  TextStyle get lyricsProjectionActive =>
      AppTypography.lyricsProjectionActive.copyWith(color: colors.textHigh);
  TextStyle get lyricsProjectionUpcoming =>
      AppTypography.lyricsProjectionUpcoming.copyWith(color: colors.textMedium);
  TextStyle get bodyLarge =>
      AppTypography.bodyLarge.copyWith(color: colors.textHigh);
  TextStyle get bodyMedium =>
      AppTypography.bodyMedium.copyWith(color: colors.textMedium);
  TextStyle get caption =>
      AppTypography.caption.copyWith(color: colors.textMedium);
  TextStyle get labelButton =>
      AppTypography.labelButton.copyWith(color: colors.primaryPurple);
  TextStyle get songNumber =>
      AppTypography.songNumber.copyWith(color: colors.primaryPurple);
  TextStyle get songTitle =>
      AppTypography.songTitle.copyWith(color: colors.textHigh);
}

extension AppTextStylesContext on BuildContext {
  AppTextStyles get appText => AppTextStyles(appColors);
}
