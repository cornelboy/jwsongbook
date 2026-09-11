import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/playback_preferences.dart';
import 'package:jwsongbook/data/repositories/playlists_repository.dart';

void main() {
  late AppDatabase db;
  late PlaylistsRepository repo;
  var databaseClosed = false;
  setUp(() async {
    databaseClosed = false;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PlaylistsRepository(db);
    for (var i = 1; i <= 3; i++) {
      await db.songsDao.upsert(
        SongsCompanion.insert(
          number: i,
          title: 'Song $i',
          isFavorited: const Value(true),
          isDownloaded: const Value(true),
          audioFilePath: Value('song$i.mp3'),
        ),
      );
    }
  });
  tearDown(() async {
    if (!databaseClosed) await db.close();
  });

  test('create, rename, validate names and stream changes', () async {
    final id = await repo.create('  Practice  ');
    expect((await repo.watchAll().first).single.name, 'Practice');
    await repo.rename(id, 'Evening');
    expect((await repo.watchAll().first).single.name, 'Evening');
    expect(() => repo.create(' '), throwsArgumentError);
    expect(() => repo.create('x' * 81), throwsArgumentError);
  });

  test('ordered songs, duplicate prevention, reorder and remove', () async {
    final id = await repo.create('Practice');
    await repo.add(id, 3);
    await repo.add(id, 1);
    await repo.add(id, 3);
    expect((await repo.watchSongs(id).first).map((s) => s.id), [3, 1]);
    await repo.reorder(id, [1, 3]);
    expect((await repo.getSongs(id)).map((s) => s.id), [1, 3]);
    await expectLater(repo.reorder(id, [1, 1]), throwsStateError);
    await repo.remove(id, 1);
    await repo.add(id, 2);
    expect((await repo.getSongs(id)).map((s) => s.id), [3, 2]);
  });

  test('deleting a playlist cascades entries, not songs or downloads',
      () async {
    final id = await repo.create('Practice');
    await repo.add(id, 1);
    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
    expect(await db.select(db.playlistEntries).get(), isEmpty);
    final song = await db.songsDao.getByNumber(1);
    expect(song?.isFavorited, true);
    expect(song?.audioFilePath, 'song1.mp3');
    expect(song?.isDownloaded, true);
  });

  test('download removal preserves playlist membership', () async {
    final id = await repo.create('Practice');
    await repo.add(id, 1);
    await db.songsDao.markDownloadRemoved(1);
    final song = (await repo.getSongs(id)).single;
    expect(song.isDownloaded, false);
    expect(song.isFavorited, true);
  });

  test('v4 upgrade preserves content and playlists survive reopen', () async {
    await db.close();
    databaseClosed = true;
    final directory =
        await Directory.systemTemp.createTemp('jw-playlists-test-');
    final file = File('${directory.path}/test.db');
    var persisted = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await persisted.songsDao.upsert(
        SongsCompanion.insert(
          number: 3,
          title: 'Existing song',
          isFavorited: const Value(true),
          isDownloaded: const Value(true),
          audioFilePath: const Value('003.mp3'),
        ),
      );
      await persisted.lyricsDao.insertSongLyrics(
        songId: 1,
        lines: [
          LyricsLinesCompanion.insert(
            songId: 1,
            lineIndex: 0,
            startMs: 0,
            endMs: 1000,
            lineText: 'Existing lyrics',
          ),
        ],
        wordsByLineIndex: {},
      );
      await persisted.customStatement('DROP TABLE playlist_entries');
      await persisted.customStatement('DROP TABLE playlists');
      await persisted.customStatement('PRAGMA user_version = 4');
      await persisted.close();
      persisted = AppDatabase.forTesting(NativeDatabase(file));
      final migrated = PlaylistsRepository(persisted);
      final id = await migrated.create('Saved playlist');
      await migrated.add(id, 1);
      expect((await persisted.songsDao.getByNumber(3))?.isFavorited, true);
      expect(
        (await persisted.songsDao.getByNumber(3))?.audioFilePath,
        '003.mp3',
      );
      expect(await persisted.lyricsDao.getLinesForSong(1), hasLength(1));
      await persisted.close();
      persisted = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await PlaylistsRepository(persisted).getSongs(id)).single.number,
        3,
      );
    } finally {
      await persisted.close();
      await directory.delete(recursive: true);
    }
  });

  test('playlist playback snapshot round-trips and accepts old preferences',
      () {
    const preferences = PlaybackPreferences(playlistSongIds: [3, 1, 2]);
    expect(
      PlaybackPreferences.fromJson(preferences.toJson()).playlistSongIds,
      [3, 1, 2],
    );
    expect(
      PlaybackPreferences.fromJson({'schemaVersion': 1}).playlistSongIds,
      isNull,
    );
  });
}
