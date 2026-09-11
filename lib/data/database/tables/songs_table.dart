import 'package:drift/drift.dart';

/// One row per Kingdom Song. The catalog can grow without a schema change.
///
/// Media is downloaded from the remote content catalog. This table tracks
/// whether a song's audio is available locally for offline playback.
class Songs extends Table {
  /// Internal auto-increment PK. Use [number] for domain identity.
  IntColumn get id => integer().autoIncrement()();

  /// Official positive song number. Unique and indexed.
  IntColumn get number => integer().unique()();

  /// Official song title (e.g. "Jehovah Is Your Name").
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Total audio duration in milliseconds. Nullable until audio is analysed.
  IntColumn get durationMs => integer().nullable()();

  /// Absolute path to the cached audio file on the device filesystem.
  /// Null means the audio has not been downloaded on this device.
  TextColumn get audioFilePath => text().nullable()();

  /// True once the audio file has been written to local storage.
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();

  /// Whether the user has hearted this song.
  BoolColumn get isFavorited => boolean().withDefault(const Constant(false))();

  /// Whether an .elrc file exists for this song (drives UI "synced" badge).
  BoolColumn get hasSyncedLyrics =>
      boolean().withDefault(const Constant(false))();

  /// ISO-8601 timestamp of the last time the user played this song.
  TextColumn get lastPlayedAt => text().nullable()();

  @override
  List<String> get customConstraints => const [
        'CONSTRAINT songs_number_positive CHECK (number > 0)',
      ];
}
