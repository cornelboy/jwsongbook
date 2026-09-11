/// App-wide constants. No magic numbers outside this file.
abstract final class AppConstants {
  // ── Catalogue ──────────────────────────────────────────────────────────
  /// Remote manifest. Override for local testing with:
  /// --dart-define=SONG_MANIFEST_URL=https://host.example/manifest.json
  static const String defaultSongManifestUrl =
      'https://cornelboy.github.io/jwsongbook-downloads/manifest.json';

  static const String songManifestUrl = String.fromEnvironment(
    'SONG_MANIFEST_URL',
    defaultValue: defaultSongManifestUrl,
  );

  static const bool hasSongManifestUrl = songManifestUrl != '';

  // ── Lyrics sync engine ────────────────────────────────────────────────
  /// How often the sync ticker fires (16 ms ≈ 60 fps).
  static const int syncTickMs = 16;

  /// Maximum allowable gap between consecutive words before we warn.
  static const int maxWordGapMs = 300;

  /// Seek debounce — wait this long after a seek before resuming sync.
  static const int seekDebounceMs = 150;

  /// Visual lead applied to lyric highlighting so sung words do not feel late.
  static const int lyricVisualLeadMs = 300;

  // ── UI ────────────────────────────────────────────────────────────────
  /// Number of lyric lines visible on screen at once (personal mode).
  static const int visibleLyricsLines = 6;

  /// Number of lyric lines visible in congregation/projection mode.
  static const int visibleLyricsLinesProjection = 3;

  /// Position of the active lyric line from the top of the visible area (0–1).
  static const double activeLyricLinePosition = 0.30;

  /// Time spent easing toward the next lyric before it becomes active.
  static const Duration lyricPreScrollDuration = Duration(milliseconds: 700);

  /// Short correction during ordinary following and after seeking.
  static const Duration lyricFollowCatchUpDuration =
      Duration(milliseconds: 220);

  /// Resume after reading nearby lyrics, but never pull back an off-screen line.
  static const Duration lyricFollowResumeDelay = Duration(seconds: 5);
  static const Duration lyricFollowResumeMinDuration =
      Duration(milliseconds: 800);
  static const Duration lyricFollowResumeMaxDuration =
      Duration(milliseconds: 1200);

  /// Safe lyric viewport excludes the decorative edge fades.
  static const double lyricsTopFadeHeight = 72;
  static const double lyricsBottomFadeHeight = 88;
  static const double lyricsLineGap = 8;
  static const double lyricsStanzaGap = 20;
  static const double lyricsProjectionStanzaGap = 28;

  // ── Database ──────────────────────────────────────────────────────────
  static const String dbFileName = 'jwsongbook.db';
  static const int dbCurrentVersion = 3;

  // ── Spacing (8dp grid) ────────────────────────────────────────────────
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;
  static const double spaceXXL = 48;

  static const double screenPaddingH = 16;
  static const double cardPadding = 16;
  static const double minTouchTarget = 48;
  static const double borderRadius = 12;
}
