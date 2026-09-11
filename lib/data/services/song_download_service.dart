import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_manifest_model.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/lyrics_repository.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef SongDownloadProgressCallback = void Function(SongDownloadProgress);

final songDownloadServiceProvider = Provider<SongDownloadService>(
  (ref) => SongDownloadService(
    songsRepository: ref.watch(songsRepositoryProvider),
    lyricsRepository: ref.watch(lyricsRepositoryProvider),
  ),
);

class SongDownloadService {
  const SongDownloadService({
    required SongsRepository songsRepository,
    required LyricsRepository lyricsRepository,
  })  : _songsRepository = songsRepository,
        _lyricsRepository = lyricsRepository;

  static const int _maxAttempts = 5;
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(milliseconds: 500);

  final SongsRepository _songsRepository;
  final LyricsRepository _lyricsRepository;

  Future<SongManifest> fetchManifest(Uri manifestUri) async {
    final content = await _readUriAsString(manifestUri);
    return SongManifest.fromJsonString(content, baseUri: manifestUri);
  }

  Future<SongManifest> fetchAndSyncManifest(Uri manifestUri) async {
    final manifest = await fetchManifest(manifestUri);
    await _songsRepository.syncRemoteCatalog(manifest);
    return manifest;
  }

  Future<void> downloadSong({
    required Song song,
    required RemoteSongAsset asset,
    DownloadCancelToken? cancelToken,
    SongDownloadProgressCallback? onAudioProgress,
  }) async {
    if (song.number != asset.number) {
      throw ArgumentError.value(
        asset.number,
        'asset.number',
        'Manifest asset does not match song ${song.number}.',
      );
    }

    final audioUrl = asset.audioUrl;
    if (audioUrl == null) {
      throw StateError(
        'Song ${song.paddedNumber} audio is not available for download yet.',
      );
    }

    final audioFile = await _downloadTarget(
      songNumber: song.number,
      folder: 'audio',
      extension: 'mp3',
    );
    if (!await _fileMatchesExpectedSize(audioFile, asset.audioSizeBytes)) {
      await _downloadToFile(
        uri: audioUrl,
        target: audioFile,
        cancelToken: cancelToken,
        onProgress: onAudioProgress,
      );
    }

    final lyricsUrl = asset.lyricsUrl;
    if (lyricsUrl != null) {
      final lyricsFile = await _downloadTarget(
        songNumber: song.number,
        folder: 'lyrics',
        extension: 'elrc',
      );
      if (!await _fileMatchesExpectedSize(
        lyricsFile,
        asset.lyricsSizeBytes,
      )) {
        await _downloadToFile(
          uri: lyricsUrl,
          target: lyricsFile,
          cancelToken: cancelToken,
        );
      }
      await _lyricsRepository.importElrcForSong(
        song,
        await lyricsFile.readAsString(),
      );
    }

    await _songsRepository.markDownloaded(
      song,
      audioFilePath: audioFile.path,
    );
  }

  Future<bool> downloadMissingLyrics({
    required Song song,
    required Uri manifestUri,
  }) async {
    final manifest = await fetchAndSyncManifest(manifestUri);
    final asset = manifest.assetFor(song.number);
    if (asset == null) {
      throw StateError('Song ${song.paddedNumber} is not in the manifest.');
    }
    return downloadLyrics(song: song, asset: asset);
  }

  Future<bool> downloadLyrics({
    required Song song,
    required RemoteSongAsset asset,
  }) async {
    if (song.number != asset.number) {
      throw ArgumentError.value(
        asset.number,
        'asset.number',
        'Manifest asset does not match song ${song.number}.',
      );
    }

    final lyricsUrl = asset.lyricsUrl;
    if (lyricsUrl == null) return false;

    final lyricsFile = await _downloadTarget(
      songNumber: song.number,
      folder: 'lyrics',
      extension: 'elrc',
    );
    await _downloadToFile(uri: lyricsUrl, target: lyricsFile);
    await _lyricsRepository.importElrcForSong(
      song,
      await lyricsFile.readAsString(),
    );
    return true;
  }

