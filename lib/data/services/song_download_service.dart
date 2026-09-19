import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

  static bool isValidContentRange({
    required String? value,
    required int resumeFrom,
    required int expectedSize,
  }) {
    if (value == null) return false;
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(value);
    if (match == null) return false;
    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final total = int.tryParse(match.group(3)!);
    return start == resumeFrom &&
        total == expectedSize &&
        end == expectedSize - 1 &&
        resumeFrom < expectedSize;
  }

  static void validateRedirectChain(
    Uri requestedUri,
    Iterable<Uri> redirectLocations,
  ) {
    var currentUri = requestedUri;
    for (final location in redirectLocations) {
      currentUri = currentUri.resolveUri(location);
      SongManifest.validateAssetUri(
        currentUri,
        manifestUri: requestedUri,
      );
    }
  }

  static Future<bool> hasExpectedIntegrity(
    File file, {
    required int expectedSize,
    required String? expectedSha256,
  }) async {
    if (!await file.exists()) return false;
    if (await file.length() != expectedSize) return false;
    if (expectedSha256 == null) return true;
    final actual = await sha256.bind(file.openRead()).first;
    return actual.toString() == expectedSha256;
  }

  final SongsRepository _songsRepository;
  final LyricsRepository _lyricsRepository;

  Future<SongManifest> fetchManifest(Uri manifestUri) async {
    SongManifest.validateManifestUri(manifestUri);
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
    if (!await _fileMatchesExpectedIntegrity(
      audioFile,
      expectedSize: asset.audioSizeBytes!,
      expectedSha256: asset.audioSha256,
    )) {
      await _downloadToFile(
        uri: audioUrl,
        target: audioFile,
        expectedSize: asset.audioSizeBytes!,
        expectedSha256: asset.audioSha256,
        maximumSize: RemoteSongAsset.maxAudioSizeBytes,
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
      if (!await _fileMatchesExpectedIntegrity(
        lyricsFile,
        expectedSize: asset.lyricsSizeBytes!,
        expectedSha256: asset.lyricsSha256,
      )) {
        await _downloadToFile(
          uri: lyricsUrl,
          target: lyricsFile,
          expectedSize: asset.lyricsSizeBytes!,
          expectedSha256: asset.lyricsSha256,
          maximumSize: RemoteSongAsset.maxLyricsSizeBytes,
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
    if (!await _fileMatchesExpectedIntegrity(
      lyricsFile,
      expectedSize: asset.lyricsSizeBytes!,
      expectedSha256: asset.lyricsSha256,
    )) {
      await _downloadToFile(
        uri: lyricsUrl,
        target: lyricsFile,
        expectedSize: asset.lyricsSizeBytes!,
        expectedSha256: asset.lyricsSha256,
        maximumSize: RemoteSongAsset.maxLyricsSizeBytes,
      );
    }
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
    final downloadsRoot = await _downloadsRoot();
    for (final file in await _downloadFilesForSong(song)) {
      if (await file.exists() &&
          await _isWithinCanonicalRoot(file, downloadsRoot)) {
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
      _validateRedirects(uri, response);
      _throwIfFailed(uri, response);
      final bytes = await _readResponseBytes(
        uri,
        response,
        maximumSize: SongManifest.maxEncodedBytes,
      );
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
    final downloadsRoot = await _downloadsRoot();
    final paddedNumber = songNumber.toString().padLeft(3, '0');
    return File(
      p.join(
        downloadsRoot.path,
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

  Future<Directory> _downloadsRoot() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDir.path, 'downloads'));
  }

  Future<bool> _fileMatchesExpectedIntegrity(
    File file, {
    required int expectedSize,
    required String? expectedSha256,
  }) async {
    return hasExpectedIntegrity(
      file,
      expectedSize: expectedSize,
      expectedSha256: expectedSha256,
    );
  }

  Future<void> _downloadToFile({
    required Uri uri,
    required File target,
    required int expectedSize,
    required String? expectedSha256,
    required int maximumSize,
    DownloadCancelToken? cancelToken,
    SongDownloadProgressCallback? onProgress,
  }) async {
    SongManifest.validateManifestUri(uri);
    if (expectedSize <= 0 || expectedSize > maximumSize) {
      throw ArgumentError.value(
        expectedSize,
        'expectedSize',
        'Expected size is outside the allowed range.',
      );
    }
    await _withRetries(
      () => _downloadToFileOnce(
        uri: uri,
        target: target,
        expectedSize: expectedSize,
        expectedSha256: expectedSha256,
        maximumSize: maximumSize,
        cancelToken: cancelToken,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _downloadToFileOnce({
    required Uri uri,
    required File target,
    required int expectedSize,
    required String? expectedSha256,
    required int maximumSize,
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
      _validateRedirects(uri, response);
      if (resumeFrom > 0 &&
          response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await tempFile.delete();
      }
      _throwIfFailed(uri, response);

      var canResume = false;
      if (resumeFrom > 0 && response.statusCode == HttpStatus.partialContent) {
        if (!_validContentRange(response, resumeFrom, expectedSize)) {
          await tempFile.delete();
          throw HttpException(
            'Server returned an invalid Content-Range for $uri.',
            uri: uri,
          );
        }
        canResume = true;
      } else if (resumeFrom > 0) {
        // A server may legitimately ignore Range and return a complete 200.
        // Discard the partial file and consume this response from byte zero.
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

      if (expectedSize > maximumSize ||
          resumeFrom > expectedSize ||
          (totalBytes != null && totalBytes != expectedSize)) {
        throw HttpException(
          'Download size does not match the manifest for $uri.',
          uri: uri,
        );
      }

      try {
        await for (final chunk in response.timeout(_receiveTimeout)) {
          cancelToken?.throwIfCancelled();
          receivedBytes += chunk.length;
          if (receivedBytes > expectedSize || receivedBytes > maximumSize) {
            throw HttpException(
              'Download exceeded its allowed size for $uri.',
              uri: uri,
            );
          }
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

      if (receivedBytes != expectedSize) {
        throw HttpException(
          'Received $receivedBytes of $expectedSize declared bytes from $uri.',
          uri: uri,
        );
      }

      final actualSha256 = await _sha256Of(tempFile);
      if (expectedSha256 != null && actualSha256 != expectedSha256) {
        throw HttpException(
          'SHA-256 verification failed for $uri.',
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
    HttpClientResponse response, {
    required int maximumSize,
  }) async {
    final builder = BytesBuilder(copy: false);
    var receivedBytes = 0;
    final totalBytes =
        response.contentLength >= 0 ? response.contentLength : null;
    if (totalBytes != null && totalBytes > maximumSize) {
      throw HttpException('Response from $uri is too large.', uri: uri);
    }

    await for (final chunk in response.timeout(_receiveTimeout)) {
      receivedBytes += chunk.length;
      if (receivedBytes > maximumSize) {
        throw HttpException('Response from $uri is too large.', uri: uri);
      }
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

  bool _validContentRange(
    HttpClientResponse response,
    int resumeFrom,
    int expectedSize,
  ) {
    return isValidContentRange(
      value: response.headers.value(HttpHeaders.contentRangeHeader),
      resumeFrom: resumeFrom,
      expectedSize: expectedSize,
    );
  }

  void _validateRedirects(Uri requestedUri, HttpClientResponse response) {
    validateRedirectChain(
      requestedUri,
      response.redirects.map((redirect) => redirect.location),
    );
  }

  Future<String> _sha256Of(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<bool> _isWithinCanonicalRoot(File file, Directory root) async {
    try {
      await root.create(recursive: true);
      final canonicalRoot = await root.resolveSymbolicLinks();
      final canonicalFile = await file.resolveSymbolicLinks();
      return p.isWithin(canonicalRoot, canonicalFile);
    } on FileSystemException {
      return false;
    }
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
