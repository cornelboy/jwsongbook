import 'package:drift/drift.dart';

/// One row per Kingdom Song (1–162).
///
/// Audio and lyrics files are bundled as app assets and referenced by
/// [AppConstants.audioFileName] / [AppConstants.lyricsFileName]. This table
/// tracks whether a song's audio has been cached to the filesystem for
/// offline playback (relevant if we later move to a download model).
class Songs extends Table {
  /// Internal auto-increment PK. Use [number] for domain identity.
  IntColumn get id => integer().autoIncrement()();

  /// Official song number, 1–162. Unique and indexed.
  IntColumn get number => integer().unique()();

  /// Official song title (e.g. "Jehovah Is Your Name").
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Total audio duration in milliseconds. Nullable until audio is analysed.
  IntColumn get durationMs => integer().nullable()();

  /// Absolute path to the cached audio file on the device filesystem.
  /// Null = not yet cached; app falls back to the bundled asset.
  TextColumn get audioFilePath => text().nullable()();

  /// True once the audio file has been written to local storage.
  BoolColumn get isDownloaded =>
      boolean().withDefault(const Constant(false))();

  /// Whether the user has hearted this song.
  BoolColumn get isFavorited =>
      boolean().withDefault(const Constant(false))();

  /// Whether an .elrc file exists for this song (drives UI "synced" badge).
  BoolColumn get hasSyncedLyrics =>
      boolean().withDefault(const Constant(false))();

  /// ISO-8601 timestamp of the last time the user played this song.
  TextColumn get lastPlayedAt => text().nullable()();

  @override
  List<String> get customConstraints => const [
        // ⚠️  Keep the upper bound in sync with AppConstants.totalSongs (162).
        // SQLite DDL cannot reference Dart constants, so this is intentionally
        // duplicated. If the song count ever changes, update both places.
        'CONSTRAINT songs_number_positive CHECK (number BETWEEN 1 AND 162)',
      ];
}
