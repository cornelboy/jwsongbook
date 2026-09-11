import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_manifest_model.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';

final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadState>(
  DownloadController.new,
);

class DownloadController extends Notifier<DownloadState> {
  static const int _maxParallelDownloads = 3;

  Future<SongManifest>? _manifestFuture;
  final Map<int, DownloadCancelToken> _downloadTokens =
      <int, DownloadCancelToken>{};
  bool _batchPauseRequested = false;

  @override
  DownloadState build() => const DownloadState();

  Future<void> downloadSong(Song song) async {
    if (song.hasLocalAudio || state.statusFor(song.number).isDownloading) {
      return;
    }

    if (!AppConstants.hasSongManifestUrl) {
      _setSongError(song.number, 'Downloads will be available soon.');
      return;
    }

    final service = ref.read(songDownloadServiceProvider);
    final token = DownloadCancelToken();
    _downloadTokens[song.number] = token;
    final existingProgress = state.statusFor(song.number).progress;
    state = state.withSong(
      song.number,
      SongDownloadStatus.downloading(progress: existingProgress),
    );

    try {
      final manifest = await _fetchManifest(service);
      token.throwIfCancelled();
      final asset = manifest.assetFor(song.number);
      if (asset == null || !asset.hasAudio) {
        throw StateError(
          'Song ${song.paddedNumber} audio is not available for download yet.',
        );
      }

      await _downloadSongWithAsset(
        service: service,
        song: song,
        asset: asset,
        cancelToken: token,
      );
    } on DownloadPausedException {
      state = state.withSong(
        song.number,
        SongDownloadStatus.paused(state.statusFor(song.number).progress),
      );
    } catch (e) {
      _setSongError(song.number, _downloadErrorMessage(e));
    } finally {
      if (identical(_downloadTokens[song.number], token)) {
        _downloadTokens.remove(song.number);
      }
    }
  }

