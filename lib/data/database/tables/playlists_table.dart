import 'package:drift/drift.dart';
import 'package:jwsongbook/data/database/tables/songs_table.dart';

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
}

class PlaylistEntries extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId =>
      integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, songId};
}
