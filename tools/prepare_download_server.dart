import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) async {
  var sourceRoot = Directory.current.path;
  var outputRoot = p.join(sourceRoot, 'build', 'download_server');

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--source':
        sourceRoot = _readArgValue(args, ++i, '--source');
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

  final sourceAudioDir = Directory(p.join(sourceRoot, 'assets', 'audio'));
  final sourceLyricsDir = Directory(p.join(sourceRoot, 'assets', 'lyrics'));
  if (!sourceAudioDir.existsSync()) {
    throw StateError('Audio directory not found: ${sourceAudioDir.path}');
  }

  final outputDir = Directory(outputRoot);
  final outputAudioDir = Directory(p.join(outputRoot, 'audio'));
  final outputLyricsDir = Directory(p.join(outputRoot, 'lyrics'));
  outputAudioDir.createSync(recursive: true);
  outputLyricsDir.createSync(recursive: true);

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
    audioFile.copySync(targetAudio.path);

    final lyricsFile = File(p.join(sourceLyricsDir.path, '$paddedNumber.elrc'));
    File? targetLyrics;
    if (lyricsFile.existsSync()) {
      targetLyrics = File(p.join(outputLyricsDir.path, '$paddedNumber.elrc'));
      lyricsFile.copySync(targetLyrics.path);
    }

    songs.add({
      'number': number,
      'audioUrl': 'audio/$paddedNumber.mp3',
      if (targetLyrics != null) 'lyricsUrl': 'lyrics/$paddedNumber.elrc',
      'audioSize': targetAudio.lengthSync(),
      if (targetLyrics != null) 'lyricsSize': targetLyrics.lengthSync(),
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

String _readArgValue(List<String> args, int index, String name) {
  if (index >= args.length) {
    throw ArgumentError('Missing value for $name');
  }
  return args[index];
}

void _printUsage() {
  stdout.writeln('Usage: dart run tools/prepare_download_server.dart');
  stdout.writeln('       [--source <repo-root>] [--output <directory>]');
}
