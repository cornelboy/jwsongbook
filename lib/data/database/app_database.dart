import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:jwsongbook/data/database/tables/songs_table.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ── DAOs ────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Songs])
class SongsDao extends DatabaseAccessor<AppDatabase> with _$SongsDaoMixin {
  SongsDao(super.db);

  // ── Queries ──────────────────────────────────────────────────────────────

  /// All songs ordered by number.
  Stream<List<Song>> watchAll() =>
      (select(songs)..orderBy([(s) => OrderingTerm.asc(s.number)])).watch();

  /// Songs whose title or number starts with [query].
  Stream<List<Song>> watchSearch(String query) {
    final normalised = query.trim().toLowerCase();
    if (normalised.isEmpty) return watchAll();

    return (select(songs)
          ..where(
            (s) =>
                s.title.lower().contains(normalised) |
                s.number.cast<String>().contains(normalised),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.number)]))
        .watch();
  }

  /// Favorited songs, ordered by number.
  Stream<List<Song>> watchFavorites() => (select(songs)
        ..where((s) => s.isFavorited.equals(true))
        ..orderBy([(s) => OrderingTerm.asc(s.number)]))
      .watch();

  Stream<List<Song>> watchRecentlyPlayed({int limit = 5}) => (select(songs)
        ..where((s) => s.lastPlayedAt.isNotNull())
        ..orderBy([(s) => OrderingTerm.desc(s.lastPlayedAt)])
        ..limit(limit))
      .watch();

  Future<List<Song>> getAll() =>
      (select(songs)..orderBy([(s) => OrderingTerm.asc(s.number)])).get();

  Future<Song?> getByNumber(int number) =>
      (select(songs)..where((s) => s.number.equals(number))).getSingleOrNull();

  Future<void> upsert(SongsCompanion entry) =>
      into(songs).insertOnConflictUpdate(entry);

  Future<void> upsertAll(List<SongsCompanion> entries) =>
      batch((b) => b.insertAllOnConflictUpdate(songs, entries));

  Future<void> toggleFavorite(int id, {required bool value}) =>
      (update(songs)..where((s) => s.id.equals(id)))
          .write(SongsCompanion(isFavorited: Value(value)));

  Future<void> markPlayed(int id) =>
      (update(songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(
          lastPlayedAt: Value(DateTime.now().toIso8601String()),
        ),
      );

  Future<void> markDownloaded(int id, {required String audioFilePath}) =>
      (update(songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(
          audioFilePath: Value(audioFilePath),
          isDownloaded: const Value(true),
        ),
      );
}

@DriftAccessor(
  include: {'package:jwsongbook/data/database/lyrics_tables.drift'},
)
class LyricsDao extends DatabaseAccessor<AppDatabase> with _$LyricsDaoMixin {
  LyricsDao(super.db);

  /// Fetch all lines for [songId], ordered by [lineIndex].
  /// Returns an empty list if no lyrics exist.
  Future<List<LyricsLine>> getLinesForSong(int songId) => (select(lyricsLines)
        ..where((l) => l.songId.equals(songId))
        ..orderBy([(l) => OrderingTerm.asc(l.lineIndex)]))
      .get();

  /// Fetch all words for [lineId], ordered by [wordIndex].
  Future<List<LyricsWord>> getWordsForLine(int lineId) => (select(lyricsWords)
        ..where((w) => w.lineId.equals(lineId))
        ..orderBy([(w) => OrderingTerm.asc(w.wordIndex)]))
      .get();

  /// Bulk-insert all lines and words for a song. Replaces any existing data.
  Future<void> insertSongLyrics({
    required int songId,
    required List<LyricsLinesCompanion> lines,
    required Map<int, List<LyricsWordsCompanion>> wordsByLineIndex,
  }) async {
    await transaction(() async {
      // Remove old data.
      await (delete(lyricsLines)..where((l) => l.songId.equals(songId))).go();

      for (var i = 0; i < lines.length; i++) {
        final lineId = await into(lyricsLines).insert(lines[i]);
        final words = wordsByLineIndex[i] ?? [];
        if (words.isNotEmpty) {
          await batch(
            (b) => b.insertAll(
              lyricsWords,
              words.map((w) => w.copyWith(lineId: Value(lineId))).toList(),
            ),
          );
        }
      }
    });
  }

  Future<bool> hasSyncedLyrics(int songId) async {
    final count = await (select(lyricsLines)
          ..where((l) => l.songId.equals(songId)))
        .get()
        .then((rows) => rows.length);
    return count > 0;
  }
}

// ── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [Songs],
  include: {'package:jwsongbook/data/database/lyrics_tables.drift'},
  daos: [SongsDao, LyricsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Constructor used in tests — pass an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Future migrations go here.
        },
        beforeOpen: (details) async {
          // Enable WAL mode and foreign key enforcement.
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

// ── Connection helper ─────────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'jwsongbook.db'));
    return NativeDatabase.createInBackground(file);
  });
}