  Future<int> downloadedSizeBytes(Song song) async {
    var total = 0;
    final files = await _downloadFilesForSong(song);
    for (final file in files) {
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  Future<void> removeDownload(Song song) async {
    for (final file in await _downloadFilesForSong(song)) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _songsRepository.markDownloadRemoved(song);
  }

  Future<void> removeAllDownloads(List<Song> songs) async {
    for (final song in songs) {
      await removeDownload(song);
    }
  }

  Future<String> _readUriAsString(Uri uri) async {
    return _withRetries(() => _readUriAsStringOnce(uri));
  }

  Future<String> _readUriAsStringOnce(Uri uri) async {
    final client = _newHttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      request.headers.set(HttpHeaders.userAgentHeader, 'jwsongbook/0.1');
      final response = await request.close();
      _throwIfFailed(uri, response);
      final bytes = await _readResponseBytes(uri, response);
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _downloadTarget({
    required int songNumber,
    required String folder,
    required String extension,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final paddedNumber = songNumber.toString().padLeft(3, '0');
    return File(
      p.join(
        docsDir.path,
        'downloads',
        folder,
        '$paddedNumber.$extension',
      ),
    );
  }

  Future<List<File>> _downloadFilesForSong(Song song) async {
    final audioTarget = await _downloadTarget(
      songNumber: song.number,
      folder: 'audio',
      extension: 'mp3',
    );
    final lyricsTarget = await _downloadTarget(
      songNumber: song.number,
      folder: 'lyrics',
      extension: 'elrc',
    );

    final files = <File>[
      audioTarget,
      File('${audioTarget.path}.part'),
      lyricsTarget,
      File('${lyricsTarget.path}.part'),
    ];

    final audioFilePath = song.audioFilePath;
    if (audioFilePath != null && audioFilePath != audioTarget.path) {
      final audioFile = File(audioFilePath);
      files
        ..add(audioFile)
        ..add(File('${audioFile.path}.part'));
    }

    return files;
  }

  Future<bool> _fileMatchesExpectedSize(File file, int? expectedSize) async {
    if (!await file.exists()) return false;
    if (expectedSize == null) return true;
    return await file.length() == expectedSize;
  }

  Future<void> _downloadToFile({
    required Uri uri,
    required File target,
    DownloadCancelToken? cancelToken,
    SongDownloadProgressCallback? onProgress,
  }) async {
    await _withRetries(
      () => _downloadToFileOnce(
        uri: uri,
        target: target,
        cancelToken: cancelToken,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _downloadToFileOnce({
    required Uri uri,
    required File target,
    DownloadCancelToken? cancelToken,
    SongDownloadProgressCallback? onProgress,
  }) async {
    final client = _newHttpClient();
    final tempFile = File('${target.path}.part');
    var keepPartialFile = false;

    try {
      await target.parent.create(recursive: true);
      cancelToken?.throwIfCancelled();

      final resumeFrom = await tempFile.exists() ? await tempFile.length() : 0;
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      request.headers.set(HttpHeaders.userAgentHeader, 'jwsongbook/0.1');
      if (resumeFrom > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeFrom-');
      }

      final response = await request.close();
      _throwIfFailed(uri, response);

      final canResume =
          resumeFrom > 0 && response.statusCode == HttpStatus.partialContent;
      if (resumeFrom > 0 && !canResume) {
        await tempFile.delete();
      }

      final sink = tempFile.openWrite(
        mode: canResume ? FileMode.append : FileMode.write,
      );
      var receivedBytes = canResume ? resumeFrom : 0;
      final contentLength =
          response.contentLength >= 0 ? response.contentLength : null;
      final totalBytes = contentLength == null
          ? null
          : canResume
              ? resumeFrom + contentLength
              : contentLength;

      try {
        await for (final chunk in response.timeout(_receiveTimeout)) {
          cancelToken?.throwIfCancelled();
          receivedBytes += chunk.length;
          sink.add(chunk);
          onProgress?.call(
            SongDownloadProgress(
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
            ),
          );
        }
      } finally {
        await sink.close();
      }

      cancelToken?.throwIfCancelled();

      if (totalBytes != null && receivedBytes != totalBytes) {
        throw HttpException(
          'Only received $receivedBytes of $totalBytes bytes from $uri.',
          uri: uri,
        );
      }

      if (await target.exists()) {
        await target.delete();
      }
      await tempFile.rename(target.path);
    } on DownloadPausedException {
      keepPartialFile = true;
      rethrow;
    } finally {
      client.close(force: true);
      if (!keepPartialFile && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  HttpClient _newHttpClient() {
    return HttpClient()..connectionTimeout = _connectionTimeout;
  }

  Future<T> _withRetries<T>(Future<T> Function() action) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await action();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt == _maxAttempts || !_isRetryable(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        await Future<void>.delayed(_retryDelay * attempt);
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  bool _isRetryable(Object error) {
    return error is IOException || error is TimeoutException;
  }

  Future<List<int>> _readResponseBytes(
    Uri uri,
    HttpClientResponse response,
  ) async {
    final builder = BytesBuilder(copy: false);
    var receivedBytes = 0;
    final totalBytes =
        response.contentLength >= 0 ? response.contentLength : null;

    await for (final chunk in response.timeout(_receiveTimeout)) {
      receivedBytes += chunk.length;
      builder.add(chunk);
    }

    if (totalBytes != null && receivedBytes != totalBytes) {
      throw HttpException(
        'Only received $receivedBytes of $totalBytes bytes from $uri.',
        uri: uri,
      );
    }

    return builder.takeBytes();
  }

  void _throwIfFailed(Uri uri, HttpClientResponse response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'HTTP ${response.statusCode} while downloading $uri.',
        uri: uri,
      );
    }
  }
}

class DownloadCancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const DownloadPausedException();
    }
  }
}

class DownloadPausedException implements Exception {
  const DownloadPausedException();

  @override
  String toString() => 'Download paused.';
}

class SongDownloadProgress {
  const SongDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }
}
