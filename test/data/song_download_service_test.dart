import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';

void main() {
  group('SongDownloadService response validation', () {
    test('checks both declared size and SHA-256 using a file stream', () async {
      final directory = await Directory.systemTemp.createTemp('song-integrity');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/asset.bin');
      await file.writeAsString('abc');

      expect(
        await SongDownloadService.hasExpectedIntegrity(
          file,
          expectedSize: 3,
          expectedSha256:
              'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
        isTrue,
      );
      expect(
        await SongDownloadService.hasExpectedIntegrity(
          file,
          expectedSize: 2,
          expectedSha256: null,
        ),
        isFalse,
      );
      expect(
        await SongDownloadService.hasExpectedIntegrity(
          file,
          expectedSize: 3,
          expectedSha256: List.filled(64, '0').join(),
        ),
        isFalse,
      );
    });

    test('accepts only an exact resumed Content-Range', () {
      expect(
        SongDownloadService.isValidContentRange(
          value: 'bytes 40-99/100',
          resumeFrom: 40,
          expectedSize: 100,
        ),
        isTrue,
      );

      for (final value in <String?>[
        null,
        'bytes 39-99/100',
        'bytes 40-98/100',
        'bytes 40-99/101',
        'items 40-99/100',
        'bytes */100',
      ]) {
        expect(
          SongDownloadService.isValidContentRange(
            value: value,
            resumeFrom: 40,
            expectedSize: 100,
          ),
          isFalse,
          reason: value,
        );
      }
    });

    test('allows same-origin HTTPS redirect chains', () {
      expect(
        () => SongDownloadService.validateRedirectChain(
          Uri.parse('https://example.com/assets/song.mp3'),
          <Uri>[
            Uri.parse('/signed/song.mp3?token=public'),
            Uri.parse('https://example.com/final/song.mp3'),
          ],
        ),
        returnsNormally,
      );
    });

    test('rejects cross-origin and credentialed redirects', () {
      expect(
        () => SongDownloadService.validateRedirectChain(
          Uri.parse('https://example.com/song.mp3'),
          <Uri>[Uri.parse('https://cdn.example/song.mp3')],
        ),
        throwsFormatException,
      );
      expect(
        () => SongDownloadService.validateRedirectChain(
          Uri.parse('https://example.com/song.mp3'),
          <Uri>[Uri.parse('https://user:pass@example.com/song.mp3')],
        ),
        throwsFormatException,
      );
    });
  });
}
