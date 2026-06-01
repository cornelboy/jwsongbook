import 'package:flutter/material.dart';
import 'app_colors.dart';

/// KS-Designer typography system.
/// All sizes follow the 8dp grid; line heights are 1.4–1.6×.
abstract final class AppTypography {
  // ── Song title / display ────────────────────────────────────────────────
  static const TextStyle displayTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textHigh,
    height: 1.4,
    letterSpacing: 0,
  );

  // ── Lyrics ─────────────────────────────────────────────────────────────

  /// The currently singing line — larger, full brightness.
  static const TextStyle lyricsActive = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.textHigh,
    height: 1.5,
    letterSpacing: 0.15,
  );

  /// Lines that haven't been reached yet — slightly smaller.
  static const TextStyle lyricsUpcoming = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 1.5,
    letterSpacing: 0.15,
  );

  /// Lines that have already been sung — dimmed.
  static const TextStyle lyricsPast = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: AppColors.textInactive,
    height: 1.5,
    letterSpacing: 0.15,
  );

  // ── Congregation projection mode ───────────────────────────────────────

  /// Active lyric in landscape/projection — must be readable at 5+ m.
  static const TextStyle lyricsProjectionActive = TextStyle(
    fontSize: 60,
    fontWeight: FontWeight.w600,
    color: AppColors.textHigh,
    height: 1.4,
  );

  static const TextStyle lyricsProjectionUpcoming = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 1.4,
  );

  // ── General UI ─────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textHigh,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 1.4,
    letterSpacing: 0.4,
  );

  static const TextStyle labelButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryPurple,
    letterSpacing: 1.25,
  );

  // ── Song card ──────────────────────────────────────────────────────────
  static const TextStyle songNumber = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryPurple,
    letterSpacing: 0.5,
  );

  static const TextStyle songTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textHigh,
    height: 1.4,
  );
}
