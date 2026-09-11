import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/core/platform/lyrics_overlay_bubble.dart';

void main() {
  group('shouldSuppressFloatingLyricsForLocation', () {
    test('suppresses the overlay on Now Playing routes', () {
      expect(shouldSuppressFloatingLyricsForLocation('/now-playing'), isTrue);
      expect(
        shouldSuppressFloatingLyricsForLocation('/now-playing?song=1'),
        isTrue,
      );
      expect(
        shouldSuppressFloatingLyricsForLocation('/now-playing/details'),
        isTrue,
      );
    });

    test('keeps the overlay available on the other app tabs', () {
      expect(shouldSuppressFloatingLyricsForLocation('/library'), isFalse);
      expect(shouldSuppressFloatingLyricsForLocation('/favorites'), isFalse);
      expect(shouldSuppressFloatingLyricsForLocation('/settings'), isFalse);
      expect(
        shouldSuppressFloatingLyricsForLocation('/now-playing-preview'),
        isFalse,
      );
    });

    test('handles null and empty strings gracefully', () {
      expect(shouldSuppressFloatingLyricsForLocation(''), isFalse);
      expect(shouldSuppressFloatingLyricsForLocation('/'), isFalse);
    });

    test('handles invalid URIs without crashing', () {
      expect(
        shouldSuppressFloatingLyricsForLocation('not a url at all'),
        isFalse,
      );
    });
  });

  group('ExternalLyricsOverlayState.toChannelArguments', () {
    test('serializes the complete native overlay state', () {
      const state = ExternalLyricsOverlayState(
        number: '001',
        title: "Jehovah's Attributes",
        line: 'Jehovah our God',
        nextLine: 'Creator of life',
        lyricLines: ['1000\t2000\tJehovah our God'],
        positionMs: 1200,
        durationMs: 159000,
        playing: true,
        canControl: true,
        darkTheme: true,
      );

      expect(state.toChannelArguments(), {
        'number': '001',
        'title': "Jehovah's Attributes",
        'line': 'Jehovah our God',
        'nextLine': 'Creator of life',
        'lyricLines': ['1000\t2000\tJehovah our God'],
        'positionMs': 1200,
        'durationMs': 159000,
        'playing': true,
        'canControl': true,
        'darkTheme': true,
      });
    });

    test('serializes empty lyric lines', () {
      const state = ExternalLyricsOverlayState(
        number: '002',
        title: 'Empty Song',
        line: 'No lyrics',
        nextLine: '',
        lyricLines: [],
        positionMs: 0,
        durationMs: 0,
        playing: false,
        canControl: false,
        darkTheme: false,
      );

      final args = state.toChannelArguments();
      expect(args['lyricLines'], isEmpty);
      expect(args['playing'], isFalse);
      expect(args['darkTheme'], isFalse);
    });

    test('serializes multiple lyric lines', () {
      const state = ExternalLyricsOverlayState(
        number: '003',
        title: 'Multi-line',
        line: 'Line 2',
        nextLine: 'Line 3',
        lyricLines: [
          '0\t1000\tLine 1',
          '1000\t2000\tLine 2',
          '2000\t3000\tLine 3',
        ],
        positionMs: 1500,
        durationMs: 3000,
        playing: true,
        canControl: true,
        darkTheme: true,
      );

      final args = state.toChannelArguments();
      expect(args['lyricLines'], hasLength(3));
      expect(args['positionMs'], 1500);
      expect(args['durationMs'], 3000);
    });

    test('all values have correct types for platform channel serialization',
        () {
      const state = ExternalLyricsOverlayState(
        number: '001',
        title: 'Test',
        line: 'Line',
        nextLine: 'Next',
        lyricLines: ['0\t1000\tLine'],
        positionMs: 500,
        durationMs: 1000,
        playing: true,
        canControl: false,
        darkTheme: true,
      );

      final args = state.toChannelArguments();
      expect(args['number'], isA<String>());
      expect(args['title'], isA<String>());
      expect(args['line'], isA<String>());
      expect(args['nextLine'], isA<String>());
      expect(args['lyricLines'], isA<List<String>>());
      expect(args['positionMs'], isA<int>());
      expect(args['durationMs'], isA<int>());
      expect(args['playing'], isA<bool>());
      expect(args['canControl'], isA<bool>());
      expect(args['darkTheme'], isA<bool>());
    });
  });
}
