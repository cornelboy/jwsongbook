import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/data/repositories/lyrics_repository.dart';

void main() {
  late AppDatabase database;
  late LyricsRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LyricsRepository(database.lyricsDao, database);
  });

  tearDown(() => database.close());

  Future<Song> insertTestSong(int number, {String title = 'Test Song'}) async {
    await database.songsDao.upsert(
      SongsCompanion.insert(number: number, title: title),
    );
    return (await database.songsDao.getByNumber(number))!;
  }

  group('loadForSong', () {
    test('returns empty lyrics when no data exists', () async {
      final song = await insertTestSong(1);
      final lyrics = await repository.loadForSong(song);
      expect(lyrics.isEmpty, isTrue);
      expect(lyrics.lines, isEmpty);
    });

    test('loads lyrics previously imported into the database', () async {
      final song = await insertTestSong(1);

      // Manually insert lyrics lines and words via the DAO.
      await database.lyricsDao.insertSongLyrics(
        songId: song.id,
        lines: [
          LyricsLinesCompanion.insert(
            songId: song.id,
            lineIndex: 0,
            startMs: 0,
            endMs: 1000,
            lineText: 'Hello world',
          ),
          LyricsLinesCompanion.insert(
            songId: song.id,
            lineIndex: 1,
            startMs: 1200,
            endMs: 2500,
            lineText: 'Second line',
          ),
        ],
        wordsByLineIndex: {
          0: [
            LyricsWordsCompanion.insert(
              lineId: 0,
              wordIndex: 0,
              startMs: 0,
              endMs: 500,
              wordText: 'Hello',
            ),
            LyricsWordsCompanion.insert(
              lineId: 0,
              wordIndex: 1,
              startMs: 500,
              endMs: 1000,
              wordText: 'world',
            ),
          ],
          1: [
            LyricsWordsCompanion.insert(
              lineId: 0,
              wordIndex: 0,
              startMs: 1200,
              endMs: 2500,
              wordText: 'Second',
            ),
          ],
        },
      );

      final lyrics = await repository.loadForSong(song);
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].text, 'Hello world');
      expect(lyrics.lines[0].words, hasLength(2));
      expect(lyrics.lines[0].words[0].text, 'Hello');
      expect(lyrics.lines[0].words[1].text, 'world');
      expect(lyrics.lines[1].text, 'Second line');
      expect(lyrics.lines[1].words, hasLength(1));
    });
  });

  group('importElrcForSong', () {
    test('parses and persists ELRC content, marks song as having synced lyrics',
        () async {
      final song = await insertTestSong(1);

      const elrcContent = '''
[ti:Test Song]
[00:00.50]<00:00.50>Hello <00:01.00>world
[00:02.00]<00:02.00>Second <00:02.50>line
''';

      final lyrics = await repository.importElrcForSong(song, elrcContent);

      // Verify the parsed lyrics are returned.
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].text, 'Hello world');
      expect(lyrics.lines[0].words, hasLength(2));
      expect(lyrics.lines[0].words[0].text, 'Hello');
      expect(lyrics.lines[0].words[0].startMs, 500);
      expect(lyrics.lines[0].words[1].text, 'world');
      expect(lyrics.lines[0].words[1].startMs, 1000);

      expect(lyrics.lines[1].text, 'Second line');
      expect(lyrics.lines[1].words, hasLength(2));

      // Verify the database marks the song as having synced lyrics.
      final updatedSong = await database.songsDao.getByNumber(1);
      expect(updatedSong?.hasSyncedLyrics, isTrue);
    });

    test('loadForSong returns the imported lyrics', () async {
      final song = await insertTestSong(1);

      const elrcContent = '''
[00:01.00]<00:01.00>Praise <00:01.50>Jehovah
''';

      await repository.importElrcForSong(song, elrcContent);
      final loaded = await repository.loadForSong(song);

      expect(loaded.lines, hasLength(1));
      expect(loaded.lines[0].text, 'Praise Jehovah');
      expect(loaded.lines[0].words, hasLength(2));
    });

    test('import replaces any existing lyrics for the song', () async {
      final song = await insertTestSong(1);

      // First import.
      const firstElrc = '''
[00:01.00]<00:01.00>First <00:01.50>import
''';
      await repository.importElrcForSong(song, firstElrc);

      // Second import should replace.
      const secondElrc = '''
[00:02.00]<00:02.00>Second <00:02.50>import
''';
      await repository.importElrcForSong(song, secondElrc);

      final lyrics = await repository.loadForSong(song);
      expect(lyrics.lines, hasLength(1));
      expect(lyrics.lines[0].text, 'Second import');
      expect(lyrics.lines[0].startMs, 2000);
    });

    test('handles ELRC with section breaks (blank lines)', () async {
      final song = await insertTestSong(1);

      const elrcContent = '''
[00:01.00]<00:01.00>Verse <00:01.50>one

[00:05.00]<00:05.00>Chorus <00:05.50>start
''';

      final lyrics = await repository.importElrcForSong(song, elrcContent);
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].sectionIndex, 0);
      expect(lyrics.lines[1].sectionIndex, 1);
    });

    test('handles empty lyrics gracefully', () async {
      final song = await insertTestSong(1);
      const elrcContent = '[ti:Empty]\n';
      final lyrics = await repository.importElrcForSong(song, elrcContent);
      expect(lyrics.isEmpty, isTrue);
    });
  });

  group('module-level provider', () {
    test('lyricsRepository provider returns a LyricsRepository', () {
      // We can't fully test the provider without Riverpod container setup,
      // but we can verify the provider function exists and has the right type.
      // This is more of a compile-time check.
      expect(lyricsRepository, isA<Function>());
    });
  });
}
