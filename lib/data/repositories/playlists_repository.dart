import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';

final playlistsRepositoryProvider =
    Provider((ref) => PlaylistsRepository(ref.watch(appDatabaseProvider)));
final playlistsProvider =
    StreamProvider((ref) => ref.watch(playlistsRepositoryProvider).watchAll());
final playlistSongsProvider = StreamProvider.family<List<Song>, int>(
  (ref, id) => ref.watch(playlistsRepositoryProvider).watchSongs(id),
);

class PlaylistsRepository {
  PlaylistsRepository(this.db);
  final AppDatabase db;

  String _name(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 80) {
      throw ArgumentError('Enter a playlist name of 1–80 characters.');
    }
    return name;
  }

  Stream<List<Playlist>> watchAll() =>
      (db.select(db.playlists)..orderBy([(p) => OrderingTerm.desc(p.id)]))
          .watch();

  Future<int> create(String name) => db
      .into(db.playlists)
      .insert(PlaylistsCompanion.insert(name: _name(name)));

  Future<void> rename(int id, String name) async {
    await (db.update(db.playlists)..where((p) => p.id.equals(id)))
        .write(PlaylistsCompanion(name: Value(_name(name))));
  }

  Future<void> delete(int id) async {
    await (db.delete(db.playlists)..where((p) => p.id.equals(id))).go();
  }

  JoinedSelectStatement<HasResultSet, dynamic> _songsQuery(int id) =>
      db.select(db.playlistEntries).join([
        innerJoin(db.songs, db.songs.id.equalsExp(db.playlistEntries.songId)),
      ])
        ..where(db.playlistEntries.playlistId.equals(id))
        ..orderBy([OrderingTerm.asc(db.playlistEntries.position)]);

  Stream<List<Song>> watchSongs(int id) => _songsQuery(id)
      .watch()
      .map((rows) => rows.map((r) => r.readTable(db.songs)).toList());

  Future<List<Song>> getSongs(int id) async =>
      (await _songsQuery(id).get()).map((r) => r.readTable(db.songs)).toList();

  Future<void> add(int id, int songId) => db.transaction(() async {
        final entries = await (db.select(db.playlistEntries)
              ..where((e) => e.playlistId.equals(id)))
            .get();
        if (entries.any((e) => e.songId == songId)) return;
        final next = entries.fold<int>(
          0,
          (value, e) => e.position >= value ? e.position + 1 : value,
        );
        await db.into(db.playlistEntries).insert(
              PlaylistEntriesCompanion.insert(
                playlistId: id,
                songId: songId,
                position: next,
              ),
            );
      });

  Future<void> remove(int id, int songId) async {
    await (db.delete(db.playlistEntries)
          ..where((e) => e.playlistId.equals(id) & e.songId.equals(songId)))
        .go();
  }

  Future<void> reorder(int id, List<int> songIds) => db.transaction(() async {
        final existing = await getSongs(id);
        final actual = existing.map((s) => s.id).toSet();
        if (songIds.length != actual.length ||
            songIds.toSet().length != actual.length ||
            !actual.containsAll(songIds)) {
          throw StateError('Playlist changed. Please try again.');
        }
        for (var i = 0; i < songIds.length; i++) {
          await (db.update(db.playlistEntries)
                ..where(
                  (e) => e.playlistId.equals(id) & e.songId.equals(songIds[i]),
                ))
              .write(PlaylistEntriesCompanion(position: Value(i)));
        }
      });
}
