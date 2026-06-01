/// In-memory representation of an entire song's synced lyrics.
///
/// After the DB rows are loaded (or the .elrc file is parsed), everything
/// is converted to this pure-Dart model so the sync engine never touches
/// the database during playback.
class SyncedLyrics {
  const SyncedLyrics({required this.lines});

  final List<SyncedLine> lines;

  bool get isEmpty => lines.isEmpty;

  /// Returns the index of the line active at [positionMs], or -1 outside the
  /// synced lyric range.
  int activeLineIndexAt(int positionMs) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (positionMs >= line.startMs && positionMs < line.endMs) return i;
    }
    return -1;
  }

  /// Returns true only when [positionMs] is inside a non-lyric gap long enough
  /// to deserve an instrumental indicator.
  bool hasInstrumentalGapAt(
    int positionMs, {
    int minGapMs = 2000,
    int? songEndMs,
  }) {
    if (lines.isEmpty || activeLineIndexAt(positionMs) >= 0) return false;

    final first = lines.first;
    if (positionMs < first.startMs) {
      return first.startMs >= minGapMs;
    }

    for (var i = 0; i < lines.length - 1; i++) {
      final current = lines[i];
      final next = lines[i + 1];
      if (positionMs >= current.endMs && positionMs < next.startMs) {
        return next.startMs - current.endMs >= minGapMs;
      }
    }

    final last = lines.last;
    if (songEndMs != null &&
        positionMs >= last.endMs &&
        positionMs < songEndMs) {
      return songEndMs - last.endMs >= minGapMs;
    }

    return false;
  }
}

class SyncedLine {
  const SyncedLine({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.words,
  });

  final int index;
  final int startMs;
  final int endMs;
  final String text;
  final List<SyncedWord> words;

  /// Returns the index of the word active at [positionMs], or -1.
  int activeWordIndexAt(int positionMs) {
    for (var i = words.length - 1; i >= 0; i--) {
      if (positionMs >= words[i].startMs) return i;
    }
    return -1;
  }

  /// Progress fraction (0.0–1.0) for the word highlight fill animation.
  /// Returns 0 if the line hasn't started; 1 if it has ended.
  double fillProgressAt(int positionMs, int wordIndex) {
    if (wordIndex < 0 || wordIndex >= words.length) return 0;
    final word = words[wordIndex];
    final elapsed = positionMs - word.startMs;
    final duration = word.endMs - word.startMs;
    if (duration <= 0) return 1;
    return (elapsed / duration).clamp(0.0, 1.0);
  }
}

class SyncedWord {
  const SyncedWord({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int index;
  final int startMs;
  final int endMs;
  final String text;

  bool isActiveAt(int positionMs) =>
      positionMs >= startMs && positionMs < endMs;
}