  /// Downloads only the missing songs in a caller-provided collection.
  ///
  /// Playlist downloads share the same per-song status and manifest cache as
  /// individual downloads, while keeping network work to a small parallel set.
  Future<void> downloadSongs(Iterable<Song> songs) async {
    final pending = songs
        .where(
          (song) =>
              !song.hasLocalAudio &&
              !state.statusFor(song.number).isDownloaded &&
              !state.statusFor(song.number).isDownloading,
        )
        .toList();
    if (pending.isEmpty) return;

    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < pending.length) {
        final song = pending[nextIndex++];
        await downloadSong(song);
      }
    }

    final workerCount = math.min(_maxParallelDownloads, pending.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  Future<void> downloadAllSongs() async {
    if (!AppConstants.hasSongManifestUrl) {
      state = state.copyWith(
        globalMessage: 'Downloads will be available soon.',
      );
      return;
    }

    if (state.isBatchDownloading) return;
    final isResumingBatch = state.batchPaused && state.batchTotal > 0;
    _batchPauseRequested = false;

    final service = ref.read(songDownloadServiceProvider);
    try {
      final manifest = await _fetchManifest(service);
      final songs = await ref.read(songsRepositoryProvider).getAllSongs();
      final availableSongNumbers = manifest.songs
          .where((asset) => asset.hasAudio)
          .map(
            (asset) => asset.number,
          )
          .toSet();
      final pendingSongs = songs
          .where(
            (song) =>
                availableSongNumbers.contains(song.number) &&
                !song.hasLocalAudio &&
                !state.statusFor(song.number).isDownloading,
          )
          .toList();

      if (pendingSongs.isEmpty) {
        state = state.copyWith(
          globalMessage: 'All available songs are already downloaded.',
        );
        return;
      }

      state = isResumingBatch
          ? state.copyWith(
              clearGlobalMessage: true,
              batchPaused: false,
            )
          : state.copyWith(
              clearGlobalMessage: true,
              batchPaused: false,
              batchTotal: pendingSongs.length,
              batchCompleted: 0,
              batchFailed: 0,
            );

      var nextIndex = 0;
      Future<void> worker() async {
        while (true) {
          if (_batchPauseRequested) return;

          final index = nextIndex++;
          if (index >= pendingSongs.length) return;

          final song = pendingSongs[index];
          final asset = manifest.assetFor(song.number);
          if (asset == null || !asset.hasAudio) {
            _setSongError(
              song.number,
              'Song ${song.paddedNumber} audio is not available yet.',
            );
            _incrementBatch(failed: true);
            continue;
          }

          state = state.withSong(
            song.number,
            SongDownloadStatus.downloading(
              progress: state.statusFor(song.number).progress,
            ),
          );

          final token = DownloadCancelToken();
          _downloadTokens[song.number] = token;

          try {
            await _downloadSongWithAsset(
              service: service,
              song: song,
              asset: asset,
              cancelToken: token,
            );
            _incrementBatch(failed: false);
          } on DownloadPausedException {
            state = state.withSong(
              song.number,
              SongDownloadStatus.paused(state.statusFor(song.number).progress),
            );
            if (_batchPauseRequested) return;
            continue;
          } catch (e) {
            _setSongError(song.number, _downloadErrorMessage(e));
            _incrementBatch(failed: true);
          } finally {
            if (identical(_downloadTokens[song.number], token)) {
              _downloadTokens.remove(song.number);
            }
          }
        }
      }

      final workerCount = math.min(
        _maxParallelDownloads,
        pendingSongs.length,
      );
      await Future.wait(List.generate(workerCount, (_) => worker()));

      if (_batchPauseRequested || state.hasPausedDownloads) {
        state = state.copyWith(
          batchPaused: true,
          globalMessage: 'Downloads paused.',
        );
        return;
      }

      final failed = state.batchFailed;
      final completed = state.batchCompleted;
      state = state.copyWith(
        globalMessage: failed == 0
            ? 'Downloaded $completed songs.'
            : 'Downloaded $completed songs. $failed failed.',
      );
    } catch (e) {
      state = state.copyWith(globalMessage: _downloadErrorMessage(e));
    }
  }

  void pauseAllDownloads() {
    _batchPauseRequested = true;
    for (final token in _downloadTokens.values) {
      token.cancel();
    }

    final pausedSongs = <int, SongDownloadStatus>{};
    for (final entry in state.songs.entries) {
      final status = entry.value;
      pausedSongs[entry.key] = status.isDownloading
          ? SongDownloadStatus.paused(status.progress)
          : status;
    }

    state = state.copyWith(
      songs: pausedSongs,
      batchPaused: true,
      globalMessage: 'Downloads paused.',
    );
  }

  void pauseSong(int songNumber) {
    final status = state.statusFor(songNumber);
    final token = _downloadTokens[songNumber];
    if (!status.isDownloading || token == null) return;

    state = state.withSong(
      songNumber,
      SongDownloadStatus.paused(status.progress),
    );
    token.cancel();
  }

  void clearGlobalMessage() {
    state = state.copyWith(clearGlobalMessage: true);
  }

  void clearSongStatuses(Iterable<int> songNumbers) {
    final updatedSongs = {...state.songs};
    for (final songNumber in songNumbers) {
      updatedSongs.remove(songNumber);
    }
    state = state.copyWith(songs: updatedSongs);
  }

  Future<SongManifest> _fetchManifest(SongDownloadService service) {
    final cached = _manifestFuture;
    if (cached != null) return cached;

    late final Future<SongManifest> future;
    future = service
        .fetchAndSyncManifest(Uri.parse(AppConstants.songManifestUrl))
        .catchError((Object error, StackTrace stackTrace) {
      if (identical(_manifestFuture, future)) {
        _manifestFuture = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _manifestFuture = future;
    return _manifestFuture!;
  }

  Future<void> _downloadSongWithAsset({
    required SongDownloadService service,
    required Song song,
    required RemoteSongAsset asset,
    DownloadCancelToken? cancelToken,
  }) async {
    await service.downloadSong(
      song: song,
      asset: asset,
      cancelToken: cancelToken,
      onAudioProgress: (progress) {
        state = state.withSong(
          song.number,
          SongDownloadStatus.downloading(progress: progress.fraction),
        );
      },
    );

    state = state.withSong(song.number, const SongDownloadStatus.downloaded());
  }

  void _incrementBatch({required bool failed}) {
    state = state.copyWith(
      batchCompleted: state.batchCompleted + (failed ? 0 : 1),
      batchFailed: state.batchFailed + (failed ? 1 : 0),
    );
  }

  void _setSongError(int songNumber, String message) {
    state = state.withSong(songNumber, SongDownloadStatus.error(message));
  }

  String _downloadErrorMessage(Object error) {
    if (error is TimeoutException || error is IOException) {
      return 'Download failed. Check your connection.';
    }
    if (error is FormatException) {
      return 'The download manifest is invalid.';
    }
    if (error is StateError) {
      return error.message.toString();
    }
    return error.toString();
  }
}

class DownloadState {
  const DownloadState({
    this.songs = const {},
    this.globalMessage,
    this.batchTotal = 0,
    this.batchCompleted = 0,
    this.batchFailed = 0,
    this.batchPaused = false,
  });

  final Map<int, SongDownloadStatus> songs;
  final String? globalMessage;
  final int batchTotal;
  final int batchCompleted;
  final int batchFailed;
  final bool batchPaused;

  bool get isBatchDownloading =>
      !batchPaused &&
      batchTotal > 0 &&
      batchCompleted + batchFailed < batchTotal;

  bool get hasPausedDownloads => songs.values.any((status) => status.isPaused);

  String? get batchProgressLabel {
    if (batchTotal <= 0) return null;
    final failureText = batchFailed > 0 ? ', $batchFailed failed' : '';
    return '$batchCompleted of $batchTotal downloaded$failureText';
  }

  String? get batchRemainingLabel {
    if (batchTotal <= 0) return null;
    final processed = batchCompleted + batchFailed;
    final remaining = (batchTotal - processed).clamp(0, batchTotal);
    if (remaining == 0) return 'All selected songs processed';
    final label = remaining == 1 ? 'song' : 'songs';
    return '$remaining $label remaining';
  }

  SongDownloadStatus statusFor(int songNumber) =>
      songs[songNumber] ?? const SongDownloadStatus.idle();

  DownloadState withSong(int songNumber, SongDownloadStatus status) {
    return DownloadState(
      songs: {...songs, songNumber: status},
      globalMessage: globalMessage,
      batchTotal: batchTotal,
      batchCompleted: batchCompleted,
      batchFailed: batchFailed,
      batchPaused: batchPaused,
    );
  }

  DownloadState copyWith({
    Map<int, SongDownloadStatus>? songs,
    String? globalMessage,
    bool clearGlobalMessage = false,
    int? batchTotal,
    int? batchCompleted,
    int? batchFailed,
    bool? batchPaused,
  }) =>
      DownloadState(
        songs: songs ?? this.songs,
        globalMessage:
            clearGlobalMessage ? null : globalMessage ?? this.globalMessage,
        batchTotal: batchTotal ?? this.batchTotal,
        batchCompleted: batchCompleted ?? this.batchCompleted,
        batchFailed: batchFailed ?? this.batchFailed,
        batchPaused: batchPaused ?? this.batchPaused,
      );
}

enum DownloadStatusKind { idle, downloading, paused, downloaded, error }

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

  const SongDownloadStatus.paused(double? progress)
      : this._(
          kind: DownloadStatusKind.paused,
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
  bool get isPaused => kind == DownloadStatusKind.paused;
  bool get isDownloaded => kind == DownloadStatusKind.downloaded;
  bool get hasError => kind == DownloadStatusKind.error;
  bool get isIdle => kind == DownloadStatusKind.idle;
}
