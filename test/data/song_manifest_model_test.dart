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
      "version": 2
    }
  ]
}
''');

      final asset = manifest.assetFor(1);

      expect(asset, isNotNull);
      expect(asset!.number, 1);
      expect(asset.audioUrl.toString(), 'https://example.com/audio/001.mp3');
      expect(asset.lyricsUrl.toString(), 'https://example.com/lyrics/001.elrc');
      expect(asset.audioSizeBytes, 2450000);
      expect(asset.lyricsSizeBytes, 12000);
      expect(asset.version, 2);
    });

    test('defaults version to 1', () {
      final manifest = SongManifest.fromJsonString('''
{
  "songs": [
    {
      "number": 2,
      "audioUrl": "https://example.com/audio/002.mp3"
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
      "lyricsUrl": "lyrics/003.elrc"
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
  });
}
