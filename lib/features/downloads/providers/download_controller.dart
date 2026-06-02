import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';

final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadState>(
  DownloadController.new,
);

class DownloadController extends Notifier<DownloadState> {
  @override
  DownloadState build() => const DownloadState();

  Future<void> downloadSong(Song song) async {
    if (song.hasLocalAudio || state.statusFor(song.number).isDownloading) {
      return;
    }

    const manifestUrl = AppConstants.songManifestUrl;
    if (manifestUrl == null) {
      _setSongError(song.number, 'Downloads will be available soon.');
      return;
    }

    final service = ref.read(songDownloadServiceProvider);
    state = state.withSong(
      song.number,
      const SongDownloadStatus.downloading(),
    );

    try {
      final manifest = await service.fetchManifest(Uri.parse(manifestUrl));
      final asset = manifest.assetFor(song.number);
      if (asset == null) {
        throw StateError('Song ${song.paddedNumber} is not in the manifest.');
      }

      await service.downloadSong(
        song: song,
        asset: asset,
        onAudioProgress: (progress) {
          state = state.withSong(
            song.number,
            SongDownloadStatus.downloading(progress: progress.fraction),
          );
        },
      );

      state =
          state.withSong(song.number, const SongDownloadStatus.downloaded());
    } catch (e) {
      _setSongError(song.number, e.toString());
    }
  }

  Future<void> downloadAllSongs() async {
    const manifestUrl = AppConstants.songManifestUrl;
    if (manifestUrl == null) {
      state = state.copyWith(
        globalMessage: 'Downloads will be available soon.',
      );
      return;
    }

    final songs = await ref.read(songsRepositoryProvider).getAllSongs();
    for (final song in songs.where((song) => !song.hasLocalAudio)) {
      await downloadSong(song);
    }
  }

  void clearGlobalMessage() {
    state = DownloadState(songs: state.songs);
  }

  void _setSongError(int songNumber, String message) {
    state = state.withSong(songNumber, SongDownloadStatus.error(message));
  }
}

class DownloadState {
  const DownloadState({
    this.songs = const {},
    this.globalMessage,
  });

  final Map<int, SongDownloadStatus> songs;
  final String? globalMessage;

  SongDownloadStatus statusFor(int songNumber) =>
      songs[songNumber] ?? const SongDownloadStatus.idle();

  DownloadState withSong(int songNumber, SongDownloadStatus status) {
    return DownloadState(
      songs: {...songs, songNumber: status},
      globalMessage: globalMessage,
    );
  }

  DownloadState copyWith({
    Map<int, SongDownloadStatus>? songs,
    String? globalMessage,
  }) =>
      DownloadState(
        songs: songs ?? this.songs,
        globalMessage: globalMessage,
      );
}

enum DownloadStatusKind { idle, downloading, downloaded, error }

class SongDownloadStatus {
  const SongDownloadStatus._({
    required this.kind,
    this.progress,
    this.message,
  });

  const SongDownloadStatus.idle() : this._(kind: DownloadStatusKind.idle);

  const SongDownloadStatus.downloading({double? progress})
      : this._(
          kind: DownloadStatusKind.downloading,
          progress: progress,
        );

  const SongDownloadStatus.downloaded()
      : this._(kind: DownloadStatusKind.downloaded);

  const SongDownloadStatus.error(String message)
      : this._(
          kind: DownloadStatusKind.error,
          message: message,
        );

  final DownloadStatusKind kind;
  final double? progress;
  final String? message;

  bool get isDownloading => kind == DownloadStatusKind.downloading;
  bool get isDownloaded => kind == DownloadStatusKind.downloaded;
  bool get hasError => kind == DownloadStatusKind.error;
}
