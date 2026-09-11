import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/playback_preferences.dart';
import 'package:jwsongbook/data/repositories/playback_preferences_repository.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:mocktail/mocktail.dart';

class _Audio extends Mock implements AudioPlayer {}

class _Preferences extends PlaybackPreferencesRepository {
  PlaybackPreferences saved = const PlaybackPreferences();
  @override
  PlaybackPreferences get current => saved;
  @override
  Future<void> save(PlaybackPreferences preferences) async {
    saved = preferences;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => registerFallbackValue(AudioSource.uri(Uri.parse('file:///test.mp3'))),
  );
  test(
      'real notifier honors playlist order, completion, repeat and library reset',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('jw-playback-test-');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final preferences = _Preferences();
    final audio = _Audio();
    final processing = StreamController<ProcessingState>.broadcast(sync: true);
    when(() => audio.playingStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.positionStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.durationStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.processingStateStream)
        .thenAnswer((_) => processing.stream);
    when(() => audio.audioSource).thenReturn(null);
    when(() => audio.play()).thenAnswer((_) async {});
    when(() => audio.stop()).thenAnswer((_) async {});
    when(() => audio.seek(any())).thenAnswer((_) async {});
    when(() => audio.setAudioSource(any())).thenAnswer((_) async {
      processing.add(ProcessingState.ready);
      return const Duration(minutes: 3);
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    // Avoid loading notification artwork; the actual notifier still resolves its path.
    await File('${directory.path}/jw_songs_notification_art.jpeg')
        .writeAsBytes([0]);
    for (var i = 1; i <= 4; i++) {
      final path = '${directory.path}/$i.mp3';
      await File(path).writeAsBytes([0]);
      await db.songsDao.upsert(
        SongsCompanion.insert(
          number: i,
          title: 'Song $i',
          isDownloaded: Value(i != 4),
          audioFilePath: Value(i != 4 ? path : null),
        ),
      );
    }
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioPlayerProvider.overrideWithValue(audio),
        playbackPreferencesRepositoryProvider.overrideWithValue(preferences),
      ],
    );
    try {
      final all = await db.songsDao.getAll();
      final player = container.read(playerNotifierProvider.notifier);
      await player.playPlaylist([all[2], all[3], all[0]]);
      expect(container.read(playerNotifierProvider).error, isNull);
      expect(container.read(playerNotifierProvider).currentSong?.number, 3);
      expect(preferences.saved.playlistSongIds, [3, 1]);
      await player.playNext();
      expect(container.read(playerNotifierProvider).currentSong?.number, 1);
      await player.playNext();
      expect(container.read(playerNotifierProvider).currentSong?.number, 1);
      await player.playPrevious();
      expect(container.read(playerNotifierProvider).currentSong?.number, 3);
      processing.add(ProcessingState.completed);
      for (var i = 0;
          i < 100 &&
              container.read(playerNotifierProvider).currentSong?.number != 1;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(container.read(playerNotifierProvider).currentSong?.number, 1);
      // Wait for async source loading before asking for another transition.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await player.toggleRepeatMode();
      await player.toggleRepeatMode();
      await player.playNext();
      expect(container.read(playerNotifierProvider).currentSong?.number, 3);
      await player.playSong(all[0]);
      expect(preferences.saved.playlistSongIds, isNull);
      await player.playNext();
      expect(container.read(playerNotifierProvider).currentSong?.number, 2);
    } finally {
      container.dispose();
      await processing.close();
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
    }
  });
}
