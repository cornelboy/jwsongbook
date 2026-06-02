/// App-wide constants. No magic numbers outside this file.
abstract final class AppConstants {
  // ── Catalogue ──────────────────────────────────────────────────────────
  static const int totalSongs = 162;

  /// Temporary bundled starter set while remote downloads are being wired.
  static const Set<int> bundledSongNumbers = {1, 2, 3};

  /// Optional remote manifest. Pass with:
  /// --dart-define=SONG_MANIFEST_URL=https://host.example/manifest.json
  static const String songManifestUrl = String.fromEnvironment(
    'SONG_MANIFEST_URL',
  );

  static const bool hasSongManifestUrl = songManifestUrl != '';

  static bool isBundledSongNumber(int songNumber) =>
      bundledSongNumbers.contains(songNumber);

  // ── Lyrics sync engine ────────────────────────────────────────────────
  /// How often the sync ticker fires (16 ms ≈ 60 fps).
  static const int syncTickMs = 16;

  /// Maximum allowable gap between consecutive words before we warn.
  static const int maxWordGapMs = 300;

  /// Seek debounce — wait this long after a seek before resuming sync.
  static const int seekDebounceMs = 150;

  // ── UI ────────────────────────────────────────────────────────────────
  /// Number of lyric lines visible on screen at once (personal mode).
  static const int visibleLyricsLines = 6;

  /// Number of lyric lines visible in congregation/projection mode.
  static const int visibleLyricsLinesProjection = 3;

  /// Position of the active lyric line from the top of the visible area (0–1).
  static const double activeLyricLinePosition = 0.30;

  /// Duration of the auto-scroll animation.
  static const Duration autoScrollDuration = Duration(milliseconds: 350);

  /// Easing curve for auto-scroll.
  // ignore: constant_identifier_names
  static const String autoScrollCurve = 'easeOut';

  // ── Assets ────────────────────────────────────────────────────────────
  static const String audioAssetPath = 'assets/audio';
  static const String lyricsAssetPath = 'assets/lyrics';

  /// Naming convention: assets/audio/001.mp3, assets/lyrics/001.elrc
  static String audioFileName(int songNumber) =>
      '$audioAssetPath/${songNumber.toString().padLeft(3, '0')}.mp3';

  static String lyricsFileName(int songNumber) =>
      '$lyricsAssetPath/${songNumber.toString().padLeft(3, '0')}.elrc';

  // ── Database ──────────────────────────────────────────────────────────
  static const String dbFileName = 'jwsongbook.db';
  static const int dbCurrentVersion = 1;

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
