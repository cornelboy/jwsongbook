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
