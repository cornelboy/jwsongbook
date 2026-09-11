import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/features/player/providers/playback_queue.dart';

void main() {
  final songs = [
    _song(id: 1, number: 161),
    _song(id: 2, number: 162),
    _song(id: 3, number: 163),
  ];

  test('next includes newly added songs and only wraps when requested', () {
    expect(nextSongInQueue(songs, songs[1], wrap: false)?.number, 163);
    expect(nextSongInQueue(songs, songs[2], wrap: false), isNull);
    expect(nextSongInQueue(songs, songs[2], wrap: true)?.number, 161);
  });

  test('previous includes newly added songs and only wraps when requested', () {
    expect(previousSongInQueue(songs, songs[2], wrap: false)?.number, 162);
    expect(previousSongInQueue(songs, songs[0], wrap: false), isNull);
    expect(previousSongInQueue(songs, songs[0], wrap: true)?.number, 163);
  });
}

Song _song({required int id, required int number}) => Song(
      id: id,
      number: number,
      title: 'Song $number',
      isDownloaded: true,
      isFavorited: false,
      hasSyncedLyrics: false,
    );
