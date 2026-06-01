import 'package:jwsongbook/data/models/synced_lyrics_model.dart';

/// Parses Enhanced LRC (.elrc) files into a [SyncedLyrics] model.
///
/// Supported format (KS-Sync spec):
/// ```
/// [ti:Song Title]
/// [ar:Kingdom Songs]
/// [00:04.50]<00:04.50>Sing <00:05.10>praises <00:05.80>to <00:06.20>Jehovah,
/// [00:08.00]<00:08.00>His <00:08.40>name <00:08.90>is ...
/// ```
///
/// Line timestamps use `[mm:ss.xx]` where xx = hundredths of a second.
/// Word timestamps use `<mm:ss.xx>` inline with each word token. A final
/// timestamp without text marks the explicit end of the line:
/// `[00:10.00]<00:10.00>Hello <00:11.00>world<00:13.00>`.
///
/// Throws [ElrcParseException] if the file is malformed.
abstract final class ElrcParser {
  static final _lineTimestampRe = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2})\]');
  static final _wordTimestampRe = RegExp(r'<(\d{2}):(\d{2})\.(\d{2})>([^<\[]*)?');
  static final _metadataRe = RegExp(r'^\[(ti|ar|al|by|offset):(.+)\]$');

  static SyncedLyrics parse(String content) {
    final rawLines = content.split('\n').map((l) => l.trim()).toList();
    final syncedLines = <SyncedLine>[];

    for (final rawLine in rawLines) {
      if (rawLine.isEmpty) continue;
      if (_metadataRe.hasMatch(rawLine)) continue; // skip [ti:...] etc.

      final lineMatch = _lineTimestampRe.firstMatch(rawLine);
      if (lineMatch == null) continue;

      final lineStartMs = _matchToMs(lineMatch);
      final rest = rawLine.substring(lineMatch.end);

      if (rest.trim().isEmpty) continue; // timestamp-only line (instrumental)

      final words = _parseWords(rest);
      if (words.isEmpty) continue;

      final lineEndMs = words.last.endMs;
      final lineText = words.map((w) => w.text.trim()).join(' ');

      syncedLines.add(
        SyncedLine(
          index: syncedLines.length,
          startMs: lineStartMs,
          endMs: lineEndMs,
          text: lineText,
          words: words,
        ),
      );
    }

    return SyncedLyrics(lines: syncedLines);
  }

  static List<SyncedWord> _parseWords(String segment) {
    final matches = _wordTimestampRe.allMatches(segment).toList();
    if (matches.isEmpty) return [];

    final words = <SyncedWord>[];

    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final startMs = _matchToMs(m);
      final rawText = (m.group(4) ?? '').trim();
      if (rawText.isEmpty) continue;

      // endMs: start of next word, or startMs + a generous 500 ms for last word.
      final endMs = i + 1 < matches.length
          ? _matchToMs(matches[i + 1])
          : startMs + 500;

      words.add(
        SyncedWord(
          index: words.length,
          startMs: startMs,
          endMs: endMs,
          text: rawText,
        ),
      );
    }

    return words;
  }

  /// Convert `[mm:ss.xx]` or `<mm:ss.xx>` match groups 1-3 to milliseconds.
  static int _matchToMs(RegExpMatch m) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    final centis = int.parse(m.group(3)!);
    return (minutes * 60 * 1000) + (seconds * 1000) + (centis * 10);
  }
}

class ElrcParseException implements Exception {
  const ElrcParseException(this.message);
  final String message;

  @override
  String toString() => 'ElrcParseException: $message';
}
