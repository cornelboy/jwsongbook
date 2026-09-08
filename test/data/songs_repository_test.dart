import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_manifest_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';

void main() {
  group('dynamic song catalog', () {
    late AppDatabase database;
    late SongsRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = SongsRepository(database.songsDao);
    });

    tearDown(() => database.close());

    test('remote additions preserve all user-owned state', () async {
      await database.songsDao.upsert(
        SongsCompanion.insert(
          number: 162,
          title: 'Old metadata',
          durationMs: const Value(1000),
          audioFilePath: const Value('saved/audio/162.mp3'),
          isDownloaded: const Value(true),
          isFavorited: const Value(true),
          hasSyncedLyrics: const Value(true),
          lastPlayedAt: const Value('2026-08-31T23:59:00.000'),
        ),
      );

      final manifest = SongManifest.fromJsonString('''
{
  "songs": [
    {"number": 162, "title": "Updated official title", "durationMs": 2000},
    {"number": 163, "title": "A Newly Added Song"}
  ]
}
''');
      await repository.syncRemoteCatalog(manifest);

      final existing = await repository.getByNumber(162);
      expect(existing?.title, 'Updated official title');
      expect(existing?.durationMs, 2000);
      expect(existing?.audioFilePath, 'saved/audio/162.mp3');
      expect(existing?.isDownloaded, isTrue);
      expect(existing?.isFavorited, isTrue);
      expect(existing?.hasSyncedLyrics, isTrue);
      expect(existing?.lastPlayedAt, '2026-08-31T23:59:00.000');

      final added = await repository.getByNumber(163);
      expect(added?.title, 'A Newly Added Song');
      expect(added?.isDownloaded, isFalse);
      expect(added?.isFavorited, isFalse);
      expect(await repository.watchCount().first, 2);
    });

    test('entries without titles do not create placeholder catalog rows',
        () async {
      final manifest = SongManifest.fromJsonString(
        '''
{
  "songs": [
    {"number": 163, "audioUrl": "audio/163.mp3"}
  ]
}
''',
        baseUri: Uri.parse('https://example.com/manifest.json'),
      );

      await repository.syncRemoteCatalog(manifest);

      expect(await repository.getByNumber(163), isNull);
    });

    test('new songs participate in title and number search', () async {
      await repository.syncRemoteCatalog(
        SongManifest.fromJsonString(
          '{"songs":[{"number":163,"title":"A Newly Added Song"}]}',
        ),
      );

      expect(
        (await repository.watchSearch('newly').first).single.number,
        163,
      );
      expect(
        (await repository.watchSearch('163').first).single.title,
        'A Newly Added Song',
      );
    });
  });

  test('schema migration removes the historical 162-song ceiling', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        sqlite.execute('''
CREATE TABLE songs (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  number INTEGER NOT NULL UNIQUE,
  title TEXT NOT NULL,
  duration_ms INTEGER,
  audio_file_path TEXT,
  is_downloaded INTEGER NOT NULL DEFAULT 0 CHECK (is_downloaded IN (0, 1)),
  is_favorited INTEGER NOT NULL DEFAULT 0 CHECK (is_favorited IN (0, 1)),
  has_synced_lyrics INTEGER NOT NULL DEFAULT 0 CHECK (has_synced_lyrics IN (0, 1)),
  last_played_at TEXT,
  CONSTRAINT songs_number_positive CHECK (number BETWEEN 1 AND 162)
)
''');
        sqlite.execute('''
INSERT INTO songs (
  number, title, audio_file_path, is_downloaded, is_favorited, last_played_at
) VALUES (162, 'Existing song', 'saved.mp3', 1, 1, '2026-08-31')
''');
        sqlite.execute('PRAGMA user_version = 2');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    final existing = await database.songsDao.getByNumber(162);
    expect(existing?.isFavorited, isTrue);
    expect(existing?.isDownloaded, isTrue);

    await database.songsDao.mergeCatalogMetadata([
      SongsCompanion.insert(number: 163, title: 'Future song'),
    ]);
    expect((await database.songsDao.getByNumber(163))?.title, 'Future song');
  });


}
