import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/data/parsers/elrc_parser.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lyrics_repository.g.dart';

class LyricsRepository {
  LyricsRepository(this._dao, this._db);

  final LyricsDao _dao;
  final AppDatabase _db;

  /// Loads lyrics previously imported from the remote content catalog.
  Future<SyncedLyrics> loadForSong(Song song) async {
    final lines = await _dao.getLinesForSong(song.id);
    if (lines.isNotEmpty) {
      return _buildModelFromDb(lines);
    }
    return const SyncedLyrics(lines: []);
  }

  Future<SyncedLyrics> importElrcForSong(Song song, String elrcContent) async {
    final parsed = ElrcParser.parse(elrcContent);
    await _persist(song.id, parsed);
    await (_db.update(_db.songs)..where((s) => s.id.equals(song.id)))
        .write(const SongsCompanion(hasSyncedLyrics: Value(true)));
    return parsed;
  }

  Future<SyncedLyrics> _buildModelFromDb(List<LyricsLine> dbLines) async {
    final syncedLines = <SyncedLine>[];
    for (final line in dbLines) {
      final dbWords = await _dao.getWordsForLine(line.id);
      syncedLines.add(
        SyncedLine(
          index: line.lineIndex,
          sectionIndex: line.sectionIndex,
          startMs: line.startMs,
          endMs: line.endMs,
          text: line.lineText,
          words: dbWords
              .map(
                (w) => SyncedWord(
                  index: w.wordIndex,
                  startMs: w.startMs,
                  endMs: w.endMs,
                  text: w.wordText,
                ),
              )
              .toList(),
        ),
      );
    }
    return SyncedLyrics.fromLines(syncedLines);
  }

  Future<void> _persist(int songId, SyncedLyrics lyrics) async {
    final lineCompanions = lyrics.lines
        .map(
          (l) => LyricsLinesCompanion.insert(
            songId: songId,
            lineIndex: l.index,
            sectionIndex: Value(l.sectionIndex),
            startMs: l.startMs,
            endMs: l.endMs,
            lineText: l.text,
          ),
        )
        .toList();

    final wordsByLineIndex = <int, List<LyricsWordsCompanion>>{};
    for (final line in lyrics.lines) {
      wordsByLineIndex[line.index] = line.words
          .map(
            (w) => LyricsWordsCompanion.insert(
              lineId: 0,
              wordIndex: w.index,
              startMs: w.startMs,
              endMs: w.endMs,
              wordText: w.text,
            ),
          )
          .toList();
    }

    await _dao.insertSongLyrics(
      songId: songId,
      lines: lineCompanions,
      wordsByLineIndex: wordsByLineIndex,
    );
  }
}

@riverpod
LyricsRepository lyricsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return LyricsRepository(db.lyricsDao, db);
}
