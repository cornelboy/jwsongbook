import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_manifest_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';

void main() {
  late AppDatabase database;
  late SongsRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SongsRepository(database.songsDao);
  });

  tearDown(() => database.close());

  // ── Seed & catalog helpers ────────────────────────────────────────────────

  Future<void> insertSong(int number, {String? title}) async {
    await database.songsDao.upsert(
      SongsCompanion.insert(
        number: number,
        title: title ?? 'Song $number',
      ),
    );
  }

  // ── Seed data tests ───────────────────────────────────────────────────────

  group('syncBundledCatalog', () {
    test('inserts all 163 seed songs on first call', () async {
      await repository.syncBundledCatalog();

      final count = await repository.watchCount().first;
      expect(count, 163);
    });

    test('is idempotent — calling twice does not duplicate rows', () async {
      await repository.syncBundledCatalog();
      await repository.syncBundledCatalog();

      final count = await repository.watchCount().first;
      expect(count, 163);
    });

    test('preserves user-owned state on existing rows', () async {
      // Pre-populate song 1 with user data before catalog sync.
      await insertSong(1, title: 'Old Title');
      await database.songsDao.toggleFavorite(1);
      await database.songsDao.markDownloaded(
        1,
        audioFilePath: '/data/001.mp3',
      );

      await repository.syncBundledCatalog();

      final song = await repository.getByNumber(1);
      expect(song?.title, "Jehovah's Attributes");
      expect(song?.isFavorited, isTrue);
      expect(song?.isDownloaded, isTrue);
      expect(song?.audioFilePath, '/data/001.mp3');
    });

    test('removes stray double-quote characters from titles', () async {
      // Insert a song with a title containing a double quote.
      await database.songsDao.upsert(
        SongsCompanion.insert(number: 200, title: 'Title with "quotes"'),
      );
      await repository.syncBundledCatalog();

      final song = await database.songsDao.getByNumber(200);
      expect(song?.title, 'Title with quotes');
    });
  });

  // ── Query / stream tests ──────────────────────────────────────────────────

  group('watchAll', () {
    test('returns songs ordered by number', () async {
      await insertSong(3, title: 'Third');
      await insertSong(1, title: 'First');
      await insertSong(2, title: 'Second');

      final songs = await repository.watchAll().first;
      expect(songs.map((s) => s.number), [1, 2, 3]);
    });
  });

  group('watchSearch', () {
    setUp(() async {
      await insertSong(1, title: 'Jehovah Is Your Name');
      await insertSong(2, title: 'Our Strength');
      await insertSong(3, title: 'God Is Love');
    });

    test('finds by title substring (case-insensitive)', () async {
      final results = await repository.watchSearch('jehovah').first;
      expect(results, hasLength(1));
      expect(results.first.number, 1);
    });

    test('finds by song number', () async {
      final results = await repository.watchSearch('2').first;
      expect(results, hasLength(1));
      expect(results.first.number, 2);
    });

    test('empty query returns all songs', () async {
      final results = await repository.watchSearch('').first;
      expect(results, hasLength(3));
    });

    test('whitespace-only query returns all songs', () async {
      final results = await repository.watchSearch('   ').first;
      expect(results, hasLength(3));
    });

    test('no matches returns empty list', () async {
      final results = await repository.watchSearch('xyz').first;
      expect(results, isEmpty);
    });
  });

  group('watchFavorites', () {
    test('returns only favorited songs', () async {
      await insertSong(1);
      await insertSong(2);
      await insertSong(3);

      await database.songsDao.toggleFavorite(1);
      await database.songsDao.toggleFavorite(3);

      final favorites = await repository.watchFavorites().first;
      expect(favorites.map((s) => s.number), [1, 3]);
    });

    test('returns empty when no favorites', () async {
      await insertSong(1);
      final favorites = await repository.watchFavorites().first;
      expect(favorites, isEmpty);
    });
  });

  group('watchRecentlyPlayed', () {
    test('returns songs ordered by lastPlayedAt descending', () async {
      await insertSong(1);
      await insertSong(2);
      await insertSong(3);

      await database.songsDao.markPlayed(1);
      await Future.delayed(const Duration(milliseconds: 10));
      await database.songsDao.markPlayed(2);

      final recent = await repository.watchRecentlyPlayed().first;
      expect(recent.first.number, 2);
      expect(recent.last.number, 1);
    });
  });

  group('watchDownloaded', () {
    test('returns only downloaded songs', () async {
      await insertSong(1);
      await insertSong(2);
      await database.songsDao.markDownloaded(1, audioFilePath: '/a.mp3');

      final downloaded = await repository.watchDownloaded().first;
      expect(downloaded, hasLength(1));
      expect(downloaded.first.number, 1);
    });
  });

  group('watchCount', () {
    test('streams the current song count', () async {
      expect(await repository.watchCount().first, 0);
      await insertSong(1);
      expect(await repository.watchCount().first, 1);
      await insertSong(2);
      expect(await repository.watchCount().first, 2);
    });
  });

  group('getAllSongs', () {
    test('returns all songs as a future list', () async {
      await insertSong(2);
      await insertSong(1);
      final all = await repository.getAllSongs();
      expect(all.map((s) => s.number), [1, 2]);
    });
  });

  group('getByNumber', () {
    test('returns the song when it exists', () async {
      await insertSong(5, title: 'My Song');
      final song = await repository.getByNumber(5);
      expect(song?.title, 'My Song');
      expect(song?.number, 5);
    });

    test('returns null when song does not exist', () async {
      final song = await repository.getByNumber(999);
      expect(song, isNull);
    });
  });

  group('watchByNumber', () {
    test('streams the song and updates on changes', () async {
      await insertSong(1, title: 'Original');
      final stream = repository.watchByNumber(1);

      final first = await stream.first;
      expect(first?.title, 'Original');

      // Update the title directly in DB.
      await (database.update(database.songs)
            ..where((s) => s.number.equals(1)))
          .write(const SongsCompanion(title: Value('Updated')));

      final updated = await stream.first;
      expect(updated?.title, 'Updated');
    });
  });

  // ── Mutation tests ────────────────────────────────────────────────────────

  group('toggleFavorite', () {
    test('toggles favorite from false to true', () async {
      await insertSong(1);
      await repository.toggleFavorite(
        (await repository.getByNumber(1))!,
      );
      final song = await repository.getByNumber(1);
      expect(song?.isFavorited, isTrue);
    });

    test('toggles favorite from true to false', () async {
      await insertSong(1);
      await repository.toggleFavorite(
        (await repository.getByNumber(1))!,
      );
      await repository.toggleFavorite(
        (await repository.getByNumber(1))!,
      );
      final song = await repository.getByNumber(1);
      expect(song?.isFavorited, isFalse);
    });
  });

  group('setFavorite', () {
    test('sets favorite to true', () async {
      await insertSong(1);
      await repository.setFavorite(
        (await repository.getByNumber(1))!,
        value: true,
      );
      expect((await repository.getByNumber(1))?.isFavorited, isTrue);
    });

    test('sets favorite to false', () async {
      await insertSong(1);
      await repository.setFavorite(
        (await repository.getByNumber(1))!,
        value: true,
      );
      await repository.setFavorite(
        (await repository.getByNumber(1))!,
        value: false,
      );
      expect((await repository.getByNumber(1))?.isFavorited, isFalse);
    });
  });

  group('markPlayed', () {
    test('sets lastPlayedAt timestamp', () async {
      await insertSong(1);
      final before = DateTime.now().toIso8601String();
      await repository.markPlayed(
        (await repository.getByNumber(1))!,
      );
      final song = await repository.getByNumber(1);
      expect(song?.lastPlayedAt, isNotNull);
      expect(
        DateTime.parse(song!.lastPlayedAt!).isAfter(
          DateTime.parse(before).subtract(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });
  });

  group('markDownloaded', () {
    test('sets isDownloaded and audioFilePath', () async {
      await insertSong(1);
      await repository.markDownloaded(
        (await repository.getByNumber(1))!,
        audioFilePath: '/data/001.mp3',
      );
      final song = await repository.getByNumber(1);
      expect(song?.isDownloaded, isTrue);
      expect(song?.audioFilePath, '/data/001.mp3');
    });
  });

  group('markDownloadRemoved', () {
    test('clears isDownloaded and audioFilePath', () async {
      await insertSong(1);
      await repository.markDownloaded(
        (await repository.getByNumber(1))!,
        audioFilePath: '/data/001.mp3',
      );
      await repository.markDownloadRemoved(
        (await repository.getByNumber(1))!,
      );
      final song = await repository.getByNumber(1);
      expect(song?.isDownloaded, isFalse);
      expect(song?.audioFilePath, isNull);
    });
  });

  // ── Remote catalog sync ──────────────────────────────────────────────────

  group('syncRemoteCatalog', () {
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

    test('empty manifest with no catalog entries is a no-op', () async {
      final manifest = SongManifest.fromJsonString(
        '{"songs":[{"number":1,"audioUrl":"a.mp3"}]}',
        baseUri: Uri.parse('https://example.com/m.json'),
      );
      await repository.syncRemoteCatalog(manifest);
      expect(await repository.watchCount().first, 0);
    });
  });

  // ── Schema migration ────────────────────────────────────────────────────

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
