import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/models/song_manifest_model.dart';

void main() {
  group('SongManifest', () {
    test('parses remote song assets', () {
      final manifest = SongManifest.fromJsonString('''
{
  "songs": [
    {
      "number": 1,
      "audioUrl": "https://example.com/audio/001.mp3",
      "lyricsUrl": "https://example.com/lyrics/001.elrc",
      "audioSize": 2450000,
      "lyricsSize": 12000,
      "audioSha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "lyricsSha256": "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
      "version": 2
    }
  ]
}
''');

      final asset = manifest.assetFor(1);

      expect(asset, isNotNull);
      expect(asset!.number, 1);
      expect(asset.hasAudio, isTrue);
      expect(asset.audioUrl.toString(), 'https://example.com/audio/001.mp3');
      expect(asset.lyricsUrl.toString(), 'https://example.com/lyrics/001.elrc');
      expect(asset.audioSizeBytes, 2450000);
      expect(asset.lyricsSizeBytes, 12000);
      expect(asset.audioSha256, List.filled(64, 'a').join());
      expect(asset.lyricsSha256, List.filled(64, 'b').join());
      expect(asset.version, 2);
    });

    test('parses catalog metadata without requiring downloadable audio', () {
      final manifest = SongManifest.fromJsonString('''
{
  "songs": [
    {
      "number": 163,
      "title": "A Newly Added Song",
      "durationMs": 194000
    }
  ]
}
''');

      final asset = manifest.assetFor(163)!;
      expect(asset.title, 'A Newly Added Song');
      expect(asset.durationMs, 194000);
      expect(asset.hasCatalogMetadata, isTrue);
      expect(asset.hasAudio, isFalse);
    });

    test('rejects duplicate song numbers', () {
      expect(
        () => SongManifest.fromJsonString('''
{
  "songs": [
    {"number": 163, "title": "First"},
    {"number": 163, "title": "Duplicate"}
  ]
}
'''),
        throwsFormatException,
      );
    });

    test('rejects non-positive numbers and empty metadata', () {
      expect(
        () => SongManifest.fromJsonString(
          '{"songs":[{"number":0,"title":"Invalid"}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => SongManifest.fromJsonString(
          '{"songs":[{"number":163,"title":"  "}]}',
        ),
        throwsFormatException,
      );
    });

    test('defaults version to 1', () {
      final manifest = SongManifest.fromJsonString('''
{
  "songs": [
    {
      "number": 2,
      "audioUrl": "https://example.com/audio/002.mp3",
      "audioSize": 42
    }
  ]
}
''');

      expect(manifest.assetFor(2)?.version, 1);
    });

    test('resolves relative URLs against the manifest URL', () {
      final manifest = SongManifest.fromJsonString(
        '''
{
  "songs": [
    {
      "number": 3,
      "audioUrl": "audio/003.mp3",
      "lyricsUrl": "lyrics/003.elrc",
      "audioSize": 42,
      "lyricsSize": 42
    }
  ]
}
''',
        baseUri: Uri.parse('https://example.com/downloads/manifest.json'),
      );

      final asset = manifest.assetFor(3);

      expect(
        asset?.audioUrl.toString(),
        'https://example.com/downloads/audio/003.mp3',
      );
      expect(
        asset?.lyricsUrl.toString(),
        'https://example.com/downloads/lyrics/003.elrc',
      );
    });

    test('parses legacy integrity metadata but validates supplied hashes', () {
      final legacy = SongManifest.fromJsonString('''
{"songs":[{"number":1,"audioUrl":"https://example.com/1.mp3","audioSize":12}]}
''');
      expect(legacy.assetFor(1)?.audioSha256, isNull);

      expect(
        () => SongManifest.fromJsonString('''
{"songs":[{"number":1,"audioUrl":"https://example.com/1.mp3","audioSize":12,"audioSha256":"not-a-digest"}]}
'''),
        throwsFormatException,
      );
    });

    test('downloadable assets require bounded positive declared sizes', () {
      for (final size in <int>[0, -1, RemoteSongAsset.maxAudioSizeBytes + 1]) {
        expect(
          () => SongManifest.fromJsonString(
            '{"songs":[{"number":1,"audioUrl":"https://example.com/1.mp3","audioSize":$size}]}',
          ),
          throwsFormatException,
        );
      }
      expect(
        () => SongManifest.fromJsonString(
          '{"songs":[{"number":1,"audioUrl":"https://example.com/1.mp3"}]}',
        ),
        throwsFormatException,
      );
    });

    test('rejects insecure, credentialed, fragmented and cross-origin URLs',
        () {
      const invalidUrls = <String>[
        'http://example.com/1.mp3',
        'ftp://example.com/1.mp3',
        'https://user:pass@example.com/1.mp3',
        'https://example.com/1.mp3#fragment',
      ];
      for (final url in invalidUrls) {
        expect(
          () => SongManifest.fromJsonString(
            '{"songs":[{"number":1,"audioUrl":"$url","audioSize":12}]}',
          ),
          throwsFormatException,
          reason: url,
        );
      }

      expect(
        () => SongManifest.fromJsonString(
          '{"songs":[{"number":1,"audioUrl":"https://cdn.example/1.mp3","audioSize":12}]}',
          baseUri: Uri.parse('https://example.com/manifest.json'),
        ),
        throwsFormatException,
      );
    });

    test('rejects an insecure manifest origin', () {
      expect(
        () => SongManifest.fromJsonString(
          '{"songs":[{"number":1,"audioUrl":"1.mp3","audioSize":12}]}',
          baseUri: Uri.parse('http://example.com/manifest.json'),
        ),
        throwsFormatException,
      );
      expect(
        () => SongManifest.validateManifestUri(
          Uri.parse('https://example.com/manifest.json#fragment'),
        ),
        throwsFormatException,
      );
    });
  });
}
