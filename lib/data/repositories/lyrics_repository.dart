import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/data/parsers/elrc_parser.dart';
import 'songs_repository.dart';

part 'lyrics_repository.g.dart';

class LyricsRepository {
  LyricsRepository(this._dao, this._db);

  final LyricsDao _dao;
  final AppDatabase _db;

  /// Load synced lyrics for [song].
  ///
  /// Strategy:
  ///   1. Check DB — if rows exist, build model from DB (fastest).
  ///   2. Otherwise, try to load the bundled .elrc asset, parse it,
  ///      persist to DB, then return the model.
  ///   3. If no .elrc asset exists, return [SyncedLyrics] with empty lines.
  Future<SyncedLyrics> loadForSong(Song song) async {
    // 1. Try DB cache.
    final lines = await _dao.getLinesForSong(song.id);
    if (lines.isNotEmpty) {
      return _buildModelFromDb(lines);
    }

    // 2. Try bundled asset.
    final assetPath = AppConstants.lyricsFileName(song.number);
    try {
      final elrcContent = await rootBundle.loadString(assetPath);
      final parsed = ElrcParser.parse(elrcContent);
      await _persist(song.id, parsed);
      // Mark the song as having synced lyrics.
      await (_db.update(_db.songs)
            ..where((s) => s.id.equals(song.id)))
          .write(const SongsCompanion(hasSyncedLyrics: Value(true)));
      return parsed;
    } catch (_) {
      // Asset not found, or .elrc file is malformed — no lyrics for this song.
      return const SyncedLyrics(lines: []);
    }
  }

  Future<SyncedLyrics> _buildModelFromDb(List<LyricsLine> dbLines) async {
    final syncedLines = <SyncedLine>[];
    for (final line in dbLines) {
      final dbWords = await _dao.getWordsForLine(line.id);
      syncedLines.add(SyncedLine(
        index: line.lineIndex,
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
      ));
    }
    return SyncedLyrics(lines: syncedLines);
  }

  Future<void> _persist(int songId, SyncedLyrics lyrics) async {
    final lineCompanions = lyrics.lines
        .map(
          (l) => LyricsLinesCompanion.insert(
            songId: songId,
            lineIndex: l.index,
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
              lineId: 0, // replaced inside insertSongLyrics
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
