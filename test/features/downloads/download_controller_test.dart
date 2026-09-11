import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_manifest_model.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSong());
    registerFallbackValue(_FakeRemoteSongAsset());
    registerFallbackValue(_FakeDownloadCancelToken());
    registerFallbackValue(_ignoreProgress);
  });

  test('catalog-only songs report unavailable audio without starting a file',
      () async {
    final service = _MockSongDownloadService();
    final manifest = SongManifest.fromJsonString(
      '{"songs":[{"number":163,"title":"A Newly Added Song"}]}',
    );
    when(
      () => service.fetchAndSyncManifest(
        Uri.parse(AppConstants.songManifestUrl),
      ),
    ).thenAnswer((_) async => manifest);

    final container = ProviderContainer(
      overrides: [
        songDownloadServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(downloadControllerProvider.notifier).downloadSong(
          _song(number: 163),
        );

    final status = container.read(downloadControllerProvider).statusFor(163);
    expect(status.hasError, isTrue);
    expect(status.message, contains('audio is not available'));
  });

  test('playlist download fetches every missing song', () async {
    final service = _MockSongDownloadService();
    final manifest = SongManifest.fromJsonString(
      '{"songs":['
      '{"number":1,"audioUrl":"https://example.com/1.mp3"},'
      '{"number":2,"audioUrl":"https://example.com/2.mp3"}'
      ']}',
    );
    when(
      () => service.fetchAndSyncManifest(
        Uri.parse(AppConstants.songManifestUrl),
      ),
    ).thenAnswer((_) async => manifest);
    when(
      () => service.downloadSong(
        song: any(named: 'song'),
        asset: any(named: 'asset'),
        cancelToken: any(named: 'cancelToken'),
        onAudioProgress: any(named: 'onAudioProgress'),
      ),
    ).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        songDownloadServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(downloadControllerProvider.notifier)
        .downloadSongs([_song(number: 1), _song(number: 2)]);

    verify(
      () => service.downloadSong(
        song: any(named: 'song'),
        asset: any(named: 'asset'),
        cancelToken: any(named: 'cancelToken'),
        onAudioProgress: any(named: 'onAudioProgress'),
      ),
    ).called(2);
    expect(
      container.read(downloadControllerProvider).statusFor(1).isDownloaded,
      isTrue,
    );
    expect(
      container.read(downloadControllerProvider).statusFor(2).isDownloaded,
      isTrue,
    );
  });
}

class _MockSongDownloadService extends Mock implements SongDownloadService {}

class _FakeSong extends Fake implements Song {}

class _FakeRemoteSongAsset extends Fake implements RemoteSongAsset {}

class _FakeDownloadCancelToken extends Fake implements DownloadCancelToken {}

void _ignoreProgress(SongDownloadProgress _) {}

Song _song({required int number}) => Song(
      id: number,
      number: number,
      title: 'Song $number',
      isDownloaded: false,
      isFavorited: false,
      hasSyncedLyrics: false,
    );
