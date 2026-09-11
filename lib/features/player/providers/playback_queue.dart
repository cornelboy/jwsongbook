import 'package:jwsongbook/data/database/app_database.dart';

Song? nextSongInQueue(
  List<Song> songs,
  Song current, {
  required bool wrap,
}) {
  if (songs.isEmpty) return null;

  final index = songs.indexWhere((song) => song.id == current.id);
  if (index < 0) return null;
  if (index < songs.length - 1) return songs[index + 1];
  return wrap ? songs.first : null;
}

Song? previousSongInQueue(
  List<Song> songs,
  Song current, {
  required bool wrap,
}) {
  if (songs.isEmpty) return null;

  final index = songs.indexWhere((song) => song.id == current.id);
  if (index < 0) return null;
  if (index > 0) return songs[index - 1];
  return wrap ? songs.last : null;
}
