import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  var sourceRoot = Directory.current.path;
  String? audioDirArg;
  String? lyricsDirArg;
  var outputRoot = p.join(sourceRoot, 'build', 'download_server');

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--source':
        sourceRoot = _readArgValue(args, ++i, '--source');
      case '--audio-dir':
        audioDirArg = _readArgValue(args, ++i, '--audio-dir');
      case '--lyrics-dir':
        lyricsDirArg = _readArgValue(args, ++i, '--lyrics-dir');
      case '--output':
        outputRoot = _readArgValue(args, ++i, '--output');
      case '--help':
      case '-h':
        _printUsage();
        return;
      default:
        stderr.writeln('Unknown argument: ${args[i]}');
        _printUsage();
        exitCode = 64;
        return;
    }
  }

  final sourceAudioDir = audioDirArg == null
      ? _defaultAudioDir(sourceRoot)
      : Directory(audioDirArg);
  final sourceLyricsDir = lyricsDirArg == null
      ? _defaultLyricsDir(sourceRoot)
      : Directory(lyricsDirArg);
  if (!sourceAudioDir.existsSync()) {
    throw StateError('Audio directory not found: ${sourceAudioDir.path}');
  }

  final outputDir = Directory(outputRoot);
  final outputAudioDir = Directory(p.join(outputRoot, 'audio'));
  final outputLyricsDir = Directory(p.join(outputRoot, 'lyrics'));
  outputAudioDir.createSync(recursive: true);
  outputLyricsDir.createSync(recursive: true);
  final existingMetadata = _readExistingMetadata(outputDir);

  final audioFiles = sourceAudioDir
      .listSync()
      .whereType<File>()
      .where((file) => p.extension(file.path).toLowerCase() == '.mp3')
      .toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final songs = <Map<String, Object?>>[];
  for (final audioFile in audioFiles) {
    final number = int.tryParse(p.basenameWithoutExtension(audioFile.path));
    if (number == null) continue;

    final paddedNumber = number.toString().padLeft(3, '0');
    final targetAudio = File(p.join(outputAudioDir.path, '$paddedNumber.mp3'));
    _copyIfDifferent(audioFile, targetAudio);

    final lyricsFile = File(p.join(sourceLyricsDir.path, '$paddedNumber.elrc'));
    File? targetLyrics;
    if (lyricsFile.existsSync()) {
      targetLyrics = File(p.join(outputLyricsDir.path, '$paddedNumber.elrc'));
      _copyIfDifferent(lyricsFile, targetLyrics);
    }

    final metadata = existingMetadata[number];
    songs.add({
      'number': number,
      if (metadata?['title'] case final String title) 'title': title,
      if (metadata?['durationMs'] case final int durationMs)
        'durationMs': durationMs,
      'audioUrl': 'audio/$paddedNumber.mp3',
      if (targetLyrics != null) 'lyricsUrl': 'lyrics/$paddedNumber.elrc',
      'audioSize': targetAudio.lengthSync(),
      'audioSha256': await _sha256File(targetAudio),
      if (targetLyrics != null) 'lyricsSize': targetLyrics.lengthSync(),
      if (targetLyrics != null) 'lyricsSha256': await _sha256File(targetLyrics),
      'version': 1,
    });
  }

  final manifest = {
    'version': 1,
    'songs': songs,
  };

  final manifestFile = File(p.join(outputDir.path, 'manifest.json'));
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  stdout.writeln('Prepared ${songs.length} songs in ${outputDir.path}');
  stdout.writeln('Manifest: ${manifestFile.path}');
}

Future<String> _sha256File(File file) async {
  return (await sha256.bind(file.openRead()).first).toString();
}

Map<int, Map<String, Object?>> _readExistingMetadata(Directory outputDir) {
  final manifestFile = File(p.join(outputDir.path, 'manifest.json'));
  if (!manifestFile.existsSync()) return const {};

  try {
    final decoded = jsonDecode(manifestFile.readAsStringSync());
    if (decoded is! Map<String, Object?>) return const {};
    final songs = decoded['songs'];
    if (songs is! List<Object?>) return const {};
    final metadata = <int, Map<String, Object?>>{};
    for (final item in songs) {
      if (item is! Map<String, Object?>) continue;
      final number = item['number'];
      if (number is! int) continue;
      final title = item['title'];
      final durationMs = item['durationMs'];
      metadata[number] = {
        if (title is String && title.trim().isNotEmpty) 'title': title.trim(),
        if (durationMs is int && durationMs >= 0) 'durationMs': durationMs,
      };
    }
    return metadata;
  } on FormatException {
    return const {};
  }
}

Directory _defaultAudioDir(String sourceRoot) {
  final downloadRepoAudio = Directory(p.join(sourceRoot, 'audio'));
  if (downloadRepoAudio.existsSync()) return downloadRepoAudio;
  return Directory(p.join(sourceRoot, 'assets', 'audio'));
}

Directory _defaultLyricsDir(String sourceRoot) {
  final downloadRepoLyrics = Directory(p.join(sourceRoot, 'lyrics'));
  if (downloadRepoLyrics.existsSync()) return downloadRepoLyrics;
  return Directory(p.join(sourceRoot, 'assets', 'lyrics'));
}

void _copyIfDifferent(File source, File target) {
  final sourcePath = p.normalize(p.absolute(source.path));
  final targetPath = p.normalize(p.absolute(target.path));
  if (sourcePath == targetPath) return;
  source.copySync(target.path);
}

String _readArgValue(List<String> args, int index, String name) {
  if (index >= args.length) {
    throw ArgumentError('Missing value for $name');
  }
  return args[index];
}

void _printUsage() {
  stdout.writeln('Usage: dart run tools/prepare_download_server.dart');
  stdout.writeln('       [--source <repo-root>] [--output <directory>]');
  stdout.writeln('       [--audio-dir <directory>] [--lyrics-dir <directory>]');
}
