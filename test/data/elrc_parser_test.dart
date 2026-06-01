import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/parsers/elrc_parser.dart';

void main() {
  group('ElrcParser', () {
    const sampleElrc = '''
[ti:Jehovah Is Your Name]
[ar:Kingdom Songs]
[00:04.50]<00:04.50>Je- <00:05.10>ho- <00:05.60>vah <00:06.20>is <00:06.80>your <00:07.20>name,
[00:08.00]<00:08.00>A- <00:08.50>bove <00:09.10>all <00:09.60>names <00:10.20>you <00:10.70>reign.
''';

    test('parses two lines', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.lines.length, 2);
    });

    test('first line starts at 4500 ms', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.lines[0].startMs, 4500);
    });

    test('first line has 6 words', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.lines[0].words.length, 6);
    });

    test('first word of first line starts at 4500 ms', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.lines[0].words[0].startMs, 4500);
      expect(lyrics.lines[0].words[0].text, 'Je-');
    });

    test('words are monotonically increasing', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      for (final line in lyrics.lines) {
        for (var i = 0; i < line.words.length - 1; i++) {
          expect(
            line.words[i].startMs,
            lessThanOrEqualTo(line.words[i + 1].startMs),
          );
        }
      }
    });

    test('activeLineIndexAt returns -1 before first line', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.activeLineIndexAt(0), -1);
    });

    test('activeLineIndexAt returns 0 during first line', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.activeLineIndexAt(5000), 0);
    });

    test('activeLineIndexAt returns 1 during second line', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.activeLineIndexAt(9000), 1);
    });

    test('activeLineIndexAt returns -1 after the last synced line ends', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      expect(lyrics.activeLineIndexAt(12000), -1);
    });

    test('explicit trailing timestamp marks line end before the next line', () {
      const elrc = '''
[00:04.00]<00:04.00>First <00:05.00>line<00:06.00>
[00:10.00]<00:10.00>Second <00:11.00>line<00:12.00>
''';

      final lyrics = ElrcParser.parse(elrc);
      expect(lyrics.lines[0].endMs, 6000);
      expect(lyrics.lines[0].words.last.endMs, 6000);
      expect(lyrics.activeLineIndexAt(7000), -1);
      expect(lyrics.activeLineIndexAt(10000), 1);
    });

    test('instrumental indicator appears only for gaps of at least 2 seconds',
        () {
      const elrc = '''
[00:04.00]<00:04.00>First <00:05.00>line<00:06.00>
[00:07.50]<00:07.50>Short <00:08.00>gap<00:08.50>
[00:12.00]<00:12.00>Long <00:12.50>gap<00:13.00>
''';

      final lyrics = ElrcParser.parse(elrc);
      expect(lyrics.hasInstrumentalGapAt(6500), isFalse);
      expect(lyrics.hasInstrumentalGapAt(9500), isTrue);
    });

    test('instrumental indicator stops after the song ends', () {
      const elrc = '''
[00:04.00]<00:04.00>Final <00:05.00>line<00:06.00>
''';

      final lyrics = ElrcParser.parse(elrc);
      expect(lyrics.hasInstrumentalGapAt(7000, songEndMs: 10000), isTrue);
      expect(lyrics.hasInstrumentalGapAt(10000, songEndMs: 10000), isFalse);
      expect(lyrics.hasInstrumentalGapAt(11000, songEndMs: 10000), isFalse);
      expect(lyrics.hasInstrumentalGapAt(7000), isFalse);
    });

    test('skips metadata lines', () {
      final lyrics = ElrcParser.parse(sampleElrc);
      for (final line in lyrics.lines) {
        expect(line.text, isNot(contains('ti:')));
      }
    });
  });
}
