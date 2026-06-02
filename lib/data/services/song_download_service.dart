import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_manifest_model.dart';
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

  final SongsRepository _songsRepository;
  final LyricsRepository _lyricsRepository;

  Future<SongManifest> fetchManifest(Uri manifestUri) async {
    final content = await _readUriAsString(manifestUri);
    return SongManifest.fromJsonString(content);
  }

  Future<void> downloadSong({
    required Song song,
    required RemoteSongAsset asset,
    SongDownloadProgressCallback? onAudioProgress,
  }) async {
    if (song.number != asset.number) {
      throw ArgumentError.value(
        asset.number,
        'asset.number',
        'Manifest asset does not match song ${song.number}.',
      );
    }

    final audioFile = await _downloadTarget(
      songNumber: song.number,
      folder: 'audio',
      extension: 'mp3',
    );
    await _downloadToFile(
      uri: asset.audioUrl,
      target: audioFile,
      onProgress: onAudioProgress,
    );

    final lyricsUrl = asset.lyricsUrl;
    if (lyricsUrl != null) {
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
    }

    await _songsRepository.markDownloaded(
      song,
      audioFilePath: audioFile.path,
    );
  }

  Future<String> _readUriAsString(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      _throwIfFailed(uri, response);
      return response.transform(utf8.decoder).join();
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

  Future<void> _downloadToFile({
    required Uri uri,
    required File target,
    SongDownloadProgressCallback? onProgress,
  }) async {
    final client = HttpClient();
    final tempFile = File('${target.path}.part');

    try {
      await target.parent.create(recursive: true);
      final request = await client.getUrl(uri);
      final response = await request.close();
      _throwIfFailed(uri, response);

      final sink = tempFile.openWrite();
      var receivedBytes = 0;
      final totalBytes =
          response.contentLength >= 0 ? response.contentLength : null;

      try {
        await for (final chunk in response) {
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

      if (await target.exists()) {
        await target.delete();
      }
      await tempFile.rename(target.path);
    } finally {
      client.close(force: true);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
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
